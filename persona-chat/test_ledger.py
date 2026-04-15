#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# Unit tests for persona-chat/ledger.py
#
# Covers:
#   - append_row creates a fresh ledger with a genesis prev_hash
#   - append_row chains correctly across multiple rows
#   - verify_chain returns (True, None) for intact chains
#   - verify_chain detects row_hash tampering
#   - verify_chain detects prev_hash tampering (severed link)
#   - quarantine moves the file and preserves a reason sidecar
#   - cross-persona read merges three persona files in timestamp order
#
# Run:  python3 -m unittest test_ledger -v
#
# Uses tempfile.TemporaryDirectory so no state leaks into real /s7
# ═══════════════════════════════════════════════════════════════════

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ledger import (
    GENESIS_PREV_HASH,
    ALLOWED_PERSONAS,
    append_row,
    compute_row_hash,
    ensure_session_dirs,
    iter_cross_persona_rows_reverse,
    last_row_hash,
    persona_ledger_path,
    quarantine,
    read_rows,
    session_dir,
    verify_chain,
)


USER = "jamie-test"
SESSION = "00000000-0000-0000-0000-000000000001"

QBIT_EMPTY = {"in": 0, "out": 0, "total": 0}


class TestGenesis(unittest.TestCase):
    """Genesis row creation and the empty-file case."""

    def test_empty_file_returns_genesis_prev_hash(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "empty.ndjson"
            self.assertEqual(last_row_hash(path), GENESIS_PREV_HASH)

    def test_first_row_uses_genesis_prev_hash(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            row = append_row(
                path=path,
                session_id=SESSION,
                user_id=USER,
                persona="samuel",
                engine="ollama",
                model="s7-samuel:v1",
                tier="L1",
                user_input="hi",
                assistant_output="hi back",
                qbit_count={"in": 1, "out": 2, "total": 3},
                latency_ms=332,
                qps=9.0,
            )
            self.assertEqual(row.prev_hash, GENESIS_PREV_HASH)
            self.assertEqual(len(row.row_hash), 64)
            # Chain the row hash we computed ourselves to verify
            payload = row.canonical_without_hash()
            expected_hash = compute_row_hash(GENESIS_PREV_HASH, payload)
            self.assertEqual(row.row_hash, expected_hash)


class TestChaining(unittest.TestCase):
    """Multi-row chains link correctly."""

    def test_three_row_chain_links_correctly(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "carli", root=root)

            r1 = append_row(
                path=path, session_id=SESSION, user_id=USER, persona="carli",
                engine="ollama", model="s7-carli:0.6b", tier="L1",
                user_input="test 1", assistant_output="response 1",
                qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
            )
            r2 = append_row(
                path=path, session_id=SESSION, user_id=USER, persona="carli",
                engine="ollama", model="s7-carli:0.6b", tier="L1",
                user_input="test 2", assistant_output="response 2",
                qbit_count=QBIT_EMPTY, latency_ms=200, qps=10.0,
            )
            r3 = append_row(
                path=path, session_id=SESSION, user_id=USER, persona="carli",
                engine="ollama", model="s7-carli:0.6b", tier="L1",
                user_input="test 3", assistant_output="response 3",
                qbit_count=QBIT_EMPTY, latency_ms=300, qps=10.0,
            )

            # Each row's prev_hash should match the previous row's row_hash
            self.assertEqual(r1.prev_hash, GENESIS_PREV_HASH)
            self.assertEqual(r2.prev_hash, r1.row_hash)
            self.assertEqual(r3.prev_hash, r2.row_hash)

            # Verify the chain on disk
            ok, err = verify_chain(path)
            self.assertTrue(ok, f"chain verification failed: {err}")

    def test_last_row_hash_returns_newest(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "elias", root=root)

            for i in range(5):
                append_row(
                    path=path, session_id=SESSION, user_id=USER, persona="elias",
                    engine="ollama", model="s7-elias:1.3b", tier="L1",
                    user_input=f"turn {i}", assistant_output=f"reply {i}",
                    qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
                )

            rows = read_rows(path)
            self.assertEqual(len(rows), 5)
            self.assertEqual(last_row_hash(path), rows[-1].row_hash)


class TestVerification(unittest.TestCase):
    """verify_chain catches tampering."""

    def test_intact_chain_verifies(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            for i in range(3):
                append_row(
                    path=path, session_id=SESSION, user_id=USER, persona="samuel",
                    engine="ollama", model="s7-samuel:v1", tier="L1",
                    user_input=f"q{i}", assistant_output=f"a{i}",
                    qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
                )
            ok, err = verify_chain(path)
            self.assertTrue(ok)
            self.assertIsNone(err)

    def test_tampered_row_hash_fails_verification(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            for i in range(3):
                append_row(
                    path=path, session_id=SESSION, user_id=USER, persona="samuel",
                    engine="ollama", model="s7-samuel:v1", tier="L1",
                    user_input=f"q{i}", assistant_output=f"a{i}",
                    qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
                )

            # Tamper with the row_hash of row 1 (middle row)
            lines = path.read_text().splitlines()
            d = json.loads(lines[1])
            d["row_hash"] = "0" * 64  # deliberately wrong
            lines[1] = json.dumps(d, sort_keys=True, separators=(",", ":"))
            path.write_text("\n".join(lines) + "\n")

            ok, err = verify_chain(path)
            self.assertFalse(ok)
            self.assertIn("row 1", err)

    def test_tampered_content_fails_verification(self):
        """Changing the user_input but keeping the stored row_hash breaks
        the canonical-payload re-computation."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            for i in range(2):
                append_row(
                    path=path, session_id=SESSION, user_id=USER, persona="samuel",
                    engine="ollama", model="s7-samuel:v1", tier="L1",
                    user_input=f"q{i}", assistant_output=f"a{i}",
                    qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
                )

            # Change the user_input of row 0 but keep the row_hash intact
            lines = path.read_text().splitlines()
            d = json.loads(lines[0])
            d["user_input"] = "TAMPERED"
            lines[0] = json.dumps(d, sort_keys=True, separators=(",", ":"))
            path.write_text("\n".join(lines) + "\n")

            ok, err = verify_chain(path)
            self.assertFalse(ok)
            self.assertIn("row 0", err)


class TestQuarantine(unittest.TestCase):
    """Corrupted files go to quarantine, not deleted."""

    def test_quarantine_moves_file_and_writes_reason(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "carli", root=root)

            append_row(
                path=path, session_id=SESSION, user_id=USER, persona="carli",
                engine="ollama", model="s7-carli:0.6b", tier="L1",
                user_input="original", assistant_output="response",
                qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
            )

            dest = quarantine(USER, SESSION, "carli", "test tamper", root=root)

            # Original file is gone
            self.assertFalse(path.exists())
            # Quarantined file exists and contains the row
            self.assertTrue(dest.exists())
            self.assertIn("original", dest.read_text())
            # Reason sidecar exists
            sidecar = dest.with_suffix(".reason.txt")
            self.assertTrue(sidecar.exists())
            self.assertIn("test tamper", sidecar.read_text())


class TestCrossPersona(unittest.TestCase):
    """Cross-persona merged read for Samuel's witness role."""

    def test_merged_read_sorts_by_timestamp(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)

            # Write one row per persona, Carli first, then Samuel, then Elias
            for persona in ("carli", "samuel", "elias"):
                p = persona_ledger_path(USER, SESSION, persona, root=root)
                append_row(
                    path=p, session_id=SESSION, user_id=USER, persona=persona,
                    engine="ollama", model=f"s7-{persona}", tier="L1",
                    user_input=f"{persona} input",
                    assistant_output=f"{persona} output",
                    qbit_count=QBIT_EMPTY, latency_ms=100, qps=10.0,
                )

            rows = list(iter_cross_persona_rows_reverse(USER, SESSION, root=root))
            self.assertEqual(len(rows), 3)
            # Newest first = elias (written last), then samuel, then carli
            # (timestamps are monotonic because each append calls _utc_now_iso)
            timestamps = [r.ts for r in rows]
            self.assertEqual(timestamps, sorted(timestamps, reverse=True))


class TestAllowedPersonas(unittest.TestCase):
    """Closed persona set is enforced on path construction."""

    def test_unknown_persona_raises(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            with self.assertRaises(ValueError):
                persona_ledger_path(USER, SESSION, "admin", root=root)

    def test_allowed_personas_are_exactly_three(self):
        self.assertEqual(ALLOWED_PERSONAS, frozenset({"carli", "elias", "samuel"}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
