# S7 Post-Demo Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the queued cleanup items from the 2026-04-12 evening session after Tonya + Trinity mobile approval, in priority order: site naming hygiene, evidence capture, pod security activation, and staged theme application.

**Architecture:** Site content edits go through the private repo and flow to public via `s7-sync-public.sh`'s whitelist-by-location phase-2 rsync. Desktop/system changes stay private-only. Every change is verified via curl/screenshot/lifecycle before declaring done. Nothing runs destructively; anything requiring sudo is staged and left for Jamie's explicit invocation.

**Tech Stack:** Bash, sed, chromium headless (flatpak, for screenshotting), gsettings (Budgie wallpaper), podman (pod restart), dconf (panel config), git with the existing two-phase sync script.

---

## File Structure

**Modified files:**
- `/s7/skyqubi-private/docs/public/index.html` — italic-i sweep; single file touched
- `/s7/skyqubi-private/evidence/2026-04-12/*.png` — new screenshots for the naming audit record

**No new files created** in this plan — everything either edits existing files or stages runtime operations.

**Files NOT touched** (explicit exclusions to prevent drift):
- Wix Custom Embeds (already live, don't re-inject)
- MemPalace memory files (already synced)
- Feature card copy on index.html (Tonya-approved, locked)
- `branding/apply-theme.sh` (staged already, sudo-run is blocked on Jamie)

---

## Task 1: Italic-*i* Sweep on Public Landing Page

**Why:** 12 occurrences of plain `QUBi` (without the italic `<em>i</em>` wrapper) violate `feedback_italic_i.md`: *"QUB\*i\*, SkyAV\*i\*, SkyQUANT\*i* must always render with italic `i` in all output."* The rule is canonical; the site is the most-seen surface; this is the highest-value naming fix tonight.

**Constraint:** `sed` must **not** touch `<code>`, `<pre>`, `<script>`, `<style>`, or URL strings. Scope is body prose only. Use Python for a safer structural pass.

**Files:**
- Modify: `/s7/skyqubi-private/docs/public/index.html`

**Steps:**

- [ ] **Step 1: Baseline the current state**

Run:
```bash
cd /s7/skyqubi-private
grep -oE 'QUBi|QUB<em>i</em>|QUB<em style[^>]*>i</em>' docs/public/index.html | sort | uniq -c
```
Expected before fix: approximately `12 QUBi`, `5 QUB<em>i</em>`, `2 QUB<em style...>i</em>` (total 19). Record the exact numbers for comparison.

- [ ] **Step 2: Write a Python pass that skips code/script/pre blocks**

Run this exact Python script (sed alone isn't safe for nested HTML contexts):

```python
python3 <<'PY'
import re, pathlib
p = pathlib.Path('docs/public/index.html')
src = p.read_text()

# Split the document into "skip-regions" (script/style/pre/code) and "prose"
# regions. Replace only inside prose regions.
SKIP_TAGS = ('script', 'style', 'pre', 'code')
pattern = re.compile(r'(<(' + '|'.join(SKIP_TAGS) + r')\b[^>]*>.*?</\2>)', re.S | re.I)

def fix_prose(text):
    # 1. Replace plain "QUBi" -> "QUB<em>i</em>" where 'i' isn't already italic.
    #    Negative lookahead: don't match QUB followed by <em>
    text = re.sub(r'QUBi(?!</em>)', 'QUB<em>i</em>', text)
    # 2. Same for SkyAVi and SkyQUANTi
    text = re.sub(r'SkyAVi(?!</em>)', 'SkyAV<em>i</em>', text)
    text = re.sub(r'SkyQUANTi(?!</em>)', 'SkyQUANT<em>i</em>', text)
    return text

parts = []
last = 0
for m in pattern.finditer(src):
    # prose before the skip block
    parts.append(fix_prose(src[last:m.start()]))
    # skip block unchanged
    parts.append(m.group(0))
    last = m.end()
# trailing prose
parts.append(fix_prose(src[last:]))
p.write_text(''.join(parts))
print('done')
PY
```

- [ ] **Step 3: Verify the sweep worked and didn't double-wrap**

Run:
```bash
grep -oE 'QUBi|QUB<em>i</em>|QUB<em><em>|QUBi</em>|SkyAVi|SkyAV<em>i</em>|SkyQUANTi|SkyQUANT<em>i</em>' docs/public/index.html | sort | uniq -c
```

Expected:
- Plain `QUBi`: **0** (down from 12)
- `QUB<em>i</em>`: **at least 17** (the new ones plus the pre-existing 5)
- Plain `SkyAVi`: **0**
- `SkyAV<em>i</em>`: **≥ N** (match whatever the pre-pass count was)
- Plain `SkyQUANTi`: **0**
- `SkyQUANT<em>i</em>`: **≥ 1**
- **No** `QUB<em><em>` (double-wrap bug — if any, stop and debug)
- **No** `QUBi</em>` stranded closing tags (tells you a replacement went wrong)

- [ ] **Step 4: Render the page headless and confirm italic renders visually**

Run:
```bash
flatpak run --filesystem=/tmp --filesystem=/s7/skyqubi-private io.github.ungoogled_software.ungoogled_chromium \
  --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=1440,900 --virtual-time-budget=15000 \
  --screenshot=/tmp/italic-sweep-verify.png \
  https://123tech.skyqubi.com/
```

Then use `Read` to view `/tmp/italic-sweep-verify.png`. Expected: S7 SkyQUB*i* in the hero, "SkyQUANT*i*" and "SkyAV*i*" in The Stack cards — every `i` in the QUB/SkyAV/SkyQUANT brand names rendered as italic gold. If any `i` renders upright instead of italic, grep for the exact surrounding context and fix manually.

- [ ] **Step 5: Commit in the private repo**

Run:
```bash
cd /s7/skyqubi-private
git add docs/public/index.html
git commit -m "site: italic-i sweep — QUBi / SkyAVi / SkyQUANTi consistency

Per feedback_italic_i.md rule: the trailing i in QUBi, SkyAVi,
SkyQUANTi must always render italic. This pass wraps the 12 plain
occurrences in <em>i</em>, leaving the pre-existing italicized
instances untouched.

Scoped via structural parse that skips <script>, <style>, <pre>,
and <code> blocks to avoid breaking code snippets."
```

- [ ] **Step 6: Sync to public and verify deploy**

Run:
```bash
./s7-sync-public.sh
```
Expected: commit pushed to public repo. Then poll GH Pages:
```bash
for i in $(seq 1 20); do
  sleep 1.5
  count=$(curl -sSL --max-time 6 https://123tech.skyqubi.com/ 2>/dev/null | grep -oE 'QUBi|QUB<em>i</em>' | sort | uniq -c | grep -v 'em' | awk '{print $1}')
  [ "${count:-12}" = "0" ] && echo "DEPLOYED" && break
done
```

- [ ] **Step 7: Run lifecycle**

Run:
```bash
./s7-lifecycle-test.sh 2>&1 | tail -4
```
Expected: `40/40 PASS — LIFECYCLE VERIFIED`.

---

## Task 2: Naming-Audit Screenshot Record

**Why:** Jamie asked for screenshots as part of the naming audit, but tonight's changes (menu simplification, Knowledge → Oz of Knowledge rename, Maps split) altered the end-user visuals. Capture the post-audit state so future sessions have a visual reference and Tonya/Trinity have something durable to review.

**Files:**
- Create: `/s7/skyqubi-private/evidence/2026-04-12/audit-site-hero.png` (desktop 1440×900)
- Create: `/s7/skyqubi-private/evidence/2026-04-12/audit-site-stack.png` (tall 1440×1800 for full Stack section)
- Create: `/s7/skyqubi-private/evidence/2026-04-12/audit-site-hero-mobile.png` (iPhone 13 390×844)

**Note on menu screenshots:** Capturing the live Budgie menu requires a running X/Wayland session with an interactive screenshot tool. There's no `gnome-screenshot` or `flameshot` installed. Two options:
1. Skip the menu screenshot (site screenshots are sufficient for the audit record)
2. Jamie takes the Budgie menu screenshot manually from his session and drops it in `evidence/2026-04-12/` — I commit it on next sync

Pick option 1 for now; Jamie can add the menu capture later if he wants.

**Steps:**

- [ ] **Step 1: Capture desktop hero**

Run:
```bash
cd /s7/skyqubi-private
OUT=/s7/skyqubi-private/evidence/2026-04-12/audit-site-hero.png
flatpak run --filesystem=/s7/skyqubi-private/evidence io.github.ungoogled_software.ungoogled_chromium \
  --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=1440,900 --virtual-time-budget=15000 \
  --screenshot="$OUT" "https://skyqubi.com/?t=$(date +%s)"
ls -la "$OUT"
```
Expected: PNG ~1.2-1.3 MB.

- [ ] **Step 2: Capture tall desktop for Stack section**

Run:
```bash
OUT=/s7/skyqubi-private/evidence/2026-04-12/audit-site-stack.png
flatpak run --filesystem=/s7/skyqubi-private/evidence io.github.ungoogled_software.ungoogled_chromium \
  --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=1440,1800 --virtual-time-budget=15000 \
  --screenshot="$OUT" "https://skyqubi.com/?t=$(date +%s)"
ls -la "$OUT"
```
Expected: PNG ~1.8-2.2 MB. Even at 1800px tall, the full Stack section may not be in the initial viewport — the capture is still useful but manually scrolling is more reliable.

- [ ] **Step 3: Capture mobile hero**

Run:
```bash
OUT=/s7/skyqubi-private/evidence/2026-04-12/audit-site-hero-mobile.png
flatpak run --filesystem=/s7/skyqubi-private/evidence io.github.ungoogled_software.ungoogled_chromium \
  --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=390,844 --virtual-time-budget=15000 \
  --screenshot="$OUT" "https://skyqubi.com/?t=$(date +%s)"
ls -la "$OUT"
```
Expected: PNG ~350-400 KB.

- [ ] **Step 4: Visually verify each PNG with Read tool**

Use the `Read` tool on each of the three PNG files. Verify:
- Hero shows italic gold `i` in "SkyQUB*i*"
- "YOUR AI · YOUR DATA · YOUR MACHINE" tagline is legible
- Nav shows 5 items: Architecture · Engine · Covenant · Chat · GitHub
- (Stack shot, if deep enough) shows SkyQUANT*i* card, MemPalace card, Memory Ledger card

If any screenshot is missing expected content, re-run with `--virtual-time-budget=30000` to give fonts more time to load.

- [ ] **Step 5: Commit**

Run:
```bash
cd /s7/skyqubi-private
git add evidence/2026-04-12/audit-*.png
git commit -m "evidence: post-audit naming state captures

Three screenshots after the italic-i sweep and menu simplification:
- audit-site-hero.png          1440×900 desktop hero
- audit-site-stack.png         1440×1800 full-page Stack section
- audit-site-hero-mobile.png   390×844 iPhone 13 portrait

Canonical reference for the post-Wix-go-live + post-naming-audit
visual state. Do not delete — Tonya/Trinity should be able to point
at these if asked 'what did the site look like on 04-12?'."
./s7-sync-public.sh
```

- [ ] **Step 6: Lifecycle**

Run:
```bash
./s7-lifecycle-test.sh 2>&1 | tail -4
```
Expected: `40/40 PASS`.

---

## Task 3: Restart `s7-skyqubi` Pod to Activate CodeQL Security Fixes

**Why:** Per `project_session_2026_04_12.md`: *"The running pod is on the OLD code — needs `podman pod restart s7-skyqubi` to pick up the fixes."* The fixes in commit `50a3776` hardened `bitnet_mcp.py` path injection and added a global exception handler to `s7_server.py`. These are already committed but not running. With Network Chuck traffic potentially inbound, the fixes should actually be loaded.

**Files:** None (runtime-only operation)

**Steps:**

- [ ] **Step 1: Pre-check — pod and container state**

Run:
```bash
podman pod ps
podman ps --all --format '{{.Names}} {{.Status}}' | grep s7-skyqubi
```
Expected: pod `s7-skyqubi` listed as `Running` with container count ≥ 4 (PG, Ollama, Qdrant, engine). If any container is already Exited, note which and include in restart check.

- [ ] **Step 2: Capture pre-restart health for baseline**

Run:
```bash
curl -sSL -o /dev/null -w "engine=%{http_code} " http://127.0.0.1:57088/health 2>&1
curl -sSL -o /dev/null -w "ollama=%{http_code} " http://127.0.0.1:57086/api/tags 2>&1
curl -sSL -o /dev/null -w "qdrant=%{http_code}\n" http://127.0.0.1:57090/collections 2>&1
```
Expected: all `200` (or equivalent success). If any fail pre-restart, the restart may surface a real bug — escalate.

- [ ] **Step 3: Restart the pod**

Run:
```bash
podman pod restart s7-skyqubi
```
Expected: exit 0, all containers restart in sequence. Takes ~15-30s.

- [ ] **Step 4: Wait for services to come back**

Run:
```bash
for i in $(seq 1 20); do
  sleep 1.5
  code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:57088/health 2>&1)
  echo "poll $i: engine=$code"
  [ "$code" = "200" ] && break
done
```
Expected: `engine=200` within 10-15 polls. If still failing at poll 20, run `podman logs s7-skyqubi-engine --tail 50` to investigate.

- [ ] **Step 5: Verify the CodeQL fixes are actually active**

The key test is the global exception handler on `s7_server.py`. Trigger an intentionally-bad request and confirm the response is generic, not a Python traceback:

```bash
# Intentional bad path to exercise the exception handler
curl -sSL http://127.0.0.1:57088/ -H 'X-Test-Exception: 1' -X POST --data-binary '@/dev/null' -w "\nHTTP %{http_code}\n" | head -20
```

Expected: a generic `{"error": "..."}` JSON response, **not** a Python traceback with file paths, line numbers, or stack frames. If you see a traceback, the fixes did not take effect and we need to check whether the pod is actually running the new image vs a stale tag.

- [ ] **Step 6: Run lifecycle against the refreshed pod**

Run:
```bash
cd /s7/skyqubi-private
./s7-lifecycle-test.sh 2>&1 | tail -8
```
Expected: `40/40 PASS`. Lifecycle exercises the pod endpoints and confirms nothing regressed.

---

## Task 4: Plymouth Boot Splash — Staged Apply *(BLOCKED on sudo)*

**Status:** The Plymouth theme files (`branding/plymouth/s7-qubi.script` with the new sandy-sunset palette) and the `branding/apply-theme.sh` installer are already committed. The install step requires root (writes to `/usr/share/plymouth/themes/s7-qubi/`, runs `dracut --force`) and a reboot to visually verify. **Jamie must invoke this step manually.**

**Files:** Already staged in `/s7/skyqubi-private/branding/` — no new files needed.

**Steps (for Jamie to run when ready — do not run as part of this plan):**

- [ ] **Step 1: Dry-run to preview changes**

```bash
cd /s7/skyqubi-private/branding
./apply-theme.sh
```
Expected: prints `[dry-run]` for every action. Verify the paths listed match your system.

- [ ] **Step 2: Apply with sudo**

```bash
sudo ./apply-theme.sh -y
```
Expected output: five phases complete, ending with `Theme applied. Reboot to see the new Plymouth splash.` Desktop wallpaper is re-applied here too as a sanity nudge.

- [ ] **Step 3: Reboot and verify**

```bash
sudo reboot
```
On boot you should see: sandy-sunset plum/wine gradient background (instead of the old blue), gold "S7 SkyQUB*i* — Sovereign Computing" tagline, gold italic "Protected by SkyAV*i*", lavender italic "Love is the architecture." at the foot, gold progress bar.

**If the boot splash shows the old blue theme after reboot**, the dracut rebuild didn't pick up the new theme. Recovery path: `sudo plymouth-set-default-theme -R s7-qubi` forces a re-rebuild.

**If boot shows a black screen or hangs at Plymouth**, you can still log in via VT (Ctrl+Alt+F3) and run `sudo plymouth-set-default-theme -R bgrt` to fall back to the default system theme, then we debug the script file.

---

## Task 5: Tri-Force Academy Decision *(BLOCKED on Jamie)*

**Status:** In the 2026-04-12 evening session, Jamie mentioned both "Tri-Force Academy" and "QUBi - Oz of Knowledge" as names for the education/learning surface. I implemented Oz of Knowledge as the rename of the existing `s7-skyqubi-knowledge.desktop` launcher. Unclear whether Tri-Force Academy is:

1. **Superseded** — same concept, Jamie iterated and landed on Oz of Knowledge → no action
2. **Separate** — Tri-Force Academy is a distinct educational component that still needs to be created → requires a new launcher + menu entry + site section
3. **Future** — queued for a later session

**Decision required from Jamie before this task can execute.**

**If separate:**

- [ ] **Step 1: Create a new launcher**

File: `/s7/.local/share/applications/s7-skyqubi-academy.desktop`
```
[Desktop Entry]
Version=1.0
Type=Application
Name=Tri-Force Academy
GenericName=S7 Learning Academy
Comment=S7 SkyQUBi — Training, education, and certification for the Covenant Witness System
Exec=xdg-open http://127.0.0.1:7080/academy
Icon=/s7/skyqubi-private/branding/icons/s7-shield-icon-256.png
Terminal=false
Categories=X-S7-SkyQUBi;
Keywords=SkyQUBi;Academy;Training;Education;Certification;Trinity;TriForce;S7;
StartupNotify=true
```

- [ ] **Step 2: Restart panel**
```bash
update-desktop-database ~/.local/share/applications/
nohup budgie-panel --replace >/dev/null 2>&1 &
```

- [ ] **Step 3: Verify entry appears under S7 SkyQUBi submenu** — open Budgie menu, browse Categories → S7 SkyQUBi, confirm "Tri-Force Academy" shows alongside the other 8 entries.

**If superseded or future:** No action. Delete this task and note the decision in memory.

---

## Waiting / Not in this plan

These items came up during the session but are explicitly **not** in scope for tonight:

- **GoDaddy API key** — Jamie said "saving for future". Deferred until the next session.
- **Google Workspace `info@skyqubi.com` catch-all forwarding** — Jamie said "ignore the email, just use all to go to omegaanswers@123tech.net". Contact routing is done via the site's mailto target; no Workspace work needed.
- **Budgie menu — category sidebar as default view** — minor UX polish, not blocking anything.
- **Wezterm as the right-of-clock panel terminal** (instead of kitty) — kitty works well with the new config; Wezterm swap is nice-to-have, not tonight.
- **Mail-enabled `info@skyqubi.com` mailbox creation** — same decision above; skipped.
- **Boot splash PNG asset regeneration** — the existing `watermark.png` and `logo.png` in `/usr/share/plymouth/themes/s7-qubi/` are still the blue-palette versions. The new `s7-qubi.script` background is correct but the raster watermark is drift. Staged for a future session when we regenerate from the palette source.

---

## Self-Review

**Spec coverage:** Every item in the session's post-demo conversation is mapped to a task or the Waiting list above:
- Italic-*i* sweep → Task 1 ✓
- Screenshots for naming audit → Task 2 ✓
- Security fixes activation → Task 3 ✓
- Boot splash apply → Task 4 (staged) ✓
- Tri-Force Academy → Task 5 (blocked on decision) ✓
- Email → Waiting ✓
- GoDaddy key → Waiting ✓
- Menu simplification → **already shipped tonight**, not in plan
- Wallpaper → **already shipped tonight**, not in plan
- Panel icons (left/right of clock) → **already shipped tonight**, not in plan

**Placeholder scan:** No "TBD", "fill in", or "similar to above" references. Every step has the exact bash command or Python script an engineer could paste.

**Type consistency:** N/A (this plan is config/content edits, not a code project with cross-task type relationships).

---

## Execution Handoff

**Plan complete.** Saved to `docs/internal/superpowers/plans/2026-04-12-post-demo-polish.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good for Tasks 1 and 2 which are self-contained file edits.

2. **Inline Execution** — I execute tasks in this session using `executing-plans`, with explicit checkpoints for review after Task 1 (italic sweep verification) and after Task 3 (pod restart health).

**My recommendation:** Inline execution for Tasks 1, 2, and 3 (I'm already in the context). Tasks 4 and 5 stay blocked until you give the respective unblock ("run the sudo apply", "Tri-Force decision"). Say which.
