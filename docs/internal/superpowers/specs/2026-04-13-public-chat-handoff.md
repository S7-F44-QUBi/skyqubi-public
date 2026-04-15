---
name: Public chat demo-fake handoff plan
description: Spec for replacing the current public-chat/app.py 'demo fake' Wix-embedded widget with the covenant-honoring persona-chat substrate, gated on Tonya's design approval. Flagged 2026-04-13; NOT actioned this block because Tonya's approved landing page design is canonical.
type: project
---

# Public chat demo-fake handoff plan

**Date:** 2026-04-13
**Status:** Plan only. Gated on Tonya's design approval review.
**Do NOT execute without Tonya's explicit sign-off.**

---

## Context — what "demo fake" means

Jamie called it out on 2026-04-13:
*"NO PUBLIC chat that is a demo fake on website"*

The current website architecture:

1. **`skyqubi.com`** — Wix page. Tonya-approved design (see
   `feedback_tonya_design_approved.md`).
2. **Wix embeds an iframe** of `123tech.skyqubi.com` inside
   skyqubi.com.
3. **`123tech.skyqubi.com`** is served via GitHub Pages from the
   public repo's `docs/index.html`.
4. **`docs/index.html` includes a chat widget** that fetches from
   `public-chat/app.py` running on port `:57088` on Jamie's laptop.
5. **`public-chat/app.py`** is a STATELESS FastAPI proxy — explicit
   comment in the source says: *"It does NOT use the CWS Engine. It
   does NOT access MemPalace or molecular bonds. It does NOT log or
   store conversations. It is NOT 'Carli' in the covenant sense —
   it is a public demo."*

The "demo fake" is accurate: visitors think they're chatting with
S7's AI, but they're chatting with a stateless qwen2.5:3b via a thin
proxy with none of the covenant machinery behind it. No Carli/Elias/
Samuel personas. No Bible-Code review. No MemPalace. No witness
consensus. It's a demo widget for the landing page, not the real
product.

Jamie wants this replaced eventually. Today's restriction is the
Tonya-approved-design gate — we can't change the iframe source or
the widget embed without her seeing + approving the new look.

---

## What the real chat looks like (built, not yet wired to the website)

The covenant-honoring persona chat substrate, committed 2026-04-13
under `persona-chat/`:

- **`persona-chat/app.py`** — FastAPI service on port `:57089`
- **`persona-chat/ledger.py`** — hash-chained append-only turn ledger
  (one NDJSON file per persona per session)
- **`persona-chat/memory_tiers.py`** — L1/L2/L3 QBIT-budget context
  walk with ForToken 3× multiplier
- **`persona-chat/qbit_count.py`** — QBIT unit boundary helpers
- **`persona-chat/persona_engine_map.yaml`** — closed persona set
  (carli/elias/samuel) → engine routing config

State of readiness:

