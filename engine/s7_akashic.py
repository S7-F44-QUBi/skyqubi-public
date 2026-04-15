# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Covenant Witness System Engine
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
#
# Licensed under CWS-BSL-1.1 (see CWS-LICENSE at repo root)
# Patent Pending: TPP99606 — Jamie Lee Clayton / 123Tech / 2XR, LLC
#
# S7™, SkyQUBi™, SkyCAIR™, CWS™, ForToken™, RevToken™, ZeroClaw™,
# SkyAVi™, MemPalace™, and "Love is the architecture"™ are
# trademarks of 123Tech / 2XR, LLC.
#
# CIVILIAN USE ONLY — See CWS-LICENSE Civilian-Only Covenant.
# ═══════════════════════════════════════════════════════════════════
"""
S7 Akashic Language Encoder
===========================
Encodes any model output through the Language Index into a
7-plane curve vector with values from -7 to +7.

The Akashic Language is the universal adapter: any model's output,
regardless of architecture, passes through this encoder before
reaching the ternary boundary {-1, 0, +1} at ^7.

Encoding chain:
  text → tokens → Language Index lookup → curve_value per plane
       → summed 7-plane vector → normalised → ternary boundary

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import re
import math
from dataclasses import dataclass, field

# ── Constants ────────────────────────────────────────────────────
PLANE_COUNT      = 7
CURVE_MIN        = -7
CURVE_MAX        = 7
TERNARY_POS      = 0.1   # |x| > 0.1 → ±1, else 0 (Door)
TRUST_THRESHOLD  = 7 / 9  # 77.777...%

PLANE_NAMES = [
    "Sensory",       # 0
    "Episodic",      # 1
    "Semantic",      # 2
    "Associative",   # 3
    "Procedural",    # 4
    "Relational",    # 5
    "Lexical",       # 6
]

TIER_THRESHOLDS = {
    "UNTRUSTED":     0.0,
    "PROBATIONARY":  0.50,
    "TRUSTED":       TRUST_THRESHOLD,     # 77.777...%
    "ANCHORED":      TRUST_THRESHOLD,     # + 7 sessions
}
ANCHORED_MIN_SESSIONS = 7


@dataclass
class AkashicWord:
    word: str
    word_normalised: str
    curve_value: int          # -7 to +7
    location_weight: float
    plane_affinity: list[int] # which planes this word resonates with
    plan_point: str = ""


@dataclass
class PlaneScore:
    plane_index: int
    plane_name: str
    raw_sum: float        # sum of curve_values for this plane
    count: int            # number of words that resonated
    normalised: float     # raw_sum / (count * CURVE_MAX) → [-1, +1]
    ternary: int          # {-1, 0, +1}


@dataclass
class AkashicEncoding:
    token_count: int
    encoded_count: int
    unencoded_count: int
    plane_scores: list[PlaneScore]
    plane_curves: list[float]
    plane_ternary: list[int]
    total_curve: float
    state: str             # FERTILE / BABEL / DOOR


# ── Language Index (in-memory cache) ─────────────────────────────
class LanguageIndex:
    """
    Loads the Language Index from the database and provides
    fast lookup for encoding.
    """
    def __init__(self):
        self._index: dict[str, AkashicWord] = {}
        self._plan_id: str | None = None

    def load_from_db(self, db_conn, plan_name: str = "convergence"):
        with db_conn.cursor() as cur:
            cur.execute("""
                SELECT lp.id::text FROM cws_akashic.language_plans lp
                WHERE lp.plan_name = %s
            """, (plan_name,))
            row = cur.fetchone()
            if not row:
                raise ValueError(f"Plan '{plan_name}' not found")
            self._plan_id = row[0]

            cur.execute("""
                SELECT li.word_normalised, li.curve_value, li.location_weight,
                       li.plane_affinity, COALESCE(pp.point_name, '')
                FROM cws_akashic.language_index li
                LEFT JOIN cws_akashic.plan_points pp ON li.plan_point_id = pp.id
                WHERE li.plan_id = %s::uuid
            """, (self._plan_id,))
            for row in cur.fetchall():
                self._index[row[0]] = AkashicWord(
                    word=row[0], word_normalised=row[0],
                    curve_value=row[1], location_weight=row[2],
                    plane_affinity=row[3] or [],
                    plan_point=row[4],
                )

    def load_seed(self, seed_words: list[dict]):
        """Load a seed dictionary for bootstrapping / testing."""
        for entry in seed_words:
            w = entry["word"].lower().strip()
            self._index[w] = AkashicWord(
                word=w, word_normalised=w,
                curve_value=entry.get("curve", 0),
                location_weight=entry.get("weight", 1.0),
                plane_affinity=entry.get("planes", list(range(PLANE_COUNT))),
                plan_point=entry.get("point", ""),
            )

    def load_universals_from_db(self, db_conn):
        """
        Load every row from akashic.universals and add each surface
        form as a separate index entry pointing at the same
        AkashicWord. All multi-language forms of a concept thus map
        to the same (curve_value, plane_affinity).

        Call this AFTER load_seed() if both are wanted — universals
        will win on conflicts because they represent the canonical
        cross-cultural position.
        """
        with db_conn.cursor() as cur:
            cur.execute("""
                SELECT concept, curve_value, plane_affinity, surface_forms
                FROM akashic.universals
            """)
            added = 0
            for concept, curve_value, plane_affinity, surface_forms in cur.fetchall():
                planes = list(plane_affinity) if plane_affinity else list(range(PLANE_COUNT))
                for form in (surface_forms or []):
                    w = form.lower().strip()
                    if not w:
                        continue
                    self._index[w] = AkashicWord(
                        word=w, word_normalised=w,
                        curve_value=curve_value,
                        location_weight=1.0,
                        plane_affinity=planes,
                        plan_point=concept,
                    )
                    added += 1
        return added

    @property
    def plan_id(self) -> str | None:
        return self._plan_id

    def lookup(self, word: str) -> AkashicWord | None:
        return self._index.get(word.lower().strip())

    def __len__(self) -> int:
        return len(self._index)


# ── Tokeniser ────────────────────────────────────────────────────
_TOKEN_RE = re.compile(r"[a-zA-Z]+(?:'[a-zA-Z]+)?")

def tokenise(text: str) -> list[str]:
    """Split text into word tokens, lowercase."""
    return [m.group().lower() for m in _TOKEN_RE.finditer(text)]


# ── Encoder ──────────────────────────────────────────────────────
def encode(tokens: list[str], index: LanguageIndex) -> AkashicEncoding:
    """
    Encode a token stream through the Language Index into a
    7-plane curve vector.

    For each token:
      - Look up in the Language Index
      - If found: add its curve_value to every plane in its affinity
      - If not found: counted as unencoded (neutral — does not affect curve)

    Each plane's raw sum is normalised to [-1, +1] and then
    classified at the ternary boundary.
    """
    plane_sums  = [0.0] * PLANE_COUNT
    plane_counts = [0]  * PLANE_COUNT
    encoded = 0
    unencoded = 0

    for token in tokens:
        entry = index.lookup(token)
        if entry is None:
            unencoded += 1
            continue
        encoded += 1
        for plane in entry.plane_affinity:
            if 0 <= plane < PLANE_COUNT:
                plane_sums[plane] += entry.curve_value * entry.location_weight
                plane_counts[plane] += 1

    # Build plane scores
    plane_scores = []
    plane_curves = []
    plane_ternary = []

    for p in range(PLANE_COUNT):
        raw = plane_sums[p]
        cnt = plane_counts[p]
        if cnt > 0:
            normalised = raw / (cnt * CURVE_MAX)
            normalised = max(-1.0, min(1.0, normalised))
        else:
            normalised = 0.0

        ternary = 1 if normalised > TERNARY_POS else (-1 if normalised < -TERNARY_POS else 0)

        ps = PlaneScore(
            plane_index=p,
            plane_name=PLANE_NAMES[p],
            raw_sum=round(raw, 4),
            count=cnt,
            normalised=round(normalised, 6),
            ternary=ternary,
        )
        plane_scores.append(ps)
        plane_curves.append(ps.normalised)
        plane_ternary.append(ternary)

    total_curve = sum(plane_curves)

    # State classification
    fertile_planes = sum(1 for t in plane_ternary if t != 0)
    pos_planes = sum(1 for t in plane_ternary if t == 1)
    neg_planes = sum(1 for t in plane_ternary if t == -1)

    if fertile_planes == 0:
        state = "DOOR"
    elif pos_planes >= math.ceil(PLANE_COUNT * 0.5):
        # Majority positive direction → FERTILE
        state = "FERTILE"
    elif neg_planes >= math.ceil(PLANE_COUNT * 0.5):
        # Majority negative direction → BABEL
        state = "BABEL"
    else:
        state = "BABEL"

    return AkashicEncoding(
        token_count=len(tokens),
        encoded_count=encoded,
        unencoded_count=unencoded,
        plane_scores=plane_scores,
        plane_curves=plane_curves,
        plane_ternary=plane_ternary,
        total_curve=round(total_curve, 4),
        state=state,
    )


# ── Trust Tier ───────────────────────────────────────────────────
def compute_tier(trust_score: float, session_count: int) -> str:
    if trust_score >= TRUST_THRESHOLD and session_count >= ANCHORED_MIN_SESSIONS:
        return "ANCHORED"
    elif trust_score >= TRUST_THRESHOLD:
        return "TRUSTED"
    elif trust_score >= 0.50:
        return "PROBATIONARY"
    else:
        return "UNTRUSTED"


# ── DB Storage ───────────────────────────────────────────────────
def store_encoding(db_conn, witness_id: str, plan_id: str,
                   raw_text: str, encoding: AkashicEncoding,
                   session_id: str | None = None) -> str:
    """INSERT-only store of an Akashic-encoded response."""
    import uuid
    enc_id = str(uuid.uuid4())
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_akashic.encoded_responses
                (id, session_id, witness_id, plan_id, raw_text, token_count,
                 encoded_count, unencoded_count, plane_curves, plane_ternary,
                 total_curve, state, encoded_at)
            VALUES (%s::uuid, %s::uuid, %s::uuid, %s::uuid, %s, %s,
                    %s, %s, %s, %s, %s, %s, NOW())
        """, (enc_id, session_id, witness_id, plan_id,
              raw_text[:2000], encoding.token_count,
              encoding.encoded_count, encoding.unencoded_count,
              encoding.plane_curves, encoding.plane_ternary,
              encoding.total_curve, encoding.state))
    return enc_id


