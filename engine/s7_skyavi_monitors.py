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
S7 SkyAVi — FACTS Monitors
==============================
Scheduled compliance + security monitors.
Run on SkyAVi scheduler. Store results as molecular bonds.
Anomalies trigger BABEL bonds.

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import asyncio
import subprocess
import os
import re
import shlex
from datetime import datetime

from s7_molecular import Bond


def _run_sync(command: str, timeout: int = 30) -> str:
    """Synchronous shell for scheduler thread (no async).

    2026-04-14: hardened from the 2026-04-13 security review
    MEDIUM. The command strings in this module ARE shell-feature
    dependent (pipes, stderr redirects, ||-fallbacks, globs), so
    shell=True is retained. The "would be injection if templated"
    finding is closed at the call-site level instead:

      1. Every call site in this file uses a HARDCODED STRING
         LITERAL as the command argument, with one exception
         (monitor_service_health's restart call). That exception
         now uses shlex.quote() to sanitize the service name
         before interpolation.

      2. Any future call site MUST either (a) use a hardcoded
         string literal, or (b) use shlex.quote() on every
         interpolated variable. This invariant is enforced by
         code review; there is no runtime check.

      3. The sanitization helper is at `_sanitize()` below,
         which masks any secrets that happen to appear in
         command output (separate concern from injection).

    This file is NEVER to accept user-provided command strings
    without explicit shlex.quote() on every variable component.
    The Samuel.shell() entrypoint in s7_skyavi.py has its own
    layered defense (allowlist + compound-shell rejection) and
    is the only path user input should ever reach subprocess.
    """
    try:
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True,
            timeout=timeout,
            env={**os.environ, "PATH": "/usr/bin:/usr/sbin:/bin:/sbin"})
        output = result.stdout.strip()
        if result.returncode != 0 and result.stderr:
            output = f"{output}\nSTDERR: {result.stderr.strip()}" if output else result.stderr.strip()
        return _sanitize(output[:4096])
    except subprocess.TimeoutExpired:
        return f"TIMEOUT: {timeout}s"
    except Exception as e:
        return f"ERROR: {e}"


def _sanitize(output: str) -> str:
    """Mask secrets in output."""
    patterns = [
        (r'(password|passwd|pass|secret|token|key|api_key|credential)(\s*[=:]\s*)\S+',
         r'\1\2***MASKED***'),
        (r'\b[0-9a-fA-F]{32,}\b', '***MASKED_HASH***'),
    ]
    for pattern, replacement in patterns:
        output = re.sub(pattern, replacement, output, flags=re.IGNORECASE)
    return output


