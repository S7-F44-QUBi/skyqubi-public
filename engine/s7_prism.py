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
S7 SkyQUBi — QBIT Prism  v1.0.1
Convergence Vector Decomposition Engine + LocationID Matrix

v1.0.0  — 8-plane ternary decomposition + direction-verified retrieval (FERTILE / BABEL)
v1.0.1  — LocationID matrix, rational subpositions, 4-way Location Detection verdict
         (FOUNDATION / FRONTIER / HALLUCINATION / VIOLATION), Stern-Brocot mediant
         for infinite subdivision inside a bounded 3^8 cube.

Decomposes any token embedding into an 8-dimensional convergence vector,
one component per OCTi plane. Each component is a true vector quantity:
magnitude (door_distance from x=0) + direction {-1, 0, +1} (ternary pole).

Replaces scalar cosine similarity with direction-verified retrieval.
Every retrieval is a testable geometric claim, not a probabilistic guess.

123Tech / 2XR, LLC — UNIFIED LINUX SkyCAIR by S7
Patent Pending — CWS-005
CWS-BSL-1.1 License | OmegaAnswers@123Tech.net
"""

__version__ = "1.0.1"

import math
from typing import Any

# ─── Convergence Geometry ────────────────────────────────────────────────────

DECAY_CENTER_STRUCTURE = -1.0   # Father curve peak
DECAY_CENTER_NURTURE   =  1.0   # Mother curve peak
CURVE_FREQUENCY        =  0.8   # Shared frequency

# Thresholds for ternary direction assignment
THRESHOLD_LOW  = -0.1   # below → structure dominant → direction = -1
THRESHOLD_HIGH =  0.1   # above → nurture dominant  → direction = +1

# Maximum door_distance for agreement (within this range = direction compatible)
AGREEMENT_DISTANCE = 1.0

# Minimum fraction of planes that must agree for FERTILE retrieval
FERTILE_PLANE_RATIO = 0.5

# OCTi 8-plane definitions — each plane occupies a segment of the embedding
OCTI_PLANES = [
    'sensory',      # 0 — input processing, raw perception
    'episodic',     # 1 — temporal sequences, events
    'semantic',     # 2 — meaning, concepts, stable knowledge
    'associative',  # 3 — relationships, connections
    'procedural',   # 4 — action patterns, how-to
    'lexical',      # 5 — vocabulary, token forms
    'relational',   # 6 — hierarchies, structure
    'executive',    # 7 — decisions, goals, control
]

EMBEDDING_DIM  = 1536
SEGMENT_SIZE   = EMBEDDING_DIM // len(OCTI_PLANES)   # 192 dims per plane
CONVERGENCE_RANGE = 2.0   # axis spans [-2, +2]


# ─── Curve Functions ─────────────────────────────────────────────────────────

def structure_curve(x: float) -> float:
    """Father curve: peaks at x = -1 (structure/foundation pole)."""
    return math.exp(-abs(x - DECAY_CENTER_STRUCTURE)) * math.cos(CURVE_FREQUENCY * x)


def nurture_curve(x: float) -> float:
    """Mother curve: peaks at x = +1 (nurture/growth pole)."""
    return math.exp(-abs(x - DECAY_CENTER_NURTURE)) * math.cos(CURVE_FREQUENCY * x)


def door_distance(x: float) -> float:
    """Distance from the Door (convergence point x=0). Magnitude of the vector."""
    return abs(x)


def assign_direction(structure_val: float, nurture_val: float,
                     convergence_w: float) -> int:
    """
    Assign ternary direction from curve evaluations.
    Returns: -1 (structure dominant), 0 (Door/neutral), +1 (nurture dominant)
    """
    if structure_val > nurture_val and convergence_w < THRESHOLD_LOW:
        return -1
    elif nurture_val > structure_val and convergence_w > THRESHOLD_HIGH:
        return 1
    return 0   # near the Door — maximum uncertainty, gate state


# ─── Projection ──────────────────────────────────────────────────────────────

def _project_segment_to_axis(segment: list[float]) -> float:
    """
    Project one 192-dim embedding segment to a scalar convergence axis position.

    Method: mean of segment values, scaled to [-CONVERGENCE_RANGE, +CONVERGENCE_RANGE].
    Positive mean → nurture side (+x). Negative mean → structure side (-x).
    """
    if not segment:
        return 0.0
    mean_val = sum(segment) / len(segment)
    # tanh scaling: monotonically maps any real mean to (-CONVERGENCE_RANGE, +CONVERGENCE_RANGE)
    # without hard saturation. SCALE_FACTOR=2.0 keeps most embeddings in the
    # ±1.5 zone where the dual-curves have clear S/N dominance:
    #   mean ≈ ±0.5 → x ≈ ±0.76  |  mean ≈ ±1.0 → x ≈ ±1.52
    return math.tanh(mean_val * 2.0) * CONVERGENCE_RANGE


# ─── QBIT Prism Core ─────────────────────────────────────────────────────────

def decompose(embedding: list[float]) -> dict[str, dict[str, Any]]:
    """
    QBIT Prism decomposition.

    Takes any 1536-dim token embedding and returns an 8-dimensional
    convergence vector — one component per OCTi plane.

    Each component is a true vector quantity:
      - convergence_x: position on the dual-curve axis
      - structure_val: Father curve evaluation at that position
      - nurture_val:   Mother curve evaluation at that position
      - convergence_w: nurture_val - structure_val (signed dominance)
      - direction:     {-1, 0, +1} — the ternary direction (which pole)
      - magnitude:     door_distance — scalar magnitude from convergence point

    Returns dict keyed by plane name.
    """
    if len(embedding) != EMBEDDING_DIM:
        # Pad or truncate gracefully
        embedding = (embedding + [0.0] * EMBEDDING_DIM)[:EMBEDDING_DIM]

    result: dict[str, dict[str, Any]] = {}

    for i, plane in enumerate(OCTI_PLANES):
        start = i * SEGMENT_SIZE
        end   = start + SEGMENT_SIZE
        segment = embedding[start:end]

        x     = _project_segment_to_axis(segment)
        s_val = structure_curve(x)
        n_val = nurture_curve(x)
        conv_w = n_val - s_val

        result[plane] = {
            'convergence_x': round(x, 6),
            'structure_val': round(s_val, 6),
            'nurture_val':   round(n_val, 6),
            'convergence_w': round(conv_w, 6),
            'direction':     assign_direction(s_val, n_val, conv_w),
            'magnitude':     round(door_distance(x), 6),
        }

    return result


# ─── Direction Agreement (Retrieval Verification) ────────────────────────────

def direction_agreement(query_prism: dict, memory_prism: dict) -> dict:
    """
    Test if a retrieved memory's convergence direction agrees with the query.

    A memory is FERTILE if, for at least FERTILE_PLANE_RATIO of planes:
      1. The ternary directions agree (or one is 0 — the neutral gate state)
      2. The convergence positions are within AGREEMENT_DISTANCE of each other

    This is the geometric test that makes retrieval verifiable — not probabilistic.

    Returns dict with per-plane breakdown and overall FERTILE/BABEL result.
    """
    plane_results: dict[str, dict[str, Any]] = {}
    fertile_count = 0

    for plane in OCTI_PLANES:
        q = query_prism.get(plane, {})
        m = memory_prism.get(plane, {})

        if not q or not m:
            plane_results[plane] = {'fertile': False, 'reason': 'missing_data'}
            continue

        q_dir = q['direction']
        m_dir = m['direction']

        # Directions agree if they match, or either is 0 (the Door — passes all)
        direction_match = (q_dir == m_dir) or (q_dir == 0) or (m_dir == 0)

        # Magnitude proximity: must be within range on convergence axis
        delta = abs(q['convergence_x'] - m['convergence_x'])
        magnitude_close = delta < AGREEMENT_DISTANCE

        # Door is the universal gate — if either side is Door (direction=0),
        # position proximity is waived. Direction match alone is sufficient.
        is_door = (q_dir == 0) or (m_dir == 0)
        fertile = direction_match and (magnitude_close or is_door)
        if fertile:
            fertile_count += 1

        plane_results[plane] = {
            'query_dir':       q_dir,
            'memory_dir':      m_dir,
            'direction_match': direction_match,
            'axis_delta':      round(delta, 6),
            'magnitude_close': magnitude_close,
            'fertile':         fertile,
        }

    total = len(OCTI_PLANES)
    score = fertile_count / total
    overall = 'FERTILE' if score >= FERTILE_PLANE_RATIO else 'BABEL'

    return {
        'planes':         plane_results,
        'agreement_score': round(score, 4),
        'fertile_planes':  fertile_count,
        'total_planes':    total,
        'result':          overall,
    }


# ─── RAG Reasoning Chain ─────────────────────────────────────────────────────

def rag_reason(query_embedding: list[float],
               candidates: list[dict],
               primary_planes: list[str] | None = None) -> list[dict]:
    """
    Direction-verified retrieval for RAG Reasoning.

    Filters candidate memory entries by direction agreement with the query.
    Only FERTILE candidates are returned for use in the reasoning chain.

    Args:
        query_embedding: 1536-dim embedding of the current query/reasoning step
        candidates: list of dicts, each must have 'prism' (dict from decompose())
                    and any other fields from cws_memory.entries
        primary_planes: if set, only these planes must agree (relaxed mode)
                        if None, all planes evaluated equally (strict mode)

    Returns:
        List of FERTILE candidates sorted by agreement_score descending.
        Each candidate gains 'prism_agreement' field with the agreement result.
    """
    query_prism = decompose(query_embedding)
    fertile = []

    for candidate in candidates:
        memory_prism = candidate.get('prism')
        if not memory_prism:
            continue

        agreement = direction_agreement(query_prism, memory_prism)

        # Relaxed mode: only check primary planes
        if primary_planes:
            plane_fertiles = sum(
                1 for p in primary_planes
                if agreement['planes'].get(p, {}).get('fertile', False)
            )
            score = plane_fertiles / len(primary_planes)
            result = 'FERTILE' if score >= FERTILE_PLANE_RATIO else 'BABEL'
            agreement['agreement_score'] = round(score, 4)
            agreement['result'] = result

        candidate['prism_agreement'] = agreement
        if agreement['result'] == 'FERTILE':
            fertile.append(candidate)

    fertile.sort(key=lambda c: c['prism_agreement']['agreement_score'], reverse=True)
    return fertile


# ─── Plane Selector ──────────────────────────────────────────────────────────

def identify_planes(query_prism: dict,
                    top_n: int = 3) -> list[str]:
    """
    Identify which OCTi planes are most activated by the query.

    Returns the top_n planes with the highest door_distance (furthest from Door)
    — these are the planes where the query has the strongest directional signal.
    """
    scored = [
        (plane, query_prism[plane]['magnitude'])
        for plane in OCTI_PLANES
        if plane in query_prism
    ]
    scored.sort(key=lambda t: t[1], reverse=True)
    return [plane for plane, _ in scored[:top_n]]


# ─── Prism Vector Summary ─────────────────────────────────────────────────────

def prism_summary(prism: dict) -> str:
    """Human-readable one-line summary of a prism decomposition."""
    parts = []
    for plane in OCTI_PLANES:
        p = prism.get(plane, {})
        d = p.get('direction', 0)
        m = p.get('magnitude', 0.0)
        symbol = {-1: '←', 0: '·', 1: '→'}.get(d, '?')
        parts.append(f"{plane[:3]}:{symbol}{m:.2f}")
    return ' | '.join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# v1.0.1 — LocationID Matrix + Location Detection
# ═══════════════════════════════════════════════════════════════════════════════

from typing import Optional

# The cube has 3^8 = 6561 integer cells. Decimal subpositions let
# infinite entries fit inside a single cell without the cube expanding.
TERNARY_CUBE_CELLS = 3 ** len(OCTI_PLANES)   # 6561

# Display scale. Internal storage is ternary {-1, 0, +1}; the human-
# facing display multiplies each direction by CURVE_MAX_DISPLAY so a
# cell prints as {-7, 0, +7} per plane, matching the Phase 5 Akashic
# CURVE_MAX=7 range and Jamie's "[-7 0 7 7 0 -7 7 7] ^7" notation.
CURVE_MAX_DISPLAY = 7


def cell_tuple(prism: dict) -> tuple[int, int, int, int, int, int, int, int]:
    """
    Extract the 8-plane integer cell address from a prism decomposition.
    Returns a tuple of 8 ternary directions — one per OCTi plane.
    """
    return tuple(prism[plane]['direction'] for plane in OCTI_PLANES)


def cell_display(cell) -> list[int]:
    """Scale a ternary cell tuple onto the ±7 display range."""
    return [v * CURVE_MAX_DISPLAY for v in cell]


def cell_display_str(cell) -> str:
    """Human-facing cell notation: '[-7  0 +7 +7  0 -7 +7 +7] ^7'."""
    scaled = cell_display(cell)
    parts = []
    for v in scaled:
        if v == 0:
            parts.append("  0")
        elif v > 0:
            parts.append(f"+{v}")
        else:
            parts.append(f"{v}")
    return "[" + " ".join(parts) + "] ^7"


# ── Capital-name aliases (S7 naming rule) ───────────────────────────
# Jamie, 2026-04-13: 'planes Planes the Capital letter is
# distinguishing in curve position location Location'
#
# The Capital/lowercase distinction is semantic, not stylistic:
#   lowercase = a single component (one plane, one position,
#               one location on one axis)
#   Capital   = the composite (Plane = the 8-axis set, Position =
#               the 8-tuple cell, Location = the full LocationID)
#
# These aliases are additive — nothing existing is renamed. New
# code that wants to emphasise the composite nature of what it's
# handling can import the Capital form; old code that operates on
# a single component keeps the lowercase form. See
# docs/internal/naming-capital-composite-rule.md.

def Cell(prism: dict):
    """Capital alias — the composite 8-tuple Position. Same as cell_tuple()."""
    return cell_tuple(prism)


def Position(prism: dict):
    """Capital alias — the 8-tuple Position. Same as cell_tuple()."""
    return cell_tuple(prism)


def CellDisplay(cell) -> str:
    """Capital alias — the human-facing ^7 notation."""
    return cell_display_str(cell)


# Location(prism, **kwargs) aliases build_location_id once that
# function is defined below. The alias is set after the definition
# to avoid forward-reference issues.


def mediant(a_num: int, a_den: int, b_num: int, b_den: int) -> tuple[int, int]:
    """
    Stern-Brocot mediant of two rationals a_num/a_den and b_num/b_den.

    Given two neighbors in the Stern-Brocot tree, the mediant is
    (a_num + b_num) / (a_den + b_den) — guaranteed in lowest terms,
    always strictly between the two neighbors, and with a denominator
    that is the sum of the neighbors' denominators. This is the
    subposition-insert operation: infinite subdivision inside a
    bounded cell with no precision loss.

    Example:
        mediant(0, 1, 1, 1)  →  (1, 2)   # halfway
        mediant(0, 1, 1, 2)  →  (1, 3)   # one-third
        mediant(1, 3, 1, 2)  →  (2, 5)   # between 1/3 and 1/2
    """
    return (a_num + b_num, a_den + b_den)


def build_location_id(
    prism: dict,
    *,
    sub_num: int = 1,
    sub_den: int = 1,
    long_deg: Optional[float] = None,
    lat_deg: Optional[float] = None,
    sun_azimuth_deg: Optional[float] = None,
    sun_elevation_deg: Optional[float] = None,
    time_j2000_s: Optional[int] = None,
    aptitude_delta: int = 0,
    for_token: Optional[str] = None,
    rev_token: Optional[str] = None,
    forbidden: bool = False,
    witness: Optional[str] = None,
    source_text_hash: Optional[str] = None,
) -> dict:
    """
    Build a full LocationID record from a prism decomposition plus
    metadata. Returns a dict shaped for INSERT into cws_core.location_id.

    The integer cell address is pulled from the prism; everything else
    is supplied by the caller (the witness declares its own geo/cosmic
    time/aptitude/strand at the moment of speaking).
    """
    cell = cell_tuple(prism)
    return {
        'sensory_dir':       cell[0],
        'episodic_dir':      cell[1],
        'semantic_dir':      cell[2],
        'associative_dir':   cell[3],
        'procedural_dir':    cell[4],
        'lexical_dir':       cell[5],
        'relational_dir':    cell[6],
        'executive_dir':     cell[7],
        'sub_num':           sub_num,
        'sub_den':           sub_den,
        'long_deg':          long_deg,
        'lat_deg':           lat_deg,
        'sun_azimuth_deg':   sun_azimuth_deg,
        'sun_elevation_deg': sun_elevation_deg,
        'time_j2000_s':      time_j2000_s,
        'aptitude_delta':    aptitude_delta,
        'for_token':         for_token,
        'rev_token':         rev_token,
        'forbidden':         forbidden,
        'witness':           witness,
        'source_text_hash':  source_text_hash,
    }


# Capital alias for build_location_id — set here after definition.
# See docs/internal/naming-capital-composite-rule.md.
Location = build_location_id


# ── 4-way verdict for Location Detection ─────────────────────────────

VERDICT_FOUNDATION = 'FOUNDATION'
VERDICT_FRONTIER   = 'FRONTIER'
VERDICT_HALLUCINATION = 'HALLUCINATION'
VERDICT_VIOLATION  = 'VIOLATION'


def detect_location(
    candidate_prism: dict,
    *,
    cell_occupied_fn,
    cell_forbidden_fn,
    has_strand_anchor_fn,
    candidate_for_token: Optional[str] = None,
    candidate_rev_token: Optional[str] = None,
) -> dict:
    """
    Run Location Detection on a candidate prism decomposition.

    Args:
        candidate_prism: output of decompose() on whatever the model
            just said (or whatever the user is about to insert).
        cell_occupied_fn: callable(cell_tuple) -> bool, returns True
            if at least one LocationID already lives in this cell.
        cell_forbidden_fn: callable(cell_tuple) -> bool, returns True
            if the cell is marked forbidden (covenant violation).
        has_strand_anchor_fn: callable(for_token, rev_token) -> bool,
            returns True if at least one of the candidate's strand
            tokens points at an occupied cell. This is the signal
            that distinguishes a legitimate frontier entry (has
            anchors) from a hallucination (no anchors).
        candidate_for_token / candidate_rev_token: the candidate's
            own strand tokens, or None.

    Returns:
        {
          'verdict': FOUNDATION | FRONTIER | HALLUCINATION | VIOLATION,
          'cell': (d1, d2, ..., d8),
          'cell_occupied': bool,
          'cell_forbidden': bool,
          'has_anchor': bool,
          'reason': str,
        }

    Verdict rules:
        forbidden cell          → VIOLATION        (covenant prohibits)
        occupied + not forbidden → FOUNDATION       (already in the matrix)
        empty + has anchor       → FRONTIER         (new but strand-supported)
        empty + no  anchor       → HALLUCINATION    (no covenant support)
    """
    cell = cell_tuple(candidate_prism)
    occupied  = cell_occupied_fn(cell)
    forbidden = cell_forbidden_fn(cell)
    has_anchor = has_strand_anchor_fn(candidate_for_token, candidate_rev_token)

    if forbidden:
        verdict = VERDICT_VIOLATION
        reason = 'candidate cell is marked forbidden by the covenant'
    elif occupied:
        verdict = VERDICT_FOUNDATION
        reason = 'candidate cell already occupied by verified foundation'
    elif has_anchor:
        verdict = VERDICT_FRONTIER
        reason = 'candidate cell empty but at least one strand token anchors into occupied cell'
    else:
        verdict = VERDICT_HALLUCINATION
        reason = 'candidate cell empty and no strand anchor — no covenant support'

    return {
        'verdict':        verdict,
        'cell':           cell,
        'cell_occupied':  occupied,
        'cell_forbidden': forbidden,
        'has_anchor':     has_anchor,
        'reason':         reason,
    }


# ── Self-test ────────────────────────────────────────────────────────

def _selftest_v101() -> dict:
    """
    Minimal v1.0.1 round-trip. Returns a dict suitable for the
    'prism verify' SkyAvi skill.
    """
    # Fake embedding that has a clear structure dominance in the
    # semantic plane — we know exactly what cell it should land in.
    # Mean must land the projected axis position near x = ±1
    # (the curve sweet spot); tanh scaling means mean ≈ ±0.3 lands
    # near x = ±1.07, which is inside the direction-resolution zone.
    emb = [0.0] * EMBEDDING_DIM
    # Push semantic segment moderately negative (structure / foundation)
    for i in range(SEGMENT_SIZE * 2, SEGMENT_SIZE * 3):
        emb[i] = -0.3
    # Push executive segment moderately positive (nurture / growth)
    for i in range(SEGMENT_SIZE * 7, SEGMENT_SIZE * 8):
        emb[i] = 0.3
    prism = decompose(emb)
    cell = cell_tuple(prism)

    # Stern-Brocot subdivision demo
    first_half  = mediant(0, 1, 1, 1)
    second_half = mediant(first_half[0], first_half[1], 1, 1)

    # Mock a matrix with ONE occupied cell = our known cell
    occupied_cells = {cell}
    forbidden_cells: set = set()

    def is_occupied(c):  return c in occupied_cells
    def is_forbidden(c): return c in forbidden_cells
    def has_anchor(f, r): return False

    # 1. Candidate matches occupied cell → FOUNDATION
    v1 = detect_location(
        prism,
        cell_occupied_fn=is_occupied,
        cell_forbidden_fn=is_forbidden,
        has_strand_anchor_fn=has_anchor,
    )

    # 2. Candidate in a different empty cell, no anchors → HALLUCINATION
    other_emb = [0.0] * EMBEDDING_DIM
    other_prism = decompose(other_emb)  # lands at (0,0,0,0,0,0,0,0)
    v2 = detect_location(
        other_prism,
        cell_occupied_fn=is_occupied,
        cell_forbidden_fn=is_forbidden,
        has_strand_anchor_fn=has_anchor,
    )

    # 3. Same empty candidate, but WITH a strand anchor → FRONTIER
    def has_anchor_yes(f, r): return True
    v3 = detect_location(
        other_prism,
        cell_occupied_fn=is_occupied,
        cell_forbidden_fn=is_forbidden,
        has_strand_anchor_fn=has_anchor_yes,
    )

    # 4. Forbidden cell → VIOLATION
    forbidden_cells.add(cell_tuple(other_prism))
    v4 = detect_location(
        other_prism,
        cell_occupied_fn=is_occupied,
        cell_forbidden_fn=is_forbidden,
        has_strand_anchor_fn=has_anchor_yes,
    )

    return {
        'version': __version__,
        'cube_cells': TERNARY_CUBE_CELLS,
        'mediant_demo': {
            '1/2':  first_half,
            '2/3':  second_half,
        },
        'verdict_foundation':    v1['verdict'],
        'verdict_hallucination': v2['verdict'],
        'verdict_frontier':      v3['verdict'],
        'verdict_violation':     v4['verdict'],
        'all_four_pass': (
            v1['verdict'] == VERDICT_FOUNDATION and
            v2['verdict'] == VERDICT_HALLUCINATION and
            v3['verdict'] == VERDICT_FRONTIER and
            v4['verdict'] == VERDICT_VIOLATION
        ),
    }


if __name__ == '__main__':
    import json
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'verify'
    if cmd == 'verify':
        print(json.dumps(_selftest_v101(), indent=2))
    elif cmd == 'version':
        print(__version__)
    else:
        print('usage: s7_prism.py [verify|version]')
