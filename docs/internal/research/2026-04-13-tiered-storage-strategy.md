# S7 Tiered Storage Strategy — Speed Hierarchy for the Prism Matrix

**Jamie's directive, 2026-04-13:**
*"NVMe over TCPIP, U.2, GPU, RAM Memory Persistent vs Zcach / linux
swap. It's important to stage tiering where speed is critical."*

The Prism matrix is growing fast (30 k rows tonight, unbounded
going forward). Not every row deserves the same speed class. The
CWS QUANT*i* tiers (`untrusted → probationary → trusted → anchored`)
already classify tokens by TRUST; this doc adds the parallel
classification by SPEED, and maps the two onto real hardware.

---

## The speed hierarchy (fastest first)

| Tier | Medium | Latency | Typical size | Persistence | S7 role |
|---|---|---|---|---|---|
| **T0** | CPU L1–L3 cache | 1–20 ns | 32 KB – 64 MB | volatile | hot Python variables + psycopg2 prepared statements |
| **T0.5** | **GPU VRAM** | 20–500 ns | 8–80 GB | volatile | massively parallel witness inference (future: CUDA kernel that scores N prisms against M cells in one pass) |
| **T1** | **DRAM (Redis in pod)** | 50 ns – 1 µs | 4–128 GB | volatile, ephemeral | **anchored tier hot cache** — every anchored LocationID cached by cell key |
| **T1.5** | **Persistent RAM (Optane / CXL)** | 100 ns – 1 µs | 128 GB – 1 TB | power-safe | **trusted tier warm cache** — survives reboots, no warm-up needed |
| **T2** | **zram / zcache (compressed RAM)** | 500 ns – 5 µs | 4–32 GB compressed | volatile | **probationary tier** — cheap to hold, 3× compression ratio |
| **T3** | **Local NVMe (U.2 or M.2)** | 10–100 µs | 500 GB – 15 TB | persistent | **full matrix + postgres shared_buffers + WAL** (current production) |
| **T4** | **NVMe over TCP/IP** | 100 µs – 1 ms | petabyte-scale | persistent, shared | **multi-appliance shared matrix** — Prism state visible to every QUBi on the LAN without replication |
| **T5** | **Linux swap (SATA SSD or HDD)** | 1 ms – 100 ms | variable | persistent | overflow only; avoid the RAG hot path |

**Rule:** *a token's speed tier is determined by its CWS trust tier
plus its dissolution_count.*

```
CWS tier       → speed tier
─────────────────────────────
anchored       → T0.5 / T1 (GPU VRAM or Redis)
trusted        → T1.5 / T2 (PRAM or zram)
probationary   → T2 / T3  (zram or NVMe)
untrusted      → (not stored)
non-consensus  → T3 (NVMe, postgres shared_buffers)
```

Dissolution_count modulates WITHIN a tier:
- `anchored + dissolution_count > 50` → GPU VRAM (highest priority)
- `anchored + dissolution_count > 20` → Redis
- `anchored + dissolution_count > 7` → both (replicated)
- `trusted + dissolution_count 3..6` → Persistent RAM
- `trusted + dissolution_count 0..2` → zram

---

## Phase 1 — postgres tier only (LANDED tonight)

  - `cws_tier` column on `cws_core.location_id` (untrusted,
    probationary, trusted, anchored)
  - Partial index `location_id_cws_tier_idx` on
    `(cws_tier, dissolution_count DESC) WHERE cws_tier IN
    ('trusted','anchored')`
  - Function `cws_core.fast_lookup_cell(...)` that tries anchored
    first, then trusted, then anything
  - `cws_core.auto_promote_tier()` trigger — `trusted → anchored`
    when `dissolution_count >= 7`
  - `dissolution_count` column with its own partial index

The partial index is the whole win: postgres scans only the
anchored B-tree partition (hundreds of rows max), which fits in
shared_buffers indefinitely. Lookup latency ≈ 100 µs end-to-end,
which puts T3 NVMe + postgres in the ~T2 zone for anchored reads.

---

## Phase 2 — Redis hot cache (NEXT COMMIT)

