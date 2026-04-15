#!/usr/bin/env python3
"""
S7 SkyQUBi — Phase 2: RAG + QBIT Prism Direction-Verified Retrieval
=====================================================================
Tests the full RAG pipeline with real nomic-embed-text embeddings
(768-dim, padded to 1536 for Prism analysis).

Workflow:
  1. Ingest 6 test documents across 3 topics
  2. Run 3 queries (on-topic, off-topic, mixed)
  3. Retrieve top-5 by cosine similarity (baseline)
  4. Apply QBIT Prism direction_agreement() as secondary filter
  5. Compare: pure cosine vs FERTILE-filtered ranking
  6. Store reasoning chain in cws_memory.rag_reasoning

123Tech / 2XR, LLC — Patent Pending CWS-005
"""

import asyncio
import json
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

import httpx
import psycopg2

from s7_prism import decompose, direction_agreement, rag_reason, prism_summary, identify_planes
from s7_rag import (
    embed_text, register_dataset, ingest_document, retrieve, chunk_text
)

# ── Config ───────────────────────────────────────────────────────────────────

DB = dict(host="127.0.0.1", port=7090, dbname="s7_cws",
          user="s7", password=os.getenv("CWS_DB_PASS", ""))

OLLAMA_URL  = "http://127.0.0.1:7081"
EMBED_MODEL = "nomic-embed-text"

# ── Test corpus — 3 topics, 2 docs each ─────────────────────────────────────

CORPUS = [
    # Topic A — Convergence geometry / AI
    {
        "title": "Ternary Weight Assignment in CWS",
        "content": (
            "The Convergence Weight Schema assigns ternary weights {-1, 0, +1} to neural network "
            "parameters using dual-curve geometry. The structure curve peaks at x=-1 representing "
            "foundation and stability. The nurture curve peaks at x=+1 representing growth and "
            "adaptation. Parameters near x=0 receive the Door weight (0), indicating maximum "
            "uncertainty and openness. This geometric approach to quantization preserves semantic "
            "relationships that purely statistical methods discard. Direction-verified retrieval "
            "confirms that retrieved memories agree with the query in convergence space."
        ),
        "topic": "cws_geometry",
    },
    {
        "title": "OCTi Plane Semantic Memory Architecture",
        "content": (
            "The OCTi architecture organizes semantic memory into eight planes: sensory (raw input "
            "processing), episodic (temporal sequences), semantic (stable conceptual knowledge), "
            "associative (relational connections), procedural (action patterns), lexical (token "
            "forms and vocabulary), relational (hierarchies and structure), and executive (goals "
            "and decisions). Each plane maps to a 192-dimensional segment of a 1536-dimensional "
            "embedding. The QBIT Prism decomposes any embedding into one convergence vector "
            "component per plane, enabling plane-level direction verification during retrieval."
        ),
        "topic": "cws_geometry",
    },
    # Topic B — Hardware / offline infrastructure
    {
        "title": "CXL Memory Expansion for Inference",
        "content": (
            "Compute Express Link (CXL) enables memory pooling across CPU and accelerator devices "
            "using a cache-coherent interconnect over PCIe 5.0. For AI inference, CXL Type 3 "
            "memory expanders allow attaching hundreds of gigabytes of DRAM without CPU memory "
            "slots. This enables large language models with hundreds of billions of parameters to "
            "run on commodity server hardware. The SkyQUBi architecture maps CXL memory tiers to "
            "the Trinity mount: SkyCAIR tmpfs (structure), QUBi tmpfs (door), and TimeCapsule "
            "persistent disk (nurture)."
        ),
        "topic": "hardware",
    },
    {
        "title": "Sovereign Offline AI on RPM-based Linux",
        "content": (
            "S7 SkyQUBi deploys as a Podman pod on Fedora Linux using systemd user services. "
            "The stack runs entirely offline: Ollama serves local language models, Qdrant provides "
            "vector search, PostgreSQL with pgvector stores the CWS knowledge base, and the "
            "QUBi Command Center provides a browser-based interface on port 7080. No cloud "
            "connectivity is required. FIPS-140 compliant cryptographic modules and CIS Benchmark "
            "Level 1 hardening ensure enterprise security posture for air-gapped deployments. "
            "SELinux enforcing mode and measured boot complete the security chain."
        ),
        "topic": "hardware",
    },
    # Topic C — Medical / emergency (off-topic for AI queries)
    {
        "title": "First Aid: Treating Severe Bleeding",
        "content": (
            "Severe bleeding requires immediate direct pressure. Apply firm continuous pressure "
            "using a clean cloth or bandage for at least 10 minutes without lifting to check. "
            "For limb bleeding, a tourniquet applied 2-3 inches above the wound can be life-saving "
            "if direct pressure fails. Mark the time of tourniquet application. Elevate the injured "
            "limb above heart level if no fracture is suspected. Do not remove embedded objects — "
            "stabilize them in place. Call emergency services immediately. Pack wounds that cannot "
            "be compressed with gauze using firm packing pressure."
        ),
        "topic": "medical",
    },
    {
        "title": "Emergency Preparedness: Water Purification",
        "content": (
            "Safe drinking water in emergencies can be obtained through boiling (1 minute rolling "
            "boil, 3 minutes above 6500 feet elevation), chemical treatment (8 drops of unscented "
            "household bleach per gallon, 30 minute wait), or filtration through a 0.1-micron "
            "ceramic filter. Commercial purification tablets containing sodium dichloroisocyanurate "
            "are effective against bacteria and protozoa but not all viruses. Store treated water "
            "in food-grade containers away from direct sunlight. The FEMA recommendation is one "
            "gallon per person per day for drinking and sanitation."
        ),
        "topic": "medical",
    },
]

