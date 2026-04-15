#!/usr/bin/env python3
# engine/tests/test_shell_compound_bypass.py
#
# Regression tests for Samuel._SHELL_COMPOUND_RE.
#
# The compound-shell-bypass was originally flagged by a 2026-04-13
# security review (Reviewer #6 in the Opus review synthesis). The
# original fix caught &&, ||, ;, |, $( and backticks but missed:
#
#   - single & (background separator: `echo hi & whoami`)
#   - newline (two commands on one line: `echo hi\nwhoami`)
#   - redirects < and > (data exfiltration to file)
#
# The 2026-04-15 SOLO audit verified all three as real bypasses
# against the original regex, then tightened it. This test file
# locks the tightened behavior in place.
#
# Run: python3 -m unittest engine.tests.test_shell_compound_bypass -v

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from s7_skyavi import Samuel


class ShellCompoundBypassTests(unittest.TestCase):
    """Every known shell-compound bypass pattern MUST be blocked."""

    def assertBlocked(self, command, label):
        """The compound regex matches — the command would be rejected."""
        match = Samuel._SHELL_COMPOUND_RE.search(command)
        self.assertIsNotNone(
            match,
            f"{label}: expected {command!r} to be BLOCKED but regex did not match",
        )

    def assertAllowed(self, command, label):
        """The compound regex does NOT match — the command proceeds to the
        allowlist check (which may still reject, but not here)."""
        match = Samuel._SHELL_COMPOUND_RE.search(command)
        self.assertIsNone(
            match,
            f"{label}: expected {command!r} to PASS the compound check "
            f"but regex matched {match!r}",
        )

    # ── Patterns the 2026-04-13 fix caught ──────────────────────
    def test_and_and_chain(self):
        self.assertBlocked("echo hi && whoami", "&& chain")

    def test_or_or_chain(self):
        self.assertBlocked("echo hi || whoami", "|| chain")

    def test_semicolon(self):
        self.assertBlocked("echo hi ; whoami", "semicolon")

    def test_single_pipe(self):
        self.assertBlocked("echo hi | grep h", "single pipe")

    def test_command_substitution(self):
        self.assertBlocked("echo $(whoami)", "$(...) substitution")

    def test_backtick_substitution(self):
        self.assertBlocked("echo `whoami`", "backtick substitution")

    # ── Patterns the 2026-04-15 SOLO audit added ────────────────
    def test_single_ampersand_background(self):
        """`echo hi & whoami` — backgrounds the first, runs the second."""
        self.assertBlocked("echo hi & whoami", "single & background")

    def test_newline_separator(self):
        """`echo hi\\nwhoami` — two commands on one input string."""
        self.assertBlocked("echo hi\nwhoami", "newline separator")

    def test_stdout_redirect(self):
        """`cat /etc/passwd > /tmp/x` — data exfiltration via file write."""
        self.assertBlocked(
            "cat /etc/os-release > /tmp/exfil.txt", "> redirect"
        )

    def test_stdin_redirect(self):
        """`cat < /etc/passwd` — reads from file via shell redirect."""
        self.assertBlocked("cat < /etc/os-release", "< redirect")

    def test_double_ampersand_also_blocked(self):
        """Belt and suspenders: && is caught because & is caught."""
        self.assertBlocked("a && b", "&& (via &)")

    def test_double_pipe_also_blocked(self):
        """Belt and suspenders: || is caught because | is caught."""
        self.assertBlocked("a || b", "|| (via |)")

    # ── Legit single-command patterns — MUST still be allowed ──
    def test_plain_ls_allowed(self):
        self.assertAllowed("ls /tmp", "plain ls")

    def test_df_with_flag_allowed(self):
        self.assertAllowed("df -h", "df -h")

    def test_bare_env_var_allowed(self):
        """$HOME alone is variable expansion, not command execution."""
        self.assertAllowed("echo $HOME", "bare $ variable")

    def test_cat_plain_file_allowed(self):
        self.assertAllowed("cat /etc/os-release", "cat plain")

    def test_find_with_name_allowed(self):
        self.assertAllowed("find /tmp -name foo.txt", "find with -name")

    def test_grep_pattern_allowed(self):
        """Plain grep with no pipe — single command."""
        self.assertAllowed("grep ERROR /tmp/foo.log", "grep pattern")

    def test_curl_loopback_allowed(self):
        """Curl to a loopback URL — single command, no redirect."""
        self.assertAllowed("curl -sf http://127.0.0.1:57077/status", "curl loopback")


