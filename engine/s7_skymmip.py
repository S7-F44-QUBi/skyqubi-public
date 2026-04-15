#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — SkyMMIP™ (Sky Multi-Modal IP Convergence)
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
#
# SkyMMIP™ is an S7 trademark of 123Tech / 2XR, LLC. "IP" is in the
# name on purpose — the product is intellectual property by design,
# safe and secure by construction.
# ═══════════════════════════════════════════════════════════════════
"""
SkyMMIP — every modality projects onto the same 8-plane trinity cube.

Jamie: 'SkyMMIP shows IP in the name, safe secure, MmIP'

One coordinate system. One matrix (cws_core.location_id). One
4-way verdict (FOUNDATION / FRONTIER / HALLUCINATION / VIOLATION).
Text, code, image, audio, sensor all end up as LocationIDs that the
rest of S7 reasons over identically.

How it works:
    input (bytes or text)
       │
       ▼
    ModalityProjector.project(input)   → prism_dict  (same shape
                                                       as s7_prism
                                                       .decompose
                                                       output)
       │
       ▼
    s7_prism.cell_tuple(prism_dict)    → 8-tuple cell address
       │
       ▼
    cws_core.location_id row  (modality=<this modality>)

Implemented projectors:
    TextProjector   — wraps the Phase 5 Akashic encoder bridge
    CodeProjector   — lexical features: LoC, comment ratio, import
                      density, function count, vocabulary size,
                      nesting depth, token entropy, has-main
Stub projectors (raise NotImplementedError cleanly):
    ImageProjector   — pixel stats, future SIFT/HOG features
    AudioProjector   — MFCC / spectral features
    SensorProjector  — time-series feature extraction

Every projector must:
  1. Accept its native input type
  2. Return a dict keyed by s7_prism.OCTI_PLANES with
     {'direction': -1|0|+1, 'magnitude': float>=0} per plane
  3. Be deterministic (same input → same prism)
  4. Be cheap (no network, no disk beyond the input itself)
"""
from __future__ import annotations

import math
import os
import re
import sys
from typing import Any

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import s7_prism


# ── Helpers ──────────────────────────────────────────────────────────

def _direction_from_value(v: float, thresh: float = 0.1) -> int:
    """Ternary classification: negative, zero, positive."""
    if v < -thresh:
        return -1
    if v > thresh:
        return 1
    return 0


def _empty_prism() -> dict:
    """Return a prism dict with all planes at the Door (direction 0, magnitude 0)."""
    return {plane: {"direction": 0, "magnitude": 0.0} for plane in s7_prism.OCTI_PLANES}


# ── Base class ───────────────────────────────────────────────────────

class ModalityProjector:
    """Abstract base. Subclasses implement .project(input)."""

    modality_name: str = "base"

    def project(self, payload: Any) -> dict:
        raise NotImplementedError(f"{self.modality_name}: project not implemented")


# ── TextProjector ────────────────────────────────────────────────────

class TextProjector(ModalityProjector):
    modality_name = "text"

    def project(self, payload: str) -> dict:
        # Delegate to the existing text → prism path used by
        # s7_prism_detect / s7_prism_ingest. Import lazily so
        # importing s7_skymmc doesn't need psycopg2.
        from s7_prism_detect import _build_index_with_universals, akashic_to_prism
        import s7_akashic
        index = _build_index_with_universals()
        tokens = s7_akashic.tokenise(payload)
        encoding = s7_akashic.encode(tokens, index)
        return akashic_to_prism(encoding)


# ── CodeProjector ────────────────────────────────────────────────────

# Simple lexical features — no AST parser needed. Each plane gets a
# feature that maps cleanly to a ternary direction + magnitude.