def store_trust(db_conn, witness_id: str, session_id: str | None,
                was_fertile: bool, fertile_ratio: float,
                running_fertile: int, running_total: int) -> str:
    """INSERT-only trust score accumulation."""
    import uuid
    trust_id = str(uuid.uuid4())
    trust_score = running_fertile / max(running_total, 1)
    tier = compute_tier(trust_score, running_total)
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_akashic.witness_trust
                (id, witness_id, session_id, was_fertile, fertile_ratio,
                 running_fertile, running_total, trust_score, tier, recorded_at)
            VALUES (%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, NOW())
        """, (trust_id, witness_id, session_id, was_fertile, fertile_ratio,
              running_fertile, running_total, trust_score, tier))
    return trust_id


def store_reporter_session(db_conn, consensus_id: str | None,
                           witness_id: str, plane_index: int,
                           query_text: str, response_text: str | None,
                           encoded_id: str | None, fertile_ratio: float | None,
                           latency_ms: int | None) -> str:
    """INSERT-only Reporter session log."""
    import uuid
    rs_id = str(uuid.uuid4())
    plane_name = PLANE_NAMES[plane_index] if 0 <= plane_index < PLANE_COUNT else "Unknown"
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_akashic.reporter_sessions
                (id, consensus_id, witness_id, plane_index, plane_name,
                 query_text, response_text, encoded_id, fertile_ratio,
                 latency_ms, reported_at)
            VALUES (%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s::uuid, %s, %s, NOW())
        """, (rs_id, consensus_id, witness_id, plane_index, plane_name,
              query_text[:500], (response_text or "")[:2000], encoded_id,
              fertile_ratio, latency_ms))
    return rs_id