# ── Queries — 3 test cases ───────────────────────────────────────────────────

QUERIES = [
    {
        "id": "q1_on_topic",
        "query": "How does QBIT Prism verify that a retrieved memory agrees with the query direction?",
        "expected_topic": "cws_geometry",
        "label": "ON-TOPIC (CWS geometry)",
    },
    {
        "id": "q2_off_topic",
        "query": "What is the recommended method for treating a deep wound in a field emergency?",
        "expected_topic": "medical",
        "label": "ON-TOPIC (medical — off-topic for AI)",
    },
    {
        "id": "q3_mixed",
        "query": "How does offline infrastructure support AI inference without cloud connectivity?",
        "expected_topic": "hardware",
        "label": "ON-TOPIC (hardware/offline)",
    },
]


# ── Helpers ──────────────────────────────────────────────────────────────────

def divider(title=""):
    w = 70
    if title:
        pad = (w - len(title) - 2) // 2
        print(f"\n{'─' * pad} {title} {'─' * pad}")
    else:
        print("─" * w)


def fmt_dir(d):
    return {-1: "←STRUCT", 0: "·DOOR·", 1: "→NURTR"}[d]


def build_plane_mask(agreement) -> int:
    """Convert per-plane fertile results to a bitmask (bit i = plane i fertile)."""
    from s7_prism import OCTI_PLANES
    mask = 0
    for i, plane in enumerate(OCTI_PLANES):
        if agreement["planes"].get(plane, {}).get("fertile", False):
            mask |= (1 << i)
    return mask


def store_reasoning_chain(conn, query_id, query, query_prism, results):
    """Store Phase 2 results in cws_memory.rag_reasoning."""
    with conn.cursor() as cur:
        for hop, r in enumerate(results):
            agr = r["prism_agreement"]
            mask = build_plane_mask(agr)
            top_planes = [p for p, v in agr["planes"].items() if v.get("fertile")]
            cur.execute("""
                INSERT INTO cws_memory.rag_reasoning
                    (hop_index, agreement_score,
                     fertile_planes, total_planes, plane_mask,
                     primary_planes, result)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s)
            """, (
                hop,
                agr["agreement_score"],
                agr["fertile_planes"],
                agr["total_planes"],
                mask,
                top_planes,
                agr["result"],
            ))
    conn.commit()


# ── Main ─────────────────────────────────────────────────────────────────────

