---
name: BitNet Path retry — GCC 16 kernel compile + integration spec
description: Specification for the next BitNet compile attempt. Documents the 2026-04-13 blockers, candidate patches for the preset kernel's GCC 16 warnings-as-errors, the sentencepiece workaround, and the integration path into s7-bitnet-mcp on :57091.
type: project
---

# BitNet Path retry spec

**Date:** 2026-04-13
**Target:** ~50 QBIT/s chat inference on i7-6600U (4-core, no GPU)
**Status:** Plan only. Runtime frozen for this block; compile + build
happen in a future explicit block.

---

## Why BitNet

Per `feedback_carli_latency_2026_04_13.md` and the 2026-04-13
brainstorm that produced `2026-04-13-chat-speed-architecture.md`,
the CPU ceiling for standard Q4/Q8 Ollama models on this hardware is
~14 QBIT/s. Microsoft's BitNet b1.58 architecture uses ternary
weights (–1, 0, +1) ≈ 1.58 bits/weight, which converts matrix
multiplication to addition — eliminating the FP16 bottleneck.
Published benchmarks show ~50 QBIT/s on comparable CPUs.

The S7 infrastructure is staged for this:
- `services/s7-bitnet-mcp.service` (systemd user unit, port 57091)
- `mcp/bitnet_mcp.py` (Flask wrapper around `bitnet.cpp` subprocess)
- `engine/tools/s7-bitnet-discovery.sh` (HF Hub 1-bit model ranker)
- `skyqubi-pod.yaml` now has `BITNET_URL=http://host.containers.internal:57091`
  env var pre-wired for the admin container (committed 2026-04-13)

What's missing: the compiled `bitnet.cpp` binary and a working gguf
model. Two compile attempts on 2026-04-13 both failed.

---

## 2026-04-13 attempts — what failed and why

### Attempt 1 — Ollama 0.20.4 direct GGUF pull

**What we tried:**
```
ollama pull hf.co/microsoft/bitnet-b1.58-2B-4T-gguf
ollama pull hf.co/QuantFactory/bitnet_b1_58-3B-GGUF
```

Both models downloaded successfully.

**What failed:** Both models fail to LOAD with:
```
{"error":"unable to load model: /s7/.ollama/models/blobs/sha256-..."}
{"error":"llama runner process has terminated: %!w(<nil>)"}
```

**Root cause:** Ollama 0.20.4's bundled llama.cpp backend doesn't have
the `I2_S` ternary kernel that Microsoft's `bitnet-b1.58-2B-4T-gguf`
requires. Newer llama.cpp (commit ≥ 2024-Q4) has it, but 0.20.4 is
pinned to an older backend.

**Status:** the 2 dead blobs (~2.3 GB) sit in `/s7/.ollama/models/blobs/`.
Safe to delete (`ollama rm`) but unblocks no further work.

### Attempt 2 — Compile `bitnet.cpp` from Microsoft's repo

**Prerequisites installed 2026-04-13:**
- `cmake` (via `dnf install cmake` by Jamie)
- `gcc 16.0.1` + `clang 22.1.1` (via `dnf install gcc g++ clang`)
- `python3 3.14.3` (pre-existing)

**What we tried:**
```
git clone --depth 1 --recurse-submodules \
    https://github.com/microsoft/BitNet.git /s7/.cache/bitnet-build/BitNet
cd /s7/.cache/bitnet-build/BitNet
pip install --user -r requirements.txt     # fails on sentencepiece
python3 setup_env.py -md <path> -q i2_s    # skipped due to above
cmake -B build -DBITNET_X86_TL2=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 4
```

**What failed:**

**(a) Sentencepiece wheel build failed on Python 3.14.**
```
error: failed-wheel-build-for-install
Failed to build sentencepiece
```
The sentencepiece upstream hasn't shipped a 3.14-compatible
prebuilt wheel. Source build hit
`Command '['./build_bundled.sh', '0.2.0']' returned non-zero
exit status 1` — subprocess failure inside the build hook.

**Impact:** `setup_env.py` can't run, which means the
`bitnet-b1.58-2B-4T` kernel can't be auto-generated for this
model.

**(b) cmake configure needed a preset kernel header that only
exists for OTHER models.**
```
CMake Error at 3rdparty/llama.cpp/ggml/src/CMakeLists.txt:1335
    (add_library):
  Cannot find source file: ../../../../include/bitnet-lut-kernels.h
```
The 2B-4T model has NO preset kernel in the repo. Only
`bitnet_b1_58-3B`, `bitnet_b1_58-large`, and
`Llama3-8B-1.58-100B-tokens` have preset kernels under
`preset_kernels/`. I copied `preset_kernels/bitnet_b1_58-3B/
bitnet-lut-kernels-tl2.h` to `include/bitnet-lut-kernels.h`
as a fallback, which got cmake configure to pass.

