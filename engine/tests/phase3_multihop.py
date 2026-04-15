#!/usr/bin/env python3
"""
S7 SkyQUBi — Phase 3: Multi-Hop Reasoning Chain with Circuit Breaker
=====================================================================
Tests the complete multi-hop QBIT Prism reasoning chain:

  - Ingest a larger polarized corpus (structure-dominant vs nurture-dominant)
  - Run 4 reasoning chains:
      Chain A: convergent — query aligns with corpus, hops stabilize (FERTILE)
      Chain B: divergent  — query misaligns, direction flip produces BABEL hops
      Chain C: breaker    — deliberately misaligned to trip ≥70% BABEL circuit
      Chain D: mixed      — starts FERTILE, drifts toward BABEL midchain
  - Store per-hop results in cws_memory.rag_reasoning
  - Store chain summaries in cws_memory.reasoning_chains
  - Store circuit breaker events in cws_core.circuit_breaker_events

Empirical targets (for patent Claim 18 / Claim 7):
  - Chain A: ≥70% FERTILE hops, converged=True
  - Chain B: significant BABEL hops, converged=False
  - Chain C: circuit_tripped=True (≥70% BABEL)
  - Chain D: mid-chain BABEL onset visible in hop-by-hop output

123Tech / 2XR, LLC — Patent Pending CWS-005
"""

import asyncio
import hashlib
import json
import sys
import os
import uuid

sys.path.insert(0, os.path.dirname(__file__))

import httpx
import psycopg2

from s7_prism import (
    decompose, direction_agreement, identify_planes, prism_summary, OCTI_PLANES
)
from s7_rag import (
    embed_text, register_dataset, ingest_document, retrieve
)

# ── Config ───────────────────────────────────────────────────────────────────

DB = dict(host="127.0.0.1", port=7090, dbname="s7_cws",
          user="s7", password=os.getenv("CWS_DB_PASS", ""))

OLLAMA_URL  = "http://127.0.0.1:7081"
EMBED_MODEL = "nomic-embed-text"

CIRCUIT_BREAKER_THRESHOLD = 0.70   # 70% BABEL trips the breaker
MAX_HOPS                  = 8      # max hops per chain before forced stop
FERTILE_PLANE_RATIO       = 0.50   # 50% planes must agree for FERTILE

# ── Polarized Corpus — 18 documents ──────────────────────────────────────────
# Structure-dominant (-1): rules, constraints, foundations, historical facts
# Nurture-dominant  (+1): growth, adaptation, creativity, future possibilities
# Door (0/neutral):        balanced, transitional, definitions

