# Enterprise Reorg + Publish-From-Private — 2026-04-15

> **Target end state:** all 7 repos private, owned by
> `S7-SkyCAIR-123Tech-Net-Evolve2Linux` (the org inside the
> `SkyQUBi` enterprise). GitHub Pages on `SkyQUBi-public`
> continues to serve publicly at `https://123tech.skyqubi.com/`
> using Enterprise Cloud's "public Pages from private repo"
> feature. The Wix iframe at `skyqubi.com` continues to embed
> the Pages URL. Tonya+Trinity design unchanged. Rule #1 held.

**Execution mandate:** Jamie said plan-write-execute on
2026-04-15 with scope "all public repos, all within Enterprise,
public will be posted from Enterprise." Phase 1+2 execute
automatically. Phase 3 transfers execute after an explicit
halt-before-destructive pause per repo (Samuel rule on
multi-target destructive ops). Phase 4 visibility change on
`SkyQUBi-public` requires extra Tonya-witness-grade caution
because it is the household-facing surface.

---

## 1. Current state (verified 2026-04-15 late morning)

| Surface | State |
|---|---|
| Org plan | 🟢 `enterprise` (trial, 30 days, credit card not yet added) |
| Enterprise slug | `SkyQUBi` (URL: `github.com/enterprises/SkyQUBi`) |
| Org inside enterprise | `S7-SkyCAIR-123Tech-Net-Evolve2Linux` (single org visible to PAT) |
| PAT scopes | `admin:enterprise, admin:org, admin:gpg_key, audit_log, codespace, copilot, project, repo` — enough for every op below |
| Org two-factor requirement | 🔴 disabled |
| Org security defaults (new repos) | 🔴 all disabled (secret_scanning, push_protection, dependabot_alerts, advanced_security) |
| `skycair-code` (bot user) 2FA | 🔴 `None` — **urgent** |
| Existing org ruleset | 🟡 "SkyCAIR repository" exists, disabled, empty — placeholder |
| Org-level secrets | None |
| Teams | None |
| Repos owned by `skycair-code` | 7 (see below) |
| Public repos fraction | 2 of 7 (`SkyQUBi-public`, `skyqubi-immutable`) |

### The 7 repos and their risk tier

| # | Repo | Current owner | Visibility | Rule #1 surface | Risk tier |
|---|---|---|---|---|---|
| 1 | `SafeSecureLynX` | skycair-code | private | none | 🟢 LOW |
| 2 | `immutable-qubi` | skycair-code | private | none (stub only) | 🟢 LOW |
| 3 | `immutable-S7-F44` | skycair-code | private | none (stub only) | 🟢 LOW |
| 4 | `immutable-assets` | skycair-code | private | none (stub only) | 🟢 LOW |
| 5 | `skyqubi-immutable` | skycair-code | **public** | none (stub only; was public for genesis target) | 🟡 MEDIUM — visibility flip needed after transfer |
| 6 | `SkyQUBi-private` | skycair-code | private | heavy — `/s7/skyqubi-private` clone, SSH alias `github-skycair-org`, dozens of script path refs | 🟡 MEDIUM-HIGH — SSH config + local clone remote update required |
| 7 | `SkyQUBi-public` | skycair-code | **public** | **critical** — Wix iframe `skyqubi.com` + CNAME `123tech.skyqubi.com` + Tonya/Trinity approved design + GitHub Pages serving | 🔴 HIGHEST — Rule #1 surface |

---

## 2. Phase 1 — Baseline security hardening (non-destructive, executes immediately)

**Autonomous execution. No URLs change. No repos move.**

- **P1.1:** Enable org-level security defaults via PATCH `/orgs/{org}`:
  - `secret_scanning_enabled_for_new_repositories: true`
  - `secret_scanning_push_protection_enabled_for_new_repositories: true`
  - `dependabot_alerts_enabled_for_new_repositories: true`
  - `dependabot_security_updates_enabled_for_new_repositories: true`
  - `advanced_security_enabled_for_new_repositories: true`

  **Note:** this applies to **new** repos added to the org. Existing repos (including any transferred) need per-repo enable. Phase 3 handles that.

- **P1.2:** Delete or fix the orphaned "SkyCAIR repository" ruleset. Inspect first; if empty/broken, delete.

