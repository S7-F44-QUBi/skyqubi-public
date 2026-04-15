# CHEF Recipe #1 — Living Audit Document

> **Living document.** Every run of `iac/audit/pre-sync-gate.sh`
> appends a dated entry below. The newest entry is at the top so the
> current state is always the first thing you see. The detailed
> per-run sections are the audit *trail*; the visual header at the
> top of each entry is the audit *verdict*.
>
> Read the top entry to know whether the household is clean *right
> now*. Scroll down to see how it got here. **An audit that doesn't
> persist is a story; an audit that persists is a witness.**

---

## 2026-04-15T18:30:51Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+68 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+68 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-183051.json`

---


## 2026-04-15T17:13:12Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+66 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+65 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-171312.json`

---


## 2026-04-15T16:06:23Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+62 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-160623.json`

---


## 2026-04-15T16:03:26Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+60 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-160326.json`

---


## 2026-04-15T15:40:59Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+58 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-154059.json`

---


## 2026-04-15T15:28:36Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 15 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (public/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable-assets/main) | matches pinned c922ccd |
| 🟢 PASS | A | 10 | Frozen tree (immutable-S7-F44/main) | matches pinned 921b39f |
| 🟢 PASS | A | 10 | Frozen tree (immutable-qubi/main) | matches pinned 060699e |
| 🟢 PASS | A | 10 | Frozen tree (SafeSecureLynX/main) | matches pinned d7cf668 |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-152836.json`

---


## 2026-04-15T08:00:25Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 15 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 5 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (public/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable-assets/main) | matches pinned c922ccd |
| 🟢 PASS | A | 10 | Frozen tree (immutable-S7-F44/main) | matches pinned 921b39f |
| 🟢 PASS | A | 10 | Frozen tree (immutable-qubi/main) | matches pinned 060699e |
| 🟢 PASS | A | 10 | Frozen tree (SafeSecureLynX/main) | matches pinned d7cf668 |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-080025.json`

---


## 2026-04-15T06:12:38Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 15 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (public/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable/main) | matches pinned 2e26698 |
| 🟢 PASS | A | 10 | Frozen tree (immutable-assets/main) | matches pinned c922ccd |
| 🟢 PASS | A | 10 | Frozen tree (immutable-S7-F44/main) | matches pinned 921b39f |
| 🟢 PASS | A | 10 | Frozen tree (immutable-qubi/main) | matches pinned 060699e |
| 🟢 PASS | A | 10 | Frozen tree (SafeSecureLynX/main) | matches pinned d7cf668 |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-061238.json`

---


## 2026-04-15T06:11:56Z — verdict: BLOCK 🔴

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 5 | 1 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+55 commits, ancestor intact) |
| 🔴 BLOCK | A | 10 | Frozen tree DIVERGED (public/main) | pinned=2e26698 actual=15c1bda — branch history rewritten or moved to sibling |
| 🟡 WARNING | A | 10 | Frozen tree (immutable/main) | could not read main in /s7/skyqubi-immutable |
| 🟡 WARNING | A | 10 | Frozen tree (immutable-assets/main) | could not read main in /s7/immutable-assets |
| 🟡 WARNING | A | 10 | Frozen tree (immutable-S7-F44/main) | could not read main in /s7/immutable-S7-F44 |
| 🟡 WARNING | A | 10 | Frozen tree (immutable-qubi/main) | could not read main in /s7/immutable-qubi |
| 🟡 WARNING | A | 10 | Frozen tree (SafeSecureLynX/main) | could not read main in /s7/SafeSecureLynX |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-061156.json`

---


## 2026-04-15T06:05:30Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+54 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+54 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-060530.json`

---


## 2026-04-15T05:57:44Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+54 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+54 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-055744.json`

---


## 2026-04-15T05:56:01Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+53 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+53 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-055601.json`

---


## 2026-04-15T05:47:22Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+52 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+52 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-054722.json`

---


## 2026-04-15T05:43:50Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 6 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-054350.json`

---


## 2026-04-15T05:40:49Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-054049.json`

---


## 2026-04-15T05:40:46Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+50 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-054046.json`

---


## 2026-04-15T05:36:12Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+48 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+48 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-053612.json`

---


## 2026-04-15T05:33:49Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+47 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+47 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-053349.json`

