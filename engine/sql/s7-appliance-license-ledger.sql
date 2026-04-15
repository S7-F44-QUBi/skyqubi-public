-- engine/sql/s7-appliance-license-ledger.sql
-- S7 Appliance License Ledger — a VIEW, not a new table.
--
-- Every deployed QUBi appliance becomes a ledgered, licensed,
-- uniquely identified unit. This view is the queryable handle for
-- that property — one row per appliance, with the fields a
-- regulator / auditor / owner actually needs to see:
--
--   identity       : serial + id
--   classification : home / business / ministry / reference
--   jurisdiction   : region (ISO alpha-2)
--   language       : IETF BCP 47
--   covenant       : covenant_accepted_at + current_version
--   owner          : display name (may be blank for privacy)
--   seed           : first 8 hex chars of akashic_seed as a fingerprint
--                    (full seed is an appliance secret — NEVER expose it)
--   encoder        : version of the per-appliance Akashic cipher
--   snapshot_count : how many snapshots recorded for this unit
--   latest_snapshot: when + kind + commit of the most recent snapshot
--   status         : active / dormant / retired
--
-- This is the open-for-a-reason surface: an auditor or regulator can
-- verify an appliance's identity, history, and compliance posture
-- WITHOUT access to the appliance's secret seed. Kerckhoff's
-- principle applied to appliance licensing — the algorithm is
-- public, the keys are per-appliance.

CREATE OR REPLACE VIEW appliance.license_ledger AS
SELECT
    a.id                                          AS appliance_id,
    a.serial                                      AS serial,
    a.classification                              AS classification,
    a.region                                      AS jurisdiction,
    a.language                                    AS language,
    a.owner_display_name                          AS owner,
    a.covenant_accepted_at                        AS covenant_accepted_at,
    a.current_version                             AS current_version,
    a.status                                      AS status,
    COALESCE(substring(a.akashic_seed for 8) || '…', 'unset')
                                                  AS seed_fingerprint,
    COALESCE(a.akashic_encoder->>'version', 'unset')
                                                  AS encoder_version,
    COALESCE(
        (SELECT count(*) FROM appliance.snapshot s WHERE s.appliance_id = a.id),
        0
    )                                             AS snapshot_count,
    (SELECT s.taken_at FROM appliance.snapshot s
      WHERE s.appliance_id = a.id
      ORDER BY s.taken_at DESC LIMIT 1)           AS latest_snapshot_at,
    (SELECT s.kind FROM appliance.snapshot s
      WHERE s.appliance_id = a.id
      ORDER BY s.taken_at DESC LIMIT 1)           AS latest_snapshot_kind,
    (SELECT substring(s.commit_sha for 10) FROM appliance.snapshot s
      WHERE s.appliance_id = a.id
      ORDER BY s.taken_at DESC LIMIT 1)           AS latest_commit,
    a.created_at                                  AS registered_at
FROM appliance.appliance a
ORDER BY a.created_at ASC;

COMMENT ON VIEW appliance.license_ledger IS
  'Per-appliance license ledger. Regulators and owners can verify an appliance''s identity, jurisdiction, covenant acceptance, snapshot history, and current status WITHOUT access to the secret akashic_seed. The algorithm is public (CWS-BSL-1.1 → Apache 2.0); the keys are per-appliance. This view is the open-for-a-reason surface.';
