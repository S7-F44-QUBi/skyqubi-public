#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# Unit tests for persona-chat/skill_runner.py
#
# No real subprocess runs — the tests inject a fake subprocess_runner
# that returns canned (exit_code, stdout, stderr) so the tests are
# hermetic, fast, and deterministic.
#
# Also uses a TemporaryDirectory for OPS_LEDGER_DIR so test runs
# don't pollute /s7/.s7-ops-ledger/.
#
# Run: python3 -m unittest test_skill_runner -v
# ═══════════════════════════════════════════════════════════════════

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import skill_runner
from skill_runner import (
    SkillResult,
    match_intent,
    build_summary,
    run_skill,
    normalize_confirmation,
    normalize_negative_confirmation,
    find_pending_suggestion,
)


# Canned scripts catalog for the tests — matches the real schema but
# in a tempfile so tests don't depend on /s7 state.
FAKE_CATALOG_YAML = """
version: 1
updated: "2026-04-13"
scripts:
  - id: preflight
    display_name: Preflight
    path: install/preflight.sh
    invocation:
      diagnose: bash install/preflight.sh --json
      apply: null
    dry_run_first: false
    requires_approval: false
    max_runs_per_hour: 60
    max_runs_per_day: unlimited
  - id: fix-pod
    display_name: Pod Fix
    path: install/fix-pod.sh
    invocation:
      diagnose: sudo bash install/fix-pod.sh --dry-run --samuel
      apply: sudo bash install/fix-pod.sh --samuel
    dry_run_first: true
    requires_approval: false
    max_runs_per_hour: 3
    max_runs_per_day: 10
  - id: lifecycle-test
    display_name: Lifecycle
    path: s7-lifecycle-test.sh
    invocation:
      diagnose: bash s7-lifecycle-test.sh --json
      apply: null
    dry_run_first: false
    requires_approval: false
    max_runs_per_hour: 12
    max_runs_per_day: 48
  - id: fix-firewall
    display_name: Firewall Fix
    path: install/fix-firewall.sh
    invocation:
      diagnose: bash install/fix-firewall.sh --dry-run --samuel
      apply: sudo bash install/fix-firewall.sh --samuel
    dry_run_first: true
    requires_approval: false
    max_runs_per_hour: 3
    max_runs_per_day: 10
  - id: test-personas
    display_name: Test Personas
    path: install/test-personas.sh
    invocation:
      diagnose: bash install/test-personas.sh --samuel
      apply: null
    dry_run_first: false
    requires_approval: false
    max_runs_per_hour: 12
    max_runs_per_day: 48
  - id: pod-stats
    display_name: Pod Stats
    path: install/pod-stats.sh
    invocation:
      diagnose: bash install/pod-stats.sh --json
      apply: null
    dry_run_first: false
    requires_approval: false
    max_runs_per_hour: 30
    max_runs_per_day: unlimited
  - id: diag
    display_name: Composite Diagnostic
    path: install/diag.sh
    invocation:
      diagnose: bash install/diag.sh --samuel
      apply: null
    dry_run_first: false
    requires_approval: false
    max_runs_per_hour: 6
    max_runs_per_day: 24
denylist: []
emergency_stop_file: /s7/.s7-samuel-emergency-stop
audit_trail_dir: /s7/.s7-ops-ledger
"""


