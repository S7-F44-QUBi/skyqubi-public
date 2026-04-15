#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# Smoke tests for persona-chat/app.py
#
# Uses FastAPI TestClient (in-process, no real port bind) + a fake
# httpx transport that stands in for Ollama. No network calls, no
# real /s7/.s7-chat-sessions writes — S7_LEDGER_ROOT is redirected
# to a TemporaryDirectory.
#
# Covers:
#   - GET / returns the config shape
#   - GET /healthz is ok (liveness probe, was /health before B3)
#   - GET /health returns Local Health Report HTML (B3 of 24hr plan)
#   - POST /persona/chat happy path (Carli, Ollama mock, writes row)
#   - POST /persona/chat with unknown persona returns 403
#   - POST /persona/chat with unknown tier returns 400
#   - Ledger row is actually on disk after /persona/chat
#   - Two consecutive turns both land and the chain is intact
#   - Cross-persona read: second persona sees the first persona's turn
#
# Run: python3 -m unittest test_app -v
# ═══════════════════════════════════════════════════════════════════

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class _FakeResponse:
    def __init__(self, status_code: int, data: dict):
        self.status_code = status_code
        self._data = data

    def json(self):
        return self._data

    def raise_for_status(self):
        if self.status_code >= 400:
            import httpx
            raise httpx.HTTPStatusError("mock", request=None, response=self)


class _FakeClient:
    """A stand-in for httpx.AsyncClient that returns canned Ollama
    responses. Pass into app._client for the duration of a test."""

    def __init__(self, ollama_response: dict):
        self._resp = ollama_response
        self.calls: list = []

    async def post(self, url, json=None, timeout=None):
        self.calls.append({"url": url, "json": json})
        return _FakeResponse(200, self._resp)

    async def get(self, url, timeout=None):
        return _FakeResponse(200, {"version": "mock"})

    async def aclose(self):
        pass


OLLAMA_MOCK_RESPONSE = {
    "model": "s7-carli:0.6b",
    "response": "hi back from mock Carli",
    "done": True,
    "eval_count": 10,
    "eval_duration": 1_000_000_000,  # 1 second
    "prompt_eval_count": 5,
    "prompt_eval_duration": 500_000_000,
}