---


## 2026-04-15T05:29:34Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+46 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+46 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-052934.json`

---


## 2026-04-15T05:24:43Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+45 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+45 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-052443.json`

---


## 2026-04-15T05:21:57Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+44 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+44 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-052157.json`

---


## 2026-04-15T05:21:55Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+44 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+44 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-052155.json`

---


## 2026-04-15T05:20:23Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+43 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+43 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-052023.json`

---


## 2026-04-15T05:16:53Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+42 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+42 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-051653.json`

---


## 2026-04-15T05:10:36Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+41 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+41 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-051036.json`

---


## 2026-04-15T05:03:35Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+40 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+40 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-050335.json`

---


## 2026-04-15T04:44:36Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 10 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-044436.json`

---


## 2026-04-15T04:43:38Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 9 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-044338.json`

---


## 2026-04-15T04:41:00Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+39 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-044100.json`

---


## 2026-04-15T04:40:12Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+38 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+38 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-044012.json`

---


## 2026-04-15T04:14:38Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 6 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-041438.json`

---


## 2026-04-15T03:57:39Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-035739.json`

---


## 2026-04-15T03:57:37Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+37 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-035737.json`

---


## 2026-04-15T03:54:27Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+36 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+36 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-035427.json`

---


## 2026-04-15T03:54:25Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+36 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+36 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-035425.json`

---


## 2026-04-15T03:46:50Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+35 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+35 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-034650.json`

---


## 2026-04-15T03:45:28Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+34 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+34 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-034528.json`

---


## 2026-04-15T03:41:10Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+34 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+34 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-034110.json`

---


## 2026-04-15T03:40:59Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 8 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+33 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+33 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-034059.json`

---


## 2026-04-15T03:37:13Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+33 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+33 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-033713.json`

---


## 2026-04-15T03:30:24Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-033024.json`

---


## 2026-04-15T03:27:10Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-032710.json`

---


## 2026-04-15T03:27:01Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:57081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-032701.json`

---


## 2026-04-15T03:24:17Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 17 | 2 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟡 WARNING | A | 1 | Listening ports not in recipe | 39727 39731  |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟡 WARNING | A | 7 | New non-loopback bind(s) | *:57081  |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+32 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-032417.json`

---


## 2026-04-15T03:24:03Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 18 | 2 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟡 WARNING | A | 1 | Listening ports not in recipe | 39727 39731  |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟡 WARNING | A | 7 | New non-loopback bind(s) | *:57081  |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+31 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+31 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-032403.json`

---


## 2026-04-15T03:17:38Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+30 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+30 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-031738.json`

---


## 2026-04-15T03:16:34Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 10 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+28 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+28 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-031634.json`

---


## 2026-04-15T03:15:56Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 18 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 8 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+28 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+28 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (SafeSecureLynX/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-SafeSecureLynX-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-031556.json`

---


## 2026-04-15T02:25:06Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 7 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+27 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+27 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-022506.json`

---


## 2026-04-15T02:21:24Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 17 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+27 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+27 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-assets/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-assets-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-S7-F44/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-S7-F44-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable-qubi/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-qubi-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-022124.json`

---


## 2026-04-15T02:18:37Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 14 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 9 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+25 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+25 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 10 | Frozen tree (immutable/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-immutable-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-021837.json`

---


## 2026-04-15T02:18:21Z — verdict: BLOCK 🔴

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 1 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 8 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+25 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+25 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 🔴 BLOCK | A | 10 | Frozen tree (immutable/main) | PENDING but no pinned.yaml entry — add frozen-tree-immutable-main-pending or pin a real sha |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-021821.json`

---


## 2026-04-15T02:11:53Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+24 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+24 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-021153.json`

---


## 2026-04-15T01:55:16Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 8 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+23 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+23 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-015516.json`

---


## 2026-04-15T01:46:50Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+22 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+22 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-014650.json`

---


## 2026-04-15T01:39:09Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+21 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+18 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-013909.json`

---


## 2026-04-15T01:38:26Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+18 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+18 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-013826.json`

---


## 2026-04-15T01:21:41Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+17 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+14 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-012141.json`

---


## 2026-04-15T00:53:43Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+13 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+13 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-005343.json`

---


## 2026-04-15T00:53:22Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-005322.json`

---