class TestIntentMatch(unittest.TestCase):
    """match_intent() should map user messages to skill_id + mode."""

    def test_empty_message(self):
        self.assertEqual(match_intent(""), (None, "none"))
        self.assertEqual(match_intent(None), (None, "none"))

    def test_unrelated_message(self):
        self.assertEqual(match_intent("what is 2+2"), (None, "none"))
        self.assertEqual(match_intent("tell me a joke"), (None, "none"))

    def test_preflight_diagnose(self):
        skill, mode = match_intent("can i install")
        self.assertEqual(skill, "preflight")
        self.assertEqual(mode, "diagnose")

    def test_preflight_is_always_diagnose_even_with_apply_hint(self):
        # Preflight has no apply mode, so even 'fix the environment' should
        # map to diagnose (if it matches preflight at all).
        skill, mode = match_intent("is the system ready")
        self.assertEqual(skill, "preflight")
        self.assertEqual(mode, "diagnose")

    def test_fix_pod_diagnose(self):
        # "check the pod health" should diagnose, not apply
        skill, mode = match_intent("check the pod health")
        self.assertEqual(skill, "fix-pod")
        self.assertEqual(mode, "diagnose")

    def test_fix_pod_apply(self):
        # "fix the pod" has an apply hint ("fix")
        skill, mode = match_intent("fix the pod")
        self.assertEqual(skill, "fix-pod")
        self.assertEqual(mode, "apply")

    def test_fix_pod_heal_is_apply(self):
        skill, mode = match_intent("heal the pod please")
        self.assertEqual(skill, "fix-pod")
        self.assertEqual(mode, "apply")

    def test_lifecycle_diagnose(self):
        skill, mode = match_intent("run the lifecycle tests")
        self.assertEqual(skill, "lifecycle-test")
        self.assertEqual(mode, "diagnose")

    def test_lifecycle_is_always_diagnose(self):
        # Even with apply hints, lifecycle tests are assertions
        skill, mode = match_intent("fix the lifecycle tests")
        self.assertEqual(skill, "lifecycle-test")
        self.assertEqual(mode, "diagnose")

    def test_case_insensitive(self):
        skill, mode = match_intent("FIX THE POD")
        self.assertEqual(skill, "fix-pod")
        self.assertEqual(mode, "apply")

    def test_explain_skill_what_does_fix_pod_do(self):
        skill, mode = match_intent("what does fix-pod do")
        self.assertEqual(skill, "explain-skill")
        self.assertEqual(mode, "introspect")

    def test_explain_skill_tell_me_about_diag(self):
        skill, mode = match_intent("tell me about diag")
        self.assertEqual(skill, "explain-skill")

    def test_explain_skill_no_target_does_not_match(self):
        # 'tell me about' alone with no skill name should NOT match
        skill, mode = match_intent("tell me about the weather")
        self.assertIsNone(skill)

    def test_explain_skill_does_not_steal_real_skill_match(self):
        # 'fix the pod' should still route to fix-pod apply, not explain
        skill, mode = match_intent("fix the pod")
        self.assertEqual(skill, "fix-pod")
        self.assertEqual(mode, "apply")

    def test_next_action_what_should_i_do(self):
        skill, mode = match_intent("what should i do")
        self.assertEqual(skill, "next-action")
        self.assertEqual(mode, "introspect")

    def test_next_action_first_time(self):
        skill, mode = match_intent("i'm new here")
        self.assertEqual(skill, "next-action")

    def test_next_action_help_me_out(self):
        skill, mode = match_intent("help me out")
        self.assertEqual(skill, "next-action")

    def test_recent_activity_what_have_you_done(self):
        skill, mode = match_intent("what have you been doing")
        self.assertEqual(skill, "recent-activity")
        self.assertEqual(mode, "introspect")

    def test_recent_activity_show_history(self):
        skill, mode = match_intent("show me your activity")
        self.assertEqual(skill, "recent-activity")

    def test_list_skills_what_can_you_do(self):
        skill, mode = match_intent("what can you do")
        self.assertEqual(skill, "list-skills")
        self.assertEqual(mode, "introspect")

    def test_list_skills_show_skills(self):
        skill, mode = match_intent("show me your skills")
        self.assertEqual(skill, "list-skills")

    def test_fix_firewall_diagnose(self):
        skill, mode = match_intent("the firewall is broken")
        self.assertEqual(skill, "fix-firewall")
        self.assertEqual(mode, "diagnose")

    def test_fix_firewall_apply(self):
        skill, mode = match_intent("fix the firewall")
        self.assertEqual(skill, "fix-firewall")
        self.assertEqual(mode, "apply")

    def test_fix_firewall_169_phrase(self):
        skill, mode = match_intent("looks like a 169.254 issue")
        self.assertEqual(skill, "fix-firewall")

    def test_fix_firewall_pod_cant_reach(self):
        skill, mode = match_intent("the pod can't reach host")
        self.assertEqual(skill, "fix-firewall")

    def test_test_personas_intent(self):
        skill, mode = match_intent("is carli alive")
        self.assertEqual(skill, "test-personas")
        self.assertEqual(mode, "diagnose")

    def test_test_personas_persona_health(self):
        skill, mode = match_intent("persona health check")
        self.assertEqual(skill, "test-personas")

    def test_pod_stats_how_busy(self):
        skill, mode = match_intent("how busy is the pod")
        self.assertEqual(skill, "pod-stats")
        self.assertEqual(mode, "diagnose")

    def test_pod_stats_resource_usage(self):
        skill, mode = match_intent("show me resource usage")
        self.assertEqual(skill, "pod-stats")

    def test_pod_stats_is_always_diagnose(self):
        skill, mode = match_intent("fix the pod stats")
        # 'pod stats' phrase wins over 'fix' intent
        self.assertEqual(skill, "pod-stats")
        self.assertEqual(mode, "diagnose")

    def test_diag_check_everything(self):
        skill, mode = match_intent("check everything")
        self.assertEqual(skill, "diag")
        self.assertEqual(mode, "diagnose")

    def test_diag_hows_the_qubi(self):
        skill, mode = match_intent("how's the qubi doing")
        self.assertEqual(skill, "diag")
        self.assertEqual(mode, "diagnose")

    def test_diag_system_health(self):
        skill, mode = match_intent("give me a system health check")
        self.assertEqual(skill, "diag")

    def test_diag_is_always_diagnose(self):
        # Even with apply hints, diag is read-only composite
        skill, mode = match_intent("fix everything and check it all")
        self.assertEqual(skill, "diag")
        self.assertEqual(mode, "diagnose")

    def test_multiple_skills_preflight_wins_if_listed_first(self):
        # "preflight and lifecycle" — preflight is listed first in the
        # matcher, so it wins. This is deterministic.
        skill, mode = match_intent("preflight and lifecycle")
        self.assertEqual(skill, "preflight")


