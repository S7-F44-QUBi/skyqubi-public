# S7 SkyQUB*i* — Public Deploy Lifecycle Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `skycair-code/SkyQUBi-public` fully deployable from a fresh clone — OCI image published, stack validated, every step tested and logged.

**Architecture:** Push pre-built admin OCI image to ghcr.io, validate full stack deploy from public repo, run test lifecycle with repair logging. No task repeats — each step validates forward, never re-does passing work.

**Tech Stack:** Podman, ghcr.io, Bash, Node.js 22, Python 3.11, AdonisJS, PostgreSQL 16, MySQL 8, Redis 7, Qdrant

---

## Phase 1: OCI Image

### Task 1.1: Update GitHub token with packages:write scope

**Files:**
- Modify: (browser action — github.com/settings/tokens)

- [ ] **Step 1:** Jamie updates token at github.com/settings/tokens — add `write:packages` scope
- [ ] **Step 2:** Re-authenticate: `gh auth login --with-token`
- [ ] **Step 3:** Verify: `gh api user/packages?package_type=container`

### Task 1.2: Tag and push admin image to ghcr.io

**Files:**
- No file changes — image operations only

- [ ] **Step 1: Tag the local image for ghcr.io**
```bash
podman tag localhost/s7-skyqubi-admin:v2.6 ghcr.io/skycair-code/s7-skyqubi-admin:v2.6
podman tag localhost/s7-skyqubi-admin:v2.6 ghcr.io/skycair-code/s7-skyqubi-admin:latest
```

- [ ] **Step 2: Login to ghcr.io**
```bash
gh auth token | podman login ghcr.io -u skycair-code --password-stdin
```

- [ ] **Step 3: Push the image**
```bash
podman push ghcr.io/skycair-code/s7-skyqubi-admin:v2.6
podman push ghcr.io/skycair-code/s7-skyqubi-admin:latest
```
Expected: Push completes, layers uploaded

- [ ] **Step 4: Make the package public**
```bash
gh api user/packages/container/s7-skyqubi-admin -X PATCH -f visibility=public
```

- [ ] **Step 5: Verify pull works**
```bash
podman pull ghcr.io/skycair-code/s7-skyqubi-admin:v2.6
```
Expected: Image pulls successfully

### Task 1.3: Update pod YAML to reference ghcr.io image

**Files:**
- Modify: `skyqubi-pod.yaml`

- [ ] **Step 1: Update image reference in pod YAML**
Change:
```yaml
image: localhost/s7-skyqubi-admin:v2.6
```
To:
```yaml
image: ghcr.io/skycair-code/s7-skyqubi-admin:v2.6
```

- [ ] **Step 2: Commit**
```bash
git add skyqubi-pod.yaml
git commit -m "deploy: OCI image on ghcr.io — public pull, no local build needed"
```

- [ ] **Step 3: Sync to public**
```bash
./s7-sync-public.sh
```

---

## Phase 2: Stack Validation

### Task 2.1: Fresh deploy from public repo (simulated)

**Files:**
- Test directory: `/tmp/s7-lifecycle-test/`

- [ ] **Step 1: Clone public repo to temp directory**
```bash
git clone https://github.com/skycair-code/SkyQUBi-public.git /tmp/s7-lifecycle-test
cd /tmp/s7-lifecycle-test
```

- [ ] **Step 2: Create .env.secrets from example**
```bash
cp .env.example .env.secrets
# Generate real passwords
python3 -c "
import secrets
subs = {
    'CHANGE_ME': lambda: secrets.token_urlsafe(32),
}
with open('.env.secrets') as f:
    content = f.read()
for placeholder, gen in subs.items():
    while placeholder in content:
        content = content.replace(placeholder, gen(), 1)
with open('.env.secrets', 'w') as f:
    f.write(content)
print('Secrets generated')
"
```

- [ ] **Step 3: Stop existing pod (if running)**
```bash
podman pod stop s7-skyqubi 2>/dev/null
podman pod rm s7-skyqubi 2>/dev/null
```

- [ ] **Step 4: Deploy from the cloned repo**
```bash
./start-pod.sh
```
Expected: Pod starts, all 5 containers created