## 2026-04-15T00:52:53Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 8 | 13 | 1 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟡 WARNING | A | 5 | Unrecognized outbound link(s) | http://www.w3.org  |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-005253.json`

---


## 2026-04-15T00:52:45Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 8 | 12 | 1 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟡 WARNING | A | 5 | Unrecognized outbound link(s) | http://www.w3.org  |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+12 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-005245.json`

---


## 2026-04-15T00:46:27Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 13 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+10 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+7 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |
| 📌 PINNED | C | 13 | PRISM/GRID/WALL integrity | reframe at JAMIE-APPROVED-PENDING-TONYA (pre-covenant, pending Tonya) |

Snapshot: `iac/audit/dist/20260415-004627.json`

---


## 2026-04-15T00:26:56Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+7 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+7 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260415-002656.json`

---


## 2026-04-15T00:16:54Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+6 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+6 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260415-001654.json`

---


## 2026-04-14T23:39:06Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+3 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+1 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-233906.json`

---


## 2026-04-14T23:30:20Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+2 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+1 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-233020.json`

---


## 2026-04-14T23:28:33Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:40:    shell=True is retained. The "would be injection if templated" |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 49af1f3 (+1 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 49af1f3 (+1 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-232833.json`

---


## 2026-04-14T23:03:55Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+16 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 1b6a2d7 (+32 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-230355.json`

---


## 2026-04-14T22:34:53Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+15 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 1b6a2d7 (+31 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-223453.json`

---


## 2026-04-14T21:38:39Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+12 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | fast-forward from pinned 1b6a2d7 (+28 commits, ancestor intact) |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-213839.json`

---


## 2026-04-14T21:38:10Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+11 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-213810.json`

---


## 2026-04-14T21:29:58Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+10 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-212958.json`

---


## 2026-04-14T21:29:52Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+9 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-212952.json`

---


## 2026-04-14T21:27:11Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+9 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-212711.json`

---


## 2026-04-14T21:26:32Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 12 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 5 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+8 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 📌 PINNED | A | 12 | Immutable registry | 0 entries (pre-ceremony, acknowledged) |

Snapshot: `iac/audit/dist/20260414-212632.json`

---


## 2026-04-14T21:26:07Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 10 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+8 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |
| 🟢 PASS | A | 12 | Immutable registry | 0 |

Snapshot: `iac/audit/dist/20260414-212607.json`

---


## 2026-04-14T21:08:02Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+6 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |

Snapshot: `iac/audit/dist/20260414-210802.json`

---


## 2026-04-14T21:06:48Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+6 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |

Snapshot: `iac/audit/dist/20260414-210648.json`

---


## 2026-04-14T21:06:11Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+5 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 8 orphan refs, incl: /s7/s7-project-nomad/skyqubi-pod.yaml /s7/skyqubi /s7/skyqubi/Caddyfile  |

Snapshot: `iac/audit/dist/20260414-210611.json`

---


## 2026-04-14T21:05:43Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 11 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+5 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |
| 📌 PINNED | A | 11 | Legacy-path service detection (acknowledged) | 12 orphan refs, incl: /s7/.ollama/models /s7/.podman-tmp /s7/.s7-chat-sessions  |

Snapshot: `iac/audit/dist/20260414-210543.json`

---


## 2026-04-14T20:59:08Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+4 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-205908.json`

---


## 2026-04-14T20:55:01Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+3 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-205501.json`

---


## 2026-04-14T20:51:29Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+3 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-205129.json`

---


## 2026-04-14T20:51:00Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+2 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-205100.json`

---


## 2026-04-14T20:46:53Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | fast-forward from pinned 85ba276 (+1 commits, ancestor intact) |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-204653.json`

---


## 2026-04-14T20:46:32Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | matches pinned 85ba276 |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-204632.json`

---


## 2026-04-14T20:44:57Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 2 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | matches pinned a3cc599 |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-204457.json`

---


