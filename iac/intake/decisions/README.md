# iac/intake/decisions/

Audit trail for the S7 intake gate.

Every time `iac/intake/gate.sh` runs, it appends one JSON line to
`YYYY-MM-DD.ndjson` in this directory. One file per UTC day. Every
line has:

```json
{
  "ts":       "2026-04-12T22:39:53Z",
  "kind":     "container",
  "name":     "quay.io/fedora/fedora-minimal:44",
  "verdict":  "pass",   // or "fail"
  "sha256_ok": true,
  "sig_ok":   "skipped",
  "scan_ok":  "skipped",
  "size_bytes": 83886080,
  "reason":   ""         // populated on fail
}
```

**This directory is committed.** The whole point is that bad gate
decisions stay in history — you can always go back and ask "what did
we pull, and why did we trust it?" Rewriting history here would
defeat the purpose.

## Querying

```bash
# Everything today
jq -c . iac/intake/decisions/$(date -u +%Y-%m-%d).ndjson

# All rejections this year
jq -c 'select(.verdict=="fail")' iac/intake/decisions/2026-*.ndjson

# Everything we ever promoted for a given image name
jq -c 'select(.name=="quay.io/fedora/fedora-minimal:44" and .verdict=="pass")' \
  iac/intake/decisions/*.ndjson
```

## Retention

Kept **forever**. This is an audit log, not a rotating cache.
