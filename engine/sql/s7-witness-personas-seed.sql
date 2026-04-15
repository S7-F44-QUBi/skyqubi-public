-- ═══════════════════════════════════════════════════════════════════
-- S7 SkyQUBi — Witness Persona Seed
--
-- Seeds cws_core.witnesses with the current S7 persona roster so that
-- /witness and /discern can find a matching witness_id for these models
-- via 'SELECT id FROM cws_core.witnesses WHERE model_name = $1'.
--
-- Root cause: run_witness() in engine/s7_witness.py fabricates a random
-- UUID when the SELECT returns no row, then uses that fabricated UUID in
-- subsequent foreign-key INSERTs — which crashes with
-- 'ForeignKeyViolation: Key (witness_id)=... is not present in table
-- "witnesses"'. This seed removes the fabrication path by ensuring every
-- model we'd realistically call is already registered.
--
-- Idempotent via ON CONFLICT (model_name) DO NOTHING. Safe to rerun.
-- Safe to ship to the public repo (no secrets, no PII).
--
-- 2026-04-13: added during the /witness ConnectError debugging pass
-- (the fix-pod.sh training block). Also applied directly to the running
-- postgres container for immediate effect.
--
-- Governing memory:
--   project_octi_witness_set.md   canonical witness plane mapping
--   project_chat_personas.md       Carli / Elias / Samuel persona identity
--   feedback_qbit_not_token.md     QBIT vocabulary (param_count stays numeric)
-- ═══════════════════════════════════════════════════════════════════

BEGIN;

-- Chat personas (custom S7 models, built via ollama create from Modelfiles)
INSERT INTO cws_core.witnesses (model_name, model_family, param_count, license, access_type, is_active)
VALUES
    ('s7-carli:0.6b',   'qwen3',  600000000,  'CWS-BSL-1.1', 'open_weights', true),
    ('s7-elias:1.3b',   'llama',  1300000000, 'CWS-BSL-1.1', 'open_weights', true),
    ('s7-samuel:v1',    'qwen3',  600000000,  'CWS-BSL-1.1', 'open_weights', true),
    ('s7-qwen3:0.6b',   'qwen3',  600000000,  'CWS-BSL-1.1', 'open_weights', true)
ON CONFLICT (model_name) DO NOTHING;

-- Upstream bases kept on this box (qwen family)
INSERT INTO cws_core.witnesses (model_name, model_family, param_count, license, access_type, is_active)
VALUES
    ('qwen3:0.6b',          'qwen3', 600000000,  'Apache-2.0',    'open_weights', true),
    ('qwen2.5:3b',          'qwen',  3100000000, 'Apache-2.0',    'open_weights', true),
    ('qwen2.5-coder:0.5b',  'qwen',  494000000,  'Apache-2.0',    'open_weights', true),
    ('qwen2.5-coder:1.5b',  'qwen',  1500000000, 'Apache-2.0',    'open_weights', true)
ON CONFLICT (model_name) DO NOTHING;

-- Small/fast models for latency-bounded tiers
INSERT INTO cws_core.witnesses (model_name, model_family, param_count, license, access_type, is_active)
VALUES
    ('smollm2:360m',   'llama', 360000000,  'Apache-2.0', 'open_weights', true),
    ('tinyllama:1.1b', 'llama', 1100000000, 'Apache-2.0', 'open_weights', true)
ON CONFLICT (model_name) DO NOTHING;

-- Embeddings (for consistency — these are used by the RAG + Prism paths,
-- not by /witness, but registering them here keeps the roster honest).
INSERT INTO cws_core.witnesses (model_name, model_family, param_count, license, access_type, is_active)
VALUES
    ('all-minilm:latest',       'bert',       23000000,  'Apache-2.0', 'open_weights', true),
    ('nomic-embed-text:latest', 'nomic-bert', 137000000, 'Apache-2.0', 'open_weights', true)
ON CONFLICT (model_name) DO NOTHING;

COMMIT;

-- After this seed:
--   Total witnesses = 14 pre-existing (legacy plan roster) + 10 new S7 roster
--                   = 24 rows in cws_core.witnesses
--   Lifecycle A02 check (>=9 models in ollama) is orthogonal — this is
--   the witness REGISTRY, not the ollama store.
--
-- Verification after seed:
--   SELECT model_name, model_family FROM cws_core.witnesses
--   WHERE model_name LIKE 's7-%' OR model_name LIKE 'qwen%'
--      OR model_name = 'smollm2:360m' OR model_name = 'tinyllama:1.1b';
