# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Akashic Cipher (Encoder / Embedder / Compressor)
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606
# ═══════════════════════════════════════════════════════════════════
"""
S7 Akashic Cipher — 27-glyph per-appliance pipeline.

This is distinct from s7_akashic.py (the Phase 5 Akashic Language
encoder that projects model outputs onto a 7-plane curve). This
module handles the per-appliance CIPHER layer — the three-stage
pipeline that gives each deployed QUBi its own randomized byte-form
of any given payload:

    encode(plaintext, seed)        → glyph_sequence
    embed(glyph_sequence)          → trinity_sequence
    compress(trinity_sequence)     → packed bytes

Reverse chain with the same seed recovers the original. Without the
seed, cross-appliance correlation of "the same update" is
mechanically blocked — which is the whole point of akashic_seed on
appliance.appliance.

Design notes: docs/internal/akashic-encoder-design.md
"""
from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from typing import Iterable, List, Tuple

# ── The 27-glyph alphabet ───────────────────────────────────────────
# Unicode code points deliberately chosen from outside the QWERTY
# keyboard space. Index 0..26 maps 1:1 to the 27 trinity positions
# (memory, present, destiny) in lexicographic order.

ALPHABET: List[str] = [
    "\u25BC", "\u25E2", "\u219F",   # STASIS, SINKING, RESURRECTION
    "\u26A0", "\u25CC", "\u21A5",   # DANGER, DISCERNMENT, RECOVERING
    "\u2318", "\u25E8", "\u21D7",   # TOWER, SURFACING, REBUILDING
    "\u2349", "\u00B7", "\u21AF",   # DOUBT, DRIFT, HOPE
    "\u25EF", "\u2727", "\u25C9",   # PORTAL_CLOSE, MAX_UNCERTAINTY, PORTAL_OPEN
    "\u2307", "\u2726", "\u21E1",   # FADING, PRESENT_ONLY, EMERGING
    "\u2198", "\u2756", "\u2934",   # FALLING, MEMORY_ONLY, RETURNING
    "\u2691", "\u2740", "\u273A",   # WARNING, ROOTED, FERTILE
    "\u21D8", "\u2722", "\u2738",   # CRESTING, GROWING, ABUNDANT
]

NAMES: List[str] = [
    "STASIS", "SINKING", "RESURRECTION",
    "DANGER", "DISCERNMENT", "RECOVERING",
    "TOWER", "SURFACING", "REBUILDING",
    "DOUBT", "DRIFT", "HOPE",
    "PORTAL_CLOSE", "MAX_UNCERTAINTY", "PORTAL_OPEN",
    "FADING", "PRESENT_ONLY", "EMERGING",
    "FALLING", "MEMORY_ONLY", "RETURNING",
    "WARNING", "ROOTED", "FERTILE",
    "CRESTING", "GROWING", "ABUNDANT",
]

VECTORS: List[Tuple[int, int, int]] = [
    (m, p, d)
    for m in (-1, 0, 1)
    for p in (-1, 0, 1)
    for d in (-1, 0, 1)
]

assert len(ALPHABET) == 27 and len(set(ALPHABET)) == 27
assert len(VECTORS) == 27
assert len(NAMES) == 27


# ── Seed & permutation ──────────────────────────────────────────────

def generate_seed(n_bytes: int = 16) -> str:
    """Fresh cryptographic seed for a new appliance (hex string)."""
    return secrets.token_hex(n_bytes)


def _permutation_from_seed(seed: str, size: int = 27) -> List[int]:
    """Deterministic permutation of [0..size-1] from a seed."""
    perm = list(range(size))
    h = hashlib.sha256(seed.encode("utf-8")).digest()
    while len(h) < size:
        h += hashlib.sha256(h).digest()
    for i in range(size - 1, 0, -1):
        j = h[i] % (i + 1)
        perm[i], perm[j] = perm[j], perm[i]
    return perm


# ── Stage 1: ENCODE / DECODE ────────────────────────────────────────
# First landing operates on byte values in [0..26], which covers the
# 27-position address space of the alphabet. Phase 2 extends to full
# 0..255 byte range via two-glyph encoding (base-27 digit pairs).

def encode(plaintext_bytes: bytes, seed: str) -> str:
    """Encode a byte sequence into an Akashic glyph sequence."""
    perm = _permutation_from_seed(seed)
    out = []
    for i, byte in enumerate(plaintext_bytes):
        shift = perm[i % 27]
        idx = (byte + shift) % 27
        out.append(ALPHABET[idx])
    return "".join(out)


def decode(glyph_sequence: str, seed: str) -> bytes:
    """Reverse of encode. Requires the same seed."""
    perm = _permutation_from_seed(seed)
    glyph_to_idx = {g: i for i, g in enumerate(ALPHABET)}
    out = bytearray()
    for i, glyph in enumerate(glyph_sequence):
        if glyph not in glyph_to_idx:
            raise ValueError(f"non-Akashic glyph at position {i}: {glyph!r}")
        shift = perm[i % 27]
        idx = glyph_to_idx[glyph]
        out.append((idx - shift) % 27)
    return bytes(out)


# ── Stage 2: EMBED / DEEMBED ────────────────────────────────────────

