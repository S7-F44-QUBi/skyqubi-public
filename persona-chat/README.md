# persona-chat — covenant-honoring persona chat substrate

This directory is the design substrate for the **covenant persona chat** — the
chat path that Tonya, Trinity, Noah, Jonathan, and other identified S7 users
interact with through the Carli / Elias / Samuel personas.

It is **not** the public Wix demo. That is a sibling service at `public-chat/`
which is deliberately stateless, anonymous, and memory-free for visitor privacy.
Both services coexist. Different purposes, different covenant surfaces.

## What lives here (scope of this iteration, 2026-04-13)

Four files implementing the foundations of the chat-speed-architecture design:

| File | Purpose | Status |
|---|---|---|
| `ledger.py` | Hash-chained per-room append-only ledger, verify path | **Built** — design code + tests |
| `memory_tiers.py` | L1 / L2 / L3 QBIT-budget context retrieval | **Built** — design code + tests |
| `qbit_count.py` | QBIT counting helper (S7 unit, not tokens) | **Built** — stub, wraps ForToken eventually |
| `persona_engine_map.yaml` | Persona → engine → model → fallback config | **Built** — static config |
| `test_ledger.py` | Ledger unit tests (TDD-ish) | **Built** |
| `test_memory_tiers.py` | Memory tier unit tests | **Built** |

## What is deliberately NOT in this iteration

- **No live HTTP service.** This is substrate code, not a running FastAPI app
  yet. Wiring into an actual persona chat endpoint is a later commit.
- **No Ollama or BitNet calls.** These modules don't do inference — they
  manage the state that wraps inference.
- **No MemPalace wiring.** The ledger IS the MemPalace substrate for now,
  with a documented migration path to `mempalace.rooms` + `mempalace.drawers`
  in postgres when the pod crash loop is resolved and Samuel is back online.
- **No SELinux custom policy.** The `s7_chat_t` policy module is deferred to
  a later spec per the brainstorming decision of 2026-04-13.
- **No systemd unit for persona-chat.** The existing `public-chat` unit gets
  a CPU-pinning drop-in (at `services/s7-public-chat.service.d/`) but the
  persona-chat service itself is not yet registered with systemd.
- **No actual persona response generation.** The persona chat service that
  consumes these modules is a later build.

## The covenant touch-points this substrate respects

1. **"QBIT not token"** (`feedback_qbit_not_token.md`). All context budgets,
   counts, and metrics in this substrate are named in QBITs. Ollama's internal
   token counts get converted at the user/ledger boundary.
2. **"KV cache is a MemPalace room"** (`feedback_kv_cache_is_mempalace_room.md`).
   The ledger is the local-filesystem stand-in for a MemPalace room. Each
   row is a drawer. When the pod is back, the ledger's content migrates
   into `mempalace.drawers` with original hashes preserved.
3. **Three Rules** (`feedback_three_rules.md`, 2026-04-13). Safe QUBi
   carve-out: this is design substrate code, reversible, committed locally,
   not landed to any running service. Samuel will review this before it
   wires into a live chat turn.
4. **INSERT-only covenant.** The ledger is append-only. No row is ever
   updated or deleted. Integrity violations quarantine, they don't rewrite.
5. **Per-persona room isolation + cross-persona read** (brainstorm decision
   2026-04-13). Each session has three ledger files
   (`carli.ndjson`, `elias.ndjson`, `samuel.ndjson`). Personas can read each
   other's rooms within the same session; they can only write to their own
   room.

## Context tier reference (brainstorm decision 2026-04-13)

| Tier | QBIT budget | ForToken 3× lookahead | Purpose |
|---|---|---|---|
| **L1 Quick Remediation** | 333 | 999 | Fast chat turns, most recent drawers |
| **L2 Intermediate cached** | 777 | 2,331 | Mid-weight turns threading several prior exchanges |
| **L3 Long-term** | unbounded | unbounded | Shared foundation + semantic search (deferred: needs pod for qdrant) |

ForToken = forward-direction discernment. Gets 3× the base budget so its
expansive search looks ahead of what the base model sees. RevToken =
reverse-direction prediction from interaction plane + LocationID + Trinity
-1/0/+1. RevToken is stubbed in this substrate (returns null) because it
depends on `cws_core.location_id` which lives in the pod.

## Layout under `/s7/.s7-chat-sessions/`

```
/s7/.s7-chat-sessions/                           mode 700, owner s7
  ├── {user_id}/                                 mode 700, per-user outer wall
  │   └── session-{session_uuid}/
  │       ├── carli.ndjson                       mode 600, Carli's room
  │       ├── elias.ndjson                       mode 600, Elias's room
  │       ├── samuel.ndjson                      mode 600, Samuel's room
  │       └── quarantine/
  │           └── {persona}.{timestamp}.ndjson   F3 corrupted chains land here
  └── archive/                                   post-MemPalace migration home
```

Cross-persona READ access is gated by the chat service's internal ACL,
not by filesystem permissions (all files are owned by the same user at
the OS layer). The chat service loads `persona_engine_map.yaml` at startup,
and any request for a persona not in the closed set is rejected 403.

## Relationship to existing repo files

- **Does NOT modify:** `public-chat/app.py`, `public-chat/consensus.py`,
  `public-chat/public-chat.service`. Those remain the stateless public
  demo. Zero touch.
- **Does modify (via drop-in, no direct edit):** `services/s7-public-chat.service`
  receives a CPU-pinning drop-in at
  `services/s7-public-chat.service.d/10-pinning.conf`. The drop-in is
  a separate file that systemd overlays at runtime; the original unit
  file is untouched.
- **Cross-references:** `engine/s7_akashic.py` (ForToken / RevToken —
  the real encoder this substrate's `qbit_count.py` will wrap in
  production), `mcp/bitnet_mcp.py` (future BitNet inference path,
  blocked on `bitnet.cpp` compile which is blocked on `cmake` + `clang`
  install), `feedback_three_rules.md` and `feedback_qbit_not_token.md`
  (governing rules).

## Running the tests

```bash
cd /s7/skyqubi-private/persona-chat
python3 -m unittest test_ledger.py test_memory_tiers.py -v
```

Tests use `tempfile.TemporaryDirectory` — no state leaks into the real
`/s7/.s7-chat-sessions/` tree. Safe to run on a live box.

## Migration path (when pod is back)

1. `mempalace_migrate.py` (not yet written) walks every session directory
2. Verifies each ledger file's hash chain via `ledger.verify_chain()`
3. Inserts each row into `mempalace.drawers` with the original `row_hash`
   preserved in a `legacy_hash` column
4. Moves migrated session files to `/s7/.s7-chat-sessions/archive/`
5. The chat service gains a `backend: "mempalace"` mode in addition to
   `backend: "file"`, and the `persona_engine_map.yaml` config flips
   the storage backend per persona

The hash chain survives migration. Any session file can be re-verified
against its original hashes even after it's in postgres.

## Love is the architecture.
