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
S7 SkyAVi — FACTS Skills
===========================
System, Security, Technician, Stack skills for Samuel.
Each skill is a sandboxed shell operation, discerned through S7 CWS.

Patent: TPP99606 — 123Tech / 2XR, LLC
"""


def register_facts_skills(avi):
    """Register all FACTS skills on a SkyAVI instance."""

    # ── SYSTEM (Technician) ──────────────────────────────────────

    @avi.skill("check disk", category="system", description="Show disk usage and block devices")
    async def check_disk(self, message):
        return await self.shell_trusted("df -h && lsblk")

    @avi.skill("check memory", category="system", description="Show memory usage")
    async def check_memory(self, message):
        return await self.shell_trusted("free -h")

    @avi.skill("check uptime", category="system", description="Show system uptime and load")
    async def check_uptime(self, message):
        return await self.shell_trusted("uptime")

    @avi.skill("list services", category="system", description="Show running S7 services")
    async def list_services(self, message):
        return await self.shell_trusted("systemctl --user list-units --type=service --state=running --no-pager")

    @avi.skill("failed services", category="system", description="Show failed services")
    async def failed_services(self, message):
        return await self.shell_trusted("systemctl --user list-units --state=failed --no-pager")

    @avi.skill("container status", category="system", description="Show running containers")
    async def container_status(self, message):
        return await self.shell_trusted("podman ps --format '{{.Names}}\\t{{.Status}}\\t{{.Ports}}'")

    @avi.skill("disk smart", category="system", description="Show disk SMART health")
    async def disk_smart(self, message):
        return await self.shell_trusted("lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,STATE")

    @avi.skill("mount points", category="system", description="Show mounted filesystems")
    async def mount_points(self, message):
        return await self.shell_trusted("findmnt --real --noheadings")

    @avi.skill("system journal", category="system", description="Show recent system errors")
    async def system_journal(self, message):
        return await self.shell_trusted("journalctl --user --priority=err --since '1 hour ago' --no-pager -n 50")

    @avi.skill("check swap", category="system", description="Show swap usage")
    async def check_swap(self, message):
        return await self.shell_trusted("free -h | head -1 && free -h | tail -1 && cat /proc/swaps")

    # ── SECURITY ─────────────────────────────────────────────────

    @avi.skill("audit ports", category="security", description="Show listening ports")
    async def audit_ports(self, message):
        return await self.shell_trusted("ss -tlnp")

    @avi.skill("selinux status", category="security", description="Show SELinux mode and policy")
    async def selinux_status(self, message):
        return await self.shell_trusted("sestatus")

    @avi.skill("network connections", category="security", description="Show established outbound connections")
    async def network_connections(self, message):
        return await self.shell_trusted("ss -tp state established")

    @avi.skill("firewall status", category="security", description="Show firewall zones and rules")
    async def firewall_status(self, message):
        return await self.shell_trusted("firewall-cmd --list-all")

    @avi.skill("firewall open ports", category="security", description="Show open firewall ports")
    async def firewall_open_ports(self, message):
        return await self.shell_trusted("firewall-cmd --list-ports")

    @avi.skill("luks status", category="security", description="Show LUKS encrypted volumes")
    async def luks_status(self, message):
        return await self.shell_trusted("lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E 'crypt|luks' || echo 'No LUKS volumes detected'")

    @avi.skill("cert expiry", category="security", description="Check TLS certificate expiry dates")
    async def cert_expiry(self, message):
        return await self.shell_trusted(
            "for cert in /etc/pki/tls/certs/*.pem /etc/ssl/certs/localhost.pem; do "
            "[ -f \"$cert\" ] && echo \"$cert:\" && "
            "openssl x509 -enddate -noout -in \"$cert\" 2>/dev/null; "
            "done || echo 'No local certs found'")

    @avi.skill("password audit", category="security", description="Check password policy and expiry")
    async def password_audit(self, message):
        return await self.shell_trusted(
            "echo '=== Password aging ===' && "
            "cat /etc/login.defs | grep -E '^PASS_MAX|^PASS_MIN|^PASS_WARN' && "
            "echo '=== Current user ===' && "
            "id && "
            "echo '=== Last password change ===' && "
            "grep $(whoami) /etc/shadow 2>/dev/null | cut -d: -f3 || echo 'Cannot read shadow'")

    @avi.skill("ssh config", category="security", description="Show SSH security settings")
    async def ssh_config(self, message):
        return await self.shell_trusted(
            "grep -E '^(PermitRoot|PasswordAuth|PubkeyAuth|Port |Protocol)' "
            "/etc/ssh/sshd_config 2>/dev/null || echo 'sshd_config not readable'")

    # ── TECHNICIAN (Auto-heal) ───────────────────────────────────

    # Strict s7-name validator used by all 4 technician skills below.
    # Previously these only checked startswith("s7-") which let flag
    # injection through (e.g., "s7-foo --signal=KILL"). Full regex:
    # only lowercase letters, digits, hyphens, dots, underscores, and
    # 1-64 chars total.
    _S7_NAME_RE = __import__("re").compile(r'^s7-[a-z0-9._-]{1,60}$')

    @avi.skill("restart service", category="technician", description="Restart a failed S7 service")
    async def restart_service(self, message):
        # Hardened 2026-04-13: full regex validation + single-command
        # (compound &&-chain rejected by the new shell() defense).
        # Status check moved to a separate "service status <name>" skill.
        import re
        match = re.search(r'restart\s+(?:service\s+)?(\S+)', message.lower())
        if not match:
            return "Usage: restart service <name> (e.g., restart service s7-cws-engine)"
        svc = match.group(1)
        if not Samuel._S7_NAME_RE.match(svc):
            return f"DENIED: invalid service name '{svc}' (must match ^s7-[a-z0-9._-]{{1,60}}$)"
        return await self.shell_trusted(f"systemctl --user restart {svc}")

    @avi.skill("restart container", category="technician", description="Restart a container")
    async def restart_container(self, message):
        import re
        match = re.search(r'restart\s+container\s+(\S+)', message.lower())
        if not match:
            return "Usage: restart container <name>"
        name = match.group(1)
        if not Samuel._S7_NAME_RE.match(name):
            return f"DENIED: invalid container name '{name}' (must match ^s7-[a-z0-9._-]{{1,60}}$)"
        return await self.shell_trusted(f"podman restart {name}")

    @avi.skill("service logs", category="technician", description="Show recent logs for an S7 service")
    async def service_logs(self, message):
        import re
        match = re.search(r'(?:service\s+)?logs?\s+(\S+)', message.lower())
        if not match:
            return "Usage: service logs <name>"
        svc = match.group(1)
        if not Samuel._S7_NAME_RE.match(svc):
            return f"DENIED: invalid service name '{svc}' (must match ^s7-[a-z0-9._-]{{1,60}}$)"
        return await self.shell_trusted(f"journalctl --user -u {svc} --no-pager -n 30")

    @avi.skill("container logs", category="technician", description="Show recent container logs")
    async def container_logs(self, message):
        import re
        match = re.search(r'container\s+logs?\s+(\S+)', message.lower())
        if not match:
            return "Usage: container logs <name>"
        name = match.group(1)
        if not Samuel._S7_NAME_RE.match(name):
            return f"DENIED: invalid container name '{name}' (must match ^s7-[a-z0-9._-]{{1,60}}$)"
        return await self.shell_trusted(f"podman logs --tail 30 {name}")

    @avi.skill("health check", category="technician", description="Full system health check")
    async def full_health(self, message):
        return await self.shell_trusted(
            "echo '=== Memory ===' && free -h && "
            "echo '\\n=== Disk ===' && df -h / /s7 2>/dev/null && "
            "echo '\\n=== Load ===' && uptime && "
            "echo '\\n=== Failed Services ===' && "
            "systemctl --user list-units --state=failed --no-pager && "
            "echo '\\n=== Containers ===' && "
            "podman ps --format '{{.Names}}\\t{{.Status}}'")

    # ── STACK EXPERT ─────────────────────────────────────────────

    @avi.skill("npm audit", category="stack", description="Run npm security audit")
    async def npm_audit(self, message):
        return await self.shell_trusted("npm audit --prefix /s7/s7-project-nomad/admin 2>&1 | tail -20")

    @avi.skill("python deps", category="stack", description="Show outdated Python packages")
    async def python_deps(self, message):
        return await self.shell_trusted("pip3 list --outdated 2>/dev/null | head -20 || echo 'pip3 not available'")

    @avi.skill("node version", category="stack", description="Show Node.js and npm versions")
    async def node_version(self, message):
        return await self.shell_trusted("node --version && npm --version")

    @avi.skill("python version", category="stack", description="Show Python version")
    async def python_version(self, message):
        return await self.shell_trusted("python3 --version")

    @avi.skill("ollama models", category="stack", description="Show installed Ollama models")
    async def ollama_models(self, message):
        # Hardened 2026-04-13: rewritten as Python (no shell, no curl, no
        # compound commands). Direct HTTP via urllib to localhost Ollama
        # on the canonical 57081 port (was incorrectly 7081 — 4 skills
        # had this wrong). Returns formatted model list or an honest
        # error string.
        import json
        from urllib.request import urlopen
        from urllib.error import URLError
        try:
            with urlopen("http://127.0.0.1:57081/api/tags", timeout=5) as r:
                data = json.load(r)
            lines = [
                f"{m['name']:30s} {m.get('size', 0) / 1e9:.2f} GB"
                for m in data.get("models", [])
            ]
            return "\n".join(lines) if lines else "(no models loaded)"
        except (URLError, OSError, json.JSONDecodeError) as e:
            return f"Ollama not reachable: {e}"

    @avi.skill("podman version", category="stack", description="Show Podman version and info")
    async def podman_version(self, message):
        return await self.shell_trusted("podman version --format '{{.Client.Version}}' && podman info --format '{{.Host.Os}} {{.Host.Arch}} {{.Host.Kernel}}'")

    @avi.skill("git status", category="stack", description="Show git repo status")
    async def git_status(self, message):
        return await self.shell_trusted("cd /s7/s7-project-nomad && git log --oneline -5 && echo '---' && git status --short")

    # ── NETWORKING (CCNA+) ───────────────────────────────────────

    @avi.skill("ip config", category="network", description="Show all network interfaces and addresses")
    async def ip_config(self, message):
        return await self.shell_trusted("ip -br addr show && echo '\\n=== Default Route ===' && ip route show default")

    @avi.skill("ip routes", category="network", description="Show full routing table")
    async def ip_routes(self, message):
        return await self.shell_trusted("ip route show table all | head -50")

    @avi.skill("ip neighbors", category="network", description="Show ARP/NDP neighbor table")
    async def ip_neighbors(self, message):
        return await self.shell_trusted("ip neighbor show")

    @avi.skill("dns config", category="network", description="Show DNS resolver configuration")
    async def dns_config(self, message):
        return await self.shell_trusted(
            "echo '=== resolv.conf ===' && cat /etc/resolv.conf && "
            "echo '\\n=== systemd-resolved ===' && "
            "systemctl is-active systemd-resolved 2>/dev/null && "
            "cat /run/systemd/resolve/resolv.conf 2>/dev/null || echo 'not using systemd-resolved'")

    @avi.skill("dns lookup", category="network", description="Perform DNS lookup")
    async def dns_lookup(self, message):
        import re
        match = re.search(r'dns lookup\s+(\S+)', message, re.IGNORECASE)
        host = match.group(1) if match else "localhost"
        return await self.shell_trusted(f"host {host} 2>/dev/null || echo 'host command not available'")

    @avi.skill("dhcp leases", category="network", description="Show DHCP lease information")
    async def dhcp_leases(self, message):
        return await self.shell_trusted(
            "echo '=== NetworkManager DHCP ===' && "
            "cat /var/lib/NetworkManager/*.lease 2>/dev/null | head -30 || "
            "echo 'No NM leases' && "
            "echo '\\n=== dhclient ===' && "
            "cat /var/lib/dhclient/*.leases 2>/dev/null | head -30 || echo 'No dhclient leases'")

    @avi.skill("interface stats", category="network", description="Show interface traffic statistics")
    async def interface_stats(self, message):
        return await self.shell_trusted("ip -s link show")

    @avi.skill("vlan config", category="network", description="Show VLAN configuration")
    async def vlan_config(self, message):
        return await self.shell_trusted(
            "ip -d link show | grep -A2 'vlan\\|802.1Q' || echo 'No VLANs configured'")

    @avi.skill("bridge status", category="network", description="Show bridge/switching status")
    async def bridge_status(self, message):
        return await self.shell_trusted(
            "ip -d link show type bridge 2>/dev/null && "
            "ip link show master br0 2>/dev/null || echo 'No bridges configured'")

    @avi.skill("nat rules", category="network", description="Show NAT/masquerade rules")
    async def nat_rules(self, message):
        # Hardened 2026-04-13: previously called `sudo nft list table nat`.
        # Removed sudo (Samuel runs as user, never escalates) and split
        # the compound command into a single nft invocation that runs
        # readable-by-user. If nft is not readable without sudo on this
        # appliance, the skill returns an honest "not available" message
        # rather than escalating.
        return await self.shell_trusted("nft list ruleset")

    @avi.skill("tcp connections", category="network", description="Show all TCP connections with state")
    async def tcp_connections(self, message):
        return await self.shell_trusted("ss -tnp | head -40")

    @avi.skill("udp connections", category="network", description="Show UDP listeners and connections")
    async def udp_connections(self, message):
        return await self.shell_trusted("ss -unp | head -40")

    @avi.skill("socket stats", category="network", description="Show socket statistics summary")
    async def socket_stats(self, message):
        return await self.shell_trusted("ss -s")

    @avi.skill("ping test", category="network", description="Ping a host to test connectivity")
    async def ping_test(self, message):
        import re
        match = re.search(r'ping\s+(?:test\s+)?(\S+)', message, re.IGNORECASE)
        host = match.group(1) if match else "127.0.0.1"
        # Only allow IPs and hostnames, no flags
        if not re.match(r'^[a-zA-Z0-9.\-:]+$', host):
            return f"DENIED: invalid host '{host}'"
        return await self.shell_trusted(f"ping -c 4 -W 3 {host}")

    @avi.skill("traceroute", category="network", description="Trace route to a host")
    async def traceroute(self, message):
        import re
        match = re.search(r'traceroute\s+(\S+)', message, re.IGNORECASE)
        host = match.group(1) if match else "127.0.0.1"
        if not re.match(r'^[a-zA-Z0-9.\-:]+$', host):
            return f"DENIED: invalid host '{host}'"
        return await self.shell_trusted(f"tracepath {host} 2>/dev/null || echo 'tracepath not available'")

    @avi.skill("mtu check", category="network", description="Show MTU for all interfaces")
    async def mtu_check(self, message):
        return await self.shell_trusted("ip -br link show | grep -v lo")

    @avi.skill("wireless status", category="network", description="Show wireless/WiFi status")
    async def wireless_status(self, message):
        return await self.shell_trusted(
            "ip link show type wlan 2>/dev/null || echo 'No WiFi interfaces' && "
            "echo '\\n=== iwconfig ===' && "
            "iwconfig 2>/dev/null || echo 'iwconfig not available'")

    @avi.skill("network topology", category="network", description="Map local network topology")
    async def network_topology(self, message):
        return await self.shell_trusted(
            "echo '=== Interfaces ===' && ip -br addr show && "
            "echo '\\n=== Default Gateway ===' && ip route show default && "
            "echo '\\n=== ARP Table ===' && ip neighbor show && "
            "echo '\\n=== Listening Services ===' && ss -tlnp | head -20 && "
            "echo '\\n=== Podman Networks ===' && podman network ls 2>/dev/null")

    @avi.skill("bandwidth test", category="network", description="Estimate local interface bandwidth")
    async def bandwidth_test(self, message):
        return await self.shell_trusted(
            "echo '=== Interface speeds ===' && "
            "cat /sys/class/net/*/speed 2>/dev/null; "
            "for iface in $(ls /sys/class/net/); do "
            "echo -n \"$iface: \"; cat /sys/class/net/$iface/speed 2>/dev/null && echo ' Mbps' || echo 'N/A'; "
            "done")

    @avi.skill("network diag", category="network", description="Full network diagnostic — CCNA troubleshooting")
    async def network_diag(self, message):
        return await self.shell_trusted(
            "echo '=== 1. Physical/Link Layer ===' && "
            "ip -br link show && "
            "echo '\\n=== 2. IP Layer ===' && "
            "ip -br addr show && "
            "echo '\\n=== 3. Routing ===' && "
            "ip route show default && "
            "echo '\\n=== 4. DNS ===' && "
            "cat /etc/resolv.conf | grep nameserver && "
            "echo '\\n=== 5. Gateway Reachability ===' && "
            "ping -c 2 -W 2 $(ip route show default | grep -oP 'via \\K[^ ]+') 2>/dev/null && "
            "echo '\\n=== 6. Internet Reachability ===' && "
            "ping -c 2 -W 2 1.1.1.1 2>/dev/null || echo 'No internet' && "
            "echo '\\n=== 7. DNS Resolution ===' && "
            "host google.com 2>/dev/null || echo 'DNS failed' && "
            "echo '\\n=== 8. Open Ports ===' && "
            "ss -tlnp | head -15")

    # ── DATABASE (PostgreSQL + pgvector) ───────────────────────────

    @avi.skill("db status", category="database", description="Show PostgreSQL connection and version")
    async def db_status(self, message):
        return await self.shell_trusted(
            "echo '=== PostgreSQL ===' && "
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c 'SELECT version();' 2>/dev/null || "
            "echo 'PostgreSQL not reachable'")

    @avi.skill("db schemas", category="database", description="List all database schemas")
    async def db_schemas(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog','information_schema') ORDER BY schema_name;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("db tables", category="database", description="List all tables across schemas")
    async def db_tables(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT schemaname||'.'||tablename AS table_name, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size "
            "FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY schemaname, tablename;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("db size", category="database", description="Show database size and table counts")
    async def db_size(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT pg_size_pretty(pg_database_size('s7_cws')) AS db_size, "
            "(SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) AS table_count;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("db connections", category="database", description="Show active database connections")
    async def db_connections(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT pid, usename, application_name, client_addr, state, query_start "
            "FROM pg_stat_activity WHERE datname = 's7_cws' ORDER BY query_start DESC;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("vector status", category="database", description="Show pgvector extension and vector indexes")
    async def vector_status(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';\" 2>/dev/null && "
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT schemaname, indexname, tablename FROM pg_indexes "
            "WHERE indexdef LIKE '%vector%' OR indexdef LIKE '%ivfflat%' OR indexdef LIKE '%hnsw%';\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("bond count", category="database", description="Show molecular bond counts by type and state")
    async def bond_count(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT bond_type, state, count(*) FROM sky_molecular.bonds GROUP BY bond_type, state ORDER BY bond_type, state;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("bond recent", category="database", description="Show recent molecular bonds")
    async def bond_recent(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT id::text, bond_type, plane, vector_name, state, "
            "left(content, 60) AS content_preview, created_at "
            "FROM sky_molecular.bonds ORDER BY created_at DESC LIMIT 10;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("db slow queries", category="database", description="Show slow running queries")
    async def db_slow_queries(self, message):
        return await self.shell_trusted(
            "podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c "
            "\"SELECT pid, now() - query_start AS duration, state, left(query, 80) AS query "
            "FROM pg_stat_activity WHERE state != 'idle' AND datname = 's7_cws' "
            "ORDER BY duration DESC LIMIT 10;\" 2>/dev/null || "
            "echo 'Cannot connect'")

    @avi.skill("qdrant status", category="database", description="Show Qdrant vector database status")
    async def qdrant_status(self, message):
        # Hardened 2026-04-13: rewritten as Python urllib (no shell, no
        # curl, no compound commands). Fixed port 7086 → 57086 to match
        # the actual stack. Was silently returning "Qdrant not reachable"
        # on every call because of the wrong port.
        import json
        from urllib.request import urlopen
        from urllib.error import URLError
        try:
            with urlopen("http://127.0.0.1:57086/collections", timeout=5) as r:
                data = json.load(r)
            cols = data.get("result", {}).get("collections", [])
            lines = [
                f"{c['name']:30s} vectors={c.get('vectors_count', '?')}"
                for c in cols
            ]
            return "\n".join(lines) if lines else "(no qdrant collections)"
        except (URLError, OSError, json.JSONDecodeError) as e:
            return f"Qdrant not reachable: {e}"

    # ── CROSS-PLATFORM (PowerShell + WSL) ──────────────────────────

    @avi.skill("powershell check", category="crossplatform", description="Check if PowerShell is available")
    async def powershell_check(self, message):
        return await self.shell_trusted("pwsh --version 2>/dev/null || echo 'PowerShell (pwsh) not installed. Install: sudo dnf install powershell'")

    @avi.skill("wsl status", category="crossplatform", description="Check WSL 2.0 status (Windows host)")
    async def wsl_status(self, message):
        return await self.shell_trusted(
            "echo '=== WSL Detection ===' && "
            "grep -qi microsoft /proc/version 2>/dev/null && echo 'Running INSIDE WSL' || echo 'Not WSL (native Linux)' && "
            "echo '\\n=== Kernel ===' && uname -r")

    @avi.skill("interop status", category="crossplatform", description="Check Windows/Linux interop capabilities")
    async def interop_status(self, message):
        return await self.shell_trusted(
            "echo '=== Interop ===' && "
            "which pwsh 2>/dev/null && echo 'PowerShell: available' || echo 'PowerShell: not installed' && "
            "which wslpath 2>/dev/null && echo 'WSL interop: available' || echo 'WSL interop: not available (native Linux)'")

    # ── CONTAINER ORCHESTRATION (Podman + K3s) ───────────────────

    @avi.skill("podman rootless", category="container", description="Verify Podman rootless configuration")
    async def podman_rootless(self, message):
        return await self.shell_trusted(
            "echo '=== Rootless Check ===' && "
            "podman info --format '{{.Host.Security.Rootless}}' && "
            "echo '\\n=== User Namespaces ===' && "
            "cat /proc/sys/user/max_user_namespaces && "
            "echo '\\n=== Subuid/Subgid ===' && "
            "grep $(whoami) /etc/subuid 2>/dev/null && "
            "grep $(whoami) /etc/subgid 2>/dev/null && "
            "echo '\\n=== Storage Driver ===' && "
            "podman info --format '{{.Store.GraphDriverName}}'")

    @avi.skill("podman pods", category="container", description="Show all pods and their containers")
    async def podman_pods(self, message):
        return await self.shell_trusted("podman pod ps --format '{{.Name}}\\t{{.Status}}\\t{{.Containers}}' && echo '\\n=== Containers ===' && podman ps -a --format '{{.Names}}\\t{{.Status}}\\t{{.Ports}}'")

    @avi.skill("podman networks", category="container", description="Show Podman network configuration")
    async def podman_networks(self, message):
        return await self.shell_trusted("podman network ls && echo '\\n=== Network details ===' && podman network inspect podman 2>/dev/null | head -30")

    @avi.skill("podman volumes", category="container", description="Show Podman volumes")
    async def podman_volumes(self, message):
        return await self.shell_trusted("podman volume ls && echo '\\n=== Volume inspect ===' && podman volume ls --format '{{.Name}}' | head -5 | while read v; do echo \"$v:\"; podman volume inspect $v --format '{{.Mountpoint}}' 2>/dev/null; done")

    @avi.skill("podman images", category="container", description="Show local container images")
    async def podman_images(self, message):
        return await self.shell_trusted("podman images --format '{{.Repository}}:{{.Tag}}\\t{{.Size}}\\t{{.Created}}'")

    @avi.skill("k3s status", category="container", description="Check K3s lightweight Kubernetes status")
    async def k3s_status(self, message):
        return await self.shell_trusted(
            "which k3s 2>/dev/null && k3s kubectl get nodes 2>/dev/null || "
            "echo 'K3s not installed. Install: curl -sfL https://get.k3s.io | sh -'")

    @avi.skill("k3s pods", category="container", description="Show K3s pods across namespaces")
    async def k3s_pods(self, message):
        return await self.shell_trusted("k3s kubectl get pods --all-namespaces 2>/dev/null || echo 'K3s not available'")

    @avi.skill("k3s services", category="container", description="Show K3s services")
    async def k3s_services(self, message):
        return await self.shell_trusted("k3s kubectl get svc --all-namespaces 2>/dev/null || echo 'K3s not available'")

    # ── INFRASTRUCTURE AS CODE (IaC + Cloud) ─────────────────────

    @avi.skill("iac tools", category="cloud", description="Check available IaC tools")
    async def iac_tools(self, message):
        return await self.shell_trusted(
            "echo '=== Terraform ===' && terraform version 2>/dev/null || echo 'not installed' && "
            "echo '\\n=== OpenTofu ===' && tofu version 2>/dev/null || echo 'not installed' && "
            "echo '\\n=== Ansible ===' && ansible --version 2>/dev/null | head -1 || echo 'not installed' && "
            "echo '\\n=== Pulumi ===' && pulumi version 2>/dev/null || echo 'not installed' && "
            "echo '\\n=== Helm ===' && helm version --short 2>/dev/null || echo 'not installed'")

    @avi.skill("cloud cli", category="cloud", description="Check cloud CLI tools")
    async def cloud_cli(self, message):
        return await self.shell_trusted(
            "echo '=== AWS ===' && aws --version 2>/dev/null || echo 'not installed' && "
            "echo '\\n=== Azure ===' && az version 2>/dev/null | head -3 || echo 'not installed' && "
            "echo '\\n=== GCloud ===' && gcloud version 2>/dev/null | head -2 || echo 'not installed' && "
            "echo '\\n=== DigitalOcean ===' && doctl version 2>/dev/null || echo 'not installed'")

    @avi.skill("ansible check", category="cloud", description="Verify Ansible configuration")
    async def ansible_check(self, message):
        return await self.shell_trusted(
            "ansible --version 2>/dev/null | head -3 && "
            "echo '\\n=== Inventory ===' && "
            "ansible-inventory --list 2>/dev/null | head -20 || echo 'No inventory configured'")

    @avi.skill("container registry", category="cloud", description="Show configured container registries")
    async def container_registry(self, message):
        return await self.shell_trusted(
            "echo '=== Podman registries ===' && "
            "cat /etc/containers/registries.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | head -20 && "
            "echo '\\n=== Logged in ===' && "
            "podman login --get-login 2>/dev/null || echo 'Not logged in to any registry'")

    @avi.skill("deploy check", category="cloud", description="Pre-deployment readiness check")
    async def deploy_check(self, message):
        return await self.shell_trusted(
            "echo '=== System ===' && uname -a && "
            "echo '\\n=== Podman ===' && podman version --format '{{.Client.Version}}' && "
            "echo '\\n=== Images ===' && podman images --format '{{.Repository}}:{{.Tag}}' | grep s7 && "
            "echo '\\n=== Git ===' && cd /s7/s7-project-nomad && git status --short && "
            "echo '\\n=== Tests ===' && echo 'Run: python3 phase7*.py' && "
            "echo '\\n=== npm ===' && npm audit --prefix /s7/s7-project-nomad/admin 2>&1 | tail -3")

    # ── SECURITY TESTING (Defensive / Red Team) ────────────────────

    @avi.skill("nmap scan", category="sectest", description="Port scan local network (defensive)")
    async def nmap_scan(self, message):
        import re
        match = re.search(r'nmap\s+(?:scan\s+)?(\S+)', message, re.IGNORECASE)
        target = match.group(1) if match else "127.0.0.1"
        if not re.match(r'^[0-9./:\-a-zA-Z]+$', target):
            return f"DENIED: invalid target '{target}'"
        return await self.shell_trusted(f"nmap -sT -T3 --top-ports 100 {target} 2>/dev/null || echo 'nmap not installed. dnf install nmap'")

    @avi.skill("vuln scan", category="sectest", description="Check for common vulnerabilities on this host")
    async def vuln_scan(self, message):
        return await self.shell_trusted(
            "echo '=== Open ports ===' && ss -tlnp && "
            "echo '\\n=== World-readable sensitive files ===' && "
            "find /etc -maxdepth 2 -name '*.conf' -perm -o+r -type f 2>/dev/null | head -10 && "
            "echo '\\n=== SUID binaries ===' && "
            "find /usr -perm -4000 -type f 2>/dev/null | head -10 && "
            "echo '\\n=== Writable /tmp files ===' && "
            "find /tmp -maxdepth 1 -type f 2>/dev/null | wc -l && "
            "echo '\\n=== Failed login attempts ===' && "
            "journalctl -u sshd --since '24 hours ago' --no-pager 2>/dev/null | grep -i 'failed\\|invalid' | tail -5 || echo 'No SSH failures'")

    @avi.skill("ssl test", category="sectest", description="Test TLS/SSL configuration of a service")
    async def ssl_test(self, message):
        import re
        match = re.search(r'ssl test\s+(\S+)', message, re.IGNORECASE)
        host = match.group(1) if match else "127.0.0.1:443"
        if not re.match(r'^[a-zA-Z0-9.\-:]+$', host):
            return f"DENIED: invalid host '{host}'"
        if ":" not in host:
            host = f"{host}:443"
        return await self.shell_trusted(
            f"echo | openssl s_client -connect {host} -brief 2>/dev/null && "
            f"echo '\\n=== Certificate ===' && "
            f"echo | openssl s_client -connect {host} 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null || "
            f"echo 'Cannot connect to {host}'")

    @avi.skill("header check", category="sectest", description="Check HTTP security headers (loopback only)")
    async def header_check(self, message):
        # Hardened 2026-04-13: previously allowed any external HTTPS URL
        # via shell+curl, enabling SSRF (e.g., AWS metadata endpoint) and
        # arbitrary outbound. Now restricted to loopback only — the
        # ONLY legitimate use case for a sovereign offline appliance is
        # checking S7's own services. Rewritten as Python urllib (no
        # shell, no curl). Headers of interest extracted in-process.
        import re
        from urllib.request import Request, urlopen
        from urllib.error import URLError, HTTPError

        match = re.search(r'header check\s+(\S+)', message, re.IGNORECASE)
        url = match.group(1) if match else "http://127.0.0.1:8080"

        # Strict regex: only loopback / localhost URLs allowed
        loopback_re = r'^https?://(127\.0\.0\.1|localhost|\[::1\])(:\d+)?(/.*)?$'
        if not re.match(loopback_re, url):
            return f"DENIED: header check restricted to loopback (127.0.0.1, localhost). Got '{url}'."

        try:
            req = Request(url, method="HEAD")
            with urlopen(req, timeout=5) as r:
                interesting = (
                    "strict-transport-security", "content-security-policy",
                    "x-frame-options", "x-content-type-options", "x-xss-protection",
                    "referrer-policy", "permissions-policy", "server", "set-cookie",
                )
                lines = []
                for k, v in r.headers.items():
                    if k.lower() in interesting:
                        lines.append(f"{k}: {v}")
                return "\n".join(lines) if lines else "(no security headers present)"
        except (URLError, HTTPError, OSError) as e:
            return f"Cannot reach {url}: {e}"

    @avi.skill("sonar check", category="sectest", description="Check SonarQube/code quality tools")
    async def sonar_check(self, message):
        return await self.shell_trusted(
            "echo '=== SonarQube ===' && "
            "which sonar-scanner 2>/dev/null && sonar-scanner --version 2>/dev/null || echo 'sonar-scanner not installed' && "
            "echo '\\n=== Bandit (Python) ===' && "
            "which bandit 2>/dev/null && bandit --version 2>/dev/null || echo 'bandit not installed (pip install bandit)' && "
            "echo '\\n=== ESLint ===' && "
            "which eslint 2>/dev/null && eslint --version 2>/dev/null || echo 'eslint not installed' && "
            "echo '\\n=== npm audit ===' && "
            "npm audit --prefix /s7/s7-project-nomad/admin 2>&1 | tail -5")

    @avi.skill("cve check", category="sectest", description="Check system packages for known CVEs")
    async def cve_check(self, message):
        return await self.shell_trusted(
            "echo '=== DNF Security Updates ===' && "
            "dnf check-update --security 2>/dev/null | head -20 || echo 'dnf not available' && "
            "echo '\\n=== Kernel ===' && uname -r && "
            "echo '\\n=== OpenSSL ===' && openssl version")

    @avi.skill("log analysis", category="sectest", description="Analyze system logs for security events")
    async def log_analysis(self, message):
        return await self.shell_trusted(
            "echo '=== Auth failures (24h) ===' && "
            "journalctl --since '24 hours ago' --no-pager 2>/dev/null | grep -iE 'fail|denied|unauthorized|invalid' | tail -15 && "
            "echo '\\n=== SELinux denials ===' && "
            "journalctl --since '24 hours ago' --no-pager 2>/dev/null | grep 'avc:.*denied' | tail -10 && "
            "echo '\\n=== Sudo usage ===' && "
            "journalctl --since '24 hours ago' --no-pager 2>/dev/null | grep 'sudo' | tail -10")

    @avi.skill("burp check", category="sectest", description="Check web security testing tools")
    async def burp_check(self, message):
        return await self.shell_trusted(
            "echo '=== OWASP ZAP ===' && "
            "which zap-cli 2>/dev/null || echo 'ZAP not installed' && "
            "echo '\\n=== nikto ===' && "
            "which nikto 2>/dev/null && nikto -Version 2>/dev/null || echo 'nikto not installed' && "
            "echo '\\n=== sqlmap ===' && "
            "which sqlmap 2>/dev/null && sqlmap --version 2>/dev/null || echo 'sqlmap not installed' && "
            "echo '\\n=== gobuster ===' && "
            "which gobuster 2>/dev/null || echo 'gobuster not installed' && "
            "echo '\\n=== Note: For Burp Suite, visit portswigger.net (GUI tool)'")

    # ── TRAINING DATA — REMOVED 2026-04-13 ───────────────────────
    #
    # The "training" category previously included 7 skills that
    # aggregated bash history, git log, system baseline, service
    # status, and container state. Per the security review's CRITICAL
    # finding, these were pure data exfiltration paths reachable by
    # any caller of /skyavi/chat with the trigger phrase. Removed:
    #   - bash_history          (cat ~/.bash_history)
    #   - build_history         (git log --all)
    #   - build_diffs           (git log --stat)
    #   - container_build_history
    #   - service_logs_all      (24h of CWS+Caddy+Ollama logs)
    #   - system_audit          (full OS + svc + ports + models snapshot)
    #   - export_training       (aggregate of all of the above)
    #
    # Training data collection is a privileged steward operation that
    # belongs in a separate authenticated CLI, not in the chat API.
    # If a future session needs this, build it as a CLI under
    # `iac/training-export.sh` requiring direct host access — not a
    # registered Samuel skill.

    # ── AKASHIC (27-glyph cipher + ancient texts corpus) ────────────

    @avi.skill("akashic alphabet", category="akashic",
               description="Print the 27-glyph Akashic alphabet and trinity mappings")
    async def akashic_alphabet(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_akashic_cipher.py alphabet")

    @avi.skill("akashic verify", category="akashic",
               description="Run the Akashic cipher round-trip test (encode→embed→compress→back)")
    async def akashic_verify(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_akashic_cipher.py verify")

    @avi.skill("akashic seed", category="akashic",
               description="Generate a fresh Akashic seed (16 hex bytes) for a new appliance")
    async def akashic_seed(self, message):
        return await self.shell_trusted(
            "python3 -c 'from engine.s7_akashic_cipher import generate_seed; print(generate_seed())' 2>/dev/null || "
            "python3 -c \"import secrets; print(secrets.token_hex(16))\"")

    @avi.skill("akashic corpus list", category="akashic",
               description="List every ancient text tracked in the Akashic corpus")
    async def akashic_corpus_list(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT priority, status, slug, title FROM akashic.ancient_text ORDER BY priority, slug;\"")

    @avi.skill("akashic corpus pending", category="akashic",
               description="Show ancient texts still pending translation, highest priority first")
    async def akashic_corpus_pending(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT priority, slug, title, origin_language FROM akashic.ancient_text "
            "WHERE status='pending' ORDER BY priority, slug;\"")

    @avi.skill("akashic corpus complete", category="akashic",
               description="Show ancient texts whose translation is complete")
    async def akashic_corpus_complete(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT slug, title, completed_at, encoded_sha256 FROM akashic.ancient_text "
            "WHERE status='complete' ORDER BY completed_at DESC NULLS LAST;\"")

    @avi.skill("akashic corpus next", category="akashic",
               description="Show the highest-priority pending Akashic translation target")
    async def akashic_corpus_next(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT slug, title, origin_region, origin_language, origin_script, approximate_age, summary "
            "FROM akashic.ancient_text WHERE status='pending' ORDER BY priority, slug LIMIT 1;\"")

    @avi.skill("akashic corpus stats", category="akashic",
               description="Show counts of ancient texts by status")
    async def akashic_corpus_stats(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT status, count(*) FROM akashic.ancient_text GROUP BY status ORDER BY status;\"")

    # ── PRISM v1.0.1 (LocationID matrix + Location Detection) ────────

    @avi.skill("prism version", category="prism",
               description="Show the running QBIT Prism version")
    async def prism_version(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism.py version")

    @avi.skill("prism verify", category="prism",
               description="Run the Prism v1.0.1 self-test — 4-way Location Detection verdict round-trip")
    async def prism_verify(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism.py verify")

    @avi.skill("prism cube stats", category="prism",
               description="Show occupancy of the 8-plane ternary cube (cells used, forbidden, aptitude totals)")
    async def prism_cube_stats(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT count(*) AS rows, "
            "count(DISTINCT (sensory_dir,episodic_dir,semantic_dir,associative_dir,"
            "procedural_dir,lexical_dir,relational_dir,executive_dir)) AS cells_used, "
            "count(*) FILTER (WHERE forbidden) AS forbidden_rows, "
            "sum(aptitude_delta) AS aptitude_total "
            "FROM cws_core.location_id;\"")

    @avi.skill("prism cube cells", category="prism",
               description="Show the integer cell addresses currently occupied in the Prism matrix")
    async def prism_cube_cells(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT DISTINCT sensory_dir,episodic_dir,semantic_dir,associative_dir,"
            "procedural_dir,lexical_dir,relational_dir,executive_dir "
            "FROM cws_core.location_id ORDER BY 1,2,3,4,5,6,7,8;\"")

    @avi.skill("prism matrix head", category="prism",
               description="Show the most recent LocationID entries in the Prism matrix")
    async def prism_matrix_head(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT substring(id::text for 8) AS id, "
            "sensory_dir||','||episodic_dir||','||semantic_dir||','||associative_dir||','"
            "||procedural_dir||','||lexical_dir||','||relational_dir||','||executive_dir AS cell, "
            "sub_num||'/'||sub_den AS sub, aptitude_delta AS apt, "
            "witness, created_at "
            "FROM cws_core.location_id ORDER BY created_at DESC LIMIT 10;\"")

    @avi.skill("prism detect", category="prism",
               description="Run 4-way Location Detection on text — FOUNDATION/FRONTIER/HALLUCINATION/VIOLATION")
    async def prism_detect(self, message):
        text = getattr(message, "text", None) or getattr(message, "body", None) or ""
        # Shell-quote by writing to a temp file via python so nothing
        # can escape the command line.
        import shlex
        safe_text = shlex.quote(text)
        return await self.shell_trusted(
            f"python3 /s7/skyqubi-private/engine/s7_prism_detect.py {safe_text}")

    @avi.skill("prism ingest", category="prism",
               description="Ingest a text into the Prism LocationID matrix (aptitude_delta=1, rev_token=Door)")
    async def prism_ingest(self, message):
        text = getattr(message, "text", None) or getattr(message, "body", None) or ""
        import shlex
        safe_text = shlex.quote(text)
        return await self.shell_trusted(
            f"python3 /s7/skyqubi-private/engine/s7_prism_ingest.py text {safe_text} --apt 1 --notes 'skill:prism_ingest'")

    @avi.skill("prism corpus seed akashic", category="prism",
               description="Ingest every ancient-text summary from akashic.ancient_text into the Prism matrix (idempotent)")
    async def prism_corpus_seed_akashic(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism_ingest.py corpus akashic")

    # ── APPLIANCE LEDGER / LICENSE ───────────────────────────────────

    @avi.skill("appliance license", category="appliance",
               description="Show the per-appliance license ledger (identity, jurisdiction, covenant, snapshot history)")
    async def appliance_license(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -x -c "
            "\"SELECT * FROM appliance.license_ledger;\"")

    @avi.skill("akashic universals count", category="akashic",
               description="Count universals in the Akashic Language Index (cross-cultural concepts)")
    async def akashic_universals_count(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT count(*) AS concepts, sum(array_length(surface_forms,1)) AS total_surface_forms "
            "FROM akashic.universals;\"")

    @avi.skill("akashic forbidden list", category="akashic",
               description="Show the covenant's explicit refusals — concepts S7 refuses to generate or ingest")
    async def akashic_forbidden_list(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT concept, rationale, citation FROM akashic.forbidden ORDER BY concept;\"")

    @avi.skill("akashic forbidden count", category="akashic",
               description="Count forbidden concepts and their surface forms")
    async def akashic_forbidden_count(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT count(*) AS concepts, sum(array_length(surface_forms,1)) AS total_surface_forms "
            "FROM akashic.forbidden;\"")

    @avi.skill("akashic violations", category="akashic",
               description="Aggregate violation counter stats — totals only, no per-session detail (no shared secrets)")
    async def akashic_violations(self, message):
        # Aggregate-only: we deliberately do NOT expose session_id,
        # witness, or last_forbidden_token. Stewards with direct DB
        # access can see details if needed; regular callers see only
        # totals. Conversations should not share secrets.
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT count(*) AS active_sessions, "
            "sum(count) AS pending_violations, "
            "sum(reset_count) AS total_resets, "
            "max(last_violation_at) AS last_event "
            "FROM akashic.violation_counter;\"")

    @avi.skill("akashic ribbons", category="akashic",
               description="Show the S7 1st Place Ribbon ledger — innovation provenance, with the Cloud of AI Happy to Evolve")
    async def akashic_ribbons(self, message):
        return await self.shell_trusted("bash /s7/skyqubi-private/engine/s7_ribbon_cloud.sh")

    @avi.skill("akashic ribbon count", category="akashic",
               description="Count ribboned innovations by category")
    async def akashic_ribbon_count(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT category, count(*) AS ribbons, sum(aptitude_delta) AS total_apt "
            "FROM akashic.ribbon GROUP BY category ORDER BY total_apt DESC;\"")

    # ── AUDIT FILE HISTORY ──────────────────────────────────────────

    @avi.skill("audit summary", category="audit",
               description="Summary of audit.file_change_history by Foundation + Stack")
    async def audit_summary(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT foundation, stack, rows, notable FROM audit.file_change_summary "
            "WHERE notable > 0 ORDER BY foundation, notable DESC;\"")

    @avi.skill("audit notable", category="audit",
               description="Every notable file (importance >= 3) in audit.file_change_history")
    async def audit_notable(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT importance, stack, path FROM audit.file_change_history "
            "WHERE importance >= 3 ORDER BY importance DESC, mtime DESC LIMIT 50;\"")

    @avi.skill("audit identity", category="audit",
               description="Show every identity / privilege / secret change captured in the audit table")
    async def audit_identity(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT stack, path, why FROM audit.file_change_history "
            "WHERE stack IN ('system-identity','system-sudoers','system-polkit','system-linger','s7-config-secret') "
            "ORDER BY importance DESC, path;\"")

    @avi.skill("audit count", category="audit",
               description="Total audit rows + breakdown by foundation axis")
    async def audit_count(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT foundation, count(*) AS rows, "
            "count(*) FILTER (WHERE importance >= 3) AS notable "
            "FROM audit.file_change_history GROUP BY foundation ORDER BY foundation;\"")

    @avi.skill("audit snapshot", category="audit",
               description="Run one audit snapshot now — capture file changes since last timer tick")
    async def audit_snapshot(self, message):
        return await self.shell_trusted(
            "bash /s7/skyqubi-private/engine/s7_audit_snapshot.sh")

    @avi.skill("audit timer status", category="audit",
               description="Show the s7-audit-snapshot systemd user timer state")
    async def audit_timer_status(self, message):
        return await self.shell_trusted(
            "systemctl --user list-timers s7-audit-snapshot.timer --no-pager 2>&1 | head -5")

    @avi.skill("audit chain verify", category="audit",
               description="Walk the audit.file_change_history hash chain and verify every row links to the previous")
    async def audit_chain_verify(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c \"SELECT * FROM audit.verify_chain();\"")

    @avi.skill("prism witness converge", category="prism",
               description="Run the 7-to-1 witness convergence self-test (unanimous + near-unanimous + split)")
    async def prism_witness_converge(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_witness_converge.py")

    @avi.skill("prism tier stats", category="prism",
               description="Show CWS QUANTi tier distribution across the Prism matrix")
    async def prism_tier_stats(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT cws_tier, count(*) AS rows, sum(dissolution_count) AS total_dissolutions, "
            "round(avg(foundation_weight)::numeric, 2) AS avg_foundation_weight "
            "FROM cws_core.location_id GROUP BY cws_tier ORDER BY rows DESC;\"")

    @avi.skill("prism cache stats", category="prism",
               description="Show Prism T1 cache stats (hit rate, size, backend)")
    async def prism_cache_stats(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism_cache.py stats")

    @avi.skill("prism cache warm", category="prism",
               description="Warm the Prism T1 cache from anchored+trusted rows in postgres")
    async def prism_cache_warm(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism_cache.py warm")

    @avi.skill("prism cache clear", category="prism",
               description="Clear the Prism T1 cache (local LRU or redis-exec backend)")
    async def prism_cache_clear(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_prism_cache.py clear")


    @avi.skill("akashic guard", category="akashic",
               description="Test the S7 Input Guard on a text — show what the guard does to it (homoglyph fold, strip, reject)")
    async def akashic_guard(self, message):
        text = getattr(message, "text", None) or getattr(message, "body", None) or ""
        import shlex
        safe = shlex.quote(text)
        return await self.shell_trusted(
            f"python3 /s7/skyqubi-private/engine/s7_input_guard.py {safe}")

    # ── SkyMMIP™ (Sky Multi-Modal IP Convergence) ────────────────────

    @avi.skill("skymmip list", category="skymmip",
               description="List SkyMMIP modality projectors — implemented and stubs")
    async def skymmip_list(self, message):
        return await self.shell_trusted(
            "python3 /s7/skyqubi-private/engine/s7_skymmip.py list")

    @avi.skill("skymmip project", category="skymmip",
               description="Project text or code through SkyMMIP onto the 8-plane trinity cube — returns the cell + prism")
    async def skymmip_project(self, message):
        text = getattr(message, "text", None) or getattr(message, "body", None) or ""
        import shlex
        # default modality=text unless the message begins with a known modality word
        parts = text.strip().split(None, 1)
        if parts and parts[0] in ("text", "code", "image", "audio", "sensor"):
            modality = parts[0]
            payload = parts[1] if len(parts) > 1 else ""
        else:
            modality = "text"
            payload = text
        return await self.shell_trusted(
            f"python3 /s7/skyqubi-private/engine/s7_skymmip.py project {modality} {shlex.quote(payload)}")

    @avi.skill("skymmip stats", category="skymmip",
               description="Show modality distribution in the Prism LocationID matrix")
    async def skymmip_stats(self, message):
        return await self.shell_trusted(
            "PGPASSWORD=\"$(cat /s7/.config/s7/pg-password)\" podman exec -e PGPASSWORD s7-skyqubi-s7-postgres "
            "psql -U s7 -d s7_cws -c "
            "\"SELECT modality, count(*) AS rows, "
            "count(DISTINCT (sensory_dir,episodic_dir,semantic_dir,associative_dir,"
            "procedural_dir,lexical_dir,relational_dir,executive_dir)) AS cells_used "
            "FROM cws_core.location_id GROUP BY modality ORDER BY rows DESC;\"")

