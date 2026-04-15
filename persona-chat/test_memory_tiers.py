#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# Unit tests for persona-chat/memory_tiers.py
#
# Covers:
#   - L1 budget (333 QBITs) returns only drawers fitting under budget
#   - L2 budget (777 QBITs) returns more drawers than L1
#   - ForToken 3x multiplier returns more drawers than base
#   - Cross-persona merge pulls from all three persona rooms
#   - Solo-persona mode stays within one persona's room
#   - L3 returns empty lists (stub — semantic search deferred)
#   - assemble_prompt format has system + prior + new input in order
#   - fits_in_budget (from qbit_count) handles edge cases
#
# Run: python3 -m unittest test_memory_tiers -v
# ═══════════════════════════════════════════════════════════════════

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ledger import (
    append_row,
    ensure_session_dirs,
    persona_ledger_path,
)
from memory_tiers import (
    DEFAULT_TIER,
    FORTOKEN_MULTIPLIER,
    TIER_BUDGETS,
    TierWalk,
    assemble_prompt,
    walk_tier,
)
from qbit_count import count_qbits, fits_in_budget, ollama_tokens_to_qbits, qps_from_ollama


USER = "jamie-test"
SESSION = "00000000-0000-0000-0000-000000000002"


def _append_fixed_size_rows(path, session, user, persona, n, qbits_each):
    """Write n rows where each row has qbits_each QBITs total. Helper for
    budget tests."""
    for i in range(n):
        append_row(
            path=path, session_id=session, user_id=user, persona=persona,
            engine="ollama", model=f"s7-{persona}", tier="L1",
            user_input=f"q{i}",
            assistant_output=f"a{i}",
            qbit_count={"in": 0, "out": 0, "total": qbits_each},
            latency_ms=100, qps=10.0,
        )


class TestQbitCount(unittest.TestCase):
    def test_empty_string_is_zero(self):
        self.assertEqual(count_qbits(""), 0)

    def test_short_string_rounds_up(self):
        # "hi" is 2 chars → 2/4 = 0 but rounded up → 1 QBIT
        self.assertEqual(count_qbits("hi"), 1)
        # "abcd" is 4 chars → exactly 1 QBIT
        self.assertEqual(count_qbits("abcd"), 1)
        # "abcde" is 5 chars → ceil(5/4) = 2 QBIT
        self.assertEqual(count_qbits("abcde"), 2)

    def test_fits_in_budget_edge_cases(self):
        # Budget 0 → 0 fit
        self.assertEqual(fits_in_budget([10], 0), 0)
        # Empty list → 0 fit
        self.assertEqual(fits_in_budget([], 100), 0)
        # All fit
        self.assertEqual(fits_in_budget([10, 10, 10], 100), 3)
        # Exact fit
        self.assertEqual(fits_in_budget([100, 100, 100], 300), 3)
        # First row exceeds budget
        self.assertEqual(fits_in_budget([500], 333), 0)
        # Partial fit
        self.assertEqual(fits_in_budget([100, 100, 100, 100], 333), 3)

    def test_ollama_conversion_is_passthrough(self):
        self.assertEqual(ollama_tokens_to_qbits(42), 42)
        self.assertEqual(ollama_tokens_to_qbits(0), 0)
        self.assertEqual(ollama_tokens_to_qbits(-5), 0)  # clamp to 0

    def test_qps_from_ollama(self):
        # 100 tokens in 1 second = 100 QBIT/s
        self.assertAlmostEqual(qps_from_ollama(100, 1_000_000_000), 100.0)
        # 50 tokens in 500ms = 100 QBIT/s
        self.assertAlmostEqual(qps_from_ollama(50, 500_000_000), 100.0)
        # zero duration handled
        self.assertEqual(qps_from_ollama(100, 0), 0.0)


class TestL1Budget(unittest.TestCase):
    def test_l1_budget_is_333(self):
        self.assertEqual(TIER_BUDGETS["L1"], 333)

    def test_l1_returns_drawers_under_333_qbits(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            # Write 5 rows, 100 QBITs each → 500 total, but budget is 333
            _append_fixed_size_rows(path, SESSION, USER, "samuel", 5, qbits_each=100)

            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="samuel",
                tier="L1", cross_persona=False, root=root,
            )
            # 3 rows × 100 = 300 QBITs fit; 4 rows × 100 = 400 > 333
            self.assertEqual(len(walk.base_drawers), 3)
            self.assertEqual(walk.used_qbits, 300)
            self.assertEqual(walk.tier, "L1")

    def test_l1_empty_session_returns_empty(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="carli",
                tier="L1", cross_persona=False, root=root,
            )
            self.assertEqual(walk.base_drawers, [])
            self.assertEqual(walk.used_qbits, 0)


class TestL2Budget(unittest.TestCase):
    def test_l2_returns_more_than_l1(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "elias", root=root)
            _append_fixed_size_rows(path, SESSION, USER, "elias", 10, qbits_each=100)

            l1_walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="elias",
                tier="L1", cross_persona=False, root=root,
            )
            l2_walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="elias",
                tier="L2", cross_persona=False, root=root,
            )
            # L1 333 → 3 rows; L2 777 → 7 rows
            self.assertEqual(len(l1_walk.base_drawers), 3)
            self.assertEqual(len(l2_walk.base_drawers), 7)


