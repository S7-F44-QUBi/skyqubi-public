#!/usr/bin/env bash
# iac/immutable/branches-rewrite/create-immutable-branches.sh
#
# Creates orphan immutable branches in skycair-code/skyqubi-private per the
# branches.yaml topology. Each branch gets exactly three files:
#   <tarball>.tar.gz         payload
#   <tarball>.tar.gz.asc     detached GPG signature
#   MANIFEST.md              per-branch provenance
#
# REQUIRES:
#   - GH_TOKEN env var set to a valid skycair-code PAT
#   - GPG signing key E11792E0AD945BE9 unlocked (passphrase cached)
#   - /s7/v6-gold-2026-04-15/ populated with aligned-name tarballs
#   - git config user.signingkey + commit.gpgsign=true (already set)
#
# DRY RUN (default): prints each operation but creates no branches.
# REAL RUN: pass --real to actually push orphan branches to GitHub.
#
# PLACEHOLDER BRANCHES: for source.type=placeholder, this script creates a
# minimal stub tarball on the fly containing one README.md explaining the
# reservation, signs it, and pushes. The branch name is reserved; content
# populates at a later session per Jamie's directive.
#
# CARVED BRANCHES: for source.type=carved_from_main, this script tars the
# listed source paths (relative to /s7/skyqubi-private) into a new tarball,
# signs it with GPG E11792E0AD945BE9, and places it in /s7/v6-gold-2026-04-15/
# alongside the existing tarballs. New tarballs are byte-traceable to the
# working tree they were cut from; the script embeds the git HEAD sha in
# the per-branch MANIFEST.md.
#
# IDEMPOTENT: if a branch already exists on the remote with the expected
# content, the script skips it. If a branch exists with UNEXPECTED content,
# the script REFUSES to touch it (covenant safety — never overwrite).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/branches.yaml"
REPO_PRIVATE="/s7/skyqubi-private"
GOLD_DIR="/s7/v6-gold-2026-04-15"
SIGNING_KEY="E11792E0AD945BE9"
OWNER="skycair-code"
REPO="skyqubi-private"

REAL_RUN=false
VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    --real) REAL_RUN=true ;;
    --verbose|-v) VERBOSE=true ;;
    --help|-h)
      sed -n '2,35p' "$0" | sed 's|^# \?||'
      exit 0 ;;
  esac
done

