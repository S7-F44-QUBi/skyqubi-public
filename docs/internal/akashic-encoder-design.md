# S7 Akashic Encoder / Embedder / Compressor

**Status:** design + phase-1 implementation landing this session
**Lives at:** `engine/s7_akashic.py`
**Skills:** `engine/s7_skyavi_skills.py` — new category `akashic`
**Patent base:** TPP99606 — 123Tech / 2XR, LLC

## The point in one paragraph

Each S7 QUBi appliance carries its own Akashic cipher, seeded at
registration and bound by its row in `appliance.appliance`. Any
payload — an update, a message, a configuration blob — flows through
a three-stage pipeline: **encode** (plaintext → 27-glyph Akashic
sequence), **embed** (glyphs → sky_molecular trinity vectors),
**compress** (trinity vectors → packed bytes). Same pipeline in
reverse to read it. Because the encode stage is keyed by the
appliance's `akashic_seed`, two appliances receiving logically
identical payloads see byte-different ciphertexts — cross-appliance
update correlation is mechanically blocked, which is the whole point
of the randomizer Jamie put in the schema.

## Five design principles

| # | Principle | What it gives us |
|---|---|---|
| 1 | **27 glyphs, not 26** | Alphabet size = $3^3$ = 27 trinity positions. Each glyph maps 1:1 to a row in `sky_molecular.vector_names` (FERTILE, RESURRECTION, PORTAL_OPEN, …). The alphabet *is* the trinity. |
| 2 | **Not keyboard-bound** | Glyphs are chosen from across the Unicode space — geometric shapes, mathematical operators, musical symbols. None of them are on QWERTY. You can't type the cipher; you have to compute it. |
| 3 | **Encoder + embedder + compressor** | Three independent stages. Swap the compressor without touching the encoder. Rotate the encoder without losing old data. Each stage is testable on its own. |
| 4 | **Decimal positions = infinite capacity** | Sequence position is a rational number, not an integer. Inserting between positions 2 and 3 gives you 2.5. Between 2 and 2.5 gives you 2.25. Forever. The alphabet stays tiny; the address space is unbounded. |
| 5 | **DNA analogy** | DNA has 4 bases and stores every human being. Information density comes from *ordering* and *context*, not from alphabet size. 27 Akashic glyphs with decimal positioning gives the same lesson: small alphabet, huge expressive power. |

## The 27-glyph alphabet

Each glyph occupies one of the 27 trinity positions
$(m, p, d) \in \{-1, 0, +1\}^3$. Mapping uses the same ordering as
`sky_molecular.vector_names` so the embedder is a single table
lookup.

```
(m, p, d)     name             glyph   code point
-----------   --------------   -----   ----------
(-1,-1,-1)    STASIS           ▼       U+25BC
(-1,-1, 0)    SINKING          ◢       U+25E2
(-1,-1,+1)    RESURRECTION     ↟       U+219F
(-1, 0,-1)    DANGER           ⚠       U+26A0
(-1, 0, 0)    DISCERNMENT      ◌       U+25CC
(-1, 0,+1)    RECOVERING       ↥       U+21A5
(-1,+1,-1)    TOWER            ⌘       U+2318
(-1,+1, 0)    SURFACING        ◨       U+25E8
(-1,+1,+1)    REBUILDING       ⇗       U+21D7
( 0,-1,-1)    DOUBT            ⍉       U+2349
( 0,-1, 0)    DRIFT            ·       U+00B7
( 0,-1,+1)    HOPE             ↯       U+21AF
( 0, 0,-1)    PORTAL_CLOSE     ◯       U+25EF
( 0, 0, 0)    MAX_UNCERTAINTY  ✧       U+2727
( 0, 0,+1)    PORTAL_OPEN      ◉       U+25C9
( 0,+1,-1)    FADING           ⌇       U+2307
( 0,+1, 0)    PRESENT_ONLY     ✦       U+2726
( 0,+1,+1)    EMERGING         ⇡       U+21E1
(+1,-1,-1)    FALLING          ↘       U+2198
(+1,-1, 0)    MEMORY_ONLY      ❖       U+2756
(+1,-1,+1)    RETURNING        ⤴       U+2934
(+1, 0,-1)    WARNING          ⚑       U+2691
(+1, 0, 0)    ROOTED           ❀       U+2740
(+1, 0,+1)    FERTILE          ✺       U+273A
(+1,+1,-1)    CRESTING         ⇘       U+21D8
(+1,+1, 0)    GROWING          ✢       U+2722
(+1,+1,+1)    ABUNDANT         ✸       U+2738
```

