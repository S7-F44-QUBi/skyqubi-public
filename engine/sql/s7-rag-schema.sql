-- ═══════════════════════════════════════════════════════════════
-- S7 RAG Schema — Retrieval-Augmented Generation Infrastructure
-- ═══════════════════════════════════════════════════════════════
-- Purpose: Ingest, chunk, embed, and retrieve text from any dataset.
--          Supports expansion over time and covenant auditing.
--
-- Dependencies: PostgreSQL 16+ with pgvector extension
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- for hybrid search (trigram + vector)

CREATE SCHEMA IF NOT EXISTS s7_rag;

-- ───────────────────────────────────────────────────────────────
-- Datasets: high-level registry of ingested corpora
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS s7_rag.datasets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT UNIQUE NOT NULL,
    version         TEXT NOT NULL DEFAULT 'v1',
    source_url      TEXT,
    source_type     TEXT NOT NULL,
    license         TEXT NOT NULL,
    description     TEXT,
    language        TEXT DEFAULT 'en',
    tags            TEXT[],
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    document_count  BIGINT NOT NULL DEFAULT 0,
    chunk_count     BIGINT NOT NULL DEFAULT 0,
    token_count     BIGINT NOT NULL DEFAULT 0,
    total_bytes     BIGINT NOT NULL DEFAULT 0,
    embedding_model TEXT NOT NULL DEFAULT 'nomic-embed-text',
    chunk_strategy  TEXT NOT NULL DEFAULT 'sentence-512',
    enabled         BOOLEAN NOT NULL DEFAULT true,
    metadata        JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_datasets_enabled ON s7_rag.datasets(enabled);
CREATE INDEX IF NOT EXISTS idx_datasets_tags ON s7_rag.datasets USING gin(tags);

-- ───────────────────────────────────────────────────────────────
-- Documents: raw documents from datasets
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS s7_rag.documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dataset_id      UUID NOT NULL REFERENCES s7_rag.datasets(id) ON DELETE CASCADE,
    title           TEXT,
    source_ref      TEXT NOT NULL,
    author          TEXT,
    published_at    DATE,
    content_hash    VARCHAR(64) NOT NULL,
    mime_type       TEXT DEFAULT 'text/plain',
    language        TEXT DEFAULT 'en',
    byte_size       INTEGER,
    token_count     INTEGER,
    metadata        JSONB DEFAULT '{}'::jsonb,
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(dataset_id, content_hash)
);

CREATE INDEX IF NOT EXISTS idx_documents_dataset ON s7_rag.documents(dataset_id);
CREATE INDEX IF NOT EXISTS idx_documents_title_trgm ON s7_rag.documents USING gin(title gin_trgm_ops);

-- ───────────────────────────────────────────────────────────────
-- Chunks: searchable document pieces with embeddings
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS s7_rag.chunks (
    id              BIGSERIAL PRIMARY KEY,
    document_id     UUID NOT NULL REFERENCES s7_rag.documents(id) ON DELETE CASCADE,
    dataset_id      UUID NOT NULL REFERENCES s7_rag.datasets(id) ON DELETE CASCADE,
    chunk_index     INTEGER NOT NULL,
    content         TEXT NOT NULL,
    content_hash    VARCHAR(64) NOT NULL,
    token_count     INTEGER,
    char_start      INTEGER,
    char_end        INTEGER,
    embedding       vector(768),
    metadata        JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(document_id, chunk_index)
);

