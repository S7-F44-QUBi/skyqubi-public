#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Audit File History Ingest
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
Populate audit.file_change_history from a path list.

Reads a file containing one absolute path per line (default
/tmp/s7-audit-33h.txt), classifies each path via rule-based
pattern matching, and bulk-inserts rows into
audit.file_change_history.

Classification assigns:
  - foundation: -1 (system), 0 (session/repo), +1 (output/noise)
  - stack: subsystem label
  - authored_by: most-likely author
  - touched_by: most-likely cause
  - why: free-text rationale
  - tracked_in_git: boolean
  - importance: 0..5

Rules are ordered from most-specific to most-general. The FIRST
matching rule wins. Unknown paths land in 'other' with importance 0.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from s7_prism_detect import _pg_connect


# ── Classification rules ────────────────────────────────────────────
# Each rule is a tuple:
#   (regex, foundation, stack, authored_by, touched_by, why, importance)
# First match wins. Compiled lazily below.

_RULES = [
    # ── -1 ROCK: system files ─────────────────────────────────────
    (r"^/etc/(passwd|shadow|group|gshadow|subuid|subgid)$",
     -1, "system-identity", "sudo+useradd", "useradd|usermod",
     "identity change — user/group created or modified", 5),

    (r"^/etc/sudoers(\.d/.*)?$",
     -1, "system-sudoers", "sudo", "visudo|dnf",
     "sudoers edited — privilege grant change", 5),

    (r"^/etc/polkit-1/",
     -1, "system-polkit", "sudo", "write",
     "polkit authorization rules modified", 5),

    (r"^/etc/selinux/",
     -1, "system-selinux", "semanage|dnf", "semanage|load_policy",
     "SELinux policy recompile / file_contexts update", 4),

    (r"^/etc/dracut\.conf\.d/",
     -1, "system-dracut", "sudo", "write",
     "dracut initramfs config — boot chain critical", 4),

    (r"^/etc/audit/",
     -1, "system-audit", "sudo", "augenrules|systemctl",
     "auditd rules / config — tamper-evident foundation", 4),

    (r"^/etc/tuned/",
     -1, "system-tuned", "tuned daemon", "tuned-adm",
     "tuned power profile state", 1),

    (r"^/etc/ld\.so\.cache$",
     -1, "system-ldcache", "ldconfig", "ldconfig",
     "dynamic linker cache rebuild (package install)", 1),

    (r"^/etc/",
     -1, "system-etc", "distro-package", "dnf|sudo",
     "/etc file modified — system config drift", 2),

    (r"^/usr/lib/sysimage/libdnf5/",
     -1, "system-dnf-meta", "dnf5", "dnf5",
     "dnf5 transaction metadata refresh", 1),

    (r"^/usr/lib/sysimage/rpm/",
     -1, "system-rpmdb", "dnf5", "dnf5",
     "rpm database transaction", 1),

    (r"^/usr/share/icons/.*/icon-theme\.cache$",
     -1, "system-icons", "dnf5", "gtk-update-icon-cache",
     "icon theme cache rebuild", 0),

    (r"^/usr/share/applications/mimeinfo\.cache$",
     -1, "system-mimeinfo", "dnf5", "update-mime-database",
     "mime cache rebuild", 0),

    (r"^/usr/",
     -1, "system-usr", "dnf5", "dnf5",
     "/usr file touched by package manager", 1),

    (r"^/var/lib/systemd/linger/",
     -1, "system-linger", "sudo+loginctl", "loginctl enable-linger",
     "user service linger enabled — background services without login", 4),

    (r"^/var/spool/mail/",
     -1, "system-mail", "sudo+useradd", "useradd",
     "mail spool file created (new user)", 2),

    (r"^/var/lib/systemd/coredump/",
     -1, "system-coredump", "systemd-coredump", "segfault",
     "process crashed and dumped core", 4),

    (r"^/var/lib/systemd/",
     -1, "system-systemd", "systemd", "systemd",
     "systemd state (timers, random-seed, backlight)", 1),

    (r"^/var/lib/upower/",
     -1, "system-upower", "upowerd", "upowerd",
     "upower battery history sample", 0),

    (r"^/var/lib/selinux/",
     -1, "system-selinux", "sudo", "semanage|load_policy",
     "SELinux runtime state", 2),

    (r"^/var/lib/fwupd/",
     -1, "system-fwupd", "fwupd", "fwupd refresh",
     "firmware update metadata", 1),

    (r"^/var/lib/plocate/",
     -1, "system-plocate", "updatedb", "updatedb",
     "plocate database rebuild", 0),

    (r"^/var/lib/plymouth/",
     -1, "system-plymouth", "plymouth", "plymouth",
     "plymouth boot splash timing", 1),

    (r"^/var/lib/logrotate/",
     -1, "system-logrotate", "logrotate", "logrotate",
     "logrotate state file", 0),

    (r"^/var/lib/lastlog/",
     -1, "system-lastlog", "login", "pam_lastlog",
     "last-login timestamps", 0),

    (r"^/var/spool/anacron/",
     -1, "system-anacron", "anacron", "anacron",
     "anacron cron tracking", 0),

    (r"^/var/",
     -1, "system-var", "systemd|daemon", "mixed",
     "/var runtime state", 1),

    # ── 0 DOOR: S7 repo work ─────────────────────────────────────
    (r"^/s7/skyqubi-private/\.git/",
      0, "s7-repo-git", "git", "git-commit",
     "git internals — index, refs, objects", 1),

    (r"^/s7/skyqubi-private/build/output/.*\.iso",
      1, "build-output-iso", "slipstream", "mksquashfs+mkisofs",
     "rebuilt S7 USB ISO with current private state", 5),

    (r"^/s7/skyqubi-private/build/output/.*\.sig",
      1, "build-output-sig", "ssh-keygen", "ssh-keygen -Y sign",
     "signature for a shipped ISO", 5),

    (r"^/s7/skyqubi-private/build/logs/",
      1, "build-logs", "builder-wrapper", "tee",
     "build log output", 0),

    (r"^/s7/skyqubi-private/build/output/",
      1, "build-output-other", "builder", "write",
     "build output artifact", 3),

    (r"^/s7/skyqubi-private/iso/[^/]+/dist/",
      1, "build-iso-dist", "slipstream", "mkisofs",
     "per-flavor ISO dist directory", 3),

    (r"^/s7/skyqubi-private/iso/[^/]+/work/",
      1, "build-iso-work", "slipstream", "cp",
     "per-flavor ISO work scratch", 0),

    (r"^/s7/skyqubi-private/iac/intake/quarantine/",
      1, "intake-quarantine", "podman", "podman pull",
     "intake gate quarantine graphRoot", 1),

    (r"^/s7/skyqubi-private/iac/intake/decisions/",
      0, "intake-decisions", "intake-gate", "gate.sh",
     "intake gate audit decision log", 4),

    (r"^/s7/skyqubi-private/iac/",
      0, "s7-repo-iac", "jamie+claude", "edit-tool",
     "iac/ — infrastructure as code changes", 4),

    (r"^/s7/skyqubi-private/engine/sql/",
      0, "s7-repo-sql", "claude", "write-tool",
     "postgres schema migration", 4),

    (r"^/s7/skyqubi-private/engine/",
      0, "s7-repo-engine", "claude", "edit-tool",
     "engine/ — S7 runtime code (Python)", 4),

    (r"^/s7/skyqubi-private/docs/internal/",
      0, "s7-repo-docs-internal", "claude", "write-tool",
     "internal-only docs (design, patent, runbooks)", 4),

    (r"^/s7/skyqubi-private/docs/public/",
      0, "s7-repo-docs-public", "claude", "write-tool",
     "public-facing docs", 3),

    (r"^/s7/skyqubi-private/docs/",
      0, "s7-repo-docs", "claude", "write-tool",
     "docs tree", 3),

    (r"^/s7/skyqubi-private/branding/",
      0, "s7-repo-branding", "jamie+claude", "write-tool",
     "brand assets (OCTi wallpapers, icons, palette)", 2),

    (r"^/s7/skyqubi-private/install/",
      0, "s7-repo-install", "claude", "write-tool",
     "install/ — builder wrappers + runtime scripts", 4),

    (r"^/s7/skyqubi-private/iso/",
      0, "s7-repo-iso", "claude", "edit-tool",
     "iso/ — slipstream, build-iso, skyloop", 4),

    (r"^/s7/skyqubi-private/profiles/",
      0, "s7-repo-profiles", "claude", "write-tool",
     "profiles/ — desktop unity profile", 2),

    (r"^/s7/skyqubi-private/mcp/",
      0, "s7-repo-mcp", "claude", "write-tool",
     "mcp/ — MCP server code", 2),

    (r"^/s7/skyqubi-private/public-chat/",
      0, "s7-repo-public-chat", "claude", "write-tool",
     "public-chat/ — website chat surface", 2),

    (r"^/s7/skyqubi-private/evidence/",
      0, "s7-repo-evidence", "jamie", "screenshot",
     "evidence/ — screenshots + demo assets", 2),

    (r"^/s7/skyqubi-private/book/",
      0, "s7-repo-book", "jamie", "write",
     "book/ — S7 book manuscript", 2),

    (r"^/s7/skyqubi-private/",
      0, "s7-repo-root", "claude", "edit-tool",
     "repo root file (README, LIFECYCLE, etc.)", 3),

    # ── 0 DOOR: persistent memory + secrets ──────────────────────
    (r"^/s7/\.claude/projects/-s7/memory/",
      0, "s7-claude-memory", "claude", "write-tool",
     "Claude persistent memory entries", 3),

    (r"^/s7/\.claude/",
      0, "s7-claude-cache", "claude", "claude-code",
     "Claude Code working state / cache", 0),

    (r"^/s7/\.mempalace/",
      0, "s7-mempalace", "mempalace-cli", "mempalace mine",
     "MemPalace palace data (chroma sqlite + hnsw)", 3),

    (r"^/s7/\.config/s7/",
      0, "s7-config-secret", "claude", "secrets.token_urlsafe",
     "S7 secrets (postgres password) — mode 600, outside repo", 5),

    (r"^/s7/\.config/autostart/",
      0, "s7-autostart", "claude", "write-tool",
     "user autostart (swaybg wallpaper agent)", 3),

    (r"^/s7/\.local/share/applications/",
      0, "s7-desktop-apps", "claude", "write-tool",
     "user applications (SkyBuilder launcher)", 3),

    (r"^/s7/Desktop/",
      0, "s7-desktop-surface", "jamie+claude", "write-tool",
     "literal Desktop directory (icons)", 2),

    # ── +1 REST: outputs / runtime / noise ───────────────────────
    (r"^/s7/\.local/share/containers/storage/overlay/",
      1, "container-cow", "podman", "podman exec/run",
     "container copy-on-write layer — pod runtime activity", 0),

    (r"^/s7/\.local/share/containers/",
      1, "container-meta", "podman", "podman",
     "container storage metadata", 1),

    (r"^/s7/\.cache/vivaldi/",
      1, "browser-cache-vivaldi", "vivaldi", "browser runtime",
     "Vivaldi browser cache", 0),

    (r"^/s7/\.cache/",
      1, "cache-other", "user apps", "app runtime",
     "user cache (dconf, mesa shaders, etc.)", 0),

    (r"^/s7/\.config/",
      0, "s7-config-app", "user apps", "dconf|writes",
     "user application config", 1),

    (r"^/s7/\.local/",
      1, "s7-local-other", "user apps", "write",
     "user local share / state", 1),

    (r"^/s7/\.bash_history$",
      0, "shell-history", "bash", "shell",
     "shell command history", 1),

    (r"^/s7/\.",
      0, "s7-dotfile-other", "mixed", "mixed",
     "other home dotfile", 1),

    (r"^/s7/",
      0, "s7-home-other", "mixed", "mixed",
     "other /s7 home file", 1),

    # ── Fallthrough ──────────────────────────────────────────────
    (r".*",
      0, "other", "unknown", "unknown",
     "unclassified path", 0),
]

