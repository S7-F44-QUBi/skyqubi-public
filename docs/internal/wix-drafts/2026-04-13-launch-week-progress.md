# Wix-paste draft — 2026-04-13 launch-week progress section

> Operator note: This is hand-paste material for Wix Studio (`skyqubi.com` /
> `skyqubi.ai`). It does **not** auto-publish anywhere. The freeze rule
> applies to the GitHub Pages public repo, not to Wix. Paste these blocks
> wherever in the landing page they fit best.

---

## Hero strapline (one-liner — shows above the fold)

**Sovereign by July 7. Verified all the way down.**

---

## Mid-page section — "What we shipped this week"

### Built tonight, on schedule for July 7

The S7 SkyQUB*i* TimeCapsule registry is live. Every container image S7 needs to run will live in one sealed, GPG-signed, mount-based store on the +1 disk layer of every QUBi appliance. No more reaching out to docker.io or ghcr.io at runtime. No more "what happens if upstream deletes the image we depend on." We have it. We signed it. It boots from us.

This is the foundation piece. Everything that ships before July 7 builds on it.

### What's verified

We installed Trivy, the open-source vulnerability scanner, and ran it against every container we plan to ship. The S7-built bootc base — the work S7 actually controls — came back **clean**. Zero CRITICAL. Zero HIGH.

We also scanned the six third-party services we currently inherit from upstream (Jellyfin, MySQL, Redis, Qdrant, Cyberchef, and our workflow backend). Those came back with real findings — 42 CRITICAL and 443 HIGH between them. Every single one is in code S7 didn't write. The whole point of the TimeCapsule registry is to put us in a position where we can **upgrade those upstream pieces deliberately**, after we've vetted them, instead of accidentally, in the dark.

The validation is the headline. The scan reports are the proof. The cleanup is the next plan.

### What's still on track for July 7

- The complete S7-X27 product image, signed and packaged
- The covenant security audit, freshly re-scanned
- The hardened upstream image set (the one that comes *after* we replace what doesn't pass)
- The boot-server validation gate, baked into every release
- The two-tier release discipline — `lifecycle` for active devops, `main` for go-live, public surfaces frozen between Core Updates so what you see on launch day is what's actually running on every shipping QUBi

### What sovereignty looks like when it works

The work S7 controls is at zero. The work S7 inherits is documented. The mechanism to bring inherited work under S7 control is built and tested. The next step is exercising that mechanism, image by image, on a focused image-hardening plan.

We are six commits beyond yesterday on the private branch. Two complete plans, half of a third. One real security finding that *validates the whole architecture*. And the household appliance is still serving the same SPA it was serving yesterday — because the cube did all the work, and the desktop never changed.

**Public Launch: July 7, 2026 · 7:00 AM CT.**

---

## Footer line (small text, near the bottom)

> *Tonight's commits live on the private branch. The freeze between Core Updates is intentional: what you see on launch day is what is actually running on every shipping QUB*i*.*