def register_monitors(samuel):
    """Register all FACTS monitors on a Samuel instance.
    These run on the SkyAVi scheduler thread (synchronous)."""

    skyavi = samuel.skyavi
    backend = samuel.backend

    # ── Service Health Monitor ───────────────────────────────────

    def monitor_service_health(**kwargs):
        """Check all S7 services are running."""
        output = _run_sync("systemctl --user list-units --type=service --state=failed --no-pager")
        failed = [line for line in output.split("\n") if "s7-" in line.lower()]

        if failed:
            backend.store_bond(Bond(
                bond_type="signal", plane=-1,
                memory=-1, present=-1, destiny=1,
                content=f"SERVICE ALERT: {len(failed)} failed services: {'; '.join(f[:60] for f in failed)}",
                witness_id=None,
                state="BABEL",
            ))

            # Auto-heal: restart failed s7 services.
            # The svc name comes from parsing `systemctl` output,
            # which is host-controlled but still passed through the
            # shell by _run_sync. shlex.quote() sanitizes it defensively
            # against any pathological unit name — injection closure
            # for the 2026-04-13 security review MEDIUM (monitors
            # subprocess.run with shell=True and f-string interpolation).
            for line in failed:
                svc = line.split()[0] if line.split() else ""
                if svc.startswith("s7-"):
                    _run_sync(f"systemctl --user restart {shlex.quote(svc)}")
                    backend.store_bond(Bond(
                        bond_type="signal", plane=-1,
                        memory=1, present=0, destiny=1,
                        content=f"AUTO-HEAL: restarted {svc}",
                        witness_id=None,
                        state="FERTILE",
                    ))
        else:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=1, present=1, destiny=1,
                content=f"Service health OK — no failed S7 services",
                witness_id=None,
                state="FERTILE",
            ))
        return True

    skyavi.schedule("svc_health", 300, "health_check")  # reuse existing

    # Register as a named callable on SkyAVi
    skyavi._monitor_service_health = monitor_service_health

    # ── Port Baseline Monitor ────────────────────────────────────

    # Updated 2026-04-13 — the stack runs on 57xxx now (per feedback_port_range).
    # CWS engine on 57077, Caddy front door on 8080, pod services on 57080-57092.
    # The previous 7xxx values would fire BABEL alerts on every tick because
    # nothing actually listens there.
    EXPECTED_PORTS = {"57077", "8080", "57080", "57081", "57086", "57090", "57091", "57092"}

    def monitor_ports(**kwargs):
        """Compare open ports against baseline."""
        output = _run_sync("ss -tlnp | grep LISTEN")
        open_ports = set()
        for line in output.split("\n"):
            match = re.search(r':(\d+)\s', line)
            if match:
                open_ports.add(match.group(1))

        unexpected = open_ports - EXPECTED_PORTS
        missing = EXPECTED_PORTS - open_ports

        if unexpected or missing:
            msg = []
            if unexpected:
                msg.append(f"UNEXPECTED ports: {', '.join(sorted(unexpected))}")
            if missing:
                msg.append(f"MISSING ports: {', '.join(sorted(missing))}")
            backend.store_bond(Bond(
                bond_type="signal", plane=-4,
                memory=-1, present=-1, destiny=-1,
                content=f"PORT ALERT: {' | '.join(msg)}",
                witness_id=None,
                state="BABEL",
            ))
        else:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=1, present=1, destiny=1,
                content=f"Port baseline OK — {len(open_ports)} ports match expected",
                witness_id=None,
                state="FERTILE",
            ))
        return True

    skyavi._monitor_ports = monitor_ports

    # ── Outbound Connection Monitor ──────────────────────────────

    # Built from a static loopback set + an env-var extension. The env var
    # `S7_ALLOWED_OUTBOUND` is a comma-separated list of additional IPs the
    # operator has authorized for outbound connections (e.g., the LAN router
    # IP, an upstream DNS, etc.). Removed the previously hardcoded
    # `192.168.1.75` (a specific dev-box LAN IP that leaked into source).
    _extra_outbound = {ip.strip() for ip in os.getenv("S7_ALLOWED_OUTBOUND", "").split(",") if ip.strip()}
    ALLOWED_OUTBOUND = {"127.0.0.1", "::1", "0.0.0.0"} | _extra_outbound

    def monitor_outbound(**kwargs):
        """Check for unexpected outbound connections."""
        output = _run_sync("ss -tp state established")
        suspicious = []
        for line in output.split("\n"):
            if not line.strip() or "Peer" in line:
                continue
            # Extract peer address
            match = re.search(r'(\d+\.\d+\.\d+\.\d+):\d+\s*$', line)
            if match:
                peer = match.group(1)
                if peer not in ALLOWED_OUTBOUND and not peer.startswith("127."):
                    suspicious.append(f"{peer} ({line.strip()[:80]})")

        if suspicious:
            backend.store_bond(Bond(
                bond_type="signal", plane=-4,
                memory=-1, present=-1, destiny=-1,
                content=f"OUTBOUND ALERT: {len(suspicious)} unexpected connections: {'; '.join(suspicious[:5])}",
                witness_id=None,
                state="BABEL",
            ))
        else:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=1, present=1, destiny=1,
                content="Outbound connections OK — no unexpected peers",
                witness_id=None,
                state="FERTILE",
            ))
        return True

    skyavi._monitor_outbound = monitor_outbound

    # ── Disk Usage Monitor ───────────────────────────────────────

    def monitor_disk(**kwargs):
        """Alert when disk usage exceeds 85%."""
        output = _run_sync("df -h / /s7 2>/dev/null")
        alerts = []
        for line in output.split("\n"):
            match = re.search(r'(\d+)%\s+(/\S*)', line)
            if match:
                pct = int(match.group(1))
                mount = match.group(2)
                if pct >= 85:
                    alerts.append(f"{mount} at {pct}%")

        if alerts:
            backend.store_bond(Bond(
                bond_type="signal", plane=-1,
                memory=-1, present=-1, destiny=1,
                content=f"DISK ALERT: {'; '.join(alerts)}",
                witness_id=None,
                state="BABEL",
            ))
        else:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=1, present=1, destiny=1,
                content="Disk usage OK — all mounts under 85%",
                witness_id=None,
                state="FERTILE",
            ))
        return True

    skyavi._monitor_disk = monitor_disk

    # ── CIS Baseline Check ───────────────────────────────────────

    def monitor_cis_baseline(**kwargs):
        """Basic CIS Fedora Level 1 checks."""
        checks = []
        score = 0
        total = 0

        # 1. SELinux enforcing
        total += 1
        se = _run_sync("getenforce")
        if "Enforcing" in se:
            score += 1
            checks.append("PASS: SELinux enforcing")
        else:
            checks.append(f"FAIL: SELinux {se.strip()}")

        # 2. No empty passwords in shadow
        total += 1
        shadow = _run_sync("grep -c '::' /etc/shadow 2>/dev/null || echo 0")
        if shadow.strip() == "0":
            score += 1
            checks.append("PASS: No empty passwords")
        else:
            checks.append("FAIL: Empty passwords in shadow")

        # 3. SSH root login disabled
        total += 1
        ssh = _run_sync("grep -i '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null")
        if "no" in ssh.lower():
            score += 1
            checks.append("PASS: SSH root login disabled")
        elif ssh.strip():
            checks.append(f"WARN: SSH PermitRootLogin = {ssh.strip()}")
        else:
            checks.append("WARN: SSH PermitRootLogin not set")

        # 4. Firewall active
        total += 1
        fw = _run_sync("firewall-cmd --state 2>/dev/null")
        if "running" in fw.lower():
            score += 1
            checks.append("PASS: Firewall running")
        else:
            checks.append("FAIL: Firewall not running")

        # 5. No world-writable files in /etc
        total += 1
        ww = _run_sync("find /etc -maxdepth 2 -perm -o+w -type f 2>/dev/null | head -5")
        if not ww.strip():
            score += 1
            checks.append("PASS: No world-writable files in /etc")
        else:
            checks.append(f"FAIL: World-writable files: {ww.strip()[:100]}")

        # 6. Password max age set
        total += 1
        maxdays = _run_sync("grep '^PASS_MAX_DAYS' /etc/login.defs 2>/dev/null")
        if maxdays.strip() and "99999" not in maxdays:
            score += 1
            checks.append(f"PASS: {maxdays.strip()}")
        else:
            checks.append("WARN: PASS_MAX_DAYS not enforced (99999 or unset)")

        pct = round(score / max(total, 1) * 100, 1)
        state = "FERTILE" if pct >= 70 else "BABEL"

        backend.store_bond(Bond(
            bond_type="output", plane=-2,
            memory=1 if state == "FERTILE" else -1,
            present=0, destiny=1 if state == "FERTILE" else -1,
            content=f"CIS Baseline: {score}/{total} ({pct}%)\n" + "\n".join(checks),
            witness_id=None,
            trust_score=pct / 100,
            state=state,
        ))
        return True

    skyavi._monitor_cis = monitor_cis_baseline

    # ── FIPS Crypto Check ────────────────────────────────────────

    def monitor_fips(**kwargs):
        """Check if FIPS mode is enabled."""
        fips = _run_sync("cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo 'N/A'")
        fips_enabled = fips.strip() == "1"

        # Check OpenSSL FIPS
        ossl = _run_sync("openssl version 2>/dev/null")

        backend.store_bond(Bond(
            bond_type="output", plane=-2,
            memory=1, present=0, destiny=1,
            content=f"FIPS check: kernel={'enabled' if fips_enabled else 'disabled'}, OpenSSL={ossl.strip()[:60]}",
            witness_id=None,
            state="FERTILE" if fips_enabled else "BABEL",
        ))
        return True

    skyavi._monitor_fips = monitor_fips

    # ── Register all monitors on scheduler ───────────────────────

    def run_all_monitors(**kwargs):
        """Master monitor that runs all checks."""
        try:
            monitor_service_health()
            monitor_ports()
            monitor_outbound()
            monitor_disk()
        except Exception as e:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=-1, present=-1, destiny=-1,
                content=f"Monitor error: {e}",
                witness_id=None,
                state="BABEL",
            ))

    def run_compliance(**kwargs):
        """Run compliance checks (daily)."""
        try:
            monitor_cis_baseline()
            monitor_fips()
        except Exception as e:
            backend.store_bond(Bond(
                bond_type="signal", plane=0,
                memory=-1, present=-1, destiny=-1,
                content=f"Compliance error: {e}",
                witness_id=None,
                state="BABEL",
            ))

    # Store callables on SkyAVi for scheduler access
    skyavi.run_all_monitors = run_all_monitors
    skyavi.run_compliance = run_compliance

    # Schedule: monitors every 5 min, compliance daily (86400s)
    skyavi.schedule("skyavi_monitors", 300, "run_all_monitors")
    skyavi.schedule("skyavi_compliance", 86400, "run_compliance")