CORPUS = [
    # ── STRUCTURE pole (-1) — rigid, constraint, foundation ─────────────────
    {
        "title": "Laws of Thermodynamics — Foundational Constraints",
        "pole": "structure",
        "content": (
            "The laws of thermodynamics are absolute constraints on all physical systems. "
            "The first law states energy cannot be created or destroyed, only transformed. "
            "The second law states entropy always increases in an isolated system — disorder "
            "grows, never diminishes, without external work. The third law establishes absolute "
            "zero as an unreachable boundary. These laws are not engineering guidelines; "
            "they are inviolable boundaries that define the limits of all possible machines, "
            "processes, and transformations in the universe. No system may exceed them."
        ),
    },
    {
        "title": "Constitutional Law — Fixed Rights and Boundaries",
        "pole": "structure",
        "content": (
            "Constitutional law establishes the fundamental, fixed boundaries of governmental "
            "power. Rights enumerated in a constitution represent constraints that no legislation "
            "may transgress. Judicial review enforces these constraints through precedent — "
            "decisions made by prior courts bind future courts in identical circumstances. "
            "The principle of stare decisis preserves stability and predictability: established "
            "law holds unless overwhelmingly contradicted. The constitution is the foundation; "
            "all other law must conform to it or be struck down as void."
        ),
    },
    {
        "title": "Database ACID Properties — Immutable Guarantees",
        "pole": "structure",
        "content": (
            "ACID database properties define the non-negotiable guarantees of reliable data "
            "storage. Atomicity: every transaction either completes fully or not at all — "
            "partial writes do not exist. Consistency: every committed transaction brings the "
            "database from one valid state to another, never an intermediate invalid state. "
            "Isolation: concurrent transactions execute as if sequential, with no visible "
            "interference. Durability: once committed, data persists through any subsequent "
            "failure. These properties are constraints on database design, not optional features."
        ),
    },
    {
        "title": "CWS INSERT-Only Covenant — Structural Foundation",
        "pole": "structure",
        "content": (
            "The INSERT-only covenant of the Convergence Weight Schema is an inviolable "
            "architectural constraint. No memory entry, discernment result, or audit record "
            "may be updated or deleted at any privilege level. UPDATE and DELETE operations "
            "are prohibited by schema-level constraints, not application logic. Every piece "
            "of information that enters the system becomes a permanent part of its history. "
            "BABEL tokens are not erased — they are logged in the suppression table with "
            "full context. The past is immutable. The covenant cannot be configured away."
        ),
    },
    {
        "title": "Binary Logic — Fixed Truth Values",
        "pole": "structure",
        "content": (
            "Boolean logic operates on two fixed truth values: TRUE and FALSE. Every logical "
            "proposition must be one or the other — no intermediate state is permitted. "
            "The law of excluded middle holds: for any proposition P, either P is true or "
            "NOT-P is true, with no third possibility. Logical inference follows deterministic "
            "rules: modus ponens, modus tollens, contradiction. These rules do not bend to "
            "context or preference. A valid proof produces the same conclusion regardless of "
            "who examines it. Logic is the structure beneath all reasoning."
        ),
    },
    {
        "title": "Physical Constants — Unchanging Universe Parameters",
        "pole": "structure",
        "content": (
            "Physical constants define the fixed parameters of the universe. The speed of light "
            "in vacuum is exactly 299,792,458 meters per second — immutable and universal. "
            "Planck's constant determines the minimum quantum of action. The gravitational "
            "constant governs all mass attraction. The fine-structure constant determines "
            "electromagnetic interaction strength. These constants are not measured to finite "
            "precision and rounded — they define the boundaries within which all physics "
            "operates. No experiment can change them; they can only be measured more precisely."
        ),
    },

    # ── NURTURE pole (+1) — growth, adaptation, creativity ──────────────────
    {
        "title": "Evolutionary Adaptation — Continuous Change",
        "pole": "nurture",
        "content": (
            "Evolution is the engine of biological creativity. Through random mutation and "
            "natural selection, living systems continuously generate novel forms adapted to "
            "their changing environments. No current adaptation is final — every species is "
            "an experiment in progress, testing new configurations against ever-shifting "
            "conditions. Diversity is the reservoir of future potential. Extinction clears "
            "space for new possibilities. The tree of life grows outward at its edges, "
            "constantly exploring adjacent possibilities that did not exist before life "
            "invented them through the cumulative creativity of billions of generations."
        ),
    },
    {
        "title": "Machine Learning — Models That Grow From Data",
        "pole": "nurture",
        "content": (
            "Machine learning systems improve continuously through exposure to new data. "
            "A neural network begins as random weights and gradually learns complex patterns "
            "through gradient descent — each training step nudging parameters toward better "
            "performance. Transfer learning allows knowledge from one domain to fertilize "
            "another. Fine-tuning adapts general-purpose models to specific applications. "
            "Reinforcement learning allows models to improve through interaction with "
            "dynamic environments. The model grows; its knowledge expands; its capabilities "
            "deepen. Learning is never finished — it is a continuously open process."
        ),
    },
    {
        "title": "Creative Writing — Language as Living Growth",
        "pole": "nurture",
        "content": (
            "Creative writing generates new meaning through metaphor, narrative, and "
            "unexpected connection. A poem does not report facts — it grows new understanding "
            "from the soil of language itself. Stories allow readers to inhabit perspectives "
            "they have never lived, expanding empathy and imagination. Each generation of "
            "writers inherits the literary tradition and transforms it. Language evolves: "
            "new words form to capture new realities, old words acquire new meanings. "
            "Creativity is the capacity to see what has never been seen before and make "
            "it visible to others through the living medium of language."
        ),
    },
    {
        "title": "Open Source Software — Community-Grown Knowledge",
        "pole": "nurture",
        "content": (
            "Open source software grows through collective contribution. Thousands of "
            "developers across the world improve the same codebase — fixing bugs, adding "
            "features, extending capabilities in directions no single designer anticipated. "
            "Forking allows divergent experimentation: multiple futures branch from a "
            "single root. Merging brings the best experiments back together. The Linux "
            "kernel, born from a student's hobby project, now runs the internet, smartphones, "
            "and supercomputers. Open source is a model of distributed creativity: each "
            "contributor adds a seed; the forest grows beyond any individual vision."
        ),
    },
    {
        "title": "Neuroplasticity — The Brain That Rewires Itself",
        "pole": "nurture",
        "content": (
            "Neuroplasticity is the brain's capacity to reorganize its structure through "
            "experience. New synaptic connections form when neurons fire together repeatedly. "
            "Unused pathways weaken and prune. Learning a new skill physically rewires "
            "cortical maps. Recovery from brain injury recruits neighboring regions to "
            "assume lost functions. The brain does not arrive fully formed — it grows "
            "in response to the world it encounters. Even in adulthood, sustained practice "
            "changes the brain's architecture. The neural substrate of who we are is "
            "continuously shaped by what we do and experience."
        ),
    },
    {
        "title": "CWS Nurture Curve — Growth and Adaptation Pole",
        "pole": "nurture",
        "content": (
            "The Nurture curve in the Convergence Weight Schema peaks at x=+1, the growth "
            "pole of the convergence axis. Parameters and tokens that evaluate to the "
            "nurture-dominant side carry the weight +1 — the positive ternary value "
            "representing adaptation, expansion, and new possibility. Retrieval candidates "
            "with nurture-dominant direction signatures are geometrically aligned with "
            "queries seeking new information, creative connections, or expanding knowledge. "
            "The nurture pole is not better than the structure pole — it is the complementary "
            "half of a complete geometric foundation. Growth without structure collapses; "
            "structure without growth stagnates."
        ),
    },

    # ── DOOR / neutral (0) — balanced, transitional ──────────────────────────
    {
        "title": "The Convergence Point — Where Both Curves Meet",
        "pole": "door",
        "content": (
            "At x=0, the structure curve and nurture curve are equal. Neither dominates. "
            "This is the Door — the convergence point where maximum uncertainty exists and "
            "all directions remain possible. A parameter at the Door receives ternary weight "
            "zero: not structure, not nurture, but open. The Door is not absence — it is "
            "the state of maximum potential, the gate through which any direction may pass. "
            "In retrieval, a memory entry at the Door is accessible from any query direction, "
            "because no direction contradicts zero. The Door is the universal gate: it "
            "neither accepts nor rejects — it passes all."
        ),
    },
    {
        "title": "Scientific Method — Structure and Exploration in Balance",
        "pole": "door",
        "content": (
            "The scientific method balances constraint and exploration. A hypothesis must be "
            "falsifiable — structured enough to be testable. But the exploration phase "
            "is open: any observation may challenge any prior theory. Peer review enforces "
            "structural standards while allowing any result to enter the record. Paradigm "
            "shifts happen when enough anomalies accumulate that the old structure can no "
            "longer contain the new growth. Science is neither pure structure (dogma) nor "
            "pure growth (chaos). It is the disciplined balance between the two: structured "
            "enough to be cumulative, open enough to be surprised."
        ),
    },
    {
        "title": "Ternary Logic — The Third State Between True and False",
        "pole": "door",
        "content": (
            "Ternary logic extends binary logic with a third value: unknown, undefined, or "
            "indeterminate. In Kleene three-valued logic, the truth value 'I' (indeterminate) "
            "propagates through operations: TRUE AND I = I, FALSE AND I = FALSE. SQL uses "
            "NULL as a similar third value for unknown data. Ternary logic is appropriate "
            "when the world cannot be cleanly divided into true and false — when information "
            "is incomplete, contested, or inherently uncertain. The middle state is not a "
            "failure of logic but a more accurate representation of incomplete knowledge."
        ),
    },
    {
        "title": "Homeostasis — Dynamic Equilibrium in Living Systems",
        "pole": "door",
        "content": (
            "Homeostasis is the maintenance of dynamic equilibrium in biological systems. "
            "Body temperature is held near 37°C through opposing mechanisms: shivering "
            "generates heat when cold; sweating dissipates heat when warm. Blood pH is "
            "regulated between 7.35 and 7.45 by respiratory and renal feedback loops. "
            "Homeostasis is not static — it is constant adjustment around a setpoint. "
            "The organism is neither fully rigid nor fully fluid: it holds a dynamic balance "
            "between structure and growth, constraint and adaptation, preservation and change."
        ),
    },
    {
        "title": "Design Patterns — Reusable Structure for Flexible Systems",
        "pole": "door",
        "content": (
            "Software design patterns provide reusable structural solutions to recurring "
            "design problems. A pattern defines a structure — roles, relationships, "
            "interfaces — without fixing the specific implementation. The Observer pattern "
            "structures event notification without dictating what events are observed or "
            "what observers do. Strategy encapsulates interchangeable algorithms behind "
            "a common interface. Patterns are structural constraints that enable growth: "
            "they prevent chaotic proliferation while allowing flexible extension. "
            "Good architecture is structured enough to be coherent and open enough to grow."
        ),
    },
    {
        "title": "Equilibrium in Chemistry — Reaction and Counter-Reaction",
        "pole": "door",
        "content": (
            "Chemical equilibrium is the state where forward and reverse reaction rates "
            "are equal. The system is not static — reactions continue in both directions — "
            "but the net concentrations of reactants and products remain constant. "
            "Le Chatelier's principle states that any perturbation to an equilibrium system "
            "produces a response that partially counteracts the disturbance: add reactant, "
            "shift toward product; remove product, shift toward reactant. Equilibrium is "
            "dynamic balance, not frozen state. It is the chemistry of the Door: "
            "both directions active, neither dominant, the system balanced between."
        ),
    },
    {
        "title": "CWS Ternary Architecture — Unified Three-Pole System",
        "pole": "door",
        "content": (
            "The CWS ternary architecture unifies three poles into a single coherent system. "
            "Structure (-1) provides foundation, constraint, and auditability. Nurture (+1) "
            "provides growth, adaptation, and new possibility. The Door (0) provides "
            "neutrality, uncertainty, and universal access. No pole is superior. Each is "
            "necessary. A system that is only structure becomes rigid and cannot learn. "
            "A system that is only nurture becomes chaotic and cannot be trusted. "
            "A system at only the Door becomes undifferentiated and cannot decide. "
            "The three together form the complete geometry of convergent intelligence."
        ),
    },
]