The s7-skyqubi pod already has a `s7-skyqubi-s7-redis` container
running but it's currently unused by the matrix. Wiring it:

```
# On anchored emerge / promotion:
redis.HSET("s7:prism:anchored", cell_key, row_id)
redis.EXPIRE("s7:prism:anchored", 604800)  # 7-day TTL, refreshed

# On lookup:
row_id = redis.HGET("s7:prism:anchored", cell_key)
if row_id:
    return row_id  # T1 hit, ~50 µs
else:
    return fast_lookup_cell(...)  # T3 fallback, ~100 µs
    # populate redis on the way back up
```

Cell key = 8-char string made from the 8 ternary directions, e.g.
`"100-1010-1"`. Keeps the hash short and human-readable.

Pinned: `engine/s7_prism_cache_redis.py` + two new skills
(`prism cache stats`, `prism cache warm`).

---

## Phase 3 — Persistent RAM (when hardware is available)

If the QUBi appliance ships with an Optane DIMM or a CXL-attached
PMem module, the trusted tier goes there instead of zram. The
migration is:

1. Mount PMem as `/mnt/s7-pmem` with `ext4 -o dax`
2. Create a postgres tablespace `s7_pmem_tablespace` on
   `/mnt/s7-pmem`
3. Move the `trusted` tier partition to that tablespace via
   partitioned table inheritance
4. No application-level change — postgres handles the move

The current reference appliance (Dell laptop) has no PMem so
Phase 3 is blocked on hardware.

---

## Phase 4 — GPU VRAM for parallel witness inference

The highest-speed path is a CUDA kernel that scores many prism
projections against many anchored cells in parallel. Shape:

```
kernel input  : N witness prisms (8×N ternary) +
                M anchored cells (8×M ternary, loaded once to VRAM)
kernel output : N × M agreement scores, reduced to one converged
                cell per prism set (or NULL)
```

At M=10 000 anchored rows and N=9 witnesses, this runs in ~100 µs
on any modern GPU. The kernel never leaves VRAM, which puts the
whole Prism detect + verdict path at T0.5.

Pinned: `engine/cuda/s7_prism_kernel.cu` + Python wrapper.
Blocked on dependency decision (pycuda vs cupy vs torch).

---

## Phase 5 — NVMe over TCP for multi-appliance matrix sharing

Once there is more than one QUBi appliance in a covenant group
(home + ministry, or two siblings on separate machines), the
Prism matrices should share the same anchored tier without
re-witnessing. NVMe/TCP is the right path:

1. One appliance exports its NVMe (or a subset) via
   `nvme-tcp-target` (Linux kernel module, already mainlined)
2. Other appliances mount the remote NVMe over TCP and read the
   shared postgres tablespace
3. Writes still go through the home appliance (single writer)
4. Reads are sub-millisecond on any appliance in the LAN

The alternative (postgres logical replication) is slower and
drifts; NVMe/TCP gives blockdevice-level consistency at line rate.

Blocked on: more than one QUBi appliance existing.

---

## Phase 6 — linux swap as overflow (never the hot path)

Swap is the last resort. If matrix pressure exceeds RAM + PMem +
NVMe, let the kernel swap out cold probationary rows. But never
let anchored or trusted rows touch swap — pin them with
`mlock` + `vm.swappiness=1`.

---

## Summary

| Phase | Status | Blocker | Delivers |
|---|---|---|---|
| 1. postgres tier | **landed tonight** | — | anchored/trusted partial indexes, auto-promote trigger, fast_lookup_cell |
| 2. Redis hot cache | next commit | — | T1 DRAM for anchored |
| 3. Persistent RAM | pinned | hardware | T1.5 PMem for trusted |
| 4. GPU VRAM kernel | pinned | dependency decision | T0.5 parallel witness inference |
| 5. NVMe/TCP sharing | pinned | multi-appliance deployment | shared matrix across covenant group |
| 6. swap overflow | permanent guard | — | mlock on anchored/trusted |

**The principle Jamie named:** stage tiering where speed is
critical. Every tier has a cost, every tier has a purpose, and
trust determines which tier a token earns.
