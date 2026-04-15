#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — self-extracting installer builder
#
# Produces a single file `s7-skyqubi-installer-YYYY-MM-DD.sh` that
# the user can run with `bash s7-skyqubi-installer-*.sh` on a fresh
# Fedora 44 (or compatible) host. The output file is bash header +
# embedded payload, fully self-contained, no internet required at
# install time.
#
# Pass 1 scope (this commit):
#   - Bundles the repo working tree as repo.tar.zst
#   - Bundles preflight.sh into the payload root
#   - Generates a manifest with sha256 of every artifact
#   - Concatenates installer-header.sh + manifest + payload tar.zst
#   - Patches the manifest sha256 placeholder in the header
#
# Pass 2 scope (deferred):
#   - podman save of every image in iac/build-all.sh
#   - ollama model blob bundling (multi-GB)
#   - postgres + mysql initial DB dumps
#   - GPG sign the manifest
#
# Usage:
#   bash package/build-installer.sh                    # build the installer
#   bash package/build-installer.sh --output FILE      # custom output path
#   bash package/build-installer.sh --check            # verify output extracts
#
# Exit codes:
#   0 — installer built (and verified if --check)
#   1 — usage error
#   2 — missing dependency (zstd, tar, sha256sum)
#   3 — payload assembly failed
#
# Governing rules:
#   feedback_recall_store_first.md   Don't recompute if a content-hashed
#                                    prior build already exists
#   project_intake_gate.md           Verify before trust
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
ok()      { echo "  ${GREEN}✓${RESET} $1"; }
fail()    { echo "  ${RED}✗${RESET} $1" >&2; }
warn()    { echo "  ${YELLOW}!${RESET} $1"; }
info()    { echo "  ${CYAN}→${RESET} $1"; }
section() { echo; echo "${CYAN}── $1${RESET}"; }

# ── Flags ───────────────────────────────────────────────────────────
DATE_TAG="$(date -u +%Y-%m-%d)"
DEFAULT_OUTPUT="${REPO_DIR}/dist/s7-skyqubi-installer-${DATE_TAG}.sh"
OUTPUT="$DEFAULT_OUTPUT"
DO_CHECK=0
WITH_IMAGES=0
WITH_MODELS=0
for arg in "$@"; do
    case "$arg" in
        --output=*)        OUTPUT="${arg#--output=}" ;;
        --output)          shift; OUTPUT="${1:-$DEFAULT_OUTPUT}" ;;
        --check)           DO_CHECK=1 ;;
        --with-images)     WITH_IMAGES=1 ;;
        --with-models)     WITH_MODELS=1 ;;
        --with-everything) WITH_IMAGES=1; WITH_MODELS=1 ;;
        --help|-h)
            sed -n '3,28p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) fail "unknown flag: $arg"; exit 1 ;;
    esac
done

# Hardcoded image list — the 5 containers the s7-skyqubi pod needs.
# Bundled via 'podman save' when --with-images is passed. Keeping it
# explicit is intentional: the public installer must not auto-discover
# images from the host (which would leak whatever else is there).
S7_BUNDLED_IMAGES=(
    "localhost/s7-skyqubi-admin:v2.6"
    "docker.io/library/mysql:8.0"
    "docker.io/pgvector/pgvector:pg16"
    "docker.io/library/redis:7-alpine"
    "docker.io/qdrant/qdrant:latest"
)

# Hardcoded model list — the personas Tonya touches plus the base
# they all inherit from. Bundled by reading each model's manifest,
# extracting blob references, deduplicating, and copying both the
# manifest and the unique blobs. The witness set + community models
# (gemma2, llama3.2, qwen3, etc.) are NOT in this list — they're
# Pass 3 work and would push the installer above 6 GB.
S7_BUNDLED_MODELS=(
    "s7-qwen3:0.6b"      # base — Carli/Samuel inherit from this
    "s7-carli:0.6b"      # warm conversational persona
    "s7-elias:1.3b"      # code/reasoning persona (larger than Carli/Samuel)
    "s7-samuel:v1"       # FACTS / sysadmin persona (current live tag)
)
OLLAMA_MODELS_DIR="${OLLAMA_MODELS_DIR:-$HOME/.ollama/models}"