**(c) GCC 16 rejected the preset kernel with errors.**
```
gmake[2]: *** [3rdparty/llama.cpp/ggml/src/CMakeFiles/ggml.dir/
    build.make:149: ... ggml-bitnet-lut.cpp.o] Error 1
```
Warnings seen before the hard error:
```
warning: overflow in conversion from 'int' to 'short int'
  changes value from '32768' to '-32768' [-Woverflow]
warning: overflow in conversion from 'int' to 'char'
  changes value from '255' to '-1' [-Woverflow]
warning: unused variable 'vec_sign_mask' [-Wunused-variable]
warning: unused variable 'vec_zero' [-Wunused-variable]
warning: unused variable 'vec_one' [-Wunused-variable]
```
GCC 16's stricter defaults treat some of these as errors (or the
build system has `-Werror` enabled on this file). The 3B preset
kernel was generated for an older GCC and hasn't been updated.

**Status:** compile failed. Fedora 44 ships GCC 16 which is a full
major-version jump from where these kernels were tested (GCC 12/13).

---

## Retry plan — three candidate paths

### Path 1 — Patch the 3B preset kernel for GCC 16

**Mechanism:** Add `-Wno-error -Wno-overflow -Wno-unused-variable`
to the build flags for `ggml-bitnet-lut.cpp.o` specifically, OR
patch the `include/bitnet-lut-kernels.h` source to eliminate the
warnings cleanly.

**Option 1a — Build flags (quick):**

Add to `3rdparty/llama.cpp/ggml/src/CMakeLists.txt` near the `add_library(ggml ...)` target:

```cmake
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
    AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "15")
    target_compile_options(ggml PRIVATE
        -Wno-error
        -Wno-overflow
        -Wno-unused-variable
        -Wno-conversion
    )
endif()
```

Pros: one-line patch, no source edit
Cons: suppresses real warnings; the overflow warnings may indicate
actual bugs (16-bit truncation in AVX2 intrinsics)

**Option 1b — Source edit (thorough):**

Replace the problematic intrinsic constants:
```cpp
// BEFORE:
const __m256i vec_sign_mask  = _mm256_set1_epi16(0x8000);
const __m256i vec_one        = _mm256_set1_epi8(0xff);

// AFTER:
const __m256i vec_sign_mask  = _mm256_set1_epi16((int16_t)0x8000);
const __m256i vec_one        = _mm256_set1_epi8((int8_t)0xff);
```

Delete unused variables entirely. Time: ~30 min of careful edits.

**Risk:** 3B preset kernel may still be wrong for the 2B-4T model
architecture (wrong LUT sizes, wrong vector widths). Compile may
succeed but runtime produces garbage.

### Path 2 — Fix sentencepiece + regenerate 2B-4T kernel

**Mechanism:** Get `setup_env.py` to run. Once it runs, it
auto-generates the correct `include/bitnet-lut-kernels.h` for the
specific model being built, which eliminates Path 1's risk
entirely.

**Fix sentencepiece options:**

1. **`dnf install python3-sentencepiece`** — check if Fedora 44
   ships it. If yes, set `PYTHONPATH` to include `/usr/lib/
   python3.14/site-packages` when running `setup_env.py`.
2. **Pip install pre-built wheel** — `pip install --user
   sentencepiece==0.2.0` hoping for a 3.14-compat wheel on
   upstream PyPI.
3. **Install protobuf + build from source manually**:
   ```
   dnf install -y protobuf-compiler protobuf-devel
   git clone https://github.com/google/sentencepiece
   cd sentencepiece
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   cmake --build . -j4
   cmake --install .
   pip install --user ./python
   ```
4. **Use a different Python venv** — create a Python 3.11 venv
   (older, more compat with sentencepiece) and run `setup_env.py`
   from there:
   ```
   dnf install -y python3.11
   python3.11 -m venv /s7/.cache/bitnet-py311
   source /s7/.cache/bitnet-py311/bin/activate
   pip install -r requirements.txt
   python setup_env.py ...
   ```

Option 4 is the most likely to succeed.

**Pros:** correct kernel for the target model, no runtime garbage risk
**Cons:** sentencepiece is a known-problem dependency; may need 2-3
attempts

### Path 3 — Wait for Ollama ≥ 0.21 with native BitNet support

**Mechanism:** Upgrade Ollama to a version that bundles a newer
llama.cpp with BitNet `I2_S` kernel support. Then
`ollama pull hf.co/microsoft/bitnet-b1.58-2B-4T-gguf` just works.