_COMMENT_RE = re.compile(r"(^\s*#.*|^\s*//.*|/\*.*?\*/|\"\"\".*?\"\"\"|'''.*?''')", re.M | re.S)
_IMPORT_RE = re.compile(r"^\s*(import |from |#include |require |use |using )", re.M)
_FUNC_RE = re.compile(r"(^\s*def |^\s*function |^\s*fn |^\s*func |^\s*class )", re.M)
_MAIN_RE = re.compile(r'(if __name__ == ["\']__main__["\']|^int main\b|^func main\b|^fn main\b)', re.M)
_TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class CodeProjector(ModalityProjector):
    modality_name = "code"

    def project(self, payload: str) -> dict:
        if not payload:
            return _empty_prism()

        lines = payload.splitlines() or [""]
        loc = max(len(lines), 1)
        chars = len(payload)

        # Feature extraction
        comment_chars = sum(len(m.group(0)) for m in _COMMENT_RE.finditer(payload))
        comment_ratio = comment_chars / max(chars, 1)            # 0..1

        imports = len(_IMPORT_RE.findall(payload))
        import_density = imports / loc                           # higher = more coupled

        funcs = len(_FUNC_RE.findall(payload))
        func_density = funcs / loc                               # higher = more structured

        tokens = _TOKEN_RE.findall(payload)
        unique_tokens = len(set(tokens))
        vocab_ratio = unique_tokens / max(len(tokens), 1)        # 0..1 (1 = all unique)

        # Nesting depth approximation — max leading-whitespace run
        max_indent = 0
        for line in lines:
            stripped = line.lstrip()
            if not stripped:
                continue
            indent = len(line) - len(stripped)
            if indent > max_indent:
                max_indent = indent
        nesting_norm = min(max_indent / 16.0, 1.0)               # 0..1 (saturates at 16 cols)

        # Token entropy (very cheap Shannon approximation)
        token_counts: dict[str, int] = {}
        for t in tokens:
            token_counts[t] = token_counts.get(t, 0) + 1
        total = sum(token_counts.values()) or 1
        entropy = -sum(
            (c / total) * math.log2(c / total) for c in token_counts.values() if c > 0
        )
        entropy_norm = min(entropy / 10.0, 1.0)                  # 0..1 (saturates ~10 bits)

        has_main = 1.0 if _MAIN_RE.search(payload) else -1.0

        # Map features to the 8 OCTi planes. Each feature becomes a
        # signed value roughly in [-1, +1], then passes through the
        # ternary direction classifier with magnitude.
        #
        # The mapping is deliberate and documented, not magical:
        #   sensory     — file-shape signal: total LoC scale
        #   episodic    — temporal approximation: entropy (how much
        #                 of the vocabulary is new vs. repeated)
        #   semantic    — comment ratio (intent density)
        #   associative — import density (cross-file coupling)
        #   procedural  — function density (how-to content)
        #   lexical     — vocab_ratio (token diversity)
        #   relational  — nesting depth (structural hierarchy)
        #   executive   — has_main (top-level control flow present)

        loc_norm = math.tanh(loc / 200.0)    # 0..~1 (200 LoC saturates)

        features = [
            ("sensory",     loc_norm * 2 - 1),
            ("episodic",    entropy_norm * 2 - 1),
            ("semantic",    comment_ratio * 4 - 0.5),     # 12.5% comment = Door
            ("associative", min(import_density * 20, 1) * 2 - 1),
            ("procedural",  min(func_density * 20, 1) * 2 - 1),
            ("lexical",     vocab_ratio * 2 - 1),
            ("relational",  nesting_norm * 2 - 1),
            ("executive",   has_main),
        ]

        prism: dict = {}
        for plane, value in features:
            prism[plane] = {
                "direction": _direction_from_value(value),
                "magnitude": round(abs(value), 6),
            }
        return prism


# ── Stub projectors ──────────────────────────────────────────────────

class ImageProjector(ModalityProjector):
    """
    Real image → 8-plane projection using PIL/Pillow.

    Features per plane:
      sensory     : log-scaled pixel count (how much visual info)
      episodic    : file format ordinal    (png→+, jpeg→0, other→-)
      semantic    : aspect ratio           (square vs wide/tall)
      associative : color channel variance (vivid vs flat)
      procedural  : edge density           (complexity via gradient)
      lexical     : unique-color bucket    (color vocabulary)
      relational  : brightness mean        (structural brightness)
      executive   : saturation mean        (dominance/intentionality)

    Accepts either bytes (image file content) or a file path string.
    """

    modality_name = "image"

    def project(self, payload):
        from PIL import Image, ImageStat, ImageFilter
        from io import BytesIO
        import math

        # Accept bytes or a file path
        if isinstance(payload, (bytes, bytearray)):
            img = Image.open(BytesIO(bytes(payload)))
        elif isinstance(payload, str) and os.path.isfile(payload):
            img = Image.open(payload)
        else:
            raise ValueError("ImageProjector payload must be bytes or a file path")

        fmt = (img.format or "").upper()
        width, height = img.size
        pixel_count = max(width * height, 1)

        # Normalise to RGB for statistics
        rgb = img.convert("RGB")
        stat = ImageStat.Stat(rgb)
        mean_r, mean_g, mean_b = stat.mean
        stddev_r, stddev_g, stddev_b = stat.stddev

        # sensory: log-scaled pixel count (a 1 MP image → ~0.5, a
        # tiny icon → negative, a huge photo → ~1)
        sensory_raw = math.log10(pixel_count / 1_000_000.0 + 1e-6) / 3.0
        sensory_raw = max(-1.0, min(1.0, sensory_raw))

        # episodic: format ordinal
        format_map = {"PNG": 0.5, "WEBP": 0.4, "JPEG": 0.0, "JPG": 0.0, "GIF": -0.3, "BMP": -0.5}
        episodic_raw = format_map.get(fmt, -0.7)

        # semantic: aspect ratio (tall = -1, square = 0, wide = +1)
        ar = width / height
        semantic_raw = math.tanh(math.log(ar))  # log(ar) smooths the curve

        # associative: average channel variance normalised to [-1, 1]
        stddev_mean = (stddev_r + stddev_g + stddev_b) / 3.0
        associative_raw = (stddev_mean / 80.0) * 2 - 1
        associative_raw = max(-1.0, min(1.0, associative_raw))

        # procedural: edge density via simple filter
        try:
            edges = rgb.convert("L").filter(ImageFilter.FIND_EDGES)
            edge_stat = ImageStat.Stat(edges)
            edge_mean = edge_stat.mean[0] if edge_stat.mean else 0.0
            procedural_raw = (edge_mean / 50.0) * 2 - 1
            procedural_raw = max(-1.0, min(1.0, procedural_raw))
        except Exception:
            procedural_raw = 0.0

        # lexical: unique colors in a downscaled version (fast, bounded)
        small = rgb.resize((64, 64))
        colors = small.getcolors(maxcolors=64 * 64) or []
        unique_colors = len(colors)
        lexical_raw = (unique_colors / 2048.0) * 2 - 1
        lexical_raw = max(-1.0, min(1.0, lexical_raw))

        # relational: brightness mean (0..255 → -1..+1)
        brightness = (mean_r + mean_g + mean_b) / 3.0
        relational_raw = (brightness / 127.5) - 1.0

        # executive: saturation via HSV mean S channel
        hsv = rgb.convert("HSV")
        hsv_stat = ImageStat.Stat(hsv)
        sat_mean = hsv_stat.mean[1] if len(hsv_stat.mean) > 1 else 0.0
        executive_raw = (sat_mean / 127.5) - 1.0

        features = [
            ("sensory",     sensory_raw),
            ("episodic",    episodic_raw),
            ("semantic",    semantic_raw),
            ("associative", associative_raw),
            ("procedural",  procedural_raw),
            ("lexical",     lexical_raw),
            ("relational",  relational_raw),
            ("executive",   executive_raw),
        ]

        prism: dict = {}
        for plane, value in features:
            prism[plane] = {
                "direction": _direction_from_value(value),
                "magnitude": round(abs(value), 6),
            }
        return prism


