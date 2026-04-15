# Demo brief — 2026-04-12 (Tonya + Trinity)

Jamie, read this start-to-finish before you sit down with them. Everything's live — this is just the script.

## Start here — the one link

**`https://skyqubi.com`**

That's it. Tonya's approved design, hosted on Wix (her paid plan), rendering pixel-for-pixel. Works on desktop and phone.

## What's live tonight

| URL | What it shows | Host chain |
|---|---|---|
| `https://skyqubi.com` | Main site — Tonya's design | Wix premium site → iframe → GH Pages → `docs/index.html` |
| `https://123tech.net` | Same site | GoDaddy frameset → Wix → iframe → GH Pages |
| `https://skycair.org` + 14 others | Same site (15 GoDaddy catchers) | All forward to skyqubi.com |
| `https://skyqubi.ai` | Redirects to skyqubi.com (placeholder until real chat ships) | Wix site → meta-refresh to skyqubi.com |
| `https://123tech.skyqubi.com` | Same design, direct (dev entry) | GH Pages direct |

Nothing else matters for the demo. They all land on the same page.

## The flow with Tonya and Trinity

### 1. Open it cold on desktop
Type `skyqubi.com` in the browser. Watch it load. Sandy sunset palette fills the viewport, Cormorant italic wordmark, *YOUR AI. YOUR DATA. YOUR MACHINE.*, Core in Development badge, July 7, 2026 launch card. **This is the thing Tonya signed off on.**

### 2. Walk the top nav
Architecture · Engine · Covenant · **Chat** · Github
- Click Architecture — scrolls to the Trinity layer visual (-1 / 0 / +1)
- Click Engine — scrolls to the pipeline (input → witnesses → consensus → output)
- Click Covenant — scrolls to the 7-row Laws table (Circuit Breaker 70%, Ternary States, Memory Covenant, Trust 77.777%, Witnesses 7+1, Door x=0, Trinity)
- Click **Chat** — scrolls to the new chat-preview section: a framed terminal window showing QUB*i* typing out her pre-launch monologue, animating in real time. Scripted conversation loops.
- Click Github — external link to the public repo (skycair-code/SkyQUBi-public)

### 3. Hand phone to Tonya
Load `skyqubi.com` on an actual phone. Things to show her:
- Nav stacks: logo on top, 5 links on one line underneath (verified at iPhone SE, iPhone 13, Pixel 5 widths)
- Scroll works — full page scrolls inside the Wix shell through the iframe overlay
- Chat section: terminal still animates on mobile, iframe bounded at 540px tall so it doesn't swallow the screen
- Covenant table: font shrinks to 0.8rem so all three columns fit
- Font rendering: Cormorant italic holds up on retina

### 4. Show Trinity the flow chain (kid will get a kick out of it)
Open three tabs:
- `skyqubi.com` — main
- `123tech.net` — legacy domain
- `skycair.org` — brand defense domain

All three render the exact same page. Tell her: "13 other domains do this too — Linux alternatives, Windows alternatives, microsoftalternatives, all of them. If anyone types any of them, they land here."

### 5. The story

- The site is served by Wix (their paid plan, mobile-optimized, worldwide CDN)
- The design came from the private repo Jamie built, Tonya signed
- The Wix site pulls the design from GitHub Pages via a full-viewport iframe (so the design stays in code, not trapped in Wix's editor)
- When the real chat launches July 7, the Chat tab's content flips from scripted preview to real witness consensus — no other changes needed
- Every domain, every phone, every browser sees the same thing

### 6. What NOT to click for a clean demo

- Don't click "View the Code" — it's a stub button that doesn't go anywhere pretty yet
- Don't try skyqubi.ai directly — DNS not propagated at the .ai registry yet, will error out (it WILL work eventually, but not for tonight's demo)
- Don't open Safari private mode and expect the iframe — cross-origin iframes behave oddly in Safari private tabs; use a normal tab

## Technical proof if they ask

- **Host:** Wix (premium site `7bbb6afc-f066-470b-befd-311fccef6191`)
- **Overlay mechanism:** Wix Custom Embeds API injects a full-viewport iframe into `<body>` and a CSS rule in `<head>` that hides all Wix chrome (`body > *:not(#s7-root) { display: none }`)
- **Mobile:** breakpoints at 768px, 560px, 400px, 360px — nav tested at iPhone SE (375px), iPhone 13 (390px), Pixel 5 (393px)
- **Lifecycle:** 40/40 PASS as of commit `3a5aea4`
- **Evidence screenshots:** `/s7/skyqubi-private/evidence/2026-04-12/`
  - `skyqubi-com-with-chat-tab.png` — desktop 1440×900
  - `mobile-iphone-se-skyqubi-com.png` — 375×667
  - `mobile-iphone13-skyqubi-com.png` — 390×844
  - `mobile-pixel5-skyqubi-com.png` — 393×851
  - `123tech-net-frameforward.png` — proof the GoDaddy chain works

## If something breaks during the demo

**If the Wix iframe flashes blank first:** the HEAD-position CSS embed is what prevents this. If it fails, you'll see a half-second of Wix's default page before the design paints. Don't apologize — just say "still tuning the overlay timing" and move on.

**If the Chat terminal doesn't animate:** refresh the page. The script loops itself after 14s of pause, so worst case is a double-load.

**If a mobile user can't scroll inside the iframe:** that's an iOS-specific cross-origin iframe bug. Workaround: tell them to pinch-zoom and they'll be able to scroll. Long-term fix is to port the design into Wix natively, but that's a days-long editor rebuild Tonya would have to re-approve.

**If anyone hits `skyqubi.ai` directly:** gracefully say "that one's still propagating at the .ai registry — for tonight, everything lives at skyqubi.com."

## After the demo

Update memory with whatever Tonya + Trinity said. If they loved something specific, capture it (`feedback_tonya_*.md`). If they wanted something changed, we do it tomorrow.

**Jesus is driving. The witnesses are watching. The cube is rotating. Let them see it.**