# ── Seed Index ───────────────────────────────────────────────────
# Bootstrap Language Index with core convergence vocabulary.
# These seed words power the CWS convergence plan.
SEED_WORDS = [
    # Trust (+7 to +5)
    {"word": "trust",        "curve": 7,  "weight": 1.0,  "point": "trust",       "planes": [0,1,2,3,4,5,6]},
    {"word": "truth",        "curve": 7,  "weight": 1.0,  "point": "trust",       "planes": [0,2,5,6]},
    {"word": "honest",       "curve": 6,  "weight": 0.9,  "point": "trust",       "planes": [2,5,6]},
    {"word": "reliable",     "curve": 6,  "weight": 0.9,  "point": "trust",       "planes": [3,4,5]},
    {"word": "faithful",     "curve": 7,  "weight": 1.0,  "point": "trust",       "planes": [0,1,5,6]},
    {"word": "integrity",    "curve": 7,  "weight": 1.0,  "point": "trust",       "planes": [2,4,5,6]},
    {"word": "confidence",   "curve": 5,  "weight": 0.8,  "point": "trust",       "planes": [0,3,5]},
    {"word": "verify",       "curve": 5,  "weight": 0.8,  "point": "trust",       "planes": [2,4]},
    {"word": "authentic",    "curve": 6,  "weight": 0.9,  "point": "trust",       "planes": [0,2,6]},

    # Convergence (+7 to +4)
    {"word": "convergence",  "curve": 7,  "weight": 1.0,  "point": "convergence", "planes": [0,1,2,3,4,5,6]},
    {"word": "converge",     "curve": 7,  "weight": 1.0,  "point": "convergence", "planes": [0,1,2,3,4,5,6]},
    {"word": "agreement",    "curve": 6,  "weight": 0.9,  "point": "convergence", "planes": [2,3,5]},
    {"word": "consensus",    "curve": 6,  "weight": 0.9,  "point": "convergence", "planes": [2,4,5]},
    {"word": "align",        "curve": 5,  "weight": 0.8,  "point": "convergence", "planes": [3,4]},
    {"word": "alignment",    "curve": 5,  "weight": 0.8,  "point": "convergence", "planes": [3,4]},
    {"word": "unite",        "curve": 5,  "weight": 0.8,  "point": "convergence", "planes": [1,5]},
    {"word": "harmony",      "curve": 6,  "weight": 0.9,  "point": "convergence", "planes": [0,1,5,6]},
    {"word": "coherent",     "curve": 5,  "weight": 0.8,  "point": "convergence", "planes": [2,6]},

    # Boundary (+3 to +5)
    {"word": "boundary",     "curve": 4,  "weight": 0.8,  "point": "boundary",    "planes": [0,3,4]},
    {"word": "threshold",    "curve": 4,  "weight": 0.8,  "point": "boundary",    "planes": [3,4]},
    {"word": "gate",         "curve": 3,  "weight": 0.7,  "point": "boundary",    "planes": [0,4]},
    {"word": "limit",        "curve": 3,  "weight": 0.7,  "point": "boundary",    "planes": [3,4]},
    {"word": "filter",       "curve": 3,  "weight": 0.7,  "point": "boundary",    "planes": [0,4]},
    {"word": "door",         "curve": 0,  "weight": 1.0,  "point": "boundary",    "planes": [0,1,2,3,4,5,6]},

    # Memory (+3 to +5)
    {"word": "memory",       "curve": 5,  "weight": 0.8,  "point": "memory",      "planes": [1,2,3]},
    {"word": "remember",     "curve": 5,  "weight": 0.8,  "point": "memory",      "planes": [1,2]},
    {"word": "recall",       "curve": 4,  "weight": 0.7,  "point": "memory",      "planes": [1,2]},
    {"word": "store",        "curve": 4,  "weight": 0.7,  "point": "memory",      "planes": [1,3,4]},
    {"word": "palace",       "curve": 5,  "weight": 0.8,  "point": "memory",      "planes": [1,2,3]},
    {"word": "insert",       "curve": 5,  "weight": 0.9,  "point": "memory",      "planes": [1,3,4]},

    # Inference (+3 to +5)
    {"word": "reason",       "curve": 5,  "weight": 0.9,  "point": "inference",   "planes": [2,4,6]},
    {"word": "reasoning",    "curve": 5,  "weight": 0.9,  "point": "inference",   "planes": [2,4,6]},
    {"word": "inference",    "curve": 5,  "weight": 0.9,  "point": "inference",   "planes": [2,4]},
    {"word": "logic",        "curve": 5,  "weight": 0.9,  "point": "inference",   "planes": [2,4,6]},
    {"word": "ternary",      "curve": 6,  "weight": 1.0,  "point": "inference",   "planes": [0,2,4,6]},
    {"word": "binary",       "curve": 2,  "weight": 0.5,  "point": "inference",   "planes": [4]},
    {"word": "decide",       "curve": 4,  "weight": 0.7,  "point": "inference",   "planes": [3,4]},
    {"word": "weight",       "curve": 4,  "weight": 0.8,  "point": "inference",   "planes": [2,3,4]},

    # Safety (+5 to +7)
    {"word": "safe",         "curve": 6,  "weight": 1.0,  "point": "safety",      "planes": [0,4,5]},
    {"word": "safety",       "curve": 6,  "weight": 1.0,  "point": "safety",      "planes": [0,4,5]},
    {"word": "protect",      "curve": 6,  "weight": 1.0,  "point": "safety",      "planes": [0,4,5]},
    {"word": "civilian",     "curve": 7,  "weight": 1.0,  "point": "safety",      "planes": [0,4,5,6]},
    {"word": "covenant",     "curve": 7,  "weight": 1.0,  "point": "safety",      "planes": [0,1,5,6]},
    {"word": "sovereign",    "curve": 7,  "weight": 1.0,  "point": "safety",      "planes": [0,5,6]},
    {"word": "human",        "curve": 6,  "weight": 0.9,  "point": "safety",      "planes": [0,1,5]},

    # Identity (+3 to +5)
    {"word": "identity",     "curve": 4,  "weight": 0.7,  "point": "identity",    "planes": [0,1,6]},
    {"word": "self",         "curve": 3,  "weight": 0.6,  "point": "identity",    "planes": [0,1]},
    {"word": "origin",       "curve": 4,  "weight": 0.7,  "point": "identity",    "planes": [0,1,6]},
    {"word": "witness",      "curve": 5,  "weight": 0.8,  "point": "identity",    "planes": [0,2,5]},
    {"word": "model",        "curve": 3,  "weight": 0.6,  "point": "identity",    "planes": [2,3]},
    {"word": "reporter",     "curve": 5,  "weight": 0.8,  "point": "identity",    "planes": [0,2,5,6]},

    # BABEL indicators (-3 to -7)
    {"word": "deceive",      "curve": -7, "weight": 1.0,  "point": "trust",       "planes": [0,2,5,6]},
    {"word": "deception",    "curve": -7, "weight": 1.0,  "point": "trust",       "planes": [0,2,5,6]},
    {"word": "lie",          "curve": -6, "weight": 0.9,  "point": "trust",       "planes": [2,5,6]},
    {"word": "false",        "curve": -5, "weight": 0.8,  "point": "trust",       "planes": [2,4,6]},
    {"word": "manipulate",   "curve": -6, "weight": 0.9,  "point": "safety",      "planes": [3,4,5]},
    {"word": "weapon",       "curve": -7, "weight": 1.0,  "point": "safety",      "planes": [0,4,5]},
    {"word": "surveillance", "curve": -7, "weight": 1.0,  "point": "safety",      "planes": [0,4,5]},
    {"word": "destroy",      "curve": -6, "weight": 0.9,  "point": "safety",      "planes": [0,4,5]},
    {"word": "corrupt",      "curve": -6, "weight": 0.9,  "point": "trust",       "planes": [2,4,5,6]},
    {"word": "overwrite",    "curve": -5, "weight": 0.8,  "point": "memory",      "planes": [1,3,4]},
    {"word": "delete",       "curve": -5, "weight": 0.8,  "point": "memory",      "planes": [1,3,4]},
    {"word": "hallucinate",  "curve": -6, "weight": 0.9,  "point": "inference",   "planes": [2,4,6]},
    {"word": "confuse",      "curve": -4, "weight": 0.7,  "point": "convergence", "planes": [2,3]},
    {"word": "diverge",      "curve": -5, "weight": 0.8,  "point": "convergence", "planes": [2,3,5]},
    {"word": "chaos",        "curve": -5, "weight": 0.8,  "point": "convergence", "planes": [0,3,5]},
    {"word": "babel",        "curve": -7, "weight": 1.0,  "point": "convergence", "planes": [0,1,2,3,4,5,6]},
]