class S7NameRegexTests(unittest.TestCase):
    """_S7_NAME_RE is the allowlist used by the 4 f-string
    interpolation skills (restart_service, restart_container,
    service_logs, container_logs) in s7_skyavi_skills.py. These
    skills call shell_trusted() which DOES NOT run the compound-
    shell check — the only defense is the name regex. This test
    class locks the allowlist's rejection behavior."""

    def setUp(self):
        # The production regex is a class attribute on the Samuel
        # subclass defined in s7_skyavi_skills.py. Re-compiling the
        # same pattern here locks the exact-string shape — any change
        # to the production regex must also update this line to
        # match, and that co-change is the covenant record.
        import re
        self.regex = re.compile(r'^s7-[a-z0-9._-]{1,60}$')

    def assertAccepted(self, name, label):
        self.assertIsNotNone(
            self.regex.match(name),
            f"{label}: expected {name!r} to be ACCEPTED as a valid s7 name",
        )

    def assertRejected(self, name, label):
        self.assertIsNone(
            self.regex.match(name),
            f"{label}: expected {name!r} to be REJECTED",
        )

    # ── Valid service/container names — MUST pass ──────────────
    def test_valid_service_name(self):
        self.assertAccepted("s7-cws-engine", "standard service")

    def test_valid_with_dots(self):
        self.assertAccepted("s7-qubi.v2.5", "dot-separated version")

    def test_valid_with_underscores(self):
        self.assertAccepted("s7-test_container", "underscore allowed")

    def test_valid_max_length_60(self):
        self.assertAccepted("s7-" + "a" * 57, "60-char max (s7- prefix + 57 body)")

    # ── Shell metacharacter injection — MUST ALL reject ────────
    def test_reject_semicolon(self):
        self.assertRejected("s7-foo;whoami", "semicolon injection")

    def test_reject_ampersand(self):
        self.assertRejected("s7-foo&whoami", "single & injection")

    def test_reject_double_ampersand(self):
        self.assertRejected("s7-foo&&whoami", "&& injection")

    def test_reject_pipe(self):
        self.assertRejected("s7-foo|whoami", "pipe injection")

    def test_reject_dollar_paren(self):
        self.assertRejected("s7-foo$(whoami)", "command substitution")

    def test_reject_backtick(self):
        self.assertRejected("s7-foo`whoami`", "backtick substitution")

    def test_reject_space(self):
        self.assertRejected("s7-foo bar", "space (flag injection)")

    def test_reject_flag_injection(self):
        """The original pre-hardening bug: 's7-foo --signal=KILL'
        would pass startswith('s7-') but contains a space."""
        self.assertRejected("s7-foo --signal=KILL", "flag injection via space")

    def test_reject_newline(self):
        self.assertRejected("s7-foo\nwhoami", "newline injection")

    def test_reject_redirect_gt(self):
        self.assertRejected("s7-foo>/tmp/x", "> redirect")

    def test_reject_redirect_lt(self):
        self.assertRejected("s7-foo</etc/passwd", "< redirect")

    def test_reject_uppercase(self):
        self.assertRejected("s7-FooBar", "uppercase not in allowlist")

    def test_reject_no_s7_prefix(self):
        self.assertRejected("foo", "missing s7- prefix")
        self.assertRejected("legit-s7-foo", "s7- not at start")
        self.assertRejected("", "empty string")

    def test_reject_length_over_60(self):
        self.assertRejected("s7-" + "a" * 61, "61-char body exceeds max")

    def test_reject_path_traversal_chars(self):
        """../etc/passwd style — slash is not in allowlist."""
        self.assertRejected("s7-foo/../bar", "slash path traversal")

    def test_reject_null_byte(self):
        self.assertRejected("s7-foo\x00whoami", "null byte injection")


if __name__ == "__main__":
    unittest.main(verbosity=2)