class TestConfirmationNormalize(unittest.TestCase):
    """normalize_confirmation() detects bare confirmations only."""

    def test_yes(self):
        self.assertEqual(normalize_confirmation("yes"), "yes")

    def test_yes_punctuation(self):
        self.assertEqual(normalize_confirmation("yes!"), "yes")
        self.assertEqual(normalize_confirmation("Yes."), "yes")

    def test_yes_with_content_does_not_match(self):
        # 'yes fix the firewall' has skill content — must NOT match
        self.assertIsNone(normalize_confirmation("yes fix the firewall"))

    def test_do_it(self):
        self.assertEqual(normalize_confirmation("do it"), "do it")

    def test_go_ahead(self):
        self.assertEqual(normalize_confirmation("go ahead"), "go ahead")

    def test_random_message(self):
        self.assertIsNone(normalize_confirmation("how is the weather"))

    def test_empty(self):
        self.assertIsNone(normalize_confirmation(""))
        self.assertIsNone(normalize_confirmation(None))

    def test_negative_no(self):
        self.assertEqual(normalize_negative_confirmation("no"), "no")
        self.assertEqual(normalize_negative_confirmation("No."), "no")
        self.assertEqual(normalize_negative_confirmation("nope"), "nope")

    def test_negative_not_now(self):
        self.assertEqual(normalize_negative_confirmation("not now"), "not now")

    def test_negative_with_content_does_not_match(self):
        self.assertIsNone(normalize_negative_confirmation("no but tell me why"))

    def test_negative_random_does_not_match(self):
        self.assertIsNone(normalize_negative_confirmation("how are you"))

    def test_natural_yes_phrasings(self):
        # Variants Tonya is likely to type — must all normalize to confirmation
        for phrase in [
            "alright", "let's go", "let's do it", "sure", "please",
            "go right ahead", "i'm in", "ok", "k", "fine",
        ]:
            self.assertIsNotNone(
                normalize_confirmation(phrase),
                f"expected '{phrase}' to be a confirmation",
            )

    def test_natural_no_phrasings(self):
        for phrase in [
            "not right now", "maybe later", "nevermind", "forget it",
            "pass", "hold up", "another time", "stop it",
        ]:
            self.assertIsNotNone(
                normalize_negative_confirmation(phrase),
                f"expected '{phrase}' to be a negative",
            )


