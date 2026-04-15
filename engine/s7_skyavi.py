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
S7 SkyAVi — Samuel Security & Automation Engine
==================================================
FACTS: FIPS/CIS, Automation, Communications, Technician, Stack
Chat-driven AI sysadmin. All actions discerned through S7 CWS.
Protected by SkyAVi. The 1st QUBi.

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import os
import re
import asyncio
import subprocess
from dataclasses import dataclass, field

from s7_molecular import Bond, MolecularBackend
from s7_skyavi_orchestrator import SkyAVi
from s7_http import mempalace_add_drawer, mempalace_search

# SHELL_ALLOWLIST — read-only system inspection only.
#
# Hardened 2026-04-13 after a public-source security review combined
# with the S7 covenant memories (civilian-only mandate; Samuel as warm-
# loop guardian, not escalation; sovereign offline). Removed:
#   - sudo, dnf, cryptsetup           (escalation / package mgmt / data destruction)
#   - nmap, nikto, sqlmap, gobuster   (offensive tools — directly contradict civilian-only)
#   - bandit, eslint, sonar-scanner   (linters — not Samuel's job)
#   - terraform, tofu, ansible, helm, k3s, pulumi  (IaC — not sovereign offline)
#   - aws, az, gcloud, doctl          (cloud CLIs — explicit "no cloud" mandate)
#   - pwsh, wslpath                   (Windows tools — copy-paste residue)
#   - npm, pip3                       (package install — operator-driven only)
#   - curl                            (outbound exfiltration risk — use s7_http instead)
#   - nft, firewall-cmd               (firewall mutation — skill-only with hardcoded args)
#   - systemctl                       (service mutation — skill-only with hardcoded units)
#   - iwconfig, ethtool               (NIC config — not Samuel's job)
#   - psql                            (direct DB access — use the typed engine APIs)
#   - cd                              (no effect in non-interactive subshell)
#
# Anything that needs to MUTATE state must be a registered skill with a
# hardcoded command string and predictable output, NOT a free-form shell
# call. The shell() method is the last resort, not the primary path.
SHELL_ALLOWLIST = [
    # System inspection (read-only)
    "df", "lsblk", "free", "uptime", "uname", "hostname", "date", "whoami", "id",
    "sestatus", "getenforce", "findmnt",
    # Container + service inspection (read-only)
    "podman", "ss", "ip",
    # Network diagnostics (local + DNS resolution only)
    "ping", "tracepath", "host", "nslookup", "dig",
    # File inspection (read-only — no write)
    "cat", "head", "tail", "wc", "grep", "find", "ls", "test",
    # Crypto verification (verify only — does not mutate)
    "certutil", "openssl",
    # Inference
    "ollama",
    # Logs
    "journalctl", "loginctl",
    # Scripting primitive (limited utility but harmless)
    "python3", "echo",
]

SHELL_DENYLIST = [
    "rm", "mkfs", "dd", "shred",
    "chmod 777", "chown root",
    "passwd root", "userdel",
    "iptables -F", "firewall-cmd --panic-on",
    "reboot", "shutdown", "poweroff", "init 0",
    "curl -o", "wget",
]


@dataclass
class SkillDef:
    name: str
    pattern: str
    category: str
    fn: object
    description: str = ""