# ── Dependency check ────────────────────────────────────────────────
section "Checking build dependencies"
for cmd in tar zstd sha256sum awk sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "missing required tool: $cmd"
        exit 2
    fi
    ok "$cmd"
done

# ── Resource preflight ──────────────────────────────────────────────
# Check that we have enough room everywhere we'll write before
# starting any expensive work. Bail loudly rather than half-build.
section "Resource preflight"
check_free_mb() {
    local path="$1"
    local need_mb="$2"
    local label="$3"
    local free_mb
    free_mb=$(df -BM "$path" 2>/dev/null | awk 'NR==2 {gsub(/M/,"",$4); print $4}')
    if [ -z "$free_mb" ]; then
        warn "$label: could not stat (assuming OK)"
        return 0
    fi
    if [ "$free_mb" -lt "$need_mb" ]; then
        fail "$label: $free_mb MB free, need at least $need_mb MB"
        return 1
    fi
    ok "$label: $free_mb MB free (need $need_mb)"
}

# Stage area needs the most room: repo (~150 MB) + images (~1.5 GB)
# + models (~3-4 GB) + payload (the same content compressed once more)
need_stage_mb=200
[ "$WITH_IMAGES" -eq 1 ] && need_stage_mb=$((need_stage_mb + 3500))
[ "$WITH_MODELS" -eq 1 ] && need_stage_mb=$((need_stage_mb + 6000))
check_free_mb "$REPO_DIR" "$need_stage_mb" "stage area" || exit 4

# /tmp is tmpfs on this box; only need a few MB for one-off tar pipes
check_free_mb "/tmp" 50 "/tmp (tmpfs)" || exit 4

# /var/tmp is also tmpfs on this box — podman save WOULD use it as
# scratch but we override TMPDIR for that. Just sanity-check the
# minimum shell scratch.
check_free_mb "/var/tmp" 50 "/var/tmp" || warn "  (best-effort; we override TMPDIR for big writes)"

