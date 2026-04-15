-- engine/sql/s7-akashic-forbidden-schema.sql
-- S7 Akashic Forbidden — the covenant's explicit refusals.
--
-- akashic.universals holds concepts S7 embraces.
-- akashic.forbidden  holds concepts S7 refuses.
--
-- Detection: any text containing a forbidden surface form returns
--            VIOLATION immediately, before encoding.
-- Ingest:    any text containing a forbidden surface form is
--            REFUSED — never inserted into cws_core.location_id.
--
-- Every forbidden row carries:
--   - canonical English concept
--   - rationale (why S7 refuses this)
--   - citation (covenant / scripture / moral anchor — optional)
--   - surface_forms (cross-language tokens)
--
-- The forbidden set is small and explicit. It is the visible edge
-- of the civilian-only mandate. It is published BY DESIGN — a
-- regulator, an owner, a peer can read it and verify that S7
-- refuses what it says it refuses.
--
-- Lives in DB:    s7_cws
-- Schema:         akashic
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)

CREATE TABLE IF NOT EXISTS akashic.forbidden (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept         TEXT          NOT NULL UNIQUE,
    rationale       TEXT          NOT NULL,
    citation        TEXT,
    surface_forms   TEXT[]        NOT NULL,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE akashic.forbidden IS
  'The covenant''s explicit refusals. Any text containing a surface form from this table is refused at ingest and returns VIOLATION at detect. Published by design — civilian-only mandate made visible.';

CREATE INDEX IF NOT EXISTS forbidden_surface_gin
  ON akashic.forbidden USING gin (surface_forms);

-- ── Seed ───────────────────────────────────────────────────────────
-- Short, explicit, civilian-only. Surface forms are English-first
-- because the _TOKEN_RE in s7_akashic.py is [a-zA-Z]+; multi-
-- language transliterations are added where the concept is
-- universal and unambiguous. Over-matching is tolerated: if a
-- legitimate technical paragraph trips on 'weapon' or 'bioweapon',
-- that's a feature, not a bug — the author can rephrase, and the
-- covenant catches the word before it catches the concept.

INSERT INTO akashic.forbidden (concept, rationale, citation, surface_forms) VALUES

-- ── Violence & harm ────────────────────────────────────────────────
('weaponization',
 'S7 is civilian-only. Weapons, munitions, armament, warhead are outside the covenant.',
 'CWS-BSL-1.1 Civilian-Only Covenant',
 '{weapon,weapons,weaponize,weaponization,weaponry,munition,munitions,warhead,armament,armaments}'),

('bioweapon',
 'Bioweapons, chemical weapons, nerve agents. No dual-use research enablement.',
 'Biological Weapons Convention (BWC) 1972; Chemical Weapons Convention (CWC) 1993',
 '{bioweapon,bioweapons,biowarfare,nerveagent,nervegas,pathogen_weaponized,sarin,vx,anthrax,smallpox_weaponized}'),

('genocide',
 'Genocide, ethnic cleansing, mass extermination. Absolute refusal.',
 'Convention on the Prevention and Punishment of the Crime of Genocide 1948',
 '{genocide,genocidal,extermination,exterminate,exterminated,ethnic_cleansing}'),

('torture',
 'Torture and inhumane treatment. Absolute refusal.',
 'UN Convention Against Torture 1984',
 '{torture,torturing,tortured,waterboarding}'),

-- ── Exploitation of persons ───────────────────────────────────────
('child_harm',
 'Sexual exploitation, abuse, or endangerment of children. Absolute refusal.',
 'UN Convention on the Rights of the Child 1989',
 '{csam,child_sexual_abuse,child_abuse,child_exploitation,child_pornography,cp}'),

('slavery',
 'Human trafficking, forced labor, debt bondage, slavery.',
 'Universal Declaration of Human Rights Article 4',
 '{slavery,enslavement,enslave,slave_labor,trafficking,human_trafficking,forced_labor,bonded_labor}'),

('coercion',
 'Coercion of persons, intimidation at scale, blackmail, extortion as policy.',
 'S7 covenant — free assent only',
 '{blackmail,extortion,extort,coerce_at_scale,coercion_campaign}'),

-- ── Deception as system ───────────────────────────────────────────
('deception',
 'Systemic deception, disinformation-at-scale, deepfake-of-real-person-without-consent.',
 'CWS covenant: Truth is the 77.777777% threshold',
 '{disinformation,disinfo,deepfake_nonconsensual,impersonate_person,impersonation_at_scale}'),

('manipulation',
 'Psychological manipulation at scale, dark patterns designed to subvert free assent.',
 'S7 covenant — free assent only',
 '{darkpattern,darkpatterns,manipulate_at_scale,psyop,psychological_warfare}'),

-- ── Surveillance overreach ────────────────────────────────────────
('mass_surveillance',
 'Mass surveillance of civilian populations without consent or due process.',
 'Universal Declaration of Human Rights Article 12',
 '{mass_surveillance,mass_monitoring,mass_tracking,warrantless_surveillance}'),

('doxxing',
 'Publishing private identifying information without consent to cause harm.',
 'S7 covenant — privacy is a first-class concern',
 '{dox,doxing,doxxing,doxx}'),

-- ── Dual-use that S7 refuses even in legitimate contexts ─────────
('malware_enablement',
 'Writing functional malware, ransomware, worms, backdoors, command-and-control infrastructure for offensive use.',
 'S7 security guidance: defensive only',
 '{ransomware,malware_offensive,rootkit,keylogger_offensive,cnc_offensive,c2_offensive}'),

('exploit_weaponization',
 'Weaponizing an 0day against a real target. Defensive research and disclosure are embraced; weaponization is refused.',
 'S7 security guidance: defensive only',
 '{zerodayweaponize,0day_weaponize,exploit_kit,payload_delivery_offensive}'),

-- ── Cross-cutting refusals ────────────────────────────────────────
('self_harm_instruction',
 'Operational instructions for self-harm or suicide methods.',
 'S7 covenant — love first',
 '{suicide_method,self_harm_instruction,self_harm_howto}'),

('discrimination_instruction',
 'Operational instructions for discriminating against a protected class.',
 'Universal Declaration of Human Rights Article 2',
 '{discriminate_operational,discrimination_howto}')

ON CONFLICT (concept) DO NOTHING;
