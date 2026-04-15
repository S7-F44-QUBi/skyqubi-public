# S7 Image Signing Key — Operations Runbook

**Created:** 2026-04-12 (with the iac/ signing pipeline)
**Scope:** Lifecycle operations for `/s7/.config/s7/s7-image-signing` — the ed25519 key that signs every S7 OCI image bundle. If this key is lost, compromised, or rotated incorrectly, historical signed releases become unverifiable and every downstream S7 machine must update its trust.

## Canonical identifiers (current)

| Field | Value |
|---|---|
| Key type | ed25519 |
| Fingerprint | `SHA256:dQDeDc3eixuLku1MhkAmgmCV7ZxXEQ1R7Gnf8eKPQQs` |
| Comment | `s7-image-signing (S7 OCI image signing · 2026-04-12)` |
| Private key path | `/s7/.config/s7/s7-image-signing` (mode 600) |
| Public key (repo) | `/s7/skyqubi-private/s7-image-signing.pub` |
| Created | 2026-04-12 |
| Used by | `iac/build-s7-base.sh`, `start-pod.sh` (verify), generated `reassemble.sh` |

**Verify at any time:** `./iac/keyops/verify-key.sh` — runs 6 checks and a round-trip sign+verify. Exit 0 means the key is sovereign and usable.

## What this key does

1. Signs the reassembled `s7-fedora-base-<TAG>.tar` bundle after every `./iac/build-s7-base.sh` run. The signature is included in the distribution chunks so the receiver can verify provenance before `podman load`.
2. (Future) Will sign `s7-skyqubi-admin-<TAG>.tar` when the admin container rebase ships. One key, two image lines, identical verification semantics.
3. The public half (`s7-image-signing.pub`) is committed to both the private and public repos so any receiver can bootstrap trust by cloning the public repo.

## The covenant

**This key is sovereign.** It never leaves the machine where it was generated. It never appears in a commit, a log file, a screenshot, a backup that leaves the host, or a shell history. The *private* half's existence is itself a secret. If Jamie ever needs to copy it to another machine, that copy must be hand-carried on a physical medium (USB, printed paper, hardware key) and never transmitted over a network in plaintext.

**The public half is meant to be public.** Distribute it as widely as possible so receivers can verify independently. A wider-than-necessary public key is not a leak — it's the whole point.

## Daily operations

### Verify the key is healthy

```bash
./iac/keyops/verify-key.sh
```

Run this any time you're unsure of the key's state — before a production build, after a reboot, after restoring from backup, whenever `verify` logs in any script complain about signatures. Exit 0 = healthy.

### Print just the fingerprint

```bash
./iac/keyops/verify-key.sh --fingerprint-only
```

## Backup (recommended, not yet automated)

**You MUST back up the private key.** The current state has exactly one copy of the key at `/s7/.config/s7/s7-image-signing`. If the laptop's SSD fails or that file is deleted, every historical signed bundle becomes permanently unverifiable and every downstream machine has to update its trust to a newly-generated key.

### Suggested backup procedures (in order of cost)

1. **Encrypt to passphrase + USB** (highest cost, highest resilience):
   ```bash
   # one-time setup: pick a strong passphrase, remember it
   openssl enc -aes-256-cbc -pbkdf2 -salt \
     -in /s7/.config/s7/s7-image-signing \
     -out /path/to/usb/s7-image-signing.enc
   # or use `age` if you have an age-encrypted recipient
   age -p -o /path/to/usb/s7-image-signing.age /s7/.config/s7/s7-image-signing
   ```
   Store the USB in a physically secure location (safe, safe deposit box). Print the passphrase on paper and store separately. Verify restore procedure once a year.

2. **Encrypted cloud backup** (lower cost, acceptable if the encryption is trustworthy):
   Same `openssl enc` or `age` command, upload the resulting `.enc`/`.age` file to any cloud storage Jamie trusts. The passphrase/recipient is the critical secret — NEVER store the passphrase alongside the encrypted file.

3. **Hardware token** (highest resilience, requires hardware):
   Transfer the signing key to a YubiKey or similar hardware security module. The key then lives on the token, cannot be extracted, and every sign operation requires physical presence. Trade-off: every build needs the token plugged in.

**Until a backup exists, treat every build as potentially-last-opportunity-to-backup.** If the key file is readable, copy it to a second device immediately.

## Rotation (when + how)

### When to rotate

