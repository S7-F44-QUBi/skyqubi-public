CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS sky_molecular;

CREATE TABLE sky_molecular.vector_names (
    memory      INT NOT NULL CHECK (memory  IN (-1, 0, 1)),
    present     INT NOT NULL CHECK (present IN (-1, 0, 1)),
    destiny     INT NOT NULL CHECK (destiny IN (-1, 0, 1)),
    name        TEXT NOT NULL,
    meaning     TEXT NOT NULL,
    PRIMARY KEY (memory, present, destiny)
);

INSERT INTO sky_molecular.vector_names (memory, present, destiny, name, meaning) VALUES
( 1,  0,  1, 'FERTILE',         'Positive origin, at door, positive destiny'),
(-1,  0,  1, 'RESURRECTION',    'Negative origin, at door, positive destiny'),
( 0,  0,  1, 'PORTAL_OPEN',     'Unknown origin, at door, positive destiny'),
( 1,  1,  1, 'ABUNDANT',        'Full positive on all axes'),
(-1, -1, -1, 'STASIS',          'Full negative — maximum intervention'),
(-1,  1, -1, 'TOWER',           'Babel — negative origin, positive present, wrong destination'),
(-1,  0, -1, 'DANGER',          'Negative origin, at door, wrong destination'),
( 0,  0,  0, 'MAX_UNCERTAINTY', 'All axes unknown — full discernment required'),
( 1,  0,  0, 'MEMORY_ONLY',     'Positive origin, present unknown, destiny unknown'),
( 0,  0, -1, 'PORTAL_CLOSE',    'Unknown origin, at door, negative destiny'),
( 1,  1,  0, 'GROWING',         'Positive origin, positive present, destiny open'),
( 0,  1,  1, 'EMERGING',        'Unknown origin, positive present, positive destiny'),
( 1,  0, -1, 'FALLING',         'Positive origin, at door, negative destiny'),
(-1,  1,  0, 'RECOVERING',      'Negative origin, positive present, destiny open'),
( 0,  1,  0, 'PRESENT_ONLY',    'Unknown origin, positive present, destiny unknown'),
( 1, -1,  1, 'TESTED',          'Positive origin, negative present, positive destiny'),
(-1, -1,  1, 'REDEEMED',        'Negative past and present, but positive destiny'),
( 1,  1, -1, 'DECLINING',       'Positive origin and present, but wrong trajectory'),
( 0, -1,  0, 'SUFFERING',       'Unknown origin, negative present, unknown destiny'),
( 1, -1,  0, 'CHALLENGED',      'Positive origin, negative present, open destiny'),
(-1,  1,  1, 'TRANSFORMED',     'Negative origin, positive present, positive destiny'),
( 0,  1, -1, 'MISLED',          'Unknown origin, positive present, wrong destination'),
( 0, -1,  1, 'ENDURING',        'Unknown origin, negative present, but positive destiny'),
(-1, -1,  0, 'TRAPPED',         'Negative origin, negative present, open destiny'),
( 0, -1, -1, 'LOST',            'Unknown origin, negative present, negative destiny'),
( 1, -1, -1, 'BETRAYED',        'Positive origin, negative present, negative destiny'),
(-1,  0,  0, 'WOUNDED',         'Negative origin, at door, destiny unknown');

CREATE TABLE sky_molecular.bonds (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bond_type       TEXT NOT NULL CHECK (bond_type IN (
                        'word', 'symbol', 'image',
                        'chunk', 'output', 'signal')),
    plane           INT NOT NULL CHECK (plane BETWEEN -4 AND 4),
    memory          INT NOT NULL CHECK (memory  IN (-1, 0, 1)),
    present         INT NOT NULL CHECK (present IN (-1, 0, 1)),
    destiny         INT NOT NULL CHECK (destiny IN (-1, 0, 1)),
    vector_name     TEXT NOT NULL,
    content         TEXT NOT NULL,
    embedding       vector(768),
    curve_value     INT CHECK (curve_value BETWEEN -7 AND 7),
    plane_curves    FLOAT[9],
    plane_ternary   INT[9],
    plan_point      TEXT,
    location_weight FLOAT DEFAULT 1.0,
    plane_affinity  INT[],
    witness_id      UUID,
    consensus_id    UUID,
    trust_score     FLOAT,
    trust_tier      TEXT CHECK (trust_tier IN (
                        'UNTRUSTED', 'PROBATIONARY', 'TRUSTED', 'ANCHORED')),
    latency_ms      INT,
    document_id     UUID,
    chunk_index     INT,
    dataset         TEXT,
    state           TEXT CHECK (state IN ('FERTILE', 'BABEL', 'DOOR')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION sky_molecular.prevent_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'INSERT-only covenant: UPDATE and DELETE are forbidden on sky_molecular.bonds';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER covenant_no_update
    BEFORE UPDATE ON sky_molecular.bonds
    FOR EACH ROW EXECUTE FUNCTION sky_molecular.prevent_mutation();

CREATE TRIGGER covenant_no_delete
    BEFORE DELETE ON sky_molecular.bonds
    FOR EACH ROW EXECUTE FUNCTION sky_molecular.prevent_mutation();

CREATE INDEX idx_bonds_type     ON sky_molecular.bonds (bond_type);
CREATE INDEX idx_bonds_plane    ON sky_molecular.bonds (plane);
CREATE INDEX idx_bonds_vector   ON sky_molecular.bonds (memory, present, destiny);
CREATE INDEX idx_bonds_state    ON sky_molecular.bonds (state);
CREATE INDEX idx_bonds_witness  ON sky_molecular.bonds (witness_id)
    WHERE witness_id IS NOT NULL;
CREATE INDEX idx_bonds_word     ON sky_molecular.bonds (content)
    WHERE bond_type IN ('word', 'symbol');
CREATE INDEX idx_bonds_dataset  ON sky_molecular.bonds (dataset)
    WHERE bond_type = 'chunk';