-- HNSW index for fast vector similarity search (nomic-embed-text is 768-dim)
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON s7_rag.chunks
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Trigram index for hybrid lexical search
CREATE INDEX IF NOT EXISTS idx_chunks_content_trgm ON s7_rag.chunks
    USING gin(content gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_chunks_dataset ON s7_rag.chunks(dataset_id);
CREATE INDEX IF NOT EXISTS idx_chunks_document ON s7_rag.chunks(document_id);

-- ───────────────────────────────────────────────────────────────
-- Retrieval log: audit trail of all RAG queries
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS s7_rag.retrieval_log (
    id              BIGSERIAL PRIMARY KEY,
    query           TEXT NOT NULL,
    query_hash      VARCHAR(64) NOT NULL,
    query_embedding vector(768),
    top_k           INTEGER NOT NULL DEFAULT 5,
    retrieved_chunks JSONB NOT NULL,
    retrieval_method TEXT NOT NULL DEFAULT 'vector',
    session_id      UUID,
    witness_id      UUID,
    latency_ms      INTEGER,
    retrieved_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_retrieval_log_session ON s7_rag.retrieval_log(session_id);
CREATE INDEX IF NOT EXISTS idx_retrieval_log_time ON s7_rag.retrieval_log(retrieved_at DESC);

-- ───────────────────────────────────────────────────────────────
-- Dataset statistics view
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW s7_rag.dataset_stats AS
SELECT
    d.id,
    d.name,
    d.version,
    d.license,
    d.enabled,
    d.document_count,
    d.chunk_count,
    d.token_count,
    pg_size_pretty(d.total_bytes) AS size,
    d.imported_at,
    d.updated_at
FROM s7_rag.datasets d
ORDER BY d.imported_at DESC;

-- ───────────────────────────────────────────────────────────────
-- Helper function: update dataset counts after ingestion
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION s7_rag.refresh_dataset_counts(p_dataset_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE s7_rag.datasets d
    SET
        document_count = (SELECT COUNT(*) FROM s7_rag.documents WHERE dataset_id = p_dataset_id),
        chunk_count = (SELECT COUNT(*) FROM s7_rag.chunks WHERE dataset_id = p_dataset_id),
        token_count = COALESCE((SELECT SUM(token_count) FROM s7_rag.chunks WHERE dataset_id = p_dataset_id), 0),
        total_bytes = COALESCE((SELECT SUM(byte_size) FROM s7_rag.documents WHERE dataset_id = p_dataset_id), 0),
        updated_at = NOW()
    WHERE id = p_dataset_id;
END;
$$ LANGUAGE plpgsql;

-- ───────────────────────────────────────────────────────────────
-- Hybrid search function: combines vector + lexical
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION s7_rag.hybrid_search(
    p_query_embedding vector(768),
    p_query_text TEXT,
    p_top_k INTEGER DEFAULT 5,
    p_dataset_filter UUID[] DEFAULT NULL,
    p_vector_weight FLOAT DEFAULT 0.7,
    p_lexical_weight FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    chunk_id BIGINT,
    document_id UUID,
    dataset_id UUID,
    content TEXT,
    vector_score FLOAT,
    lexical_score FLOAT,
    combined_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    WITH vector_results AS (
        SELECT
            c.id AS cid,
            c.document_id AS did,
            c.dataset_id AS dsid,
            c.content AS ctext,
            (1.0 - (c.embedding <=> p_query_embedding))::FLOAT AS vscore
        FROM s7_rag.chunks c
        WHERE c.embedding IS NOT NULL
          AND (p_dataset_filter IS NULL OR c.dataset_id = ANY(p_dataset_filter))
        ORDER BY c.embedding <=> p_query_embedding
        LIMIT p_top_k * 3
    ),
    lexical_results AS (
        SELECT
            c.id AS cid,
            c.document_id AS did,
            c.dataset_id AS dsid,
            c.content AS ctext,
            similarity(c.content, p_query_text)::FLOAT AS lscore
        FROM s7_rag.chunks c
        WHERE (p_dataset_filter IS NULL OR c.dataset_id = ANY(p_dataset_filter))
          AND c.content % p_query_text
        ORDER BY similarity(c.content, p_query_text) DESC
        LIMIT p_top_k * 3
    )
    SELECT
        COALESCE(v.cid, l.cid) AS chunk_id,
        COALESCE(v.did, l.did) AS document_id,
        COALESCE(v.dsid, l.dsid) AS dataset_id,
        COALESCE(v.ctext, l.ctext) AS content,
        COALESCE(v.vscore, 0.0) AS vector_score,
        COALESCE(l.lscore, 0.0) AS lexical_score,
        (COALESCE(v.vscore, 0.0) * p_vector_weight +
         COALESCE(l.lscore, 0.0) * p_lexical_weight) AS combined_score
    FROM vector_results v
    FULL OUTER JOIN lexical_results l ON v.cid = l.cid
    ORDER BY combined_score DESC
    LIMIT p_top_k;
END;
$$ LANGUAGE plpgsql;

-- ───────────────────────────────────────────────────────────────
-- Permissions
-- ───────────────────────────────────────────────────────────────
GRANT USAGE ON SCHEMA s7_rag TO s7;
GRANT ALL ON ALL TABLES IN SCHEMA s7_rag TO s7;
GRANT ALL ON ALL SEQUENCES IN SCHEMA s7_rag TO s7;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA s7_rag TO s7;
