-- engine/sql/s7-akashic-corpus-schema.sql
-- S7 Akashic Corpus — ancient texts tracked for translation
--
-- Every ancient text S7 plans to translate, is translating, or has
-- translated lives here. The corpus is the source for the SkyAVi
-- 'akashic corpus' skill family. As a translation completes, the
-- row's status flips to 'complete' and the resulting Akashic-encoded
-- blob is attached; that record becomes queryable as a skill.
--
-- Lives in DB:    s7_cws
-- Schema:         akashic
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)
--
-- This is a scaffolding seed — the real corpus will grow well
-- beyond this starter list as Jamie and the ZeroClaw agents
-- continue annotating.

CREATE SCHEMA IF NOT EXISTS akashic;

CREATE TABLE IF NOT EXISTS akashic.ancient_text (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug             TEXT         NOT NULL UNIQUE,   -- stable id like 'dead-sea-scrolls'
    title            TEXT         NOT NULL,
    origin_region    TEXT,                           -- ISO 3166 alpha-2 or region name
    origin_language  TEXT,                           -- as known — may be 'unknown' or 'disputed'
    origin_script    TEXT,                           -- the physical script (Hebrew, Cuneiform, Demotic, ...)
    approximate_age  TEXT,                           -- '~3rd century BCE', '~1500 BCE', ...
    status           TEXT         NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending','in_progress','complete','disputed','unavailable')),
    priority         INT          NOT NULL DEFAULT 5, -- 1 = highest, 10 = lowest
    summary          TEXT,                           -- one-paragraph description
    canonical_source TEXT,                           -- URL, IMS reference, catalog entry
    notes            TEXT,                           -- free-text notes (provenance, caveats)
    encoded_blob     BYTEA,                          -- Akashic-encoded payload once complete (null otherwise)
    encoded_sha256   TEXT,                           -- sha256 of encoded_blob for integrity
    started_at       TIMESTAMPTZ,
    completed_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ancient_text_status_idx
    ON akashic.ancient_text (status, priority);

COMMENT ON TABLE akashic.ancient_text IS
  'S7 Akashic corpus — ancient texts tracked for translation. Each row becomes a queryable SkyAVi skill when status flips to complete.';

-- ── Seed corpus ─────────────────────────────────────────────────────
-- Canonical ancient texts across traditions. All start 'pending'.
-- Priority reflects deployment value + provenance confidence, not
-- theological ranking. Rows can be reordered / replaced as Jamie
-- refines the list.

INSERT INTO akashic.ancient_text (slug, title, origin_region, origin_language, origin_script, approximate_age, priority, summary) VALUES
  ('dead-sea-scrolls',       'Dead Sea Scrolls',                      'Qumran / Judea',   'Hebrew / Aramaic / Greek', 'Hebrew / Aramaic square', '~3rd c. BCE – 1st c. CE', 1, 'Hebrew Bible manuscripts and sectarian texts found at Qumran. Oldest surviving copies of most Hebrew Bible books.'),
  ('nag-hammadi',            'Nag Hammadi Library',                   'Upper Egypt',      'Coptic',                   'Coptic',                  '~4th c. CE',             1, 'Thirteen leather-bound codices of Gnostic and early Christian texts, including the Gospel of Thomas.'),
  ('septuagint',             'Septuagint (LXX)',                      'Alexandria',       'Koine Greek',              'Greek uncial',            '~3rd c. BCE',            2, 'Earliest extant Greek translation of the Hebrew Bible — the text most early Christians read.'),
  ('codex-sinaiticus',       'Codex Sinaiticus',                      'Eastern Roman',    'Koine Greek',              'Greek uncial',            '~4th c. CE',             2, 'One of the oldest complete manuscripts of the Christian Bible.'),
  ('codex-vaticanus',        'Codex Vaticanus',                       'Eastern Roman',    'Koine Greek',              'Greek uncial',            '~4th c. CE',             2, 'Alongside Sinaiticus, one of the two oldest complete Greek Bible manuscripts.'),
  ('epic-of-gilgamesh',      'Epic of Gilgamesh',                     'Mesopotamia',      'Akkadian',                 'Cuneiform',               '~2100 BCE',              3, 'Oldest known long-form epic; Sumerian king Gilgamesh searches for immortality.'),
  ('enuma-elish',            'Enuma Elish',                           'Babylon',          'Akkadian',                 'Cuneiform',               '~18th–16th c. BCE',      3, 'Babylonian creation epic on seven tablets — heaven, earth, and the Marduk ascendancy.'),
  ('code-of-hammurabi',      'Code of Hammurabi',                     'Babylon',          'Akkadian',                 'Cuneiform',               '~1754 BCE',              4, 'Neo-Sumerian law code inscribed on a diorite stele; one of the earliest near-complete legal codes.'),
  ('egyptian-book-of-dead',  'Egyptian Book of the Dead',             'Egypt',            'Middle Egyptian',          'Hieroglyphic / Hieratic', '~1550 BCE onward',       3, 'Funerary spells and ritual guidance for the afterlife — Papyrus of Ani is the best-known witness.'),
  ('pyramid-texts',          'Pyramid Texts',                         'Egypt',            'Old Egyptian',             'Hieroglyphic',            '~2400–2300 BCE',         4, 'Oldest known religious texts — inscribed on the walls of Old Kingdom pyramids.'),
  ('rosetta-stone',          'Rosetta Stone',                         'Egypt',            'Egyptian / Greek',         'Hieroglyphic / Demotic / Greek', '196 BCE',         2, 'Trilingual decree of Ptolemy V; the key that unlocked Egyptian hieroglyphs.'),
  ('vedas-rig',              'Rig Veda',                              'Indus / Kuru',     'Vedic Sanskrit',           'Brahmi (later)',          '~1500–1200 BCE',         3, 'Oldest of the four Vedas — hymns to the pre-Vedic pantheon in archaic Sanskrit.'),
  ('bhagavad-gita',          'Bhagavad Gita',                         'Kurukshetra',      'Sanskrit',                 'Devanagari (later)',      '~5th–2nd c. BCE',        3, 'Philosophical dialogue between Krishna and Arjuna inset in the Mahabharata.'),
  ('tao-te-ching',           'Dao De Jing',                           'China',            'Classical Chinese',        'Seal / Clerical',         '~6th–4th c. BCE',        3, 'Foundational Daoist text attributed to Laozi — eighty-one short chapters.'),
  ('analects',               'Analects of Confucius',                 'China',            'Classical Chinese',        'Seal / Clerical',         '~5th–3rd c. BCE',        4, 'Sayings and dialogues of Confucius collected by his disciples.'),
  ('i-ching',                'I Ching (Yijing / Book of Changes)',    'China',            'Classical Chinese',        'Seal / Clerical',         '~9th c. BCE',            3, 'Divination and wisdom text organized around sixty-four hexagrams.'),
  ('avesta',                 'Avesta (Zoroastrian scriptures)',       'Iran',             'Avestan',                  'Avestan script',          '~6th c. BCE onward',     4, 'Primary collection of Zoroastrian religious texts, including the Gathas attributed to Zarathustra.'),
  ('quran-sanaa',            'Sanaa Manuscript (Quran)',              'Yemen',            'Classical Arabic',         'Hijazi script',           '~7th c. CE',             2, 'Among the oldest surviving Quranic manuscripts — palimpsest discovered 1972 in Sanaa.'),
  ('pali-canon',             'Pali Canon (Tipitaka)',                 'Sri Lanka',        'Pali',                     'Various (Sinhala, Burmese, Thai)', '~1st c. BCE', 3, 'Standard collection of Theravada Buddhist scriptures preserved in Pali.'),
  ('mahabharata',            'Mahabharata',                           'India',            'Sanskrit',                 'Devanagari (later)',      '~4th c. BCE – 4th c. CE', 4, 'Longest epic poem known — contains the Bhagavad Gita and the story of the Kurukshetra war.'),
  ('iliad-odyssey',          'Iliad and Odyssey',                     'Greece',           'Homeric Greek',            'Greek alphabet',          '~8th c. BCE',            4, 'Two foundational Greek epics attributed to Homer.'),
  ('oxyrhynchus-papyri',     'Oxyrhynchus Papyri',                    'Egypt',            'Greek / Demotic / Latin',  'various',                 '~1st c. BCE – 7th c. CE', 2, 'Massive cache of papyrus fragments recovered at Oxyrhynchus — including early Christian and classical texts.'),
  ('enoch-ethiopic',         '1 Enoch (Ethiopic)',                    'Ethiopia',         'Ge''ez',                   'Ethiopic',                '~3rd c. BCE – 1st c. CE', 2, 'Apocalyptic Jewish text preserved in full only in Ethiopic; fragments found at Qumran.'),
  ('book-of-jubilees',       'Book of Jubilees',                      'Judea / Ethiopia', 'Hebrew / Ge''ez',          'Hebrew / Ethiopic',       '~2nd c. BCE',            3, 'Rewritten Genesis–Exodus narrative preserved in full in Ethiopic and in fragments at Qumran.'),
  ('mishnah',                'Mishnah',                               'Roman Palestine',  'Mishnaic Hebrew',          'Hebrew square',           '~200 CE',                3, 'First written compilation of Jewish oral Torah — the foundation of the Talmud.'),
  ('voynich-manuscript',     'Voynich Manuscript',                    'Europe (disputed)','unknown',                  'unknown',                 '~15th c. CE',            5, 'Illustrated codex in an undeciphered script — marked disputed: origin and meaning unresolved.'),
  ('rongorongo',             'Rongorongo tablets',                    'Rapa Nui',         'unknown',                  'Rongorongo',              '~pre-19th c. CE',        5, 'Undeciphered glyphic script from Easter Island, found on wooden tablets.')
ON CONFLICT (slug) DO NOTHING;