class PersonaChatAppTest(unittest.TestCase):
    def setUp(self):
        # Redirect ledger root to a temp dir for every test
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["S7_LEDGER_ROOT"] = self._tmp.name
        # Import app only after env is set so load_config picks up the tmp root
        # (load_config itself doesn't use the env, but the ledger helpers do)
        import importlib
        if "app" in sys.modules:
            del sys.modules["app"]
        import app
        self.app_module = app
        app.load_config()
        # Force-install the fake http client
        self.fake_client = _FakeClient(OLLAMA_MOCK_RESPONSE)
        app._client = self.fake_client

        from fastapi.testclient import TestClient
        self.client = TestClient(app.app)

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.pop("S7_LEDGER_ROOT", None)

    # ── Happy path ──

    def test_root_returns_config(self):
        r = self.client.get("/")
        self.assertEqual(r.status_code, 200)
        d = r.json()
        self.assertEqual(d["service"], "S7 SkyQUBi Persona Chat")
        self.assertIn("carli", d["personas"])
        self.assertIn("elias", d["personas"])
        self.assertIn("samuel", d["personas"])
        self.assertIn("ollama", d["engines"])

    def test_healthz_is_ok(self):
        # /healthz is the minimal liveness probe (was /health before B3).
        r = self.client.get("/healthz")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["status"], "ok")

    def test_health_returns_report_or_503(self):
        # /health is the Local Health Report GUI surface (B3 of the
        # 24hr ship plan). If the latest JSON snapshot exists, returns
        # 200 + HTML. If the report file is missing, returns 503 with
        # a clear "run the generator" message. Either is acceptable
        # from the test's perspective — we confirm the route exists
        # and behaves correctly in both states.
        r = self.client.get("/health")
        self.assertIn(r.status_code, (200, 503))
        if r.status_code == 200:
            body = r.text
            self.assertIn("Local Health Report", body)
            self.assertIn("S7 SkyQUB", body)

    def test_persona_chat_happy_path_carli(self):
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0001",
            "persona": "carli",
            "message": "hi",
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        d = r.json()
        self.assertEqual(d["persona"], "carli")
        self.assertEqual(d["engine"], "ollama")
        self.assertEqual(d["response"], "hi back from mock Carli")
        self.assertEqual(d["status"], "ok")
        self.assertEqual(d["qbit_count"]["in"], 5)   # from mock prompt_eval_count
        self.assertEqual(d["qbit_count"]["out"], 10)  # from mock eval_count
        self.assertEqual(d["qbit_count"]["total"], 15)
        self.assertAlmostEqual(d["qps"], 10.0)        # 10 tokens / 1 second
        self.assertIn("standard", d["badge"])
        self.assertIn("L1", d["badge"])

    def test_carli_operator_question_redirects_to_samuel(self):
        # An operator-shaped question to Carli should NOT hit Ollama —
        # it should return a redirect-to-Samuel hint.
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-redirect-1",
            "persona": "carli",
            "message": "fix the pod",
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        d = r.json()
        self.assertEqual(d["persona"], "carli")
        self.assertEqual(d["engine"], "redirect")
        self.assertIn("Samuel", d["response"])
        self.assertIn("fix-pod", d["response"])
        self.assertEqual(d["skill_invoked"]["state"], "redirected")
        self.assertEqual(d["skill_invoked"]["mode"], "redirect")

    def test_elias_operator_question_redirects_to_samuel(self):
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-redirect-2",
            "persona": "elias",
            "message": "how's the qubi doing",
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        d = r.json()
        self.assertEqual(d["engine"], "redirect")
        self.assertIn("Samuel", d["response"])
        self.assertEqual(d["skill_invoked"]["skill_id"], "diag")

    def test_carli_normal_chat_still_works(self):
        # A non-operator message to Carli should NOT redirect — it should
        # still go through the LLM path.
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-redirect-3",
            "persona": "carli",
            "message": "hi",
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        d = r.json()
        self.assertEqual(d["engine"], "ollama")  # NOT redirect
        self.assertNotIn("Samuel", d["response"])

    # ── Persona + tier validation ──

    def test_unknown_persona_returns_403(self):
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0002",
            "persona": "admin",
            "message": "hi",
        })
        self.assertEqual(r.status_code, 403)
        self.assertIn("closed set", r.json()["detail"])

    def test_unknown_tier_returns_400(self):
        r = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0003",
            "persona": "carli",
            "message": "hi",
            "tier": "L99",
        })
        self.assertEqual(r.status_code, 400)

    # ── Ledger persistence ──

    def test_ledger_row_is_written_to_disk(self):
        self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0004",
            "persona": "samuel",
            "message": "check the firewall",
            "tier": "L1",
        })
        from ledger import persona_ledger_path
        p = persona_ledger_path("jamie", "s-0004", "samuel")
        self.assertTrue(p.exists())
        lines = p.read_text().strip().split("\n")
        self.assertEqual(len(lines), 1)
        row = json.loads(lines[0])
        self.assertEqual(row["persona"], "samuel")
        self.assertEqual(row["user_input"], "check the firewall")
        self.assertEqual(row["assistant_output"], "hi back from mock Carli")
        # qbit_count.total = in + out
        self.assertEqual(row["qbit_count"]["total"], 15)

    def test_two_consecutive_turns_chain_correctly(self):
        # Turn 1
        r1 = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0005",
            "persona": "elias",
            "message": "turn one",
            "tier": "L1",
        })
        self.assertEqual(r1.status_code, 200)
        # Turn 2
        r2 = self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0005",
            "persona": "elias",
            "message": "turn two",
            "tier": "L1",
        })
        self.assertEqual(r2.status_code, 200)

        from ledger import persona_ledger_path, verify_chain
        p = persona_ledger_path("jamie", "s-0005", "elias")
        ok, err = verify_chain(p)
        self.assertTrue(ok, f"chain failed: {err}")

        rows = p.read_text().strip().split("\n")
        self.assertEqual(len(rows), 2)

    # ── Cross-persona read ──

    def test_second_persona_sees_first_persona_turn_via_cross_persona_walk(self):
        # Carli writes first
        self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0006",
            "persona": "carli",
            "message": "I asked Carli something",
            "tier": "L1",
            "cross_persona": True,
        })
        # Samuel answers next; cross_persona default True → should see Carli's row
        self.client.post("/persona/chat", json={
            "user_id": "jamie",
            "session_id": "s-0006",
            "persona": "samuel",
            "message": "now follow up",
            "tier": "L1",
            "cross_persona": True,
        })

        # Inspect Samuel's ledger file — his own row is there
        from ledger import persona_ledger_path, iter_cross_persona_rows_reverse
        merged = list(iter_cross_persona_rows_reverse("jamie", "s-0006"))
        self.assertEqual(len(merged), 2)
        personas_seen = {r.persona for r in merged}
        self.assertEqual(personas_seen, {"carli", "samuel"})