def embed(glyph_sequence: str) -> List[Tuple[int, int, int]]:
    """Glyph sequence → trinity vector sequence."""
    glyph_to_idx = {g: i for i, g in enumerate(ALPHABET)}
    return [VECTORS[glyph_to_idx[g]] for g in glyph_sequence]


def deembed(trinity_sequence: Iterable[Tuple[int, int, int]]) -> str:
    """Trinity vector sequence → glyph sequence."""
    vec_to_idx = {v: i for i, v in enumerate(VECTORS)}
    return "".join(ALPHABET[vec_to_idx[v]] for v in trinity_sequence)


# ── Stage 3: COMPRESS / DECOMPRESS ──────────────────────────────────
# 2 bits per trinity axis → 6 bits per glyph → 4 glyphs per 3 bytes.

def _axis_to_bits(v: int) -> int:
    return {-1: 0b00, 0: 0b01, 1: 0b10}[v]


def _bits_to_axis(b: int) -> int:
    return {0b00: -1, 0b01: 0, 0b10: 1}[b]


def compress(trinity_sequence: List[Tuple[int, int, int]]) -> bytes:
    """Pack a trinity sequence into bytes. 4-byte BE length prefix + 6 bits/glyph."""
    n = len(trinity_sequence)
    bits = 0
    width = 0
    out = bytearray(n.to_bytes(4, "big"))
    for (m, p, d) in trinity_sequence:
        bits = (bits << 6) | (_axis_to_bits(m) << 4) | (_axis_to_bits(p) << 2) | _axis_to_bits(d)
        width += 6
        while width >= 8:
            width -= 8
            out.append((bits >> width) & 0xFF)
            bits &= (1 << width) - 1
    if width > 0:
        out.append((bits << (8 - width)) & 0xFF)
    return bytes(out)


def decompress(packed: bytes) -> List[Tuple[int, int, int]]:
    """Reverse of compress."""
    n = int.from_bytes(packed[:4], "big")
    data = packed[4:]
    bits = 0
    width = 0
    out: List[Tuple[int, int, int]] = []
    pos = 0
    while len(out) < n:
        if width < 6:
            if pos >= len(data):
                raise ValueError("truncated packed payload")
            bits = (bits << 8) | data[pos]
            pos += 1
            width += 8
        glyph_bits = (bits >> (width - 6)) & 0b111111
        width -= 6
        bits &= (1 << width) - 1
        m = _bits_to_axis((glyph_bits >> 4) & 0b11)
        p = _bits_to_axis((glyph_bits >> 2) & 0b11)
        d = _bits_to_axis(glyph_bits & 0b11)
        out.append((m, p, d))
    return out


# ── Full pipeline + round-trip verification ─────────────────────────

@dataclass
class AkashicStats:
    raw_bytes: int
    glyph_count: int
    packed_bytes: int
    compression_ratio: float


def pipeline(plaintext_bytes: bytes, seed: str) -> Tuple[bytes, AkashicStats]:
    """Full encode → embed → compress. Returns packed bytes + stats."""
    glyphs = encode(plaintext_bytes, seed)
    trinity = embed(glyphs)
    packed = compress(trinity)
    stats = AkashicStats(
        raw_bytes=len(plaintext_bytes),
        glyph_count=len(glyphs),
        packed_bytes=len(packed),
        compression_ratio=len(packed) / max(len(plaintext_bytes), 1),
    )
    return packed, stats


def unpipeline(packed: bytes, seed: str) -> bytes:
    """Full decompress → deembed → decode. Reverse of pipeline()."""
    trinity = decompress(packed)
    glyphs = deembed(trinity)
    return decode(glyphs, seed)


def verify_roundtrip(seed: str | None = None, sample: bytes | None = None) -> dict:
    """Round-trip a sample through the full pipeline. Raises on mismatch."""
    if seed is None:
        seed = generate_seed()
    if sample is None:
        # 27-byte sample covering the full alphabet index range.
        sample = bytes(range(27))
    packed, stats = pipeline(sample, seed)
    recovered = unpipeline(packed, seed)
    if recovered != sample:
        raise AssertionError(
            f"round-trip mismatch:\n  sample   ={sample.hex()}\n  recovered={recovered.hex()}"
        )
    return {
        "status": "pass",
        "seed_head": seed[:8] + "…",
        "raw_bytes": stats.raw_bytes,
        "glyph_count": stats.glyph_count,
        "packed_bytes": stats.packed_bytes,
        "ratio": round(stats.compression_ratio, 3),
    }


# ── Alphabet introspection ──────────────────────────────────────────

def alphabet_table() -> str:
    lines = ["idx  (m, p, d)   name              glyph"]
    lines.append("---  ----------  ---------------   -----")
    for i, (g, v, n) in enumerate(zip(ALPHABET, VECTORS, NAMES)):
        m, p, d = v
        lines.append(f"{i:3d}  ({m:+d},{p:+d},{d:+d})  {n:<15}   {g}")
    return "\n".join(lines)


# ── CLI ──
if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "verify"
    if cmd == "verify":
        print(verify_roundtrip())
    elif cmd == "alphabet":
        print(alphabet_table())
    else:
        print("usage: s7_akashic_cipher.py [verify|alphabet]")