- [ ] **Step 5: Validate all containers running**
```bash
podman ps --pod --format "table {{.Names}}\t{{.Status}}"
```
Expected: 6 lines (infra + 5 containers), all "Up"

### Task 2.2: Validate CWS Engine starts inside fresh deploy

- [ ] **Step 1: Check admin container logs**
```bash
podman logs s7-skyqubi-s7-admin 2>&1 | tail -15
```
Expected: "Uvicorn running on http://127.0.0.1:7077"

- [ ] **Step 2: Test CWS Engine status**
```bash
podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status
```
Expected: JSON with "engine": "S7 CWS Engine v2.5"

- [ ] **Step 3: Test auth enforcement**
```bash
podman exec s7-skyqubi-s7-admin curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:7077/route
```
Expected: 401 (or 403)

### Task 2.3: Validate all databases

- [ ] **Step 1: PostgreSQL**
```bash
podman exec s7-skyqubi-s7-postgres pg_isready
```
Expected: "accepting connections"

- [ ] **Step 2: MySQL**
```bash
podman exec s7-skyqubi-s7-mysql mysqladmin ping -u root -p<password>
```
Expected: "mysqld is alive"

- [ ] **Step 3: Redis**
```bash
podman exec s7-skyqubi-s7-redis redis-cli ping
```
Expected: PONG

- [ ] **Step 4: Qdrant**
```bash
podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:6333/healthz
```
Expected: "healthz check passed"

### Task 2.4: Validate Command Center UI

- [ ] **Step 1: Test HTTP response**
```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:57080/
```
Expected: 302

- [ ] **Step 2: Test app install API**
```bash
podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:57080/api/system/services
```
Expected: JSON array of services

### Task 2.5: Validate port security

- [ ] **Step 1: All S7 ports bound to localhost only**
```bash
ss -tlnp | grep -E "57080|57086|57090" | grep -v "127.0.0.1"
```
Expected: No output (nothing on 0.0.0.0)

---

## Phase 3: Testing — Full Lifecycle Log

### Task 3.1: Test log infrastructure

**Files:**
- Create: `/tmp/s7-lifecycle-test/test-lifecycle.log`

- [ ] **Step 1: Create test runner that logs every step**
```bash
#!/usr/bin/env bash
# S7 Lifecycle Test Runner
LOG="/tmp/s7-lifecycle-test/test-lifecycle.log"
PASS=0
FAIL=0

test_step() {
    local name="$1"
    local cmd="$2"
    local expect="$3"
    
    echo -n "[$name] " | tee -a "$LOG"
    result=$(eval "$cmd" 2>&1)
    if echo "$result" | grep -qi "$expect"; then
        echo "PASS" | tee -a "$LOG"
        ((PASS++))
    else
        echo "FAIL — got: $result" | tee -a "$LOG"
        ((FAIL++))
    fi
}

echo "=== S7 SkyQUBi Lifecycle Test — $(date) ===" | tee "$LOG"

# Pod
test_step "Pod running" "podman pod ps --format '{{.Status}}'" "Running"

# Containers
test_step "Admin up" "podman ps --format '{{.Names}}' | grep s7-admin" "s7-skyqubi-s7-admin"
test_step "MySQL up" "podman ps --format '{{.Names}}' | grep s7-mysql" "s7-skyqubi-s7-mysql"
test_step "Postgres up" "podman ps --format '{{.Names}}' | grep s7-postgres" "s7-skyqubi-s7-postgres"
test_step "Redis up" "podman ps --format '{{.Names}}' | grep s7-redis" "s7-skyqubi-s7-redis"
test_step "Qdrant up" "podman ps --format '{{.Names}}' | grep s7-qdrant" "s7-skyqubi-s7-qdrant"

# Services
test_step "CWS Engine" "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status" "CWS Engine"
test_step "PostgreSQL ready" "podman exec s7-skyqubi-s7-postgres pg_isready" "accepting"
test_step "MySQL alive" "podman exec s7-skyqubi-s7-mysql mysqladmin ping 2>&1" "alive"
test_step "Redis PONG" "podman exec s7-skyqubi-s7-redis redis-cli ping" "PONG"
test_step "Qdrant health" "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:6333/healthz" "passed"
test_step "Admin UI" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:57080/" "302"

# Auth
test_step "CWS auth enforced" "podman exec s7-skyqubi-s7-admin curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:7077/route" "401\|403\|422"

# Ports
test_step "57080 localhost only" "ss -tlnp | grep ':57080' | grep '127.0.0.1' | wc -l" "1"
test_step "57090 localhost only" "ss -tlnp | grep ':57090' | grep '127.0.0.1' | wc -l" "1"

echo "" | tee -a "$LOG"
echo "=== RESULTS: $PASS PASS / $FAIL FAIL ===" | tee -a "$LOG"
echo "=== Log: $LOG ===" | tee -a "$LOG"
```