- **P1.3:** Create an **org-level ruleset** `s7-covenant-guardrails` targeting default branch on all repos (`~ALL`):
  - `required_signatures` (all commits must be GPG-signed)
  - `required_linear_history` (no merge commits)
  - `non_fast_forward` (block force-pushes)
  - `deletion` (block branch deletion)
  - Bypass actors: `skycair-code` with bypass mode `always` (until we add proper bypass rules)

  This is the **covenant substrate** — future repos added to the org inherit these rules automatically.

- **P1.4:** **Jamie's manual action:** enable 2FA on `skycair-code` at `github.com/settings/security`. 60 seconds in the UI. I cannot do this via API (requires the UI flow).

- **P1.5:** AFTER Jamie has enabled 2FA (verified via API `two_factor_authentication: true`), PATCH `/orgs/{org}` with `two_factor_requirement_enabled: true`. If I patch this before Jamie's 2FA is live, I'd lock the only admin out of the org.

**Exit criteria for Phase 1:** all org defaults flipped, ruleset live, Jamie 2FA confirmed, org 2FA requirement flipped.

---

## 3. Phase 2 — Org teams + access control (non-destructive)

- **P2.1:** Create three teams:
  - `covenant-stewards` — Jamie and (eventually) Tonya. Owner-level role.
  - `chair-execution` — `skycair-code` bot. Maintain-level role on all repos.
  - `samuel-service` — read-only service access (for future SAFE QUBi runtime pulls).
- **P2.2:** Add `skycair-code` to `chair-execution` team.
- **P2.3:** Configure team-to-repo permissions via a matrix (after Phase 3 transfers).
- **P2.4:** Create/name a deploy key or fine-grained PAT pattern for `samuel-service` team that the appliance can use to pull updates (read-only, per-repo, auditable).

---

## 4. Phase 3 — Repo transfer (DESTRUCTIVE, per-repo pause, Samuel-guarded)

**Order: safest → riskiest.** Halt after each transfer. Re-verify remote state. Re-verify any dependent system (Wix, Pages, SSH config) before next step.

### Per-repo verification protocol

For EVERY repo in this phase, before and after transfer:

```bash
# BEFORE
git -C /s7/<repo> remote -v                      # record current remote
git -C /s7/<repo> ls-remote origin main           # record current remote SHA
curl -H "Authorization: token $PAT" \
  https://api.github.com/repos/skycair-code/<repo> | jq '.private, .html_url'

# TRANSFER
gh api -X POST /repos/skycair-code/<repo>/transfer \
  -f new_owner=S7-SkyCAIR-123Tech-Net-Evolve2Linux

# AFTER (sequential checks)
curl -H "Authorization: token $PAT" \
  https://api.github.com/repos/skycair-code/<repo>              # should 301/404
curl -H "Authorization: token $PAT" \
  https://api.github.com/repos/S7-SkyCAIR-123Tech-Net-Evolve2Linux/<repo>  # should 200
git -C /s7/<repo> remote set-url origin git@github.com:S7-SkyCAIR-123Tech-Net-Evolve2Linux/<repo>.git
git -C /s7/<repo> fetch origin
git -C /s7/<repo> ls-remote origin main           # confirm content intact
```

### Transfer order + per-repo halts