class TestForToken(unittest.TestCase):
    def test_fortoken_multiplier_is_three(self):
        self.assertEqual(FORTOKEN_MULTIPLIER, 3)

    def test_fortoken_returns_superset(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "carli", root=root)
            # 15 rows × 100 QBITs = 1500 total
            _append_fixed_size_rows(path, SESSION, USER, "carli", 15, qbits_each=100)

            no_ft = walk_tier(
                user_id=USER, session_id=SESSION, persona="carli",
                tier="L1", fortoken=False, cross_persona=False, root=root,
            )
            with_ft = walk_tier(
                user_id=USER, session_id=SESSION, persona="carli",
                tier="L1", fortoken=True, cross_persona=False, root=root,
            )
            # L1 base: 333/100 = 3 rows
            # L1 fortoken: 999/100 = 9 rows
            self.assertEqual(len(no_ft.base_drawers), 3)
            self.assertEqual(len(with_ft.base_drawers), 3)
            self.assertEqual(len(with_ft.fortoken_drawers), 9)
            # fortoken_drawers is a superset prefix of base_drawers
            self.assertEqual(
                with_ft.fortoken_drawers[: len(with_ft.base_drawers)],
                with_ft.base_drawers,
            )


class TestCrossPersona(unittest.TestCase):
    def test_cross_persona_pulls_from_all_three(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)

            # 2 rows per persona × 50 QBITs each = 300 total, fits in L1 333
            for persona in ("carli", "elias", "samuel"):
                p = persona_ledger_path(USER, SESSION, persona, root=root)
                _append_fixed_size_rows(p, SESSION, USER, persona, 2, qbits_each=50)

            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="samuel",
                tier="L1", cross_persona=True, root=root,
            )
            # 6 rows × 50 = 300 QBITs, fits in 333
            self.assertEqual(len(walk.base_drawers), 6)
            # Should see all three personas represented
            personas_seen = {r.persona for r in walk.base_drawers}
            self.assertEqual(personas_seen, {"carli", "elias", "samuel"})

    def test_solo_persona_stays_within_one_room(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)

            for persona in ("carli", "elias", "samuel"):
                p = persona_ledger_path(USER, SESSION, persona, root=root)
                _append_fixed_size_rows(p, SESSION, USER, persona, 2, qbits_each=50)

            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="samuel",
                tier="L1", cross_persona=False, root=root,
            )
            # Only samuel's 2 rows = 100 QBITs
            self.assertEqual(len(walk.base_drawers), 2)
            personas_seen = {r.persona for r in walk.base_drawers}
            self.assertEqual(personas_seen, {"samuel"})


class TestL3Stub(unittest.TestCase):
    def test_l3_returns_empty_walk(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            _append_fixed_size_rows(path, SESSION, USER, "samuel", 10, qbits_each=100)

            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="samuel",
                tier="L3", cross_persona=False, root=root,
            )
            # L3 is stubbed — semantic search deferred to post-pod
            self.assertEqual(walk.base_drawers, [])
            self.assertEqual(walk.used_qbits, 0)
            self.assertIsNone(walk.revtoken_hint)


class TestAssemble(unittest.TestCase):
    def test_assemble_prompt_contains_system_prior_input(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            path = persona_ledger_path(USER, SESSION, "samuel", root=root)
            append_row(
                path=path, session_id=SESSION, user_id=USER, persona="samuel",
                engine="ollama", model="s7-samuel:v1", tier="L1",
                user_input="what is the firewall status",
                assistant_output="firewall is up on ports 22 and 57080",
                qbit_count={"in": 0, "out": 0, "total": 20},
                latency_ms=100, qps=10.0,
            )

            walk = walk_tier(
                user_id=USER, session_id=SESSION, persona="samuel",
                tier="L1", cross_persona=False, root=root,
            )

            prompt = assemble_prompt(
                system_prompt="You are Samuel.",
                walk=walk,
                new_user_input="and what about port 57081",
            )

            # System prompt comes first
            self.assertTrue(prompt.startswith("You are Samuel."))
            # Prior drawer is included (contains the user_input text)
            self.assertIn("what is the firewall status", prompt)
            # Prior drawer's assistant output is included
            self.assertIn("firewall is up on ports", prompt)
            # New input is at the end
            self.assertTrue(prompt.rstrip().endswith("and what about port 57081"))
            # The "user:" label appears for the new input
            self.assertIn("user: and what about port 57081", prompt)

    def test_assemble_empty_walk_still_works(self):
        walk = TierWalk(
            tier="L1", base_drawers=[], fortoken_drawers=[],
            used_qbits=0, fortoken_used_qbits=0, cross_persona=False,
        )
        prompt = assemble_prompt(
            system_prompt="You are Carli.",
            walk=walk,
            new_user_input="hi",
        )
        # No prior-turns block when walk is empty
        self.assertNotIn("--- prior turns ---", prompt)
        self.assertIn("user: hi", prompt)
        self.assertTrue(prompt.startswith("You are Carli."))


class TestDefaultTier(unittest.TestCase):
    def test_default_tier_is_l1(self):
        self.assertEqual(DEFAULT_TIER, "L1")


class TestInvalidInputs(unittest.TestCase):
    def test_unknown_tier_raises(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ensure_session_dirs(USER, SESSION, root=root)
            with self.assertRaises(ValueError):
                walk_tier(
                    user_id=USER, session_id=SESSION, persona="samuel",
                    tier="L99", cross_persona=False, root=root,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