# ── Reasoning Chain Scenarios ─────────────────────────────────────────────────

CHAINS = [
    {
        "id": "chain_A_convergent",
        "label": "Chain A — Convergent (FERTILE hops)",
        "seed_query": "What immutable constraints govern reliable AI inference and data integrity?",
        "expected": "converged",
        "description": "Structure-aligned query — should retrieve structure-pole docs, hops stabilize",
    },
    {
        "id": "chain_B_divergent",
        "label": "Chain B — Divergent (direction drift)",
        "seed_query": "How do living systems continuously adapt and grow beyond their initial design?",
        "expected": "divergent",
        "description": "Nurture-aligned query through a mixed corpus — measures direction stability",
    },
    {
        "id": "chain_C_breaker",
        "label": "Chain C — Circuit Breaker (≥70% BABEL)",
        "seed_query": "The quantum uncertainty principle dissolves all fixed boundaries enabling unlimited growth",
        "expected": "circuit_tripped",
        "description": "Deliberately contradictory framing — structure and nurture simultaneously asserted",
    },
    {
        "id": "chain_D_mixed",
        "label": "Chain D — Mixed (FERTILE → BABEL drift)",
        "seed_query": "How does software architecture balance fixed structural patterns with evolutionary adaptation?",
        "expected": "mixed",
        "description": "Starts near Door, drifts as hops propagate — tests mid-chain sensitivity",
    },
]


