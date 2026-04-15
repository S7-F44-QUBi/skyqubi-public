#!/usr/bin/env bash
# iac/keyops/verify-key.sh
# Verify that the local signing key matches the canonical published
# public key and the expected fingerprint. Run this any time you
# suspect the signing key may have been lost, rotated, or tampered.
#
# Exit 0 = everything matches, key is sovereign and usable
# Exit 1 = something is off, DO NOT build releases until resolved
#
# Usage:
#   ./verify-key.sh                   # full check against canonical
#   ./verify-key.sh --fingerprint-only  # just print the current fp
#   ./verify-key.sh --help

set -euo pipefail

# Canonical identifiers for the current production signing key.
# When a rotation happens, update these values AND bump the
# rotation history in docs/internal/runbooks/s7-image-signing-key-ops.md
CANONICAL_FINGERPRINT="SHA256:dQDeDc3eixuLku1MhkAmgmCV7ZxXEQ1R7Gnf8eKPQQs"
CANONICAL_COMMENT_PREFIX="s7-image-signing"
EXPECTED_TYPE="ED25519"

PRIV_KEY="${S7_IMAGE_SIGNING_KEY:-/s7/.config/s7/s7-image-signing}"
PUB_KEY_REPO="/s7/skyqubi-private/s7-image-signing.pub"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,15p' "$0" | sed 's|^# \?||'
  exit 0
fi

fp_of() {
  local path="$1"
  ssh-keygen -lf "$path" 2>/dev/null | awk '{print $2}'
}

type_of() {
  local path="$1"
  ssh-keygen -lf "$path" 2>/dev/null | awk '{gsub(/[()]/,""); print $NF}'
}

if [[ "${1:-}" == "--fingerprint-only" ]]; then
  [[ -f "$PRIV_KEY" ]] && echo "private: $(fp_of "$PRIV_KEY")"
  [[ -f "$PUB_KEY_REPO" ]] && echo "public:  $(fp_of "$PUB_KEY_REPO")"
  exit 0
fi

echo "S7 signing key verification"
echo "==========================="
fail=0

# 1. Private key exists + is readable only by the user
if [[ ! -f "$PRIV_KEY" ]]; then
  echo "[FAIL] private key missing: $PRIV_KEY"
  echo "       see docs/internal/runbooks/s7-image-signing-key-ops.md for recovery"
  fail=1
else
  mode=$(stat -c %a "$PRIV_KEY")
  if [[ "$mode" != "600" && "$mode" != "400" ]]; then
    echo "[FAIL] private key permissions too open: $mode (expected 600)"
    echo "       fix: chmod 600 $PRIV_KEY"
    fail=1
  else
    echo "[PASS] private key present, mode $mode"
  fi
fi

# 2. Public key exists in repo
if [[ ! -f "$PUB_KEY_REPO" ]]; then
  echo "[FAIL] public key missing from repo: $PUB_KEY_REPO"
  echo "       fix: cp $PRIV_KEY.pub $PUB_KEY_REPO && cd /s7/skyqubi-private && git add + commit"
  fail=1
else
  echo "[PASS] public key present in repo"
fi

# 3. Private and public halves match
if [[ -f "$PRIV_KEY" && -f "$PUB_KEY_REPO" ]]; then
  priv_pub=$(ssh-keygen -yf "$PRIV_KEY" 2>/dev/null | awk '{print $1" "$2}')
  repo_pub=$(awk '{print $1" "$2}' "$PUB_KEY_REPO")
  if [[ "$priv_pub" == "$repo_pub" ]]; then
    echo "[PASS] private key matches repo public key"
  else
    echo "[FAIL] private key does NOT match the public key in the repo"
    echo "       private derives to: $priv_pub"
    echo "       repo contains:      $repo_pub"
    echo "       one of them is stale — DO NOT build releases until reconciled"
    echo "       see docs/internal/runbooks/s7-image-signing-key-ops.md"
    fail=1
  fi
fi

# 4. Fingerprint matches the canonical
if [[ -f "$PUB_KEY_REPO" ]]; then
  actual_fp=$(fp_of "$PUB_KEY_REPO")
  if [[ "$actual_fp" == "$CANONICAL_FINGERPRINT" ]]; then
    echo "[PASS] fingerprint matches canonical ($CANONICAL_FINGERPRINT)"
  else
    echo "[WARN] fingerprint drift from canonical"
    echo "       actual:    $actual_fp"
    echo "       canonical: $CANONICAL_FINGERPRINT"
    echo "       either this is a rotation (update CANONICAL_FINGERPRINT in this"
    echo "       script + the runbook), or the key has been replaced without"
    echo "       going through the rotation procedure — investigate."
    fail=1
  fi
fi

# 5. Key type
if [[ -f "$PUB_KEY_REPO" ]]; then
  actual_type=$(type_of "$PUB_KEY_REPO")
  if [[ "$actual_type" == "$EXPECTED_TYPE" ]]; then
    echo "[PASS] key type $actual_type"
  else
    echo "[WARN] key type is $actual_type, expected $EXPECTED_TYPE"
    echo "       S7 policy: ed25519 only. rsa/ecdsa/dsa not accepted."
    fail=1
  fi
fi

# 6. Sign + verify round trip with the current key
if [[ -f "$PRIV_KEY" && -f "$PUB_KEY_REPO" ]]; then
  tmp_file=$(mktemp)
  tmp_sig="${tmp_file}.sig"
  tmp_allowed=$(mktemp)
  trap 'rm -f "$tmp_file" "$tmp_sig" "$tmp_allowed"' EXIT
  echo "round-trip payload $(date +%s)" > "$tmp_file"
  if ssh-keygen -Y sign -f "$PRIV_KEY" -n file -I s7-skyqubi "$tmp_file" 2>/dev/null; then
    printf 's7-skyqubi %s\n' "$(cat "$PUB_KEY_REPO")" > "$tmp_allowed"
    if ssh-keygen -Y verify -f "$tmp_allowed" -I s7-skyqubi -n file -s "$tmp_sig" < "$tmp_file" >/dev/null 2>&1; then
      echo "[PASS] sign + verify round-trip with current keypair"
    else
      echo "[FAIL] signed with private key, verify against public key FAILED"
      echo "       the keypair is broken — DO NOT build releases"
      fail=1
    fi
  else
    echo "[FAIL] could not sign with private key"
    fail=1
  fi
fi

echo "==========================="
if [[ "$fail" -eq 0 ]]; then
  echo "VERDICT: PASS — signing key is sovereign and usable"
  exit 0
else
  echo "VERDICT: FAIL — see failures above before building or shipping"
  exit 1
fi