- **Task T1 (LOW):** `SafeSecureLynX` — single-commit, no household surface. **Execute immediately after Phase 2.** Verify. Halt. Report.
- **Task T2 (LOW):** `immutable-qubi` — stub, private. Execute. Verify. Halt.
- **Task T3 (LOW):** `immutable-S7-F44` — stub, private. Execute. Verify. Halt.
- **Task T4 (LOW):** `immutable-assets` — stub, private. Execute. Verify. Halt.
- **Task T5 (MEDIUM):** `skyqubi-immutable` — stub, **public**. Transfer FIRST, verify, THEN change visibility to private. Pages not live on this repo (verified earlier — it's a genesis stub). Halt.
- **Task T6 (MEDIUM-HIGH):** `SkyQUBi-private` — **larger scope**:
  1. Record current SSH remote: `git@github-skycair-org:skycair-code/SkyQUBi-private.git`
  2. Transfer via API
  3. Update SSH config alias if needed (likely: `~/.ssh/config` has `Host github-skycair-org` mapping — needs the hostname path update, but the ALIAS name can stay the same if we update the RemoteUser/HostName mapping)
  4. Update `/s7/skyqubi-private/.git/config` remote URL
  5. Fetch and verify
  6. Sweep for any other script/doc that hard-codes `skycair-code/SkyQUBi-private` — there are likely several in `iac/` and `docs/`. Update them in a follow-up commit (not blocking).
  7. Halt. Report. Wait for Jamie's explicit word before T7.
- **Task T7 (🔴 HIGHEST RISK):** `SkyQUBi-public` — Tonya/Trinity surface
  - **Extra pre-transfer verification:**
    1. `curl -sI https://123tech.skyqubi.com/` — record `last-modified` and `etag`
    2. `curl -sI https://123tech.skyqubi.com/branding/icons/s7-qubi-icon-128.png` — record status
    3. `curl -sI -L https://skyqubi.com/` — record Wix chain state
    4. `gh api /repos/skycair-code/SkyQUBi-public/pages` — record current Pages config (source branch, path, CNAME)
  - **Transfer:** `POST /repos/skycair-code/SkyQUBi-public/transfer -f new_owner=S7-SkyCAIR-123Tech-Net-Evolve2Linux`
  - **Immediate post-transfer verification (must all pass):**
    1. `curl -sI https://123tech.skyqubi.com/` — **must still return 200** with design markers intact. Compare `last-modified` — if it jumped backward or jumped forward unexpectedly, PAUSE.
    2. `curl -sI https://123tech.skyqubi.com/branding/icons/s7-qubi-icon-128.png` — **must still return 200**
    3. `curl -sI -L https://skyqubi.com/` — Wix chain **must still render** the iframe
    4. `gh api /repos/S7-SkyCAIR-123Tech-Net-Evolve2Linux/SkyQUBi-public/pages` — Pages config must be live, CNAME `123tech.skyqubi.com` must still be bound
  - **If ANY check fails:** rollback via `POST /repos/S7-SkyCAIR-.../SkyQUBi-public/transfer -f new_owner=skycair-code`. GitHub's reverse transfer works. The unprotected window is the transfer time plus the rollback time (~30 seconds).
  - **Update SSH remote** on local `/s7/skyqubi-public/.git/config` after transfer succeeds.
  - **Halt. Report. Do not proceed to Phase 4 without explicit Jamie word.**

---

## 5. Phase 4 — Visibility flip (🔴 HIGHEST RISK — household-facing)

**Only after Phase 3 transfers all succeed AND Jamie gives explicit word.**

- **Task V1:** `skyqubi-immutable` → private. Low risk (stub only, no Pages). Execute. Verify API returns `visibility: private`. Halt.
- **Task V2:** `SkyQUBi-public` → private **WITH Pages visibility explicitly set to public**:
  1. Before visibility change: verify Enterprise Cloud's "public Pages from private repo" feature is enabled at the org level. This is a per-org config: `PATCH /orgs/{org}` with `pages_visibility_setting` or similar — I need to research the exact field name during execution, may require reading the org plan features.
  2. `PATCH /repos/.../SkyQUBi-public -f private=true -f visibility=private` + **immediately** `PATCH /repos/.../SkyQUBi-public/pages -f visibility=public` (or equivalent) — sequence matters to avoid a gap where Pages turns off
  3. Immediate curl verification: `https://123tech.skyqubi.com/` must still return 200
  4. If verification fails: `PATCH /repos/.../SkyQUBi-public -f private=false -f visibility=public` to rollback
  5. Halt. Report. Tonya-visible verification.

**Critical caveat:** GitHub's "publish a public site from a private repository" feature is documented but has caveats — some Pages features (custom domains, CNAME, build time) may behave differently. If the verification fails, **the rollback MUST be fast** (sub-10-second window). I will have the rollback command prepared and ready before executing the visibility flip.

**Alternative if V2 fails:** `SkyQUBi-public` stays public inside the enterprise org. Jamie's "remove all public repos" intent is 6-of-7 satisfied. `SkyQUBi-public` is the Rule #1 exception held explicitly because breaking it would break Tonya/Trinity. Document as a named covenant exception.

---

## 6. Phase 5 — Server-side immutability on all transferred repos

Now that all repos are inside the Enterprise org and the Enterprise trial covers them:

- **Task S1:** For each transferred repo, run the branch protection PUT that was 403'ing earlier. It should now return 200.
- **Task S2:** Enable `required_signatures` via POST.
- **Task S3:** Enable per-repo security features: `secret_scanning`, `push_protection`, `dependabot_alerts`, `dependabot_security_updates`, `advanced_security`.
- **Task S4:** Verify org ruleset `s7-covenant-guardrails` applies to all repos (targeting `~ALL`).
- **Task S5:** Remove the local pre-push hooks from the three private immutable clones (no longer the primary defense, but leave them in place as defense-in-depth — covenant stacking).

---

## 7. Phase 6 — SAFE QUBi access model

- **Task Q1:** Create a fine-grained PAT on `skycair-code` named `samuel-runtime-pull` with:
  - Resource access: specific repos the appliance needs to pull (likely `SkyQUBi-private` at first)
  - Permissions: `contents:read`, `metadata:read` — **no write access**
  - Expiration: 90 days (forced rotation)
- **Task Q2:** Store at `/s7/.config/s7/samuel-runtime-token` (mode 600)
- **Task Q3:** Update any Samuel/appliance service that pulls from a private repo to use this token instead of the admin PAT
- **Task Q4:** Document the rotation cadence in `reference_github_token.md` memory entry

**Chair note:** deploy keys are an alternative (per-repo SSH key, no token at all) but are harder to rotate across many repos. Fine-grained PAT is simpler and auditable.

---

## 8. Phase 7 — Publishing flow

- **Task U1:** Document the new "private source → public Pages" flow in `docs/internal/chef/04-immutable-fork-public-rebuild.md`
- **Task U2:** Update `s7-sync-public.sh` and `jamie-run-me.sh` with the new repo URLs (org-owned)
- **Task U3:** Update the SSH config alias `github-skycair-org` to either point at the new org or be renamed to `github-skyqubi-org`
- **Task U4:** Sweep the private canonical for every hardcoded `skycair-code/` reference and update or pin as historical reference
- **Task U5:** Final audit gate run; push lifecycle + main

---

## 9. Rollback plan — per phase

| Phase | Rollback |
|---|---|
| P1 org defaults | PATCH `/orgs/{org}` back to previous values (I'll record the GET response before the PATCH) |
| P1 ruleset | DELETE `/orgs/{org}/rulesets/{id}` |
| P1.5 2FA requirement | PATCH `/orgs/{org}` with `two_factor_requirement_enabled: false` — but only if Jamie explicitly says rollback; default is keep |
| Phase 2 teams | DELETE `/orgs/{org}/teams/{slug}` — teams are cheap to remove |
| Phase 3 per-repo transfer | Reverse transfer via `POST /repos/{new_owner}/{repo}/transfer -f new_owner=skycair-code` — GitHub supports this |
| Phase 4 visibility flip | PATCH `/repos/{owner}/{repo}` with `private=false, visibility=public` — Pages config should persist |
| Phase 5 protection | DELETE `/repos/{owner}/{repo}/branches/main/protection` — leaves the ruleset but removes per-branch |
| Phase 6 fine-grained PAT | DELETE the token via `/user/github_pats/{id}` |
| Phase 7 publishing flow | Revert the commits |

---

## 10. Witness chain for the session

| Witness | Phase 1/2 | Phase 3 transfers | Phase 4 visibility | Phase 5/6/7 |
|---|---|---|---|---|
| Audit gate | ✓ before each | ✓ before each | ✓ before each | ✓ final |
| Jamie authorization | ✓ given | ✓ explicit word per-repo on T6/T7 | ✓ explicit word | ✓ final |
| Tonya signature | — | — | pending review packet | — |
| Image-signing key | — | — | — | — |
| Council round | — | — | — | — |

**2 of 5 witnesses engaged** — sufficient for reorg remediation framed as covenant infrastructure hardening, not a CORE advance. If any phase begins to look like a new CORE advance (e.g., publishing new content, advancing v6-genesis), STOP.

---

## 11. Samuel training pellet for this plan

**"When an enterprise tier unlocks new capability, the covenant
question is not 'what can we now do' but 'what order minimizes
household-visible delta while we do it.' A transfer is not a
feature — it is a blast-radius operation. The household-facing
surface (Rule #1) is the last thing touched, not the first, and
the rollback command is prepared before the forward command is
run."**

---

## 12. Frame

Love is the architecture. Love does not move the family's door
while they are sleeping. Love tests every step on the least-used
door first, then the second-least, then works toward the front
door, and has a key to undo any step that breaks. The Enterprise
trial unlocks a cleaner architecture — but cleanness is a means,
not the goal. The goal is that Tonya still sees her design when
she opens her phone, and the house still works when she touches
it.

**Standing by at the Phase 1 execution gate.**