class AudioProjector(ModalityProjector):
    modality_name = "audio"

    def project(self, payload: bytes) -> dict:
        raise NotImplementedError(
            "audio projector is a stub — next turn: MFCC + spectral centroid + zero-crossing rate"
        )


class SensorProjector(ModalityProjector):
    modality_name = "sensor"

    def project(self, payload: list) -> dict:
        raise NotImplementedError(
            "sensor projector is a stub — next turn: mean/variance/trend features over time series"
        )


# ── Registry ─────────────────────────────────────────────────────────

MODALITIES: dict[str, ModalityProjector] = {
    "text":   TextProjector(),
    "code":   CodeProjector(),
    "image":  ImageProjector(),
    "audio":  AudioProjector(),
    "sensor": SensorProjector(),
}

IMPLEMENTED = {"text", "code", "image"}
STUBS = {"audio", "sensor"}


def list_modalities() -> dict:
    return {
        "implemented": sorted(IMPLEMENTED),
        "stubs":       sorted(STUBS),
        "total":       len(MODALITIES),
    }


def convergence(modality: str, payload: Any) -> dict:
    """
    Project `payload` through the named modality and return a
    prism dict plus the 8-plane integer cell tuple. Raises
    ValueError for unknown modality and NotImplementedError for
    stub modalities.

    The response includes BOTH the internal ternary cell and the
    human-facing ^7-scale display. Storage is ternary (that's what
    indexes); display is on the ±7 curve range.
    """
    if modality not in MODALITIES:
        raise ValueError(f"unknown modality: {modality} (known: {sorted(MODALITIES)})")
    projector = MODALITIES[modality]
    prism = projector.project(payload)
    cell = s7_prism.cell_tuple(prism)
    return {
        "modality":     modality,
        "cell":         list(cell),              # ternary storage form
        "cell_display": s7_prism.cell_display(cell),   # ±7 display form
        "cell_notation": s7_prism.cell_display_str(cell),
        "prism":        prism,
    }


# ── CLI ──
if __name__ == "__main__":
    import json
    if len(sys.argv) < 2:
        print(json.dumps({"usage": "s7_skymmc.py <list|project> [modality] [input...]"}))
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == "list":
        print(json.dumps(list_modalities(), indent=2))
        sys.exit(0)
    if cmd == "project":
        if len(sys.argv) < 4:
            print("usage: s7_skymmc.py project <modality> <input...>")
            sys.exit(2)
        modality = sys.argv[2]
        raw = " ".join(sys.argv[3:])
        # For binary modalities (image/audio/sensor), pass the path
        # through — the projector handles file I/O itself. For text
        # modalities, read the file if it exists, else pass the
        # literal string.
        if modality in ("image", "audio", "sensor"):
            payload = raw
        elif os.path.isfile(raw):
            with open(raw, "r", encoding="utf-8", errors="replace") as f:
                payload = f.read()
        else:
            payload = raw
        try:
            result = convergence(modality, payload)
        except NotImplementedError as e:
            print(json.dumps({"status": "stub", "modality": modality, "reason": str(e)}, indent=2))
            sys.exit(3)
        except ValueError as e:
            print(json.dumps({"status": "error", "reason": str(e)}, indent=2))
            sys.exit(2)
        print(json.dumps(result, indent=2))
        sys.exit(0)
    print(f"unknown subcommand: {cmd}")
    sys.exit(2)