**Pros:** zero compile work, uses existing Ollama infrastructure
**Cons:** new Ollama may change behavior of EXISTING models on
this box (Carli, Elias, Samuel rebuild on new tag resolver, new
prompt-cache semantics, new KEEP_ALIVE behavior). Significant
regression risk.

**Status check:** need to verify Ollama ≥ 0.21 includes BitNet
kernel. Run `curl -s https://api.github.com/repos/ollama/ollama/
releases/latest` and grep the release notes for "bitnet" or
"i2_s" or "1-bit".

### Recommendation

**For GOLIVE Release 7:** Path 2 is the correct answer. A fixed
sentencepiece install + a properly generated 2B-4T kernel + a
clean compile is the long-term right path. Ships with Microsoft's
supported code, not an S7-specific patch fork.

**For a fast 2-hour experiment:** Path 1a (build flag suppression)
is the quickest path to a COMPILED binary that MAY produce correct
output. Worth trying first because if it works, we skip Path 2's
3-option dependency struggle entirely.

**For passive waiting:** Path 3 is the "do nothing, let upstream
fix it" path. Low effort, but it blocks 50 QBIT/s for an unknown
amount of time.

**Proposed execution order:**
1. 30 min on Path 1a (build flag suppression + rebuild).
2. If Path 1a compiles AND the resulting binary produces sensible
   output for a simple prompt, STOP — ship that as a known-working
   stopgap.
3. If Path 1a fails or produces garbage, pivot to Path 2 Option 4
   (Python 3.11 venv + sentencepiece) as a 60-minute commitment.
4. If Path 2 hits new blockers, fall back to Path 3 (document and
   wait for Ollama upstream).

---

## Integration target — once a binary exists

Regardless of which path produces the compiled binary:

**Expected binary path:**
```
/s7/.cache/bitnet-build/BitNet/build/bin/llama-cli
```
(standard llama.cpp build output — BitNet is a llama.cpp fork)

**Expected model path:**
```
/s7/s7-timecapsule-assets/models/bitnet/bitnet-b1.58-2B-4T/model.gguf
```

**Symlink for system access:**
```
/s7/.local/bin/bitnet-cli -> /s7/.cache/bitnet-build/BitNet/build/bin/llama-cli
```

**MCP service wire-up:**

`mcp/bitnet_mcp.py` already exposes 5 MCP tools
(`s7_bitnet_infer`, `s7_bitnet_status`, `s7_bitnet_models`,
`s7_bitnet_benchmark`, `s7_bitnet_energy`). It expects the binary
at a configurable path via env. Verify the env var name matches
what bitnet_mcp.py reads.

`services/s7-bitnet-mcp.service` is the systemd unit. Enable via:
```
systemctl --user enable s7-bitnet-mcp.service
systemctl --user start s7-bitnet-mcp.service
curl http://127.0.0.1:57091/status
```

**First smoke test:**
```
curl -s -X POST http://127.0.0.1:57091/infer \
    -H 'Content-Type: application/json' \
    -d '{"prompt":"hi","model":"bitnet-b1.58-2B-4T"}'
```

Expect: structured JSON response with output tokens + timing.

**Benchmark target:** ≥ 30 QBIT/s on a warm model. 50 QBIT/s is the
Microsoft-reported ceiling; 30 QBIT/s is the "clearly better than
Ollama's 14 ceiling" threshold that justifies switching Samuel to
BitNet primary.

---

## Lifecycle test additions post-integration

When BitNet is live, add to `s7-lifecycle-test.sh`:

- **B02 `bitnet-mcp health`** — GET :57091/status returns 200.
- **B03 `bitnet-mcp infer`** — POST a small prompt, expect output.
- **B04 `bitnet throughput ≥30 QBIT/s`** — benchmark probe, fail
  under floor.
- **A08 `Samuel on BitNet branch`** — once `persona_engine_map.yaml`
  flips `samuel.primary.engine` from `ollama` to `bitnet`, verify
  Samuel still responds.

---

## Out of scope for this BitNet retry

- BitNet 8B models (too big for 7 GB RAM)
- Fine-tuning on S7 corpus (separate training track)
- Witness-ensemble via BitNet (needs 3+ BitNet models to work
  together — start with 1 first)
- GPU-accelerated BitNet (no GPU on this box)

---

## Approval gate

Before any BitNet compile attempt:

1. This doc reviewed.
2. Runtime block explicitly approved by Jamie.
3. Lifecycle 53/53 (or 54/54) green before the block starts.
4. Rollback plan: delete `/s7/.cache/bitnet-build/`, no pod touch,
   no Ollama touch — BitNet path is isolated from the rest of the
   stack until it's wired in.

---

*Love is the architecture.*