class Samuel:
    def __init__(self, skyavi: SkyAVi):
        self.skyavi = skyavi
        self.backend = skyavi.backend
        self.skills: list[SkillDef] = []
        self.persona = "Samuel"
        self._notifications: list[dict] = []  # internal log

    def skill(self, pattern: str, category: str = "system", description: str = ""):
        """Decorator to register a skill."""
        def decorator(fn):
            self.skills.append(SkillDef(
                name=fn.__name__,
                pattern=pattern.lower(),
                category=category,
                fn=fn,
                description=description or fn.__doc__ or "",
            ))
            return fn
        return decorator

    def match_skill(self, message: str) -> SkillDef | None:
        """Find the best matching skill for a message."""
        msg = message.lower().strip()
        for skill in self.skills:
            if skill.pattern in msg:
                return skill
        return None

    def list_skills(self) -> list[dict]:
        """Return all registered skills."""
        return [{"name": s.name, "pattern": s.pattern,
                 "category": s.category, "description": s.description}
                for s in self.skills]

    # Compound shell metacharacters that bypass the first-word allowlist.
    # The shell() method passes its arg to bash, which evaluates &&, ;, |,
    # `...`, and $(...) as control flow. Validating only the first word
    # means everything after the first &&/;/|/etc. runs unchecked. This
    # is the second-review root finding — closing it at the entrypoint.
    # Compound-shell bypass guard. Rejects any character or sequence
    # that bash treats as a command separator, command-substitution
    # opener, or I/O redirect.
    #
    # What this catches:
    #   & or &&   — command separator (single & backgrounds; && chains)
    #   | or ||   — pipe or logical-or (single | pipes; || chains)
    #   ;         — command separator
    #   newline   — command separator on a new line
    #   $(        — command substitution
    #   `         — backtick command substitution
    #   < or >    — I/O redirect (stdin/stdout file)
    #
    # What this does NOT catch (and why):
    #   $VAR      — bare variable expansion (not code execution).
    #               Many safe skills reference $HOME, $USER. Blocking
    #               this would be too noisy. $( is still blocked.
    #
    # 2026-04-15 tightening: the original 2026-04-13 fix caught &&, ||,
    # ;, |, $(, and backtick but missed single &, newline, and < / >
    # redirects. All three were verified as real bypasses in the SOLO
    # block's security audit and are now caught.
    _SHELL_COMPOUND_RE = __import__("re").compile(
        r'(\&|\||;|\n|\$\(|`|<|>)'
    )

    async def shell(self, command: str, timeout: int = 30) -> str:
        """Execute a shell command with allowlist/denylist sandboxing.

        Hardened 2026-04-13 against the &&-chain bypass: any command
        containing shell control characters (&&, ||, ;, |, $(...), `...`)
        is rejected up front. Skills that need multi-step output should
        either chain via Python or be split into multiple registered
        skills with hardcoded single-command bodies.
        """
        import re

        # Strip leading/trailing whitespace once
        cmd_stripped = command.strip()

        # ── Defense layer 1: reject compound shell control characters ──
        # The first-word allowlist below is meaningless if the command
        # contains && or | or ; — bash evaluates them all. Reject up front.
        if Samuel._SHELL_COMPOUND_RE.search(cmd_stripped):
            return ("DENIED: compound shell commands are not allowed "
                    "(&&, ||, ;, |, $(...), backticks). Each shell call "
                    "must be a single command. Use a registered skill "
                    "to chain multiple operations.")

        # ── Defense layer 2: existing denylist (catches dangerous patterns) ──
        for denied in SHELL_DENYLIST:
            # Match as whole word or at word boundary to avoid false positives
            # e.g. "rm" should not match "--format" or "firewall"
            if re.search(r'(?:^|\s|/)' + re.escape(denied) + r'(?:\s|$)', cmd_stripped):
                return f"DENIED: command contains blocked pattern '{denied}'"

        # ── Defense layer 3: first-word allowlist ──
        first_word = cmd_stripped.split()[0] if cmd_stripped.split() else ""
        base_cmd = os.path.basename(first_word)
        if base_cmd not in SHELL_ALLOWLIST:
            return f"DENIED: '{base_cmd}' not in allowlist"

        return await self._run_subprocess(command, timeout)

    async def shell_trusted(self, command: str, timeout: int = 30) -> str:
        """TRUSTED shell entry — for built-in skills only.

        Bypasses compound-shell rejection and the allowlist because the
        caller is reviewed code in this repository, not user input. The
        trust boundary is the skill author + code review, not runtime
        validation. NEVER expose this method to LLM tool calls, MCP
        argument paths, or any web-facing handler. Denylist still applies
        as defense in depth against pattern-level catastrophes.
        """
        import re
        cmd_stripped = command.strip()
        for denied in SHELL_DENYLIST:
            if re.search(r'(?:^|\s|/)' + re.escape(denied) + r'(?:\s|$)', cmd_stripped):
                return f"DENIED: command contains blocked pattern '{denied}'"
        return await self._run_subprocess(command, timeout)

    async def _run_subprocess(self, command: str, timeout: int) -> str:
        """Internal runner shared by shell + shell_trusted."""
        try:
            proc = await asyncio.create_subprocess_shell(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, "PATH": "/usr/bin:/usr/sbin:/bin:/sbin"},
            )
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=timeout)
            output = stdout.decode("utf-8", errors="replace").strip()
            if proc.returncode != 0:
                err = stderr.decode("utf-8", errors="replace").strip()
                output = f"{output}\nSTDERR: {err}" if output else f"STDERR: {err}"
            return self._sanitize(output[:4096])
        except asyncio.TimeoutError:
            return f"TIMEOUT: command exceeded {timeout}s"
        except Exception as e:
            return f"ERROR: {e}"

    @staticmethod
    def _sanitize(output: str) -> str:
        """Mask passwords, secrets, tokens, and keys in output."""
        import re
        # Mask common secret patterns
        patterns = [
            (r'(password|passwd|pass|secret|token|key|api_key|apikey|credential)(\s*[=:]\s*)\S+',
             r'\1\2***MASKED***'),
            (r'(PASS_\w+\s+)\d+', r'\1***'),
            # Mask anything that looks like a hash/token (32+ hex chars)
            (r'\b[0-9a-fA-F]{32,}\b', '***MASKED_HASH***'),
        ]
        for pattern, replacement in patterns:
            output = re.sub(pattern, replacement, output, flags=re.IGNORECASE)
        return output

    async def _share_to_palace(self, wing: str, hall: str, room: str,
                               label: str, content: str):
        """Share to S7 MemPalace — all aware."""
        try:
            await mempalace_add_drawer(
                wing=wing, hall=hall, room=room,
                label=label, content=self._sanitize(content[:1000]))
        except Exception:
            pass  # MemPalace offline is non-fatal

    def _notify(self, level: str, message: str):
        """Internal notification log."""
        from datetime import datetime, timezone
        entry = {
            "time": datetime.now(timezone.utc).isoformat(),
            "level": level,
            "from": self.persona,
            "message": message[:500],
        }
        self._notifications.append(entry)
        # Keep last 100
        if len(self._notifications) > 100:
            self._notifications = self._notifications[-100:]

    async def execute_skill(self, skill: SkillDef, message: str) -> str:
        """Run a skill function, store result as bond, share to MemPalace."""
        try:
            output = await skill.fn(self, message)
        except Exception as e:
            output = f"Skill error: {e}"

        # Bond it
        bond = Bond(
            bond_type="output",
            plane=-1,
            memory=1, present=0, destiny=1,
            content=f"[{skill.category}:{skill.name}] {output[:2048]}",
            witness_id=None,
            state="FERTILE",
        )
        self.backend.store_bond(bond)

        # Share to MemPalace — all aware
        await self._share_to_palace(
            wing="private-ai", hall="skyavi",
            room=skill.category,
            label=f"skill:{skill.name}:{bond.id[:8]}",
            content=f"[{skill.category}:{skill.name}] {output[:500]}")

        # Internal notification
        self._notify("INFO", f"Skill executed: {skill.category}:{skill.name}")

        return output

    # ── Sensitive patterns that require full consensus ──────────────
    SENSITIVE_PATTERNS = [
        "delete", "remove", "drop", "destroy", "kill", "wipe",
        "password", "secret", "token", "credential",
        "firewall", "iptables", "nft", "selinux",
        "reboot", "shutdown", "poweroff",
        "chmod", "chown", "userdel", "passwd",
        "sudo", "root",
    ]

    def _classify_tier(self, message: str) -> str:
        """Classify message into response tier.
        FAST  — skill match, skip consensus entirely (< 1s)
        LITE  — single witness, no guardian (~10-15s)
        FULL  — guardian + all witnesses (~30-45s)
        """
        msg_lower = message.lower()

        # Sensitive queries always get full consensus
        for pattern in self.SENSITIVE_PATTERNS:
            if pattern in msg_lower:
                return "FULL"

        # Skill-matched queries get FAST path
        if self.match_skill(message):
            return "FAST"

        # Everything else gets LITE
        return "LITE"

    async def chat(self, message: str, tier: str | None = None) -> dict:
        """Samuel receives a message. Response tier determines speed vs rigor.
        FAST  — skill match, skip consensus (< 1s)
        LITE  — single witness, no guardian (~10-15s)
        FULL  — guardian + all witnesses (~30-45s)
        All actions shared to MemPalace. All components aware."""

        tier = tier or self._classify_tier(message)

        # ── FAST path: skill-matched, skip consensus ──────────────
        if tier == "FAST":
            skill = self.match_skill(message)
            if skill:
                output = await self.execute_skill(skill, message)
                return {
                    "from": self.persona,
                    "response": output,
                    "skill": skill.name,
                    "category": skill.category,
                    "blocked": False,
                    "verdict": "FERTILE",
                    "tier": "FAST",
                }
            # Skill disappeared between classify and execute — fall through to LITE
            tier = "LITE"

        # ── LITE path: single witness, no guardian ────────────────
        if tier == "LITE":
            # Pick the fastest witness (lowest plane = primary)
            witnesses = sorted(
                [a for a in self.skyavi.agents.values() if a.plane > 0],
                key=lambda a: a.plane)
            if witnesses:
                bond = await self.skyavi.run_agent(witnesses[0], message)
                if bond.state == "FERTILE":
                    # Check for skill match on the original message
                    skill = self.match_skill(message)
                    if skill:
                        output = await self.execute_skill(skill, message)
                        return {
                            "from": self.persona,
                            "response": output,
                            "skill": skill.name,
                            "category": skill.category,
                            "blocked": False,
                            "verdict": "FERTILE",
                            "tier": "LITE",
                        }
                    response = bond.content
                    voice = bond.witness_id or witnesses[0].name
                    await self._share_to_palace(
                        wing="private-ai", hall="skyavi", room="conversation",
                        label=f"chat:{message[:20]}",
                        content=f"Q: {message[:200]}\nA: {response[:300]}")
                    self._notify("INFO", f"Chat(LITE/{voice}): {message[:60]}")
                    return {
                        "from": voice,
                        "response": response,
                        "skill": None,
                        "blocked": False,
                        "verdict": "FERTILE",
                        "tier": "LITE",
                    }
                # BABEL from single witness — escalate to FULL
                tier = "FULL"

        # ── FULL path: guardian + all witnesses (original behavior) ─
        result = await self.skyavi.run_consensus(message)

        if result["verdict"] != "FERTILE":
            self.backend.store_bond(Bond(
                bond_type="signal", plane=-4,
                memory=-1, present=-1, destiny=-1,
                content=f"BLOCKED: {message[:256]}",
                witness_id=None,
                state="BABEL",
            ))
            await self._share_to_palace(
                wing="private-ai", hall="skyavi", room="blocked",
                label=f"blocked:{message[:20]}",
                content=f"BLOCKED by CWS: {message[:256]}")
            self._notify("WARN", f"Blocked: {message[:100]}")

            return {
                "from": self.persona,
                "response": "I can't do that — blocked by S7 CWS discernment.",
                "blocked": True,
                "verdict": result["verdict"],
                "tier": "FULL",
            }

        skill = self.match_skill(message)
        if skill:
            output = await self.execute_skill(skill, message)
            return {
                "from": self.persona,
                "response": output,
                "skill": skill.name,
                "category": skill.category,
                "blocked": False,
                "verdict": "FERTILE",
                "tier": "FULL",
            }

        # Pick the best FERTILE bond as the voice
        fertile_bonds = [b for b in result["bonds"] if b.state == "FERTILE"]
        if fertile_bonds:
            best = max(fertile_bonds, key=lambda b: b.trust_score or 0)
            response = best.content
            voice = best.witness_id or self.persona
        else:
            response = result["bonds"][0].content if result["bonds"] else "I heard you."
            voice = self.persona

        await self._share_to_palace(
            wing="private-ai", hall="skyavi", room="conversation",
            label=f"chat:{message[:20]}",
            content=f"Q: {message[:200]}\nA: {response[:300]}")
        self._notify("INFO", f"Chat(FULL/{voice}): {message[:60]}")

        return {
            "from": voice,
            "response": response,
            "skill": None,
            "blocked": False,
            "verdict": "FERTILE",
            "tier": "FULL",
        }

    async def self_audit(self) -> dict:
        """Samuel audits himself — skill count, notifications, bond stats."""
        skill_count = len(self.skills)
        categories = list(set(s.category for s in self.skills))
        recent_notifications = self._notifications[-10:]

        # Count bonds by state
        fertile = self.backend.query_bonds(state="FERTILE", limit=1000)
        babel = self.backend.query_bonds(state="BABEL", limit=1000)

        audit = {
            "persona": self.persona,
            "skills": skill_count,
            "categories": categories,
            "notifications": len(self._notifications),
            "recent_notifications": recent_notifications,
            "bonds_fertile": len(fertile),
            "bonds_babel": len(babel),
            "skyavi": self.skyavi.status(),
        }

        # Bond the self-audit
        self.backend.store_bond(Bond(
            bond_type="signal", plane=0,
            memory=1, present=1, destiny=1,
            content=f"Self-audit: {skill_count} skills, {len(fertile)} FERTILE, "
                    f"{len(babel)} BABEL, {len(self._notifications)} notifications",
            witness_id=None,
            state="FERTILE",
        ))

        # Share audit to MemPalace
        await self._share_to_palace(
            wing="private-ai", hall="skyavi", room="self-audit",
            label=f"audit:{audit['bonds_fertile']}f:{audit['bonds_babel']}b",
            content=f"Self-audit: {skill_count} skills, "
                    f"{len(fertile)} FERTILE, {len(babel)} BABEL")

        self._notify("INFO", "Self-audit complete")
        return audit

    def get_notifications(self, limit: int = 20) -> list[dict]:
        """Return recent internal notifications."""
        return self._notifications[-limit:]

    def status(self) -> dict:
        """Return SkyAVi status."""
        return {
            "persona": self.persona,
            "skills": len(self.skills),
            "categories": list(set(s.category for s in self.skills)),
            "notifications": len(self._notifications),
            "skyavi": self.skyavi.status(),
        }