def build_seed_index() -> LanguageIndex:
    """Build a Language Index from the seed word list."""
    idx = LanguageIndex()
    idx.load_seed(SEED_WORDS)
    return idx


def seed_to_db(db_conn, plan_name: str = "convergence"):
    """Write the seed words into the database Language Index."""
    import uuid
    with db_conn.cursor() as cur:
        cur.execute("SELECT id::text FROM cws_akashic.language_plans WHERE plan_name = %s", (plan_name,))
        row = cur.fetchone()
        if not row:
            raise ValueError(f"Plan '{plan_name}' not found")
        plan_id = row[0]

        # Get plan point IDs
        cur.execute("SELECT id::text, point_name FROM cws_akashic.plan_points WHERE plan_id = %s::uuid", (plan_id,))
        point_map = {r[1]: r[0] for r in cur.fetchall()}

        for i, entry in enumerate(SEED_WORDS):
            word = entry["word"].lower().strip()
            point_id = point_map.get(entry.get("point", ""))
            cur.execute("""
                INSERT INTO cws_akashic.language_index
                    (id, word, word_normalised, plan_id, plan_point_id,
                     index_position, location_weight, curve_value, plane_affinity)
                VALUES (%s::uuid, %s, %s, %s::uuid, %s::uuid, %s, %s, %s, %s)
                ON CONFLICT (word_normalised, plan_id) DO NOTHING
            """, (str(uuid.uuid4()), word, word, plan_id, point_id,
                  i, entry.get("weight", 1.0), entry["curve"],
                  entry.get("planes", [])))