class TestBuildSummary(unittest.TestCase):
    """build_summary() generates the natural-language sentence."""

    def test_preflight_ready(self):
        parsed = {"state": "ready", "errors": 0, "warnings": 0}
        s = build_summary("preflight", "diagnose", parsed, 0)
        self.assertIn("ready", s.lower())
        self.assertIn("zero", s.lower())

    def test_preflight_ready_with_warnings(self):
        parsed = {"state": "ready_with_warnings", "errors": 0, "warnings": 3}
        s = build_summary("preflight", "diagnose", parsed, 2)
        self.assertIn("3", s)
        self.assertIn("warning", s.lower())

    def test_fix_firewall_no_action_needed(self):
        parsed = {"state": "no_action_needed"}
        s = build_summary("fix-firewall", "diagnose", parsed, 2)
        self.assertIn("already trusts", s.lower())

    def test_fix_firewall_dry_run(self):
        parsed = {"state": "dry_run_complete"}
        s = build_summary("fix-firewall", "diagnose", parsed, 1)
        self.assertIn("169.254", s)
        self.assertIn("can fix it", s.lower())

    def test_fix_firewall_applied(self):
        parsed = {"state": "pod_can_reach_host"}
        s = build_summary("fix-firewall", "apply", parsed, 0)
        self.assertIn("in place", s.lower())

    def test_fix_firewall_must_run_as_root_includes_command(self):
        parsed = {"state": "must_run_as_root"}
        s = build_summary("fix-firewall", "apply", parsed, 4)
        # Must include the exact command for copy-paste — direct
        # script path so the NOPASSWD sudoers drop-in matches
        self.assertIn("sudo ", s)
        self.assertIn("/s7/skyqubi-private/install/fix-firewall.sh", s)
        self.assertNotIn("sudo bash", s)  # must NOT use the bash form
        self.assertIn("ask me again", s.lower())

    def test_fix_pod_already_running(self):
        parsed = {"state": "pod_already_running"}
        s = build_summary("fix-pod", "diagnose", parsed, 0)
        self.assertIn("already running", s.lower())

    def test_fix_pod_healthy(self):
        parsed = {"state": "pod_healthy"}
        s = build_summary("fix-pod", "apply", parsed, 0)
        self.assertIn("healthy", s.lower())

    def test_fix_pod_no_avc(self):
        parsed = {"state": "no_avc_denials"}
        s = build_summary("fix-pod", "diagnose", parsed, 2)
        self.assertIn("SELinux isn't", s)

    def test_lifecycle_verified(self):
        parsed = {"state": "verified", "pass": 53, "total": 53}
        s = build_summary("lifecycle-test", "diagnose", parsed, 0)
        self.assertIn("53", s)
        self.assertIn("green", s.lower())

    def test_lifecycle_failed(self):
        parsed = {"state": "failed", "pass": 50, "fail": 3, "total": 53}
        s = build_summary("lifecycle-test", "diagnose", parsed, 1)
        self.assertIn("3", s)
        self.assertIn("failed", s.lower())

    def test_test_personas_all_responding(self):
        parsed = {
            "state": "all_responding",
            "carli": {"state": "ok", "latency_ms": 850},
            "elias": {"state": "ok", "latency_ms": 1200},
        }
        s = build_summary("test-personas", "diagnose", parsed, 0)
        self.assertIn("Both personas responded", s)
        self.assertIn("850", s)
        self.assertIn("1200", s)

    def test_test_personas_service_unreachable(self):
        parsed = {"state": "service_unreachable"}
        s = build_summary("test-personas", "diagnose", parsed, 3)
        self.assertIn("substrate code", s)
        self.assertIn("not yet wired", s)

    def test_pod_stats_ok(self):
        parsed = {
            "state": "ok",
            "containers": 6,
            "running": 6,
            "cpu_total_pct": 1.3,
            "mem_total_mib": 281.3,
            "top": {"name": "s7-skyqubi-s7-admin", "mem_mib": 211.8},
        }
        s = build_summary("pod-stats", "diagnose", parsed, 0)
        self.assertIn("6/6", s)
        self.assertIn("1.3%", s)
        self.assertIn("281.3", s)
        self.assertIn("s7-admin", s)

    def test_pod_stats_not_running(self):
        parsed = {"state": "pod_not_running", "containers": 0, "running": 0}
        s = build_summary("pod-stats", "diagnose", parsed, 1)
        self.assertIn("isn't reporting", s)

    def test_diag_healthy(self):
        parsed = {
            "state": "healthy",
            "preflight": {"state": "ready", "errors": 0, "warnings": 0},
            "fixpod": {"state": "pod_already_running", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 0)
        self.assertIn("green", s.lower())
        self.assertIn("53/53", s)

    def test_diag_degraded(self):
        parsed = {
            "state": "degraded",
            "preflight": {"state": "ready_with_warnings", "errors": 0, "warnings": 2},
            "fixpod": {"state": "no_avc_denials", "exit_code": 2},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 1)
        self.assertIn("not perfect", s.lower())
        self.assertIn("no_avc_denials", s)

    def test_diag_degraded_with_actionable_hint(self):
        parsed = {
            "state": "degraded",
            "preflight": {
                "state": "ready_with_warnings",
                "errors": 0,
                "warnings": 2,
                "warned": ["low_ram", "firewall_rootless_trust_missing"],
            },
            "fixpod": {"state": "pod_already_running", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 1)
        self.assertIn("Suggestion", s)
        self.assertIn("firewall", s.lower())

    def test_diag_degraded_with_ollama_hint(self):
        parsed = {
            "state": "degraded",
            "preflight": {
                "state": "ready_with_warnings",
                "errors": 0,
                "warnings": 1,
                "warned": ["ollama_local_unreachable"],
            },
            "fixpod": {"state": "pod_already_running", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 1)
        self.assertIn("ollama", s.lower())
        self.assertIn("systemctl restart", s)

    def test_diag_degraded_no_actionable_hint(self):
        # Only low_ram warning — no actionable fix from Samuel
        parsed = {
            "state": "degraded",
            "preflight": {
                "state": "ready_with_warnings",
                "errors": 0,
                "warnings": 1,
                "warned": ["low_ram"],
            },
            "fixpod": {"state": "pod_already_running", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 1)
        self.assertNotIn("Suggestion", s)

    def test_diag_failed(self):
        parsed = {
            "state": "failed",
            "preflight": {"state": "not_ready", "errors": 3, "warnings": 1},
            "fixpod": {"state": "setsebool_failed", "exit_code": 3},
            "lifecycle": {"state": "failed", "pass": 50, "fail": 3, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 2)
        self.assertIn("hard blocker", s.lower())

    def test_diag_error(self):
        parsed = {
            "state": "error",
            "preflight": {"state": "no_json", "errors": 0, "warnings": 0},
            "fixpod": {"state": "script_missing", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        }
        s = build_summary("diag", "diagnose", parsed, 3)
        self.assertIn("clean read", s.lower())

    def test_parsed_none_with_clean_exit(self):
        s = build_summary("preflight", "diagnose", None, 0)
        self.assertIn("completed cleanly", s)

    def test_parsed_none_with_error_exit(self):
        s = build_summary("preflight", "diagnose", None, 1)
        self.assertIn("exited with code 1", s)


class TestRunSkill(unittest.TestCase):
    """run_skill() end-to-end with a fake subprocess runner."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

        # Write a fake catalog in the temp dir
        self.catalog_path = self.tmp / "catalog.yaml"
        self.catalog_path.write_text(FAKE_CATALOG_YAML)

        # Redirect the ops ledger dir into the temp dir
        self._orig_ops_dir = skill_runner.OPS_LEDGER_DIR
        self._orig_ops_file = skill_runner.OPS_LEDGER_FILE
        self._orig_stop = skill_runner.EMERGENCY_STOP_FILE
        skill_runner.OPS_LEDGER_DIR = self.tmp / "ops-ledger"
        skill_runner.OPS_LEDGER_FILE = skill_runner.OPS_LEDGER_DIR / "skill_runner.ndjson"
        skill_runner.EMERGENCY_STOP_FILE = self.tmp / "emergency_stop"

    def tearDown(self):
        skill_runner.OPS_LEDGER_DIR = self._orig_ops_dir
        skill_runner.OPS_LEDGER_FILE = self._orig_ops_file
        skill_runner.EMERGENCY_STOP_FILE = self._orig_stop
        self._tmp.cleanup()

    # ── Persona gate ──

    def test_carli_cannot_invoke_skills(self):
        result = run_skill(
            user_message="fix the pod",
            persona="carli",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
        )
        self.assertFalse(result.attempted)
        self.assertEqual(result.persona, "carli")
        self.assertIn("Only Samuel", result.summary)
        self.assertIn("not allowed", result.blocked_reason)

    def test_elias_cannot_invoke_skills(self):
        result = run_skill(
            user_message="run preflight",
            persona="elias",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
        )
        self.assertFalse(result.attempted)
        self.assertIn("Elias", result.summary)

    # ── Intent match ──

    def test_samuel_unmatched_intent(self):
        result = run_skill(
            user_message="what is the weather",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
        )
        self.assertFalse(result.matched)
        self.assertFalse(result.attempted)
        self.assertIsNone(result.skill_id)
        self.assertIn("don't have a skill", result.summary)

    # ── Happy path — preflight ready ──

    def test_preflight_happy_path(self):
        fake_output = json.dumps({
            "script": "preflight.sh",
            "state": "ready_with_warnings",
            "exit_code": 2,
            "errors": 0,
            "warnings": 2,
            "failed": [],
            "warned": ["os_not_fedora", "low_ram"],
        })
        def fake_runner(cmd):
            return (2, fake_output, "some stderr\n")

        result = run_skill(
            user_message="can i install",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "preflight")
        self.assertEqual(result.mode, "diagnose")
        self.assertTrue(result.attempted)
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.state, "ready_with_warnings")
        self.assertIsNotNone(result.parsed)
        self.assertEqual(result.parsed["warnings"], 2)
        self.assertIn("ready", result.summary.lower())
        self.assertIn("2 warning", result.summary.lower())

    # ── Happy path — fix-pod apply ──

    def test_fix_pod_apply_happy_path(self):
        fake_output = json.dumps({
            "script": "fix-pod.sh",
            "state": "pod_healthy",
            "exit_code": 0,
            "detail": {"pod": "running", "containers_up": 6},
        })
        def fake_runner(cmd):
            self.assertIn("fix-pod.sh", cmd)
            self.assertIn("--samuel", cmd)
            self.assertNotIn("--dry-run", cmd)  # apply mode, not dry-run
            return (0, fake_output, "")

        result = run_skill(
            user_message="fix the pod please",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.attempted)
        self.assertEqual(result.mode, "apply")
        self.assertEqual(result.state, "pod_healthy")
        self.assertIn("healthy", result.summary.lower())

    # ── Diagnose selection ──

    def test_fix_pod_diagnose_uses_dry_run_command(self):
        fake_output = json.dumps({
            "script": "fix-pod.sh",
            "state": "dry_run_complete",
            "exit_code": 1,
        })
        captured_cmds = []
        def fake_runner(cmd):
            captured_cmds.append(cmd)
            return (1, fake_output, "")

        result = run_skill(
            user_message="check the pod",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertEqual(result.mode, "diagnose")
        self.assertEqual(len(captured_cmds), 1)
        self.assertIn("--dry-run", captured_cmds[0])

    def test_explain_skill_renders_catalog_entry(self):
        def fake_runner(cmd):
            self.fail("explain-skill should not invoke subprocess")
        result = run_skill(
            user_message="what does fix-pod do",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "explain-skill")
        self.assertEqual(result.state, "explained")
        self.assertEqual(result.parsed["target"], "fix-pod")
        self.assertIn("fix-pod", result.summary)
        self.assertIn("apply", result.summary.lower())  # has both modes

    def test_next_action_blank_session(self):
        # No prior activity → suggests "how's the qubi"
        result = run_skill(
            user_message="what should i do",
            persona="samuel",
            user_id="jamie",
            session_id="next-action-blank",
            catalog_path=self.catalog_path,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "next-action")
        self.assertEqual(result.mode, "introspect")
        self.assertIn("how's the qubi", result.summary.lower())

    def test_next_action_with_pending_suggestion(self):
        # Prime: run a fix-pod diagnose that returns dry_run_complete
        diag_output = json.dumps({"state": "dry_run_complete", "exit_code": 1})
        def fake_runner(cmd):
            return (1, diag_output, "")
        run_skill(
            user_message="check the pod",
            persona="samuel", user_id="jamie", session_id="next-action-pending",
            catalog_path=self.catalog_path, subprocess_runner=fake_runner,
        )
        # Now ask for next action — should detect the pending suggestion
        result = run_skill(
            user_message="what should i do",
            persona="samuel", user_id="jamie", session_id="next-action-pending",
            catalog_path=self.catalog_path,
        )
        self.assertEqual(result.skill_id, "next-action")
        self.assertIn("pending", result.summary.lower())
        self.assertIn("yes", result.summary.lower())
        self.assertEqual(result.parsed["pending"], "fix-pod")

    def test_recent_activity_empty_ledger(self):
        # Fresh tmp dir → no ledger file exists
        def fake_runner(cmd):
            self.fail("recent-activity should not invoke subprocess")
        result = run_skill(
            user_message="what have you been doing",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "recent-activity")
        self.assertEqual(result.mode, "introspect")
        # State will be 'listed' because the recent-activity call itself
        # writes a ledger row first, so by the time it reads the file
        # there's at least the genesis row from this very call... actually
        # no, the read happens BEFORE the write. So state is 'empty'.
        self.assertEqual(result.state, "empty")
        self.assertIn("haven't run", result.summary.lower())

    def test_recent_activity_with_history(self):
        # Pre-populate ledger by running a successful preflight first
        fake_output = json.dumps({"script": "preflight.sh", "state": "ready", "exit_code": 0})
        def fake_runner(cmd):
            return (0, fake_output, "")
        run_skill(
            user_message="is the system ready",
            persona="samuel", user_id="jamie", session_id="s1",
            catalog_path=self.catalog_path, subprocess_runner=fake_runner,
        )
        # Now ask for recent activity
        result = run_skill(
            user_message="show me your activity",
            persona="samuel", user_id="jamie", session_id="s1",
            catalog_path=self.catalog_path, subprocess_runner=fake_runner,
        )
        self.assertEqual(result.skill_id, "recent-activity")
        self.assertEqual(result.state, "listed")
        self.assertIn("preflight", result.summary)
        self.assertIn("ready", result.summary)

    def test_list_skills_no_subprocess(self):
        def fake_runner(cmd):
            self.fail("list-skills should not invoke subprocess")
        result = run_skill(
            user_message="what can you do",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "list-skills")
        self.assertEqual(result.mode, "introspect")
        self.assertTrue(result.attempted)
        self.assertEqual(result.state, "listed")
        # Catalog has preflight, fix-pod, lifecycle-test, fix-firewall, test-personas, pod-stats, diag = 7 entries
        self.assertEqual(result.parsed["count"], 7)
        self.assertIn("preflight", result.summary)
        self.assertIn("fix-pod", result.summary)

    def test_diag_happy_path(self):
        fake_output = json.dumps({
            "script": "diag.sh",
            "run_id": "test",
            "state": "healthy",
            "exit_code": 0,
            "preflight": {"state": "ready", "errors": 0, "warnings": 0},
            "fixpod": {"state": "pod_already_running", "exit_code": 0},
            "lifecycle": {"state": "verified", "pass": 53, "fail": 0, "total": 53},
        })
        captured = []
        def fake_runner(cmd):
            captured.append(cmd)
            return (0, fake_output, "")

        result = run_skill(
            user_message="how's the qubi doing",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.skill_id, "diag")
        self.assertEqual(result.mode, "diagnose")
        self.assertTrue(result.attempted)
        self.assertEqual(result.state, "healthy")
        self.assertIn("green", result.summary.lower())
        self.assertEqual(len(captured), 1)
        self.assertIn("diag.sh", captured[0])
        self.assertIn("--samuel", captured[0])

    def test_confirmation_routes_to_pending_apply(self):
        # First turn: a diagnose that returns dry_run_complete (a real
        # suggestion). We use fix-pod since the test catalog has it
        # with both diagnose and apply modes.
        diag_output = json.dumps({
            "script": "fix-pod.sh",
            "state": "dry_run_complete",
            "exit_code": 1,
        })
        captured = []
        def fake_runner(cmd):
            captured.append(cmd)
            # First call (diagnose) returns dry_run_complete
            # Second call (apply, after confirmation) returns pod_healthy
            if "--dry-run" in cmd:
                return (1, diag_output, "")
            return (0, json.dumps({"state": "pod_healthy", "exit_code": 0}), "")

        # Turn 1: ask for a diagnose
        r1 = run_skill(
            user_message="check the pod",
            persona="samuel",
            user_id="jamie",
            session_id="confirm-test-1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertEqual(r1.skill_id, "fix-pod")
        self.assertEqual(r1.mode, "diagnose")
        self.assertEqual(r1.state, "dry_run_complete")

        # Turn 2: bare 'yes' should route to fix-pod apply
        r2 = run_skill(
            user_message="yes",
            persona="samuel",
            user_id="jamie",
            session_id="confirm-test-1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertEqual(r2.skill_id, "fix-pod")
        self.assertEqual(r2.mode, "apply")
        self.assertEqual(r2.state, "pod_healthy")
        # Verify the apply command actually ran (no --dry-run)
        self.assertEqual(len(captured), 2)
        self.assertIn("--dry-run", captured[0])
        self.assertNotIn("--dry-run", captured[1])

    def test_yes_without_pending_suggestion_returns_expired_message(self):
        # No prior diagnose → 'yes' returns the graceful expired
        # message. matched=True because the confirmation route handled
        # the turn (even though no real skill ran).
        result = run_skill(
            user_message="yes",
            persona="samuel",
            user_id="jamie",
            session_id="no-pending",
            catalog_path=self.catalog_path,
        )
        self.assertTrue(result.matched)
        self.assertEqual(result.state, "no_pending")
        self.assertIn("expired", result.summary.lower())

    def test_yes_with_no_pending_returns_graceful_message(self):
        # Used to fall through to 'I don't have a skill' which was
        # confusing. Now it's an explicit 'expired' acknowledgment.
        # matched=True because the confirmation route handled the turn.
        result = run_skill(
            user_message="yes",
            persona="samuel",
            user_id="jamie",
            session_id="graceful-yes",
            catalog_path=self.catalog_path,
        )
        self.assertTrue(result.matched)  # confirmation route handled it
        self.assertEqual(result.state, "no_pending")
        self.assertIn("expired", result.summary.lower())
        self.assertIn("5-minute", result.summary)

    def test_no_with_pending_declines_gracefully(self):
        diag_output = json.dumps({"state": "dry_run_complete", "exit_code": 1})
        ran_apply = []
        def fake_runner(cmd):
            if "--dry-run" not in cmd:
                ran_apply.append(cmd)
            return (1, diag_output, "")

        # First turn: get a pending suggestion
        run_skill(
            user_message="check the pod",
            persona="samuel", user_id="jamie", session_id="decline-test",
            catalog_path=self.catalog_path, subprocess_runner=fake_runner,
        )
        # Second turn: decline
        result = run_skill(
            user_message="no thanks",
            persona="samuel", user_id="jamie", session_id="decline-test",
            catalog_path=self.catalog_path, subprocess_runner=fake_runner,
        )
        self.assertEqual(result.skill_id, "fix-pod")
        self.assertEqual(result.mode, "declined")
        self.assertEqual(result.state, "declined")
        self.assertFalse(result.attempted)
        self.assertIn("holding off", result.summary.lower())
        # Critically: the apply command must NOT have run
        self.assertEqual(len(ran_apply), 0)

    def test_no_without_pending_falls_through(self):
        # 'no' alone without a pending suggestion should NOT match a
        # skill — it should fall through to normal LLM chat
        result = run_skill(
            user_message="no",
            persona="samuel", user_id="jamie", session_id="no-no-pending",
            catalog_path=self.catalog_path,
        )
        self.assertFalse(result.matched)
        self.assertIn("don't have a skill", result.summary)

    def test_yes_in_different_session_does_not_apply(self):
        # A diagnose in session A should NOT trigger apply for 'yes'
        # in session B (session scoping). Session B's 'yes' returns
        # the graceful 'expired/no pending' message — matched=True
        # because the confirmation route handled it, but mode is
        # NOT 'apply' (no skill was actually invoked).
        diag_output = json.dumps({"state": "dry_run_complete", "exit_code": 1})
        def fake_runner(cmd):
            return (1, diag_output, "")
        run_skill(
            user_message="check the pod",
            persona="samuel",
            user_id="jamie",
            session_id="session-a",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        # Now 'yes' from session-b should not pick up session-a's pending
        result = run_skill(
            user_message="yes",
            persona="samuel",
            user_id="jamie",
            session_id="session-b",
            catalog_path=self.catalog_path,
        )
        # Confirmation route handled it, but no apply happened
        self.assertTrue(result.matched)
        self.assertEqual(result.state, "no_pending")
        self.assertFalse(result.attempted)
        self.assertNotEqual(result.mode, "apply")

    # ── Emergency stop ──

    def test_emergency_stop_blocks_execution(self):
        # Create the emergency stop file
        skill_runner.EMERGENCY_STOP_FILE.touch()

        def fake_runner(cmd):
            self.fail("subprocess should not run when emergency stop is active")

        result = run_skill(
            user_message="fix the pod",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(result.matched)
        self.assertFalse(result.attempted)
        self.assertIn("emergency stop", result.blocked_reason)
        self.assertIn("emergency-stop", result.summary)

    # ── Ops ledger ──

    def test_successful_run_writes_ops_ledger_row(self):
        fake_output = json.dumps({"script": "preflight.sh", "state": "ready", "exit_code": 0})
        def fake_runner(cmd):
            return (0, fake_output, "")

        run_skill(
            user_message="is the system ready",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
            subprocess_runner=fake_runner,
        )
        self.assertTrue(skill_runner.OPS_LEDGER_FILE.exists())
        lines = skill_runner.OPS_LEDGER_FILE.read_text().strip().split("\n")
        self.assertEqual(len(lines), 1)
        row = json.loads(lines[0])
        self.assertEqual(row["skill_id"], "preflight")
        self.assertEqual(row["mode"], "diagnose")
        self.assertEqual(row["state"], "ready")
        self.assertEqual(row["exit_code"], 0)
        self.assertEqual(row["user_id"], "jamie")
        self.assertEqual(row["session_id"], "s1")
        self.assertIsNone(row["blocked_reason"])
        # First row's prev_hash is the genesis zero
        self.assertEqual(row["prev_hash"], "0" * 64)

    def test_blocked_run_also_writes_ledger(self):
        skill_runner.EMERGENCY_STOP_FILE.touch()
        run_skill(
            user_message="fix the pod",
            persona="samuel",
            user_id="jamie",
            session_id="s1",
            catalog_path=self.catalog_path,
        )
        self.assertTrue(skill_runner.OPS_LEDGER_FILE.exists())
        row = json.loads(skill_runner.OPS_LEDGER_FILE.read_text().strip())
        self.assertIsNotNone(row["blocked_reason"])
        self.assertIn("emergency stop", row["blocked_reason"])

    # ── SkillResult.as_samuel_reply ──

    def test_as_samuel_reply_unmatched_with_summary(self):
        # When summary is set, it always wins — reflects how all
        # real return paths in run_skill build a meaningful summary.
        result = SkillResult(
            matched=False, skill_id=None, persona="samuel", mode="none",
            attempted=False, exit_code=None, state=None, parsed=None,
            stderr_tail="", summary="some custom message", elapsed_ms=5,
        )
        self.assertEqual(result.as_samuel_reply(), "some custom message")

    def test_as_samuel_reply_unmatched_no_summary(self):
        # Empty summary + matched=False → standard fall-through message
        result = SkillResult(
            matched=False, skill_id=None, persona="samuel", mode="none",
            attempted=False, exit_code=None, state=None, parsed=None,
            stderr_tail="", summary="", elapsed_ms=5,
        )
        self.assertIn("don't have a skill", result.as_samuel_reply())

    def test_as_samuel_reply_success(self):
        result = SkillResult(
            matched=True, skill_id="preflight", persona="samuel", mode="diagnose",
            attempted=True, exit_code=0, state="ready", parsed={"state": "ready"},
            stderr_tail="", summary="The box is ready.", elapsed_ms=120,
        )
        self.assertEqual(result.as_samuel_reply(), "The box is ready.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