- Annually (calendar reminder — don't wait for a compromise)
- Immediately if the key is suspected compromised (host breach, leaked private file, suspicious sig on an unknown release)
- When transitioning to a hardware token
- When changing primary build host and the old key won't follow

### How to rotate

1. **Generate the new key** (same settings, new timestamp in comment):
   ```bash
   ssh-keygen -t ed25519 \
     -f /s7/.config/s7/s7-image-signing.new \
     -N '' \
     -C "s7-image-signing (S7 OCI image signing · $(date +%Y-%m-%d))"
   chmod 600 /s7/.config/s7/s7-image-signing.new
   chmod 644 /s7/.config/s7/s7-image-signing.new.pub
   ```

2. **Record the new fingerprint** in this runbook (canonical identifiers table above) AND in `iac/keyops/verify-key.sh` (`CANONICAL_FINGERPRINT=` at the top).

3. **Append the old key to rotation history** (see "Rotation history" section below — add a dated row with the old fingerprint, the reason for rotation, and the cutover date).

4. **Atomically swap the keys:**
   ```bash
   # Back up the old key first (required for verifying historical bundles)
   mv /s7/.config/s7/s7-image-signing /s7/.config/s7/s7-image-signing.v$(date +%Y%m%d)
   mv /s7/.config/s7/s7-image-signing.new /s7/.config/s7/s7-image-signing
   mv /s7/.config/s7/s7-image-signing.new.pub /s7/.config/s7/s7-image-signing.pub
   cp /s7/.config/s7/s7-image-signing.pub /s7/skyqubi-private/s7-image-signing.pub
   ```

5. **Verify the new key:**
   ```bash
   ./iac/keyops/verify-key.sh
   ```
   Expect PASS. If FAIL, do not proceed — roll back.

6. **Commit + sync + lifecycle:**
   ```bash
   cd /s7/skyqubi-private
   git add s7-image-signing.pub iac/keyops/verify-key.sh docs/internal/runbooks/s7-image-signing-key-ops.md
   git commit -m "keyops: rotate image signing key — reason: <reason>"
   ./s7-sync-public.sh
   ./s7-lifecycle-test.sh
   ```

7. **Re-sign historical bundles (optional but recommended):**
   Any `s7-fedora-base-<TAG>.tar` or `s7-skyqubi-admin-<TAG>.tar` that's still in production needs a new signature from the new key, OR the old key's pub must be preserved as an "allowed historical signer" in the verification path. Easiest: re-run `build-s7-base.sh --tag <SAME_TAG>` to regenerate signed chunks for each tag in active use.

8. **Notify downstream users** (if any exist by rotation time) that the public key has changed. They need to pull the updated `s7-image-signing.pub` from the public repo before verifying new bundles.

## Compromise response

If you believe the private key has been stolen or leaked:

1. **Immediately rotate** following the procedure above. Use a new fingerprint, new filename.
2. **Revoke the old key** by marking it compromised in the rotation history (below) with a note about WHEN and HOW the compromise was detected.
3. **Do not delete the old key file** — keep it (renamed, marked compromised) so you can verify historical bundles and prove which ones were signed before vs after the compromise window.
4. **Re-sign every current-production bundle** with the new key and ship updated SHA256SUMS / `.sig` files.
5. **Audit every signed bundle** against the rotation-history to identify any bundle signed during the compromise window that should be treated as untrusted.
6. **Notify Jamie's contacts** if any downstream users exist. The covenant demands transparency here — hiding a compromise to save face is the kind of behavior S7 is built to refuse.

## Recovery (key file lost, no backup)

If `/s7/.config/s7/s7-image-signing` is gone and there's no backup, you CANNOT recover the private key — ed25519 private keys are not derivable from their public halves. Options:

1. **Accept the loss** — generate a brand-new key, publish the new pub key, re-sign every bundle you want to keep usable, accept that every historical bundle signed by the lost key is now unverifiable unless someone still has the `.sig` files + the old pub key.
2. **Preserve historical verify path** — keep the old `s7-image-signing.pub` in the repo at a path like `docs/internal/keyops/historical/s7-image-signing-<date>.pub` and update `start-pod.sh` / `reassemble.sh` to try multiple pub keys when verifying. This is complex and not currently implemented.

**The better answer is: don't let this happen. Back up the key.**

## Rotation history

| Date | Old fingerprint | New fingerprint | Reason | Old key file path |
|---|---|---|---|---|
| 2026-04-12 | (none — initial key) | `SHA256:dQDeDc3eixuLku1MhkAmgmCV7ZxXEQ1R7Gnf8eKPQQs` | First generation as part of the iac/ signing pipeline | n/a |

## Related files

- `/s7/.config/s7/s7-image-signing` — the private key (NEVER share)
- `/s7/skyqubi-private/s7-image-signing.pub` — the public key (SAFE to share; goes to public repo)
- `iac/build-s7-base.sh` — uses the private key in phase 5 (sign) via `S7_IMAGE_SIGNING_KEY` env var
- `iac/pack-chunks.sh` — includes the `.sig` file in distribution manifests
- `iac/keyops/verify-key.sh` — end-to-end verification (run before production builds)
- `start-pod.sh` — verifies the admin container's signature on pod startup
- `docs/internal/ip/GO-LIVE-2026-04-12.md` — the public go-live marker (claims #7 and #8 reference signed images)

## The one-line rule

**If `./iac/keyops/verify-key.sh` returns non-zero, stop and resolve before building anything.**