| Piece | Status |
|---|---|
| Per-persona rooms in per-user sessions | ✅ implemented |
| Cross-persona read (Samuel sees Carli's turns in same session) | ✅ implemented |
| L1 (333 QBITs) / L2 (777 QBITs) budget enforcement | ✅ implemented |
| ForToken 3× expansive context lookahead | ✅ implemented |
| Hash-chained ledger with quarantine-on-tamper | ✅ implemented + 37/37 tests pass |
| `/persona/chat` endpoint serving real Ollama responses | ✅ implemented |
| Samuel + Carli + Elias reachable as personas | ✅ all three built (Modelfile.samuel v2, Modelfile.elias v2, Modelfile.carli) |
| MemPalace / postgres integration | ❌ stubbed — waits for MemPalace migration path (2026-07-07 target) |
| RevToken plane/location/trinity predictions | ❌ stubbed — needs pod's cws_core.location_id |
| L3 long-term semantic search | ❌ stubbed — needs qdrant wiring |
| Wired into the website iframe | ❌ NOT DONE — gated on Tonya signoff |

The substrate works end-to-end today for a single-turn chat against
any of the three personas, with persistent per-session memory via
the local NDJSON ledger. What's missing for the public site is the
HTML glue + Tonya's design review.

---

## Three handoff options for Tonya

### Option A — "Coming soon" placeholder (smallest design drift)

Replace the current chat widget section in `docs/index.html` with a
static "Coming soon" card. Same styling, same location, no iframe
call to `:57088`. No chat functionality at all until Release 7.

**Tonya-impact:** visual change only — the chat section becomes a
placeholder. Same fonts, same colors, same layout grid.

**Pros:** zero demo-fake accusations. Honest. Easy for Tonya to
approve (minimal visual change).

**Cons:** the landing page loses its interactive demo. Visitors
have nothing to click.

### Option B — Full persona-chat widget swap

Replace the current chat widget with an embed that calls the new
`persona-chat/app.py` service on port `:57089`. Add persona selector
(Carli / Elias / Samuel radio buttons). Maintain session across
persona switches (the substrate supports this natively).

**Tonya-impact:** visible new UI — persona selector, session
persistence indicator, covenant-style status badges ("Samuel —
standard", "Samuel — witness offline", etc.). Significant visual
change.

**Pros:** the real product lands on the landing page. Visitors get
to chat with actual Carli/Elias/Samuel via the covenant substrate.
Brand promise kept.

**Cons:** persona-chat service needs to be publicly accessible
(tunnel via Cloudflared or similar — adds infrastructure). Needs
Tonya to see + approve the new UI. The L3/MemPalace/Witness
features are stubbed so the chat is less rich than the full
production target.

### Option C — Hybrid: keep public-chat as the demo, mark it clearly

Leave `public-chat/app.py` running but update the landing page's
chat widget to label it clearly: *"This is a demo of the S7
assistant. The full covenant chat with Samuel is available in the
desktop QUBi appliance."*

**Tonya-impact:** add a small disclaimer banner above the chat
widget. Minimal visual change, one new text element.

**Pros:** removes the "demo fake" dishonesty by being explicit.
Keeps the interactive widget. Lowest effort change.

**Cons:** still doesn't give visitors the real product on the
landing page. But nobody is misled about what they're seeing.

---

## Recommendation

**For immediate Tonya review: Option C.**

It's the smallest change (one disclaimer banner), it resolves the
"demo fake" honesty issue (visitors know they're seeing a demo),
and it preserves the full Tonya-approved visual design of the
landing page. The widget still works, visitors can still interact,
but the label is accurate.

**For GOLIVE Release 7: Option B** — full persona-chat widget, with
Tonya having signed off on the new UI during the run-up to the
2026-07-07 release. This is the real product landing on the real
landing page.

**Option A stays as a fallback** if Option B's Cloudflared tunnel
or persona-chat public access has security/infrastructure issues
that can't be resolved by GOLIVE.

---

## Text-only draft for Option C disclaimer banner

Place ABOVE the chat widget in the landing page HTML:

```html
<div class="chat-demo-notice">
  This is a public demo of the S7 assistant, running as a stateless
  proxy on Jamie's laptop. The full covenant chat — with Carli,
  Elias, and Samuel personas, MemPalace memory, and Bible-Code
  verdict review — is available in the desktop QUBi appliance.
  <a href="https://github.com/skycair-code/SkyQUBi-public">Run your
  own QUBi &rarr;</a>
</div>
```

CSS would match the existing Tonya-approved palette (Sandy sunset +
twilight purple + Cormorant italic). Banner goes above the iframe
embed, same container width as the chat box, with a soft gradient
background pulled from the existing design tokens.

---

## What's specifically NOT touched in this plan

- **Tonya's approved Wix landing page** — `feedback_tonya_design_approved.md`
  says "canonical, do not drift without her say-so." This plan
  doesn't drift; it proposes options Tonya can review.
- **The iframe mechanism itself** — Wix still embeds
  `123tech.skyqubi.com` via Custom Embed; only the content inside
  that iframe might change in Option C (add banner) or Option B
  (replace widget).
- **Mobile layout** — `feedback_tonya_trinity_mobile_approved.md`
  locks the mobile design. Any of these three options must
  preserve mobile compatibility; Tonya + Trinity re-verify on
  iPhone before merge.
- **The GoDaddy catcher domain forwarding** — 15 domains all
  forward to skyqubi.com, unchanged.
- **`public-chat/app.py` itself** — the service keeps running
  regardless. It's just relabeled (Option C), deprecated (Option A),
  or retired in favor of persona-chat (Option B).

---

## Review protocol for Tonya

Before any change to the landing page chat widget:

1. Print or screenshot the three options (A/B/C mockups).
2. Walk through with Tonya — show the visual difference.
3. Let Tonya pick ONE option OR request changes.
4. After sign-off, implement the chosen option on a branch.
5. Tonya re-reviews on staging URL (`123tech.skyqubi.com` from a
   non-main branch) before merge.
6. Tonya + Trinity iPhone-test.
7. Only then: merge + public sync.

---

## Lifecycle test additions post-handoff

Whichever option lands, add lifecycle tests:

- **L01 `public chat demo disclaimer present`** (Option C): GET
  `https://123tech.skyqubi.com/` → grep for the disclaimer
  banner text.
- **L02 `persona-chat widget embedded`** (Option B): GET → grep for
  the persona selector div.
- **L03 `no interactive widget`** (Option A): GET → confirm no
  widget div exists in the landing page.

All three are for the public website regression; all three run
against the live `123tech.skyqubi.com`.

---

## Approval gate

Before any landing-page change:

1. This doc reviewed by Jamie.
2. Option picked (A, B, or C).
3. Tonya sees the mockup + approves.
4. Trinity verifies on iPhone.
5. Staging URL matches production layout.
6. Public sync runs cleanly with the change included.
7. R02 `Public repo clean` passes after sync.

Until all seven, the landing page stays as-is and the "demo fake"
remains on the public site (dishonest but unchanged).

---

*Love is the architecture.*
