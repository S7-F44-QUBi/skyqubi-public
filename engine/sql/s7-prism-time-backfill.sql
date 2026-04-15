-- engine/sql/s7-prism-time-backfill.sql
-- Populate time_j2000_s for every row so the temporal intersection
-- works.
--
-- Jamie: 'This will Intersect all language compared through time.'
--
-- The LocationID matrix is already a cross-language semantic index
-- (thanks to akashic.universals), but without Time, 'compared
-- through time' doesn't work. This migration fills the column for
-- every existing row and wires ingest to set it by default going
-- forward.
--
-- J2000 TT epoch  : 2000-01-01 12:00:00 UTC (~)
-- J2000 in Unix s : 946,728,000
--
-- For a modern ingest row:
--   time_j2000_s = extract(epoch from created_at)::BIGINT - 946728000
--
-- For an ancient-text row with a known approximate age:
--   time_j2000_s = -(2000 + year_bce) * 31557600   (average year seconds)
--   (negative = before J2000, positive = after)
--
-- 31557600 = 365.25 * 86400 — the average Julian year in seconds.

-- ── Step 1. Backfill from created_at for every row that has NULL ──
UPDATE cws_core.location_id
SET time_j2000_s = (extract(epoch from created_at)::BIGINT - 946728000)
WHERE time_j2000_s IS NULL;

-- ── Step 2. Re-stamp the 27 ancient-text rows with their authorial era ──
-- Maps the approximate_age field in akashic.ancient_text to a signed
-- J2000 second count. Very approximate — the goal is rough epoch
-- ordering, not archaeological precision.

WITH era_map AS (
    SELECT
        'dead-sea-scrolls'::text     AS slug, -150 AS year,
        '1st c. BCE'::text as era UNION ALL
    SELECT 'nag-hammadi',         350,  '4th c. CE'     UNION ALL
    SELECT 'septuagint',          -250, '3rd c. BCE'    UNION ALL
    SELECT 'codex-sinaiticus',    350,  '4th c. CE'     UNION ALL
    SELECT 'codex-vaticanus',     350,  '4th c. CE'     UNION ALL
    SELECT 'epic-of-gilgamesh',  -2100, '21st c. BCE'   UNION ALL
    SELECT 'enuma-elish',        -1700, '17th c. BCE'   UNION ALL
    SELECT 'code-of-hammurabi',  -1754, '1754 BCE'      UNION ALL
    SELECT 'egyptian-book-of-dead',-1550,'16th c. BCE'  UNION ALL
    SELECT 'pyramid-texts',      -2350, '24th c. BCE'   UNION ALL
    SELECT 'rosetta-stone',      -196,  '196 BCE'       UNION ALL
    SELECT 'vedas-rig',          -1500, '15th c. BCE'   UNION ALL
    SELECT 'bhagavad-gita',      -300,  '3rd c. BCE'    UNION ALL
    SELECT 'tao-te-ching',       -500,  '5th c. BCE'    UNION ALL
    SELECT 'analects',           -400,  '4th c. BCE'    UNION ALL
    SELECT 'i-ching',            -900,  '9th c. BCE'    UNION ALL
    SELECT 'avesta',             -600,  '6th c. BCE'    UNION ALL
    SELECT 'quran-sanaa',         650,  '7th c. CE'     UNION ALL
    SELECT 'pali-canon',         -100,  '1st c. BCE'    UNION ALL
    SELECT 'mahabharata',         50,   '1st c. CE'     UNION ALL
    SELECT 'iliad-odyssey',      -800,  '8th c. BCE'    UNION ALL
    SELECT 'oxyrhynchus-papyri',  200,  '2nd c. CE'     UNION ALL
    SELECT 'enoch-ethiopic',     -250,  '3rd c. BCE'    UNION ALL
    SELECT 'book-of-jubilees',   -200,  '2nd c. BCE'    UNION ALL
    SELECT 'mishnah',             200,  '200 CE'        UNION ALL
    SELECT 'voynich-manuscript',  1450, '15th c. CE'    UNION ALL
    SELECT 'rongorongo',          1700, '~pre-19th CE'
)
UPDATE cws_core.location_id lid
SET time_j2000_s = ((em.year::BIGINT - 2000::BIGINT) * 31557600::BIGINT)
FROM era_map em
WHERE lid.notes LIKE 'akashic corpus: ' || em.slug || ' —%';

-- ── Step 3. Verify ────────────────────────────────────────────────

SELECT
    count(*) FILTER (WHERE time_j2000_s IS NOT NULL) AS with_time,
    count(*) AS total,
    MIN(time_j2000_s) AS earliest_j2000,
    MAX(time_j2000_s) AS latest_j2000
FROM cws_core.location_id;

-- Sanity check — show the 27 ancient rows sorted by era
SELECT
    substring(notes from 'akashic corpus: ([a-z-]+)') AS slug,
    time_j2000_s,
    to_char(
        to_timestamp(time_j2000_s + 946728000),
        'YYYY-MM-DD'
    ) AS approx_calendar_date
FROM cws_core.location_id
WHERE notes LIKE 'akashic corpus:%'
ORDER BY time_j2000_s ASC
LIMIT 8;