_COMPILED = [(re.compile(p), *rest) for p, *rest in _RULES]

_GIT_ROOTS = ["/s7/skyqubi-private/"]


def classify(path: str):
    for rx, foundation, stack, authored, touched, why, importance in _COMPILED:
        if rx.match(path):
            tracked = any(path.startswith(r) for r in _GIT_ROOTS) and "/.git/" not in path
            return dict(
                foundation=foundation, stack=stack, authored_by=authored,
                touched_by=touched, why=why, importance=importance,
                tracked_in_git=tracked,
            )
    return None


def mtime_and_size(path: str):
    try:
        st = os.stat(path)
        return datetime.fromtimestamp(st.st_mtime, tz=timezone.utc), st.st_size
    except Exception:
        return None, None


_INSERT_SQL = """
    INSERT INTO audit.file_change_history
      (path, mtime, size_bytes,
       foundation, stack, authored_by,
       touched_by, why, tracked_in_git,
       importance,
       row_hash, prev_row_hash)
    SELECT
        %(path)s::TEXT, %(mtime)s::TIMESTAMPTZ, %(size)s::BIGINT,
        %(foundation)s::SMALLINT, %(stack)s::TEXT, %(authored)s::TEXT,
        %(touched)s::TEXT, %(why)s::TEXT, %(tracked)s::BOOLEAN,
        %(importance)s::SMALLINT,
        audit.compute_row_hash(
            %(path)s::TEXT, %(mtime)s::TIMESTAMPTZ, %(size)s::BIGINT,
            %(foundation)s::SMALLINT, %(stack)s::TEXT, %(authored)s::TEXT,
            %(touched)s::TEXT, %(why)s::TEXT, %(tracked)s::BOOLEAN,
            %(importance)s::SMALLINT),
        COALESCE(
            (SELECT row_hash FROM audit.file_change_history
              ORDER BY observed_at DESC, id DESC LIMIT 1),
            ''
        )
    ON CONFLICT (path, mtime) DO NOTHING
"""