async def main():
    print("S7 SkyQUBi — Phase 2: RAG + QBIT Prism Direction-Verified Retrieval")
    print("nomic-embed-text (768-dim → padded 1536 for Prism)")
    divider()

    conn = psycopg2.connect(**DB)
    async with httpx.AsyncClient() as client:

        # ── Step 1: Ingest corpus ─────────────────────────────────────────
        divider("STEP 1 — INGEST CORPUS")

        dataset_id = await register_dataset(
            conn,
            name="phase2_test_corpus",
            source_url="s7://local/phase2",
            license="internal-test",
            source_type="text",
            description="Phase 2 test corpus: 3 topics × 2 docs",
            tags=["test", "phase2", "prism"],
        )
        conn.commit()
        print(f"Dataset ID: {dataset_id}")

        total_chunks = 0
        for doc in CORPUS:
            result = await ingest_document(
                conn, client,
                dataset_id=dataset_id,
                title=doc["title"],
                content=doc["content"],
                source_ref=f"s7://test/{doc['topic']}/{doc['title'][:20]}",
                metadata={"topic": doc["topic"]},
            )
            conn.commit()
            status = "SKIPPED (exists)" if result.get("skipped") else f"{result['chunks_created']} chunks"
            print(f"  [{doc['topic']:12s}] {doc['title'][:45]:<45s} — {status}")
            total_chunks += result.get("chunks_created", 0)

        print(f"\nTotal new chunks ingested: {total_chunks}")

        # Verify chunk count
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM s7_rag.chunks WHERE dataset_id = %s::uuid",
                        (dataset_id,))
            n = cur.fetchone()[0]
        print(f"Chunks in DB for this dataset: {n}")

        # ── Step 2: Retrieve + Prism filter ──────────────────────────────
        divider("STEP 2 — RETRIEVE + PRISM FILTER")

        all_results = {}

        for q in QUERIES:
            divider(q["label"])
            print(f"Query: \"{q['query']}\"")
            print()

            # 2a. Vector retrieval (top 6 so Prism filter has room)
            retrieved = await retrieve(conn, client, q["query"], top_k=6)
            conn.commit()

            # 2b. Get query embedding for Prism
            query_emb = await embed_text(client, q["query"])

            # 2c. Build candidate list with prism decompositions
            candidates = []
            for r in retrieved:
                # Get chunk embedding from DB
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT embedding::text FROM s7_rag.chunks WHERE id = %s",
                        (r["chunk_id"],)
                    )
                    row = cur.fetchone()
                    if not row:
                        continue
                    # Parse pgvector text format "[v1,v2,...]"
                    emb_str = row[0].strip("[]")
                    chunk_emb = [float(x) for x in emb_str.split(",")]

                r["prism"] = decompose(chunk_emb)
                candidates.append(r)

            # 2d. QBIT Prism direction-verified filter
            query_prism = decompose(query_emb)
            fertile_candidates = rag_reason(query_emb, candidates)

            # 2e. Display comparison
            print(f"{'Rank':<5} {'CosSim':>7}  {'Prism':>8}  {'Score':>6}  Topic       Title")
            print("─" * 70)

            for rank, r in enumerate(retrieved[:5]):
                # Find this chunk's prism result
                fc = next((c for c in fertile_candidates
                           if c["chunk_id"] == r["chunk_id"]), None)

                prism_tag = "FERTILE ✓" if fc else "BABEL   ✗"
                p_score   = f"{fc['prism_agreement']['agreement_score']:.2f}" if fc else "—"

                # Get topic from metadata
                with conn.cursor() as cur:
                    cur.execute(
                        """SELECT doc.metadata->>'topic', doc.title
                           FROM s7_rag.chunks c
                           JOIN s7_rag.documents doc ON c.document_id = doc.id
                           WHERE c.id = %s""",
                        (r["chunk_id"],)
                    )
                    row = cur.fetchone()
                topic = (row[0] or "?") if row else "?"
                title = (row[1] or "?")[:35] if row else "?"

                print(f"  {rank+1:<3}  {r['combined_score']:>6.3f}  {prism_tag:<10} {p_score:>6}  "
                      f"{topic:<12} {title}")

            print()
            print(f"Query Prism: {prism_summary(query_prism)}")
            top_planes = identify_planes(query_prism, top_n=3)
            print(f"Dominant planes: {', '.join(top_planes)}")
            print()
            print(f"Baseline top-5 (cosine):  {len(retrieved[:5])} chunks")
            print(f"FERTILE after Prism filter: {len(fertile_candidates)} / {len(candidates)}")

            # Correctness: does top-1 match expected topic?
            if retrieved:
                with conn.cursor() as cur:
                    cur.execute(
                        """SELECT doc.metadata->>'topic'
                           FROM s7_rag.chunks c
                           JOIN s7_rag.documents doc ON c.document_id = doc.id
                           WHERE c.id = %s""",
                        (retrieved[0]["chunk_id"],)
                    )
                    row = cur.fetchone()
                top1_topic = row[0] if row else "?"
                match = "✓ CORRECT" if top1_topic == q["expected_topic"] else "✗ WRONG"
                print(f"Top-1 topic: {top1_topic}  (expected: {q['expected_topic']})  {match}")

            if fertile_candidates:
                with conn.cursor() as cur:
                    cur.execute(
                        """SELECT doc.metadata->>'topic'
                           FROM s7_rag.chunks c
                           JOIN s7_rag.documents doc ON c.document_id = doc.id
                           WHERE c.id = %s""",
                        (fertile_candidates[0]["chunk_id"],)
                    )
                    row = cur.fetchone()
                top1_fertile_topic = row[0] if row else "?"
                match = "✓ CORRECT" if top1_fertile_topic == q["expected_topic"] else "✗ WRONG"
                print(f"Prism top-1:  {top1_fertile_topic}  (expected: {q['expected_topic']})  {match}")

            # Store reasoning chain
            store_reasoning_chain(conn, q["id"], q["query"], query_prism, candidates)
            all_results[q["id"]] = {
                "fertile": len(fertile_candidates),
                "total":   len(candidates),
                "query_prism": prism_summary(query_prism),
            }

    # ── Step 3: Summary ──────────────────────────────────────────────────
    divider("PHASE 2 SUMMARY")
    print(f"{'Query ID':<20} {'Fertile/Total':>14}  Prism Vector")
    print("─" * 70)
    for qid, r in all_results.items():
        print(f"  {qid:<18} {r['fertile']:>3}/{r['total']:<3} ({r['fertile']/r['total']*100:.0f}%)   "
              f"{r['query_prism']}")

    print()
    print("Reasoning chains stored in cws_memory.rag_reasoning")

    # Verify DB storage
    with psycopg2.connect(**DB) as conn2:
        with conn2.cursor() as cur:
            cur.execute("SELECT count(*) FROM cws_memory.rag_reasoning")
            n = cur.fetchone()[0]
    print(f"Total rag_reasoning rows: {n}")
    print()
    print("Phase 2 complete. ✓")

    conn.close()


if __name__ == "__main__":
    asyncio.run(main())