## 2026-04-14T20:44:29Z — verdict: BLOCK 🔴

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 8 | 9 | 0 | 1 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🔴 BLOCK | A | 10 | Frozen tree mismatch (lifecycle) | pinned=1b0509a actual=a3cc599 — branch moved without authorization |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-204429.json`

---


## 2026-04-14T20:26:37Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 10 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 5 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | matches pinned 1b0509a |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 📌 PINNED | A | 10 | Frozen tree (public/main) | PENDING — acknowledged via pinned.yaml (frozen-tree-public-main-pending) |

Snapshot: `iac/audit/dist/20260414-202637.json`

---


## 2026-04-14T20:26:22Z — verdict: BLOCK 🔴

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 9 | 9 | 0 | 1 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |
| 🟢 PASS | A | 10 | Frozen tree (lifecycle) | matches pinned 1b0509a |
| 🟢 PASS | A | 10 | Frozen tree (private/main) | matches pinned 1b6a2d7 |
| 🔴 BLOCK | A | 10 | Frozen tree (public/main) | PENDING but no pinned.yaml entry — add frozen-tree-public-main-pending or pin a real sha |

Snapshot: `iac/audit/dist/20260414-202622.json`

---


## 2026-04-14T20:00:24Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 8 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-200024.json`

---


## 2026-04-14T20:00:09Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 3 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-200009.json`

---


## 2026-04-14T19:59:11Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 6 | 9 | 1 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟡 WARNING | A | 5 | Unrecognized outbound link(s) | https://bford.info https://docs.pytest.org  |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-195911.json`

---


## 2026-04-14T19:58:59Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 6 | 9 | 1 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟡 WARNING | A | 5 | Unrecognized outbound link(s) | https://bford.info https://docs.pytest.org  |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-195859.json`

---


## 2026-04-14T19:56:12Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 8 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-195612.json`

---


## 2026-04-14T19:53:23Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 8 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-195323.json`

---


## 2026-04-14T19:42:51Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-194251.json`

---


## 2026-04-14T19:42:13Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 1 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-194213.json`

---


## 2026-04-14T19:41:07Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 8 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-194107.json`

---


## 2026-04-14T19:32:08Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 6 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-193208.json`

---


## 2026-04-14T19:31:31Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 6 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-193131.json`

---


## 2026-04-14T19:28:08Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 6 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-192808.json`

---


## 2026-04-14T19:23:05Z — verdict: PASS 🟢

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 7 | 9 | 0 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟢 PASS | A | 5 | Outbound links | all links resolve to the approved domain set |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-192305.json`

---


## 2026-04-14T19:22:48Z — verdict: WARNING 🟡

| | Pass | Pinned | Warning | Block |
|---|---|---|---|---|
| count | 6 | 9 | 1 | 0 |

### Findings

| Status | Axis | Zero | Title | Detail |
|---|---|---|---|---|
| 🟢 PASS | A | 1 | Inconsistencies | every listening port is named in the recipe |
| 🟢 PASS | A | 2 | Public repo clean | 0 uncommitted changes |
| 📌 PINNED | A | 2 | Private repo has work-in-progress | 4 uncommitted changes (expected on lifecycle) |
| 📌 PINNED | A | 3 | shell=True (acknowledged) | /s7/skyqubi-private/engine/s7_skyavi_monitors.py:37:            command, shell=True, capture_output=True, text=True, |
| 🟢 PASS | A | 4 | Secrets in tracked files | 0 hits |
| 🟡 WARNING | A | 5 | Unrecognized outbound link(s) | http://127.0.0.1  |
| 📌 PINNED | A | 6 | DNS resolver 192.168.1.1 (acknowledged) | expected 9.9.9.9 per project_security_model.md |
| 🟢 PASS | A | 7 | Non-loopback binds | all accounted for (sshd, LLMNR, pinned: Ollama, Caddy) |
| 📌 PINNED | A | 7 | Ollama *:7081 | wildcard bind (acknowledged) |
| 📌 PINNED | A | 7 | Caddy *:8080 | wildcard bind (acknowledged) |
| 🟢 PASS | A | 8 | Process owners | all accounted for |
| 📌 PINNED | B | 9 | bandit missing | install during next Core Update window |
| 📌 PINNED | B | 9 | shellcheck missing | install during next Core Update window |
| 📌 PINNED | B | 9 | gitleaks missing | install during next Core Update window |
| 📌 PINNED | B | 9 | pip-audit missing | install during next Core Update window |
| 🟢 PASS | B | 9 | trivy available | vuln scan tool present |

Snapshot: `iac/audit/dist/20260414-192248.json`

---