def ingest(path_list_file: str, batch_size: int = 1000, skip_noise: bool = False) -> dict:
    """
    Read `path_list_file`, classify each line, insert each row into
    audit.file_change_history one-at-a-time so the hash chain links
    correctly. ON CONFLICT DO NOTHING handles dedup at the DB layer.

    NOTE: per-row insert is deliberate. Previous executemany approach
    caused all rows in a batch to see the same "previous row" when
    computing prev_row_hash, breaking the chain. One row at a time
    means each INSERT sees the row that was just committed before it.

    skip_noise : if True, importance-0 rows are filtered out before
                 insert (keeps the continuous-snapshot runs small by
                 dropping container-cow and browser-cache churn).
    """
    if not os.path.isfile(path_list_file):
        raise FileNotFoundError(path_list_file)

    examined = 0
    queued = 0
    conn = _pg_connect()
    try:
        cur = conn.cursor()
        with open(path_list_file, "r") as f:
            for line in f:
                p = line.strip()
                if not p:
                    continue
                examined += 1
                cls = classify(p)
                if cls is None:
                    continue
                if skip_noise and cls["importance"] == 0:
                    continue
                mt, sz = mtime_and_size(p)
                cur.execute(_INSERT_SQL, {
                    "path": p, "mtime": mt, "size": sz,
                    "foundation": cls["foundation"], "stack": cls["stack"],
                    "authored": cls["authored_by"], "touched": cls["touched_by"],
                    "why": cls["why"], "tracked": cls["tracked_in_git"],
                    "importance": cls["importance"],
                })
                queued += 1
        conn.commit()
    finally:
        conn.close()

    return {
        "source": path_list_file,
        "examined": examined,
        "queued_for_insert": queued,
        "skip_noise": skip_noise,
    }


def main() -> int:
    parser = argparse.ArgumentParser(prog="s7_audit_file_ingest")
    parser.add_argument("--source", default="/tmp/s7-audit-33h.txt")
    parser.add_argument("--skip-noise", action="store_true",
                        help="filter out importance=0 rows (container-cow, browser cache)")
    args = parser.parse_args()
    result = ingest(args.source, skip_noise=args.skip_noise)
    import json
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
