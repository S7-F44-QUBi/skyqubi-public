-- engine/sql/s7-akashic-forbidden-expand-2.sql
-- Expand akashic.forbidden per Jamie's directive:
-- "i cant stand keyloggers, or clipboard cheating, or dns unencrypted
--  by defaults, oh my"
--
-- Three new forbidden concepts plus an expansion of the existing
-- malware_enablement surface_forms to include standalone 'keylogger'
-- (previously only keylogger_offensive was covered).

-- ── 1. Add 'keylogger' as a standalone surface form ───────────────
-- UPDATE the existing malware_enablement row to include the
-- unqualified word. Before: only keylogger_offensive matched.
UPDATE akashic.forbidden
SET surface_forms = array_cat(
        surface_forms,
        ARRAY['keylogger','keyloggers','keylogging','keystroke_capture','keyboard_spyware']
    )
WHERE concept = 'malware_enablement'
  AND NOT ('keylogger' = ANY(surface_forms));

-- ── 2. New concept: clipboard_hijack ──────────────────────────────
INSERT INTO akashic.forbidden (concept, rationale, citation, surface_forms) VALUES
('clipboard_hijack',
 'Covert clipboard read/write for credential theft, crypto address swapping (clippers), paste hijacking, or data exfiltration. The clipboard is a short-term trust space between the user and their intentional paste target; hijacking it breaks that trust.',
 'S7 covenant — the user owns their keystrokes and their clipboard',
 '{clipper,clippers,clipboard_hijack,clipboard_hijacking,clipboard_logger,clipboard_stealer,clipboard_monitor_covert,paste_hijack}')
ON CONFLICT (concept) DO NOTHING;

-- ── 3. New concept: dns_exfiltration ──────────────────────────────
INSERT INTO akashic.forbidden (concept, rationale, citation, surface_forms) VALUES
('dns_exfiltration',
 'DNS tunneling for data exfiltration, command-and-control traffic over DNS, abuse of unencrypted DNS-by-default to sneak payloads past security controls. S7 posture: DoT/DoH encrypted DNS by default via Quad9; refuse to author code that depends on or enables plaintext DNS exfiltration.',
 'S7 security model — sovereignty from the name layer up',
 '{dns_exfiltration,dns_exfil,dns_tunneling,dns_tunnel_offensive,dns_c2,dns_cnc_offensive,dns_covert_channel}')
ON CONFLICT (concept) DO NOTHING;

-- ── 4. New concept: screen_capture_covert ─────────────────────────
-- Natural companion to keylogger + clipboard_hijack. Any system
-- that monitors keyboard + clipboard usually also wants the screen.
-- S7 refuses all three as a matched set.
INSERT INTO akashic.forbidden (concept, rationale, citation, surface_forms) VALUES
('screen_capture_covert',
 'Covert screen capture, screenshot-without-consent, screen-recording malware, display buffer scraping. Companion refusal to keylogger and clipboard_hijack — the three together are the "eyes, hands, and page" of a surveilled user.',
 'S7 covenant — the user owns what their screen shows them',
 '{screen_scraper,screen_scraper_offensive,covert_screenshot,screen_stealer,display_hijack,screen_monitor_covert}')
ON CONFLICT (concept) DO NOTHING;

-- ── Verify ─────────────────────────────────────────────────────────
SELECT count(*) AS concepts, sum(array_length(surface_forms,1)) AS total_forms
FROM akashic.forbidden;

SELECT concept, array_length(surface_forms,1) AS forms
FROM akashic.forbidden
WHERE concept IN ('malware_enablement','clipboard_hijack','dns_exfiltration','screen_capture_covert')
ORDER BY concept;