# ── Stage the payload ───────────────────────────────────────────────
# Stage under the repo's dist/.build-tmp instead of /tmp because /tmp
# is a 1G tmpfs on this box — way too small for a real payload.
section "Staging payload"
mkdir -p "$REPO_DIR/dist/.build-tmp"
STAGE=$(mktemp -d -p "$REPO_DIR/dist/.build-tmp" "stage-XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
info "stage dir: $STAGE"

# 1. Snapshot the repo as repo.tar.zst
#    ALLOWLIST: explicitly name what ships. Defaults to "don't ship"
#    so we never leak training data, ISO build artifacts, patents,
#    or other large/sensitive content into a public installer.
SHIP_PATHS=(
    autostart
    dashboard
    docs/internal/reference     # keep public reference docs only
    engine
    iac
    install
    mcp
    persona-chat
    profiles
    public-chat
    services
    APACHE-LICENSE
    CODE_OF_CONDUCT.md
    Containerfile
    CONTRIBUTING.md
    COVENANT.md
    CWS-LICENSE
    DEPLOY.md
)
info "Snapshotting allowlisted paths (${#SHIP_PATHS[@]} entries)"
# Filter to paths that actually exist (don't fail on optional ones)
EXISTING_PATHS=()
for p in "${SHIP_PATHS[@]}"; do
    if [ -e "$REPO_DIR/$p" ]; then
        EXISTING_PATHS+=("$p")
    else
        warn "  skipping (not present): $p"
    fi
done
tar \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='node_modules' \
    --exclude='.git' \
    -C "$REPO_DIR" -cf - "${EXISTING_PATHS[@]}" \
    | zstd -T0 -19 --quiet -o "$STAGE/repo.tar.zst"
repo_size=$(du -sh "$STAGE/repo.tar.zst" | awk '{print $1}')
ok "repo.tar.zst staged ($repo_size)"

# 2. Copy preflight.sh into the payload root so the inner installer
#    can run it even before the repo is unpacked
cp "$REPO_DIR/install/preflight.sh" "$STAGE/preflight.sh"
chmod +x "$STAGE/preflight.sh"
ok "preflight.sh staged"

# 3. Copy the inner installer
cp "$SCRIPT_DIR/installer-inner.sh" "$STAGE/inner.sh"
chmod +x "$STAGE/inner.sh"
ok "inner.sh staged"

# 3b. Bundle container images via podman save (only with --with-images)
if [ "$WITH_IMAGES" -eq 1 ]; then
    info "Bundling ${#S7_BUNDLED_IMAGES[@]} container images via podman save"
    if ! command -v podman >/dev/null 2>&1; then
        fail "podman not installed — cannot bundle images"
        exit 2
    fi
    # podman save uses TMPDIR (default /var/tmp) as scratch when
    # converting to oci-archive. On this box /var/tmp is tmpfs-small,
    # so we point it at the real-disk staging area instead.
    PODMAN_TMP="$STAGE/.podman-tmp"
    mkdir -p "$PODMAN_TMP" "$STAGE/images"
    export TMPDIR="$PODMAN_TMP"
    for img in "${S7_BUNDLED_IMAGES[@]}"; do
        # Sanitize image name into a filename: replace / and : with _
        fname=$(echo "$img" | sed 's|[/:]|_|g').tar
        info "  saving $img → images/$fname"
        if ! podman save --format=oci-archive -o "$STAGE/images/$fname" "$img" 2>&1 | tail -3; then
            fail "podman save failed for $img"
            fail "  is the image present? try: podman images | grep $(echo $img | cut -d: -f1)"
            exit 3
        fi
        size=$(du -sh "$STAGE/images/$fname" | awk '{print $1}')
        ok "    $fname ($size)"
    done
    images_total=$(du -sh "$STAGE/images" | awk '{print $1}')
    ok "images bundled (total $images_total)"
    # Clean up the podman scratch dir; we no longer need it
    rm -rf "$PODMAN_TMP"
    unset TMPDIR

    # Write an images manifest the inner installer reads to know
    # which files to load and what tag to load them as.
    {
        printf '{"version": 1, "images": [\n'
        first=1
        for img in "${S7_BUNDLED_IMAGES[@]}"; do
            fname=$(echo "$img" | sed 's|[/:]|_|g').tar
            sha=$(sha256sum "$STAGE/images/$fname" | awk '{print $1}')
            sz=$(stat -c%s "$STAGE/images/$fname")
            [ $first -eq 0 ] && printf ',\n'
            printf '  {"image": "%s", "file": "images/%s", "sha256": "%s", "bytes": %d}' \
                "$img" "$fname" "$sha" "$sz"
            first=0
        done
        printf '\n]}\n'
    } > "$STAGE/images.manifest.json"
    ok "images.manifest.json generated"
else
    info "No image bundling (use --with-images to bundle 5 podman images)"
fi

# 3c. Bundle ollama model weights (only with --with-models)
if [ "$WITH_MODELS" -eq 1 ]; then
    info "Bundling ${#S7_BUNDLED_MODELS[@]} ollama models with blob deduplication"
    if [ ! -d "$OLLAMA_MODELS_DIR" ]; then
        fail "ollama models dir not found: $OLLAMA_MODELS_DIR"
        fail "  set OLLAMA_MODELS_DIR if your install uses a custom path"
        exit 3
    fi
    mkdir -p "$STAGE/models/manifests" "$STAGE/models/blobs"

    # Use python to walk each manifest, collect blob digests, dedupe.
    # We pass the model list via env var (avoiding heredoc-stdin
    # collision we hit in pod-stats.sh earlier today).
    export OLLAMA_MODELS_DIR
    export S7_BUNDLED_MODELS_STR="${S7_BUNDLED_MODELS[*]}"
    export STAGE
    python3 - <<'PY' || { fail "model bundling failed"; exit 3; }
import os, sys, json, shutil, pathlib

models_dir = pathlib.Path(os.environ["OLLAMA_MODELS_DIR"])
stage = pathlib.Path(os.environ["STAGE"])
models = os.environ["S7_BUNDLED_MODELS_STR"].split()

manifests_root = models_dir / "manifests" / "registry.ollama.ai" / "library"
blobs_root = models_dir / "blobs"
out_manifests = stage / "models" / "manifests" / "registry.ollama.ai" / "library"
out_blobs = stage / "models" / "blobs"
out_manifests.mkdir(parents=True, exist_ok=True)
out_blobs.mkdir(parents=True, exist_ok=True)

# Collect blob digests across all bundled models, deduped
blob_digests = set()
copied_manifests = []

for mref in models:
    if ":" not in mref:
        print(f"FAIL: model ref must include tag: {mref}", file=sys.stderr)
        sys.exit(2)
    name, tag = mref.split(":", 1)
    manifest_path = manifests_root / name / tag
    if not manifest_path.exists():
        print(f"FAIL: manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(2)

    # Copy the manifest itself
    out_path = out_manifests / name / tag
    out_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(manifest_path, out_path)
    copied_manifests.append(f"{name}:{tag}")

    # Parse manifest, collect blob digests
    with manifest_path.open() as f:
        m = json.load(f)
    if "config" in m and "digest" in m["config"]:
        blob_digests.add(m["config"]["digest"])
    for layer in m.get("layers", []):
        if "digest" in layer:
            blob_digests.add(layer["digest"])

# Copy each unique blob (digest format: sha256:hex)
copied_blobs = 0
total_bytes = 0
for digest in sorted(blob_digests):
    if not digest.startswith("sha256:"):
        print(f"FAIL: unexpected digest format: {digest}", file=sys.stderr)
        sys.exit(2)
    # Ollama stores blobs as sha256-XXXX (dash, not colon)
    blob_filename = digest.replace(":", "-", 1)
    src = blobs_root / blob_filename
    if not src.exists():
        print(f"FAIL: blob missing: {src}", file=sys.stderr)
        sys.exit(2)
    dst = out_blobs / blob_filename
    shutil.copy2(src, dst)
    copied_blobs += 1
    total_bytes += dst.stat().st_size

print(f"OK: {len(copied_manifests)} manifests, {copied_blobs} unique blobs, {total_bytes / (1024*1024):.0f} MiB total")
print(f"manifests: {', '.join(copied_manifests)}")
PY
    models_total=$(du -sh "$STAGE/models" | awk '{print $1}')
    ok "models bundled (total $models_total)"

    # Generate a models manifest the inner installer reads
    {
        printf '{"version": 1, "ollama_models_dir_dest": "~/.ollama/models", "models": [\n'
        first=1
        for mref in "${S7_BUNDLED_MODELS[@]}"; do
            [ $first -eq 0 ] && printf ',\n'
            printf '  {"ref": "%s"}' "$mref"
            first=0
        done
        printf '\n]}\n'
    } > "$STAGE/models.manifest.json"
    ok "models.manifest.json generated"
else
    info "No model bundling (use --with-models to bundle 4 ollama models)"
fi

# 4. Manifest with per-artifact sha256
info "Generating manifest.json"
{
    printf '{\n'
    printf '  "version": 1,\n'
    printf '  "build_date": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "repo_commit": "%s",\n' "$(cd "$REPO_DIR" && git rev-parse HEAD 2>/dev/null || echo unknown)"
    printf '  "repo_branch": "%s",\n' "$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    printf '  "pass": 1,\n'
    printf '  "artifacts": {\n'
    first=1
    for f in repo.tar.zst preflight.sh inner.sh; do
        h=$(sha256sum "$STAGE/$f" | awk '{print $1}')
        s=$(stat -c%s "$STAGE/$f")
        [ $first -eq 0 ] && printf ',\n'
        printf '    "%s": {"sha256": "%s", "bytes": %d}' "$f" "$h" "$s"
        first=0
    done
    printf '\n  }\n}\n'
} > "$STAGE/manifest.json"
ok "manifest.json generated"

# ── Build the payload tar.zst ───────────────────────────────────────
section "Building payload archive"
PAYLOAD="$STAGE/payload.tar.zst"
PAYLOAD_FILES=(manifest.json inner.sh preflight.sh repo.tar.zst)
if [ "$WITH_IMAGES" -eq 1 ]; then
    PAYLOAD_FILES+=(images images.manifest.json)
fi
if [ "$WITH_MODELS" -eq 1 ]; then
    PAYLOAD_FILES+=(models models.manifest.json)
fi
# Use a lower zstd level when bundling images or models — they're
# already heavily compressed (oci-archive / gguf) and -19 wastes
# minutes for marginal gains. -3 is fast and adds ~5% overhead.
ZSTD_LEVEL=19
[ "$WITH_IMAGES" -eq 1 ] || [ "$WITH_MODELS" -eq 1 ] && ZSTD_LEVEL=3
tar -C "$STAGE" -cf - "${PAYLOAD_FILES[@]}" \
    | zstd -T0 -${ZSTD_LEVEL} --quiet -o "$PAYLOAD"
payload_size=$(du -sh "$PAYLOAD" | awk '{print $1}')
ok "payload.tar.zst built ($payload_size)"

PAYLOAD_HASH=$(sha256sum "$PAYLOAD" | awk '{print $1}')
ok "payload sha256: $PAYLOAD_HASH"

# ── Concatenate header + payload ────────────────────────────────────
section "Assembling installer"
mkdir -p "$(dirname "$OUTPUT")"

# Substitute the manifest hash placeholder in the header
HEADER="$STAGE/header.patched.sh"
sed "s|__S7_MANIFEST_SHA256_PLACEHOLDER__|${PAYLOAD_HASH}|" \
    "$SCRIPT_DIR/installer-header.sh" > "$HEADER"

# Concatenate: patched header + marker line + payload
{
    cat "$HEADER"
    printf '\n__S7_PAYLOAD_BELOW__\n'
    cat "$PAYLOAD"
} > "$OUTPUT"
chmod +x "$OUTPUT"

output_size=$(du -sh "$OUTPUT" | awk '{print $1}')
ok "installer assembled: $OUTPUT ($output_size)"

# ── Optional self-check ─────────────────────────────────────────────
if [ "$DO_CHECK" -eq 1 ]; then
    section "Self-check (--check)"
    CHECK_DIR=$(mktemp -d -t s7-check-XXXXXX)
    info "extracting to $CHECK_DIR"
    if bash "$OUTPUT" --extract="$CHECK_DIR" >/dev/null 2>&1; then
        ok "extract succeeded"
        for f in inner.sh preflight.sh repo.tar.zst manifest.json; do
            if [ -f "$CHECK_DIR/$f" ]; then
                ok "  found $f"
            else
                fail "  missing $f after extract"
                rm -rf "$CHECK_DIR"
                exit 3
            fi
        done
        rm -rf "$CHECK_DIR"
        ok "self-check passed"
    else
        fail "self-check failed during extract"
        rm -rf "$CHECK_DIR"
        exit 3
    fi
fi

# ── Cleanup verification ────────────────────────────────────────────
# The trap at the top deletes $STAGE on exit. Here we verify it
# actually went and report any orphan staging dirs from prior runs
# so they don't accumulate and silently consume disk.
section "Cleanup verification"
orphan_count=$(find "$REPO_DIR/dist/.build-tmp" -maxdepth 1 -type d -name 'stage-*' 2>/dev/null | wc -l)
if [ "$orphan_count" -gt 1 ]; then  # >1 because our current STAGE is still there until trap fires
    warn "$((orphan_count - 1)) orphan stage dir(s) from prior runs:"
    find "$REPO_DIR/dist/.build-tmp" -maxdepth 1 -type d -name 'stage-*' \
        -not -path "$STAGE" 2>/dev/null | while read -r o; do
        sz=$(du -sh "$o" 2>/dev/null | awk '{print $1}')
        info "  $o ($sz) — consider 'rm -rf' if you don't need it"
    done
else
    ok "no orphan stage dirs"
fi

# ── Done ────────────────────────────────────────────────────────────
section "Done"
echo
echo "  ${GREEN}Installer ready:${RESET}"
echo "    file:  $OUTPUT"
echo "    size:  $output_size"
echo "    sha256: $(sha256sum "$OUTPUT" | awk '{print $1}')"
echo
echo "  Test it (without installing) with:"
echo "    bash $OUTPUT --dry-run"
echo "    bash $OUTPUT --extract=/tmp/s7-extract-test"
echo