None of these are on a US keyboard. All of them are valid Unicode.
Every one maps to a trinity vector the rest of S7 already understands.

## Stage 1 — ENCODE

```
plaintext (UTF-8 bytes) + akashic_seed → glyph_sequence
```

Algorithm: **seeded Vigenère over base-27.** The seed is hashed into
a length-27 permutation of the alphabet indices. For each input byte
at integer position $i$, the output glyph is:

$$
\text{glyph}[i] = \text{alphabet}[\, (byte_i + \text{perm}[i \bmod 27]) \bmod 27 \,]
$$

Reversible iff you know the seed. No seed → no plaintext.

**Why seeded Vigenère and not AES?** AES is the right tool for
*secrecy*. Akashic's job is *differentiation* — making sure no two
appliances receive the same bytes for the same logical update. A
seeded permutation is cheap, deterministic, per-appliance unique,
and deliberately lightweight so the rest of the pipeline runs fast.
Use AES around it if you need secrecy; Akashic is not a replacement.

## Stage 2 — EMBED

```
glyph_sequence → trinity_sequence (list of (m, p, d))
```

Table lookup. O(1) per glyph. No seed. No secret. Purely geometric —
glyph → its trinity position in sky_molecular space. This is the
stage that lets downstream S7 services (MemPalace, molecular bonds,
discernment) *reason over the payload without decoding it*. You can
ask questions like "is this payload mostly in the +1 destiny half of
space?" without ever recovering plaintext.

## Stage 3 — COMPRESS

```
trinity_sequence → packed bytes
```

Each trinity value is one of $\{-1, 0, +1\}$ — that's 2 bits per
axis, 6 bits per glyph. The compressor packs 4 glyphs (24 bits) into
3 bytes. A 12-glyph message becomes 9 bytes, not 48. For longer
sequences we apply LZ-style dictionary compression on top, but the
6-bits-per-glyph packing is the floor.

**Decimal positions:** the packed output is prefixed with a compact
position header so out-of-order insertions are legal. A standard
message has positions $[1, 2, 3, \ldots]$ and the header is empty. A
message that was inserted between positions 5 and 6 has positions
$[5.5]$ and carries a one-glyph delta instead of re-shipping the
whole document. This is how the decimal-position rule turns into
wire savings: *you only ship the new positions, not the ordering.*

Infinite subdivision means an appliance can receive an unbounded
stream of small patches without ever running out of address space.
DNA-like: each new base slots into the sequence by position, the
overall structure grows without bound, the alphabet stays at 27.

## Round trip

```
plaintext
  └─encode(seed)─▶ glyph_sequence
                    └─embed─▶ trinity_sequence
                               └─compress─▶ bytes ─ network/disk ─▶
                                             ▼
                                          decompress
                                             ▼
                                          deembed
                                             ▼
                                          decode(seed)
                                             ▼
                                          plaintext
```

Any stage can be tested in isolation. The full round trip is the
gate a payload must pass through before it's considered Akashic-clean.

## Skills landing in this session

New category `akashic` in `engine/s7_skyavi_skills.py`:

| Skill | What it does |
|---|---|
| `akashic alphabet` | Print the 27 glyphs and their trinity mappings |
| `akashic encode` | Encode a plaintext through this appliance's cipher |
| `akashic decode` | Decode a ciphertext back to plaintext |
| `akashic verify` | Round-trip test: encode → decode → assert equal |
| `akashic seed` | Generate a fresh seed (hex) for a new appliance |
| `akashic embed` | Show the trinity-vector embedding of a glyph sequence |
| `akashic compress stats` | Report raw / packed / ratio for a sample payload |

## Phase 2 (not tonight, but pinned)

1. **Decimal position class** — `DecimalPositions` with `insert_between(a, b) → midpoint_rational`. Tonight the module supports integer positions; decimal positions are opt-in via the position header.
2. **LZ dictionary compression** on top of the 6-bits-per-glyph packing, once we have enough traffic to learn a dictionary from.
3. **Vector-space reasoning API** — `query_embed(trinity_seq, "is mostly positive destiny?")` so downstream services can operate over embedded payloads without decoding.
4. **Multi-encoder versioning** — store `encoder.version` in each `appliance.snapshot` so a version bump doesn't break old snapshots.

Jesus holds the watch. The witnesses watch each other. S7 holds the cipher.