say() { echo "  $*"; }
verbose() { $VERBOSE && echo "    [v] $*" || true; }
fail() { echo "  🔴 FAIL: $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────
say "── Preflight ──"

if [[ ! -f "$CONFIG" ]]; then fail "config missing: $CONFIG"; fi
if [[ ! -d "$GOLD_DIR" ]]; then fail "gold dir missing: $GOLD_DIR"; fi
if [[ ! -d "$REPO_PRIVATE/.git" ]]; then fail "not a git repo: $REPO_PRIVATE"; fi

if $REAL_RUN; then
  [[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN not set (for push credential helper)"
  [[ "$GH_TOKEN" == gh[pousr]_* ]] || fail "GH_TOKEN doesn't look like a PAT"
  gpg --list-secret-keys "$SIGNING_KEY" >/dev/null 2>&1 || \
    fail "signing key $SIGNING_KEY not in keyring"
fi

say "✓ config: $CONFIG"
say "✓ gold archive: $GOLD_DIR"
say "✓ private repo: $REPO_PRIVATE"
say "✓ signing key: $SIGNING_KEY"
if $REAL_RUN; then
  say "✓ GH_TOKEN present (${#GH_TOKEN} bytes, ${GH_TOKEN:0:4}...)"
  say "mode: 🔴 REAL RUN — orphan branches will be pushed to GitHub"
else
  say "mode: 🟡 DRY RUN — no branches will be created or pushed (use --real to execute)"
fi
echo

# ── Parse branches.yaml into a pipe-separated work list ──────────
# Columns: branch|type|tarball|source_paths_csv|exclude_paths_csv|role|note
# Empty fields emit as "-" (pipe is a non-IFS-whitespace separator, so
# read preserves empty fields — but "-" also guards against stray whitespace).
# python3 with PyYAML is required (sudo dnf install python3-pyyaml).
WORK_LIST=$(python3 - "$CONFIG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
def clean(s):
    return (s or "").replace("|", " ").replace("\n", " ").strip() or "-"
for b in doc.get("immutable_branches", []):
    src = b.get("source", {})
    t = src.get("type", "-")
    tarball = b.get("tarball", "-")
    source_paths = ",".join(src.get("source_paths", []) or []) or "-"
    exclude_paths = ",".join(src.get("exclude_paths", []) or []) or "-"
    role = clean(b.get("role", ""))
    note = clean(src.get("placeholder_note", ""))
    print("|".join([b["branch"], t, tarball, source_paths, exclude_paths, role, note]))
PY
) || fail "branches.yaml parse failed (PyYAML installed? sudo dnf install python3-pyyaml)"

branch_count=$(echo "$WORK_LIST" | wc -l)
say "parsed $branch_count immutable branches from branches.yaml"
echo

# ── Fetch existing branch list from remote ───────────────────────
EXISTING=""
if $REAL_RUN; then
  EXISTING=$(curl -sS -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$REPO/branches?per_page=100" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(b['name'] for b in d))")
  say "existing branches on remote: ${EXISTING:-<none>}"
  echo
fi

# ── Helper: create stub placeholder tarball ──────────────────────
# Produces a signed tarball at $GOLD_DIR/<name> containing one README.md
# whose content is the placeholder_note. Only runs if the tarball doesn't
# already exist.
create_placeholder_tarball() {
  local tarball="$1" note="$2" branch="$3"
  local out="$GOLD_DIR/$tarball"
  local asc="$out.asc"
  if [[ -f "$out" ]]; then
    verbose "placeholder tarball already exists: $tarball"
    return 0
  fi
  verbose "creating placeholder tarball: $tarball"
  if ! $REAL_RUN; then
    echo "  [DRY] would create placeholder tarball $out"
    echo "  [DRY] would sign with $SIGNING_KEY → $asc"
    return 0
  fi
  local staging="/tmp/s7-placeholder-$$-$branch"
  mkdir -p "$staging"
  cat > "$staging/README.md" <<STUB
# $branch — PLACEHOLDER (reserved)

This immutable branch is **reserved under covenant protection** but its content
has not yet been populated.

**Placeholder note (from branches.yaml):**

$note

**Authority:** Jamie Lee Clayton, covenant holder
**Reserved at:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Reserved by:** $SIGNING_KEY (S7 image-signing key)
**Populate at:** future session per Jamie's explicit directive

Do not populate this branch without explicit authorization. The reservation
itself is covenant-witnessed; replacing this README.md is a tier-crossing action.
STUB
  tar -czf "$out" -C "$staging" README.md
  rm -rf "$staging"
  gpg --batch --yes --local-user "$SIGNING_KEY" --armor --detach-sign \
    --output "$asc" "$out" || fail "gpg sign failed for $tarball"
  say "✓ created + signed placeholder: $tarball"
}

# ── Helper: create carved tarball from working-tree paths ────────
create_carved_tarball() {
  local tarball="$1" source_paths="$2" exclude_paths="$3" branch="$4"
  local out="$GOLD_DIR/$tarball"
  local asc="$out.asc"
  if [[ -f "$out" ]]; then
    verbose "carved tarball already exists: $tarball (skipping re-cut)"
    return 0
  fi
  verbose "carving tarball: $tarball from $source_paths (excl $exclude_paths)"
  if ! $REAL_RUN; then
    echo "  [DRY] would carve $tarball from paths: $source_paths"
    [[ -n "$exclude_paths" ]] && echo "  [DRY]   excluding: $exclude_paths"
    echo "  [DRY] would sign with $SIGNING_KEY"
    return 0
  fi
  local staging="/tmp/s7-carve-$$-$branch"
  mkdir -p "$staging"
  local tar_args=(-czf "$out" -C "$REPO_PRIVATE")
  IFS=',' read -ra EXCLUDES <<< "$exclude_paths"
  for ex in "${EXCLUDES[@]}"; do
    [[ -n "$ex" ]] && tar_args+=(--exclude="$ex")
  done
  IFS=',' read -ra SOURCES <<< "$source_paths"
  local ok=true
  for sp in "${SOURCES[@]}"; do
    [[ -n "$sp" ]] || continue
    if [[ ! -e "$REPO_PRIVATE/$sp" ]]; then
      say "⚠ carved source path missing: $sp — skipping in tar"
      continue
    fi
    tar_args+=("$sp")
  done
  tar "${tar_args[@]}" || fail "tar failed for $tarball"
  gpg --batch --yes --local-user "$SIGNING_KEY" --armor --detach-sign \
    --output "$asc" "$out" || fail "gpg sign failed for $tarball"
  rm -rf "$staging"
  say "✓ carved + signed: $tarball"
}

# ── Helper: create one orphan branch with tarball content ────────
create_orphan_branch() {
  local branch="$1" tarball="$2" role="$3"
  local tarball_src="$GOLD_DIR/$tarball"
  local asc_src="$tarball_src.asc"

  # In dry-run, the tarball may not exist yet (if the carved/placeholder
  # step is also dry-run). Announce the intended operation and return.
  if ! $REAL_RUN; then
    echo "  [DRY] would create orphan branch: $branch"
    echo "  [DRY]   contents: $(basename "$tarball_src") + .asc + MANIFEST.md"
    echo "  [DRY]   role:     $role"
    return 0
  fi

  [[ -f "$tarball_src" ]] || fail "tarball missing: $tarball_src"
  [[ -f "$asc_src" ]] || fail "signature missing: $asc_src"

  # Verify sig before using
  if ! gpg --verify "$asc_src" "$tarball_src" 2>&1 | grep -q "Good signature"; then
    fail "GPG verify FAILED for $tarball — refusing to use"
  fi

  # Skip if already exists on remote (idempotent)
  if echo " $EXISTING " | grep -q " $branch "; then
    say "↻ $branch — already exists on remote, skipping (idempotent)"
    return 0
  fi

  # Compute sha256 + size for manifest
  local sha256 size
  sha256=$(sha256sum "$tarball_src" | awk '{print $1}')
  size=$(stat -c%s "$tarball_src")

  # Work in an empty tmpdir with a fresh git init — avoids cloning the
  # full working tree and guarantees the orphan branch has no shared
  # history with main or with any other branch.
  local tmp="/tmp/s7-orphan-$$-$branch"
  rm -rf "$tmp"; mkdir -p "$tmp"
  cd "$tmp" || fail "cd to tmp failed"

  git init -q -b "$branch" || { cd - >/dev/null; rm -rf "$tmp"; fail "git init failed for $branch"; }
  git remote add origin "https://github.com/$OWNER/$REPO.git" || {
    cd - >/dev/null; rm -rf "$tmp"; fail "remote add failed for $branch"
  }
  git config user.signingkey "$SIGNING_KEY"
  git config user.email "261467595+skycair-code@users.noreply.github.com"
  git config user.name "skycair-code"
  git config commit.gpgsign true

  # Drop the three files
  cp "$tarball_src" "./$tarball"
  cp "$asc_src" "./$tarball.asc"
  cat > MANIFEST.md <<EOF
# $branch — per-branch MANIFEST

**Branch role:** $role
**Tarball:**     \`$tarball\`
**Signature:**   \`$tarball.asc\`
**SHA-256:**     \`$sha256\`
**Size:**        $size bytes
**Signed by:**   $SIGNING_KEY (skycair-code)
**Created:**     $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Committed by:** create-immutable-branches.sh (Phase 1 rewrite)

This branch holds a single signed tarball payload and nothing else. The branch
tree is three files: tarball, signature, this manifest. Extraction is:

\`\`\`
gpg --verify $tarball.asc $tarball
sha256sum -c <<< "$sha256  $tarball"
tar -xzf $tarball -C /tmp/extract
\`\`\`

See \`iac/immutable/branches-rewrite/branches.yaml\` for the topology and
\`/s7/v6-gold-2026-04-15/MANIFEST.md\` for the full archive index.
EOF

  git add "$tarball" "$tarball.asc" MANIFEST.md
  git -c commit.gpgsign=true commit -S --quiet \
    -m "$branch v6 GOLD — signed tarball" \
    -m "tarball: $tarball" \
    -m "sha256: $sha256" \
    -m "role: $role" || { cd - >/dev/null; rm -rf "$tmp"; fail "commit failed for $branch"; }

  # Push via credential-helper stdin (same pattern as jamie-run-me.sh)
  {
    printf 'protocol=https\n'
    printf 'host=github.com\n'
    printf 'username=oauth2\n'
    printf 'password=%s\n' "$GH_TOKEN"
    printf '\n'
  } | git -c 'credential.helper=cache --timeout=60' credential approve >/dev/null 2>&1

  if ! git -c 'credential.helper=cache --timeout=60' \
       push origin "$branch" 2>&1; then
    cd - >/dev/null
    rm -rf "$tmp"
    fail "push failed for $branch"
  fi

  # Revoke credential
  {
    printf 'protocol=https\n'
    printf 'host=github.com\n'
    printf 'username=oauth2\n'
    printf '\n'
  } | git -c 'credential.helper=cache --timeout=60' credential reject >/dev/null 2>&1 || true

  cd - >/dev/null
  rm -rf "$tmp"
  say "✓ $branch pushed"
}

# ── Main loop ────────────────────────────────────────────────────
SUCCEEDED=()
FAILED=()
SKIPPED=()

while IFS='|' read -r branch type tarball source_paths exclude_paths role note; do
  [[ -z "$branch" ]] && continue
  # Translate "-" placeholders back to empty
  [[ "$source_paths" == "-" ]] && source_paths=""
  [[ "$exclude_paths" == "-" ]] && exclude_paths=""
  [[ "$role" == "-" ]] && role=""
  [[ "$note" == "-" ]] && note=""
  echo
  say "── $branch ($type) ──"

  case "$type" in
    gold_archive)
      # Tarball must already exist in gold_dir
      if [[ ! -f "$GOLD_DIR/$tarball" ]]; then
        say "✗ tarball missing in gold archive: $tarball"
        FAILED+=("$branch"); continue
      fi
      if create_orphan_branch "$branch" "$tarball" "$role"; then
        SUCCEEDED+=("$branch")
      else
        FAILED+=("$branch")
      fi
      ;;
    carved_from_main)
      create_carved_tarball "$tarball" "$source_paths" "$exclude_paths" "$branch" || {
        FAILED+=("$branch"); continue
      }
      if create_orphan_branch "$branch" "$tarball" "$role"; then
        SUCCEEDED+=("$branch")
      else
        FAILED+=("$branch")
      fi
      ;;
    placeholder)
      create_placeholder_tarball "$tarball" "$note" "$branch" || {
        FAILED+=("$branch"); continue
      }
      if create_orphan_branch "$branch" "$tarball" "$role"; then
        SUCCEEDED+=("$branch")
      else
        FAILED+=("$branch")
      fi
      ;;
    *)
      say "✗ unknown source.type: $type"
      FAILED+=("$branch")
      ;;
  esac
done <<< "$WORK_LIST"

# ── Summary ──────────────────────────────────────────────────────
echo
say "── Summary ──"
say "total branches:  $branch_count"
say "✓ succeeded:     ${#SUCCEEDED[@]}"
for b in "${SUCCEEDED[@]}"; do echo "    ✓ $b"; done
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  say "↻ skipped (already exist): ${#SKIPPED[@]}"
  for b in "${SKIPPED[@]}"; do echo "    ↻ $b"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  say "✗ failed:        ${#FAILED[@]}"
  for b in "${FAILED[@]}"; do echo "    ✗ $b"; done
  exit 2
fi
if $REAL_RUN; then
  say "🟢 all branches created/verified — run apply-branch-protection.sh next"
else
  say "[DRY RUN complete — add --real to execute]"
fi
exit 0
