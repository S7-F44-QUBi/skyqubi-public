# S7 SkyQUB*i* — Documentation Structure

This directory has two sections with a **mechanical public/private split**. Read this once, then follow the rule.

```
docs/
├── public/    ← syncs to the public repo (and GitHub Pages serves it)
│   ├── index.html          the live landing page (skyqubi.com)
│   ├── coming-soon/        the chat preview page
│   ├── branding/icons/     all public-facing brand assets
│   ├── CNAME               github pages domain binding
│   ├── README.md           user-facing readme (shown on public repo)
│   ├── INSTALL.md          how to install S7
│   ├── USAGE.md            how to query witnesses / consensus
│   ├── ARCHITECTURE.md     high-level architecture (no secrets)
│   └── COVENANT.md         the seven laws, public-facing
└── internal/    ← NEVER syncs to public, mechanically guaranteed
    ├── architecture/       internal architecture notes (may reference ports, IPs, hostnames)
    ├── ip/                 patent drafts, IP memos, legal
    ├── reference/          internal technical reference (credentials paths, keys, DB schemas)
    └── superpowers/        private process docs, runbooks, admin procedures
```

## The rule

**If a file is not physically inside `docs/public/`, it cannot reach the public repo.**

This is enforced by `s7-sync-public.sh`:

- **Phase 1** rsyncs everything at the repo root EXCEPT `docs/` entirely.
- **Phase 2** rsyncs only `docs/public/` → public repo's `docs/`.

No regex filters. No "redact this keyword" rules. The security property is **location-based**, not content-based — which means a secret accidentally typed into `docs/internal/runbook.md` is mechanically unable to reach public, regardless of its format.

## Adding a new document

- **Internal/admin/secret-adjacent** → place in `docs/internal/<subdir>/`. Done. Never touches public.
- **User-facing / install / usage / architecture overview** → place in `docs/public/`. It will sync on the next `./s7-sync-public.sh` run.
- **Moving a doc from internal → public** is a conscious git operation: `git mv docs/internal/foo.md docs/public/foo.md`. Review the diff. Sanitize anything sensitive. Commit. Sync.

## What lives in `docs/public/` today

The website source (`index.html` + assets) and the starter user instruction set (README, INSTALL, USAGE, ARCHITECTURE, COVENANT). Extend these as needed; the public repo will mirror them.

## Why not a blacklist filter?

Filter-based redaction (regex for API keys, keyword blacklists) inevitably leaks. A new secret format the filter wasn't trained on walks right through. A typo in the filter matches nothing. A subtly renamed variable in an example slips by. The only reliable security property is *physical separation*: the file is either inside `docs/public/` or it isn't. No human judgment required at sync time — the judgment happens once, when the file is placed.

## When to edit the sync script

If you need to add a new **non-docs** category to the blacklist (e.g., a new folder with internal tools), edit the `EXCLUDE` array at the top of `s7-sync-public.sh`. Do not edit it for docs — docs is handled by the phase-2 whitelist and needs no list.