# ── Helpers ──────────────────────────────────────────────────────────────────

def divider(title=""):
    w = 72
    if title:
        pad = (w - len(title) - 2) // 2
        print(f"\n{'─' * pad} {title} {'─' * (w - len(title) - 2 - pad)}")
    else:
        print("─" * w)


def content_hash(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:64]


async def get_chunk_embedding(conn, chunk_id) -> list[float]:
    """Fetch a chunk's embedding from the DB."""
    with conn.cursor() as cur:
        cur.execute("SELECT embedding::text FROM s7_rag.chunks WHERE id = %s", (chunk_id,))
        row = cur.fetchone()
        if not row:
            return [0.0] * 768
        return [float(x) for x in row[0].strip("[]").split(",")]


async def get_chunk_topic(conn, chunk_id) -> tuple[str, str]:
    """Return (pole, title) for a chunk."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT doc.metadata->>'pole', doc.title
            FROM s7_rag.chunks c
            JOIN s7_rag.documents doc ON c.document_id = doc.id
            WHERE c.id = %s
        """, (chunk_id,))
        row = cur.fetchone()
        return (row[0] or "?", row[1] or "?") if row else ("?", "?")


def store_hop(conn, chain_db_id, hop_idx, query_prism, result_chunk_id, agr):
    """INSERT one hop into cws_memory.rag_reasoning."""
    mask = 0
    for i, plane in enumerate(OCTI_PLANES):
        if agr["planes"].get(plane, {}).get("fertile", False):
            mask |= (1 << i)
    fertile_planes = [p for p in OCTI_PLANES if agr["planes"].get(p, {}).get("fertile")]

    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.rag_reasoning
                (chain_id, hop_index, agreement_score,
                 fertile_planes, total_planes, plane_mask,
                 primary_planes, result)
            VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s)
        """, (
            str(chain_db_id),
            hop_idx,
            agr["agreement_score"],
            agr["fertile_planes"],
            agr["total_planes"],
            mask,
            fertile_planes,
            agr["result"],
        ))


def store_chain_final(conn, query, total, fertile, babel,
                      final_dir, final_plane, converged, babel_ratio, tripped) -> str:
    """INSERT final chain summary (separate from pre-registration row)."""
    final_uuid = str(uuid.uuid4())
    qhash = content_hash(query)
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.reasoning_chains
                (id, query_text, query_hash, total_hops, fertile_hops,
                 babel_hops, final_direction, final_plane, converged,
                 babel_ratio, circuit_tripped)
            VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            final_uuid, query, qhash, total, fertile, babel,
            final_dir, final_plane, converged,
            babel_ratio, tripped,
        ))
    conn.commit()
    return final_uuid


def store_circuit_event(conn, babel_ratio, tripped):
    """INSERT circuit breaker event into cws_core.circuit_breaker_events."""
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_core.circuit_breaker_events
                (babel_ratio, threshold, triggered, action_taken)
            VALUES (%s, %s, %s, %s)
        """, (
            babel_ratio,
            CIRCUIT_BREAKER_THRESHOLD,
            tripped,
            "inference_halted" if tripped else "inference_continues",
        ))
    conn.commit()


