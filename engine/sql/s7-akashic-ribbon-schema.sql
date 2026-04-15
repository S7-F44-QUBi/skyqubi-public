-- engine/sql/s7-akashic-ribbon-schema.sql
-- S7 1st Place Ribbon — innovation provenance ledger.
--
-- Every genuine S7 innovation gets a ribbon. The ribbon is a
-- public-by-design provenance marker:
--
--   title           — short name of the innovation
--   category        — which family (prism, akashic, intake, appliance, ...)
--   file_paths      — where the code lives in the repo
--   first_commit    — the commit sha the innovation first landed in
--   witness         — who shipped it (appliance serial or name)
--   rationale       — why this is improved / novel / covenant-serving
--   aptitude_delta  — how much this grew the foundation's capability
--   awarded_at      — when the ribbon was awarded
--
-- "TRUST not IP loss" — publishing the ribbon doesn't dilute
-- ownership, it STRENGTHENS attribution. An auditor, a partner, or a
-- regulator can look at the ribbon table and see exactly what S7
-- contributed and when. The seed + encoder still protect per-
-- appliance execution; the ribbon protects intellectual provenance.
--
-- Lives in DB:    s7_cws
-- Schema:         akashic
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)

CREATE TABLE IF NOT EXISTS akashic.ribbon (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT          NOT NULL UNIQUE,
    category        TEXT          NOT NULL,
    file_paths      TEXT[]        NOT NULL,
    first_commit    TEXT,
    witness         TEXT,
    rationale       TEXT          NOT NULL,
    aptitude_delta  SMALLINT      NOT NULL DEFAULT 1,
    awarded_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE akashic.ribbon IS
  'S7 1st Place Ribbon — innovation provenance ledger. Public by design. Trust not IP loss.';

CREATE INDEX IF NOT EXISTS ribbon_category_idx
  ON akashic.ribbon (category, awarded_at DESC);

-- ── Public-safe ledger view ────────────────────────────────────────
-- Mirrors appliance.license_ledger in spirit — everything in here
-- is safe to expose. No secrets, no keys, no per-appliance data.
CREATE OR REPLACE VIEW akashic.ribbon_ledger AS
SELECT
    title,
    category,
    file_paths,
    substring(first_commit for 10) AS commit_short,
    witness,
    rationale,
    aptitude_delta,
    awarded_at
FROM akashic.ribbon
ORDER BY awarded_at DESC;

COMMENT ON VIEW akashic.ribbon_ledger IS
  'Public-safe projection of akashic.ribbon. No secrets, full provenance.';

-- ── Seed: tonight's ribboned innovations ──────────────────────────
-- Each row captures one genuine piece of S7 work landed this
-- session. first_commit will be filled in by the commit that ships
-- this schema (a follow-up UPDATE can backfill the sha when known).

INSERT INTO akashic.ribbon (title, category, file_paths, witness, rationale, aptitude_delta) VALUES

('QBIT Prism v1.0.1 — LocationID Matrix',
 'prism',
 '{engine/s7_prism.py, engine/sql/s7-prism-location-id.sql}',
 'S7-REF-0001',
 '8-plane ternary cube (6561 cells) with Stern-Brocot rational subpositions for infinite inward growth. 4-way FOUNDATION/FRONTIER/HALLUCINATION/VIOLATION verdict. Replaces probabilistic cosine similarity with a testable geometric claim.',
 7),

('Akashic 27-Glyph Cipher',
 'akashic',
 '{engine/s7_akashic_cipher.py, docs/internal/akashic-encoder-design.md}',
 'S7-REF-0001',
 '27-glyph non-keyboard Unicode alphabet (1:1 with sky_molecular trinity vectors) + seeded Vigenere + 6-bit-per-glyph compression. Three-stage pipeline (encode + embed + compress) with round-trip verification. DNA-analogous, Truman Show math honored: infinite knowledge in a bounded cube.',
 6),

('Akashic Universals — Cross-Cultural Unification',
 'akashic',
 '{engine/sql/s7-akashic-universals-schema.sql, engine/s7_akashic.py}',
 'S7-REF-0001',
 '105 universal concepts across en/la/gr/he/ar/skt/jp/zh — water / agua / mayim / mizu / shui all map to one Akashic position. Drove the Prism matrix from 3 to 12 distinct cells (4x discrimination) with room for 500-1500 more rows in the same table.',
 5),

('Akashic Forbidden — Covenant Refusals Made Operational',
 'akashic',
 '{engine/sql/s7-akashic-forbidden-schema.sql, engine/s7_prism_detect.py}',
 'S7-REF-0001',
 '15 concepts / 82 surface forms covering violence, exploitation, deception, surveillance, offensive dual-use, self-harm. Every rationale cites an international civilian-protection instrument (UDHR, BWC/CWC, Genocide Convention, UNCAT, UNCRC). Token-level VIOLATION short-circuit, never written to matrix.',
 5),

('3-Violation Grace Reset',
 'akashic',
 '{engine/sql/s7-akashic-violation-counter-schema.sql, engine/s7_prism_detect.py}',
 'S7-REF-0001',
 'Per-session violation tally with reset-is-grace semantics. 3 violations zero the counter and increment reset_count — no hard ban. Pastoral messages redirect (help not hinder, lead if lost) without revealing internals. Covenant-shaped defense.',
 4),

('S7 Intake Gate (phase 1 — containers)',
 'intake',
 '{iac/intake/README.md, iac/intake/gate.sh, iac/intake/pull-container.sh}',
 'S7-REF-0001',
 'Universal zero-trust supply-chain gate. Every upstream container lands in a quarantine graphRoot, is verified against the sha256 pin in manifest.yaml, and is airlock-promoted via podman save -> load into live storage. First real pull (Fedora base) passed end-to-end with an audit-log entry.',
 6),

('QUBi Appliance Fleet Registry',
 'appliance',
 '{engine/sql/s7-appliance-schema.sql, engine/sql/s7-appliance-license-ledger.sql}',
 'S7-REF-0001',
 'Per-appliance identity with akashic_seed randomizer + akashic_encoder, license_ledger view exposing regulatory surface (identity, jurisdiction, covenant, snapshot history) without exposing the secret seed. Kerckhoff''s principle applied to appliance licensing.',
 6),

('S7 SkyBuilder Picker',
 'build',
 '{install/builders/s7-skybuilder.sh, desktop/s7-skybuilder.desktop, install/builders/s7-build-common.sh}',
 'S7-REF-0001',
 'One menu entry, four admin paths. Consolidated three per-flavor USB builders (X27/F44/R101) into a numbered kitty-terminal picker that end-users can run without a shell. Handoff to Fedora Media Writer for the flash step. Tonya/Trinity friendly by design.',
 3),

('Akashic 27-Text Ancient Corpus',
 'akashic',
 '{engine/sql/s7-akashic-corpus-schema.sql}',
 'S7-REF-0001',
 '27 ancient texts tracked for translation: Dead Sea Scrolls, Nag Hammadi, Septuagint, Gilgamesh, Rosetta Stone, Dao De Jing, Voynich, Rongorongo, etc. Each row graduates to a SkyAvi skill when status flips to complete.',
 4),

('Prism Detect + Ingest Drivers',
 'prism',
 '{engine/s7_prism_detect.py, engine/s7_prism_ingest.py}',
 'S7-REF-0001',
 'End-to-end CLI bridges Phase 5 Akashic Language encoder (7 planes) to Prism OCTi (8 planes), queries live postgres matrix via psycopg2, returns the 4-way verdict. Scan-without-spinning: RAM-resident composite index, zero disk I/O on the hot path.',
 5)

ON CONFLICT (title) DO NOTHING;