- [ ] **Step 2: Run the test suite**
Expected: All PASS, 0 FAIL

- [ ] **Step 3: If any FAIL — repair and re-test only failed items**
Do NOT re-run passing tests. Fix the failure, re-test that single step, log the repair.

### Task 3.2: App install lifecycle test

- [ ] **Step 1: Install each app and log result**
```bash
for svc in s7_kiwix_server s7_flatnotes s7_cyberchef s7_kolibri; do
    echo "Installing $svc..." | tee -a "$LOG"
    result=$(podman exec s7-skyqubi-s7-admin curl -s -X POST http://127.0.0.1:57080/api/system/services/install \
        -H "Content-Type: application/json" \
        -d "{\"service_name\": \"$svc\"}")
    echo "$result" | tee -a "$LOG"
done
```

- [ ] **Step 2: Validate each app responds**
```bash
test_step "Kiwix" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8090/" "200"
test_step "CyberChef" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8100/" "200"
test_step "FlatNotes" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8200/" "200"
test_step "Kolibri" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8300/" "302"
```

- [ ] **Step 3: Validate all app ports are localhost only**
```bash
for port in 8090 8100 8200 8300; do
    test_step "Port $port localhost" "ss -tlnp | grep ':$port' | grep '127.0.0.1' | wc -l" "1"
done
```

### Task 3.3: Chat lifecycle test (Ollama + Carli)

- [ ] **Step 1: Verify Ollama running on host**
```bash
test_step "Ollama version" "curl -s http://127.0.0.1:57081/api/version" "version"
```

- [ ] **Step 2: Verify pod can reach Ollama**
```bash
test_step "Pod→Ollama" "podman exec s7-skyqubi-s7-admin curl -s http://host.containers.internal:57081/api/version" "version"
```

- [ ] **Step 3: Chat with Carli**
```bash
test_step "Carli responds" "podman exec s7-skyqubi-s7-admin curl -s -X POST http://127.0.0.1:57080/api/ollama/chat -H 'Content-Type: application/json' -d '{\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}],\"model\":\"s7-carli:0.6b\",\"stream\":false}'" "done"
```

### Task 3.4: Final report

- [ ] **Step 1: Generate lifecycle report**
```bash
echo "=== S7 SKYQUBI LIFECYCLE REPORT ===" | tee -a "$LOG"
echo "Date: $(date)" | tee -a "$LOG"
echo "Image: ghcr.io/skycair-code/s7-skyqubi-admin:v2.6" | tee -a "$LOG"
echo "Repo: skycair-code/SkyQUBi-public" | tee -a "$LOG"
echo "Deploy: PASS/FAIL" | tee -a "$LOG"
echo "Stack: PASS/FAIL" | tee -a "$LOG"
echo "Apps: PASS/FAIL" | tee -a "$LOG"
echo "Chat: PASS/FAIL" | tee -a "$LOG"
echo "Security: PASS/FAIL" | tee -a "$LOG"
```

- [ ] **Step 2: Commit test log to private repo**
```bash
cp "$LOG" /s7/skyqubi-private/docs/superpowers/plans/
cd /s7/skyqubi-private
git add docs/
git commit -m "test: lifecycle deployment validation — full report"
git push origin main
```