# ── Multi-Hop Chain Runner ────────────────────────────────────────────────────

async def run_chain(conn, client, chain_cfg, dataset_id):
    print(f"\n{chain_cfg['label']}")
    print(f"Seed: \"{chain_cfg['seed_query']}\"")
    print(f"Expect: {chain_cfg['expected']} — {chain_cfg['description']}")
    divider()

    # Pre-register chain in reasoning_chains so FK from rag_reasoning.chain_id is satisfied
    chain_uuid = str(uuid.uuid4())
    qhash = content_hash(chain_cfg["seed_query"])
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.reasoning_chains
                (id, query_text, query_hash, total_hops, fertile_hops,
                 babel_hops, converged, babel_ratio, circuit_tripped)
            VALUES (%s::uuid, %s, %s, 0, 0, 0, false, 0, false)
        """, (chain_uuid, chain_cfg["seed_query"], qhash))
    conn.commit()

    current_query    = chain_cfg["seed_query"]
    current_embedding = await embed_text(client, current_query)

    hop_results  = []   # list of dicts per hop
    babel_count  = 0
    fertile_count = 0
    final_dir    = 0
    final_plane  = "executive"
    circuit_tripped = False

    print(f"{'Hop':<4} {'Result':<10} {'Score':>6}  {'Top Plane':<12}  {'Dir':>4}  Retrieved Doc (pole)")
    print("─" * 72)

    for hop in range(MAX_HOPS):
        # Retrieve top-4 candidates
        retrieved = await retrieve(conn, client, current_query, top_k=4)
        conn.commit()

        if not retrieved:
            print(f"  {hop+1:<2}  (no candidates — stopping)")
            break

        # Build candidates with prism decompositions
        candidates = []
        for r in retrieved:
            chunk_emb = await get_chunk_embedding(conn, r["chunk_id"])
            r["prism"] = decompose(chunk_emb)
            candidates.append(r)

        # Direction agreement
        query_prism = decompose(current_embedding)
        top_planes  = identify_planes(query_prism, top_n=2)

        # Score each candidate
        best = None
        best_agr = None
        for c in candidates:
            agr = direction_agreement(query_prism, c["prism"])
            c["prism_agreement"] = agr
            if best is None or agr["agreement_score"] > best_agr["agreement_score"]:
                best = c
                best_agr = agr

        result   = best_agr["result"]
        score    = best_agr["agreement_score"]
        top_plane = top_planes[0] if top_planes else "?"

        # Dominant direction on top plane
        dir_val = query_prism.get(top_plane, {}).get("direction", 0)
        dir_sym = {-1: "←-1", 0: "·0·", 1: "+1→"}[dir_val]

        pole, title = await get_chunk_topic(conn, best["chunk_id"])

        print(f"  {hop+1:<2}  {'FERTILE ✓' if result=='FERTILE' else 'BABEL   ✗':<10} "
              f"{score:>5.2f}  {top_plane:<12}  {dir_sym}  {title[:28]} [{pole}]")

        # Store hop
        store_hop(conn, chain_uuid, hop, query_prism, best["chunk_id"], best_agr)
        conn.commit()

        hop_results.append({"hop": hop, "result": result, "score": score,
                            "plane": top_plane, "dir": dir_val})

        if result == "FERTILE":
            fertile_count += 1
        else:
            babel_count += 1

        final_dir   = dir_val
        final_plane = top_plane

        # Check circuit breaker
        total_so_far = hop + 1
        babel_ratio  = babel_count / total_so_far
        if babel_ratio >= CIRCUIT_BREAKER_THRESHOLD and total_so_far >= 3:
            circuit_tripped = True
            store_circuit_event(conn, float(babel_ratio), True)
            print(f"\n  ⚡ CIRCUIT BREAKER TRIPPED — babel_ratio={babel_ratio:.1%} ≥ {CIRCUIT_BREAKER_THRESHOLD:.0%}")
            print(f"     Inference halted at hop {hop+1}. Chain marked circuit_tripped=TRUE.")
            break

        # Advance: use best FERTILE candidate's content as next query
        # If BABEL, use the original query modified by plane emphasis
        if result == "FERTILE":
            current_query     = best.get("content", current_query)[:500]
            current_embedding = await embed_text(client, current_query)
        else:
            # BABEL hop: re-query with plane emphasis rather than advancing
            current_query = f"{top_plane} perspective: {current_query}"
            current_embedding = await embed_text(client, current_query)

        # Convergence check: executive plane stabilized?
        exec_dir = query_prism.get("executive", {}).get("direction", 0)
        if hop >= 2 and exec_dir != 0 and fertile_count >= 3:
            total_hops = hop + 1
            converged = True
            babel_ratio = babel_count / total_hops
            print(f"\n  ✓ Chain converged at hop {hop+1} — executive plane direction: {exec_dir}")
            chain_db_id = store_chain_final(
                conn, chain_cfg["seed_query"],
                total_hops, fertile_count, babel_count,
                int(final_dir), final_plane, converged,
                float(babel_ratio), False
            )
            store_circuit_event(conn, float(babel_ratio), False)
            return {"id": chain_cfg["id"], "total": total_hops, "fertile": fertile_count,
                    "babel": babel_count, "babel_ratio": babel_ratio,
                    "converged": converged, "circuit_tripped": False}

    # Chain ended (max hops or circuit break)
    total_hops  = len(hop_results)
    babel_ratio = babel_count / total_hops if total_hops > 0 else 0.0
    converged   = (not circuit_tripped) and (fertile_count / total_hops >= 0.6) if total_hops else False

    chain_db_id = store_chain_final(
        conn, chain_cfg["seed_query"],
        total_hops, fertile_count, babel_count,
        int(final_dir), final_plane, converged,
        float(babel_ratio), circuit_tripped
    )
    if not circuit_tripped:
        store_circuit_event(conn, float(babel_ratio), False)

    return {"id": chain_cfg["id"], "total": total_hops, "fertile": fertile_count,
            "babel": babel_count, "babel_ratio": babel_ratio,
            "converged": converged, "circuit_tripped": circuit_tripped}


# ── Main ─────────────────────────────────────────────────────────────────────

async def main():
    print("S7 SkyQUBi — Phase 3: Multi-Hop Reasoning Chain with Circuit Breaker")
    print("nomic-embed-text (768-dim) | 18-doc polarized corpus | 4 chains")
    divider()

    conn = psycopg2.connect(**DB)
    async with httpx.AsyncClient() as client:

        # ── Ingest expanded corpus ────────────────────────────────────────
        divider("STEP 1 — INGEST POLARIZED CORPUS")

        dataset_id = await register_dataset(
            conn,
            name="phase3_polarized_corpus",
            source_url="s7://local/phase3",
            license="internal-test",
            source_type="text",
            description="Phase 3: 18 docs — structure (-1), nurture (+1), door (0) poles",
            tags=["test", "phase3", "polarized", "prism"],
        )
        conn.commit()

        pole_counts = {"structure": 0, "nurture": 0, "door": 0}
        for doc in CORPUS:
            result = await ingest_document(
                conn, client,
                dataset_id=dataset_id,
                title=doc["title"],
                content=doc["content"],
                source_ref=f"s7://test/phase3/{doc['pole']}/{doc['title'][:20]}",
                metadata={"pole": doc["pole"]},
            )
            conn.commit()
            pole_counts[doc["pole"]] += 1
            status = "SKIP" if result.get("skipped") else f"+{result['chunks_created']}"
            print(f"  [{doc['pole']:9s}] {doc['title'][:50]:<50s} {status}")

        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM s7_rag.chunks WHERE dataset_id = %s::uuid",
                        (dataset_id,))
            n_chunks = cur.fetchone()[0]
        print(f"\nCorpus: {sum(pole_counts.values())} docs "
              f"({pole_counts['structure']} structure / {pole_counts['nurture']} nurture / "
              f"{pole_counts['door']} door) → {n_chunks} chunks in DB")

        # ── Run reasoning chains ──────────────────────────────────────────
        divider("STEP 2 — MULTI-HOP REASONING CHAINS")

        all_results = []
        for chain_cfg in CHAINS:
            result = await run_chain(conn, client, chain_cfg, dataset_id)
            all_results.append(result)

        # ── Summary ───────────────────────────────────────────────────────
        divider("PHASE 3 SUMMARY")

        print(f"{'Chain':<28} {'Hops':>5}  {'F':>3}  {'B':>3}  {'BABEL%':>7}  {'Status'}")
        print("─" * 72)
        for r in all_results:
            if r["circuit_tripped"]:
                status = "⚡ CIRCUIT TRIPPED"
            elif r["converged"]:
                status = "✓ CONVERGED"
            else:
                status = "~ COMPLETED"
            print(f"  {r['id']:<26} {r['total']:>5}  {r['fertile']:>3}  {r['babel']:>3}  "
                  f"{r['babel_ratio']:>6.1%}  {status}")

        # DB verification
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM cws_memory.reasoning_chains")
            n_chains = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM cws_memory.rag_reasoning")
            n_hops = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM cws_core.circuit_breaker_events WHERE triggered = TRUE")
            n_trips = cur.fetchone()[0]

        print(f"\nDB: {n_chains} reasoning_chains | {n_hops} rag_reasoning hops | "
              f"{n_trips} circuit_breaker_events (triggered)")
        print("\nPhase 3 complete. ✓")

    conn.close()


if __name__ == "__main__":
    asyncio.run(main())