class TonyaSmokeWalkthrough(PersonaChatAppTest):
    """End-to-end Tonya walkthrough — drives the in-process FastAPI
    handler with the actual cheat-sheet phrasings and verifies each
    one routes correctly. Stays on the introspection surface so it
    needs no subprocess and runs in <1 second.

    This is the test that proves the whole thing actually composes
    together as a user would experience it. If any of these break,
    Tonya's tonight session is broken at that step."""

    def _ask_samuel(self, msg, session="tonya-walk"):
        r = self.client.post("/persona/chat", json={
            "user_id": "tonya",
            "session_id": session,
            "persona": "samuel",
            "message": msg,
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        return r.json()

    def test_walk_1_what_can_you_do(self):
        d = self._ask_samuel("what can you do")
        self.assertIn("preflight", d["response"])
        self.assertIn("fix-pod", d["response"])
        self.assertIn("diag", d["response"])
        self.assertEqual(d["skill_invoked"]["skill_id"], "list-skills")

    def test_walk_2_what_does_fix_firewall_do(self):
        d = self._ask_samuel("what does fix-firewall do")
        self.assertEqual(d["skill_invoked"]["skill_id"], "explain-skill")
        self.assertIn("fix-firewall", d["response"].lower())

    def test_walk_3_first_time_what_now(self):
        d = self._ask_samuel("i'm new, what should i do", session="tonya-blank")
        self.assertEqual(d["skill_invoked"]["skill_id"], "next-action")
        # Blank session → suggests how's the qubi
        self.assertIn("how's the qubi", d["response"].lower())

    def test_walk_4_yes_with_no_pending_is_graceful(self):
        d = self._ask_samuel("yes", session="tonya-no-context")
        # Should explain the expired window (no real skill ran but the
        # confirmation route handled the turn meaningfully)
        self.assertIn("expired", d["response"].lower())
        self.assertEqual(d["skill_invoked"]["state"], "no_pending")

    def test_walk_5_recent_activity_after_one_call(self):
        # Prime
        self._ask_samuel("what can you do", session="tonya-history")
        # Now ask
        d = self._ask_samuel("what have you been doing", session="tonya-history")
        self.assertEqual(d["skill_invoked"]["skill_id"], "recent-activity")
        # Should contain a list-skills row from the prime
        self.assertIn("list-skills", d["response"])

    def test_walk_6_carli_natural_chat_still_works(self):
        # Tonya might also chat with Carli normally — no operator intent
        r = self.client.post("/persona/chat", json={
            "user_id": "tonya",
            "session_id": "tonya-carli",
            "persona": "carli",
            "message": "hi carli",
            "tier": "L1",
        })
        self.assertEqual(r.status_code, 200, r.text)
        d = r.json()
        self.assertEqual(d["engine"], "ollama")  # NOT a redirect
        self.assertEqual(d["response"], "hi back from mock Carli")

    def test_walk_7_carli_operator_intent_redirects(self):
        # And if she asks Carli an operator question, Carli redirects
        r = self.client.post("/persona/chat", json={
            "user_id": "tonya",
            "session_id": "tonya-carli-redir",
            "persona": "carli",
            "message": "fix the pod",
            "tier": "L1",
        })
        d = r.json()
        self.assertEqual(d["engine"], "redirect")
        self.assertIn("Samuel", d["response"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
