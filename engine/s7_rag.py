# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Covenant Witness System Engine
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
#
# Licensed under CWS-BSL-1.1 (see CWS-LICENSE at repo root)
# Patent Pending: TPP99606 — Jamie Lee Clayton / 123Tech / 2XR, LLC
#
# S7™, SkyQUBi™, SkyCAIR™, CWS™, ForToken™, RevToken™, ZeroClaw™,
# SkyAVi™, MemPalace™, and "Love is the architecture"™ are
# trademarks of 123Tech / 2XR, LLC.
#
# CIVILIAN USE ONLY — See CWS-LICENSE Civilian-Only Covenant.
# ═══════════════════════════════════════════════════════════════════
"""
S7 RAG Module — Retrieval-Augmented Generation

Core functions:
- chunk_text: split text into embedding-friendly chunks
- embed_text: get embeddings via nomic-embed-text (Ollama)
- ingest_document: store a document and its chunks in Postgres
- ingest_dataset: register a dataset and ingest all documents in it
- retrieve: semantic + lexical hybrid search over chunks
- expand_with_retrieved: inject retrieved chunks into a prompt for witness inference

Designed to be called from the CWS Engine or a standalone ingest CLI.
"""
import os
import re
import hashlib
import asyncio
import json
from pathlib import Path
from typing import Iterator, Optional
from datetime import datetime

import httpx

OLLAMA_URL = os.getenv("S7_OLLAMA_URL", os.getenv("OLLAMA_URL", "http://127.0.0.1:57081"))
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")

# Chunking parameters (tunable per dataset)
CHUNK_SIZE_CHARS = 2048     # ~500 tokens for most English
CHUNK_OVERLAP_CHARS = 256   # overlap between chunks for context preservation
MIN_CHUNK_CHARS = 100        # skip chunks smaller than this


# ───────────────────────────────────────────────────────────────
# Chunking
# ───────────────────────────────────────────────────────────────
def chunk_text(
    text: str,
    chunk_size: int = CHUNK_SIZE_CHARS,
    overlap: int = CHUNK_OVERLAP_CHARS,
) -> list[dict]:
    """Split text into overlapping chunks. Returns list of {content, char_start, char_end}."""
    text = text.strip()
    if len(text) < MIN_CHUNK_CHARS:
        return [{"content": text, "char_start": 0, "char_end": len(text)}] if text else []

    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))

        # Try to break at sentence boundary
        if end < len(text):
            for delim in [". ", "! ", "? ", ".\n", "!\n", "?\n", "\n\n"]:
                last_delim = text.rfind(delim, start, end)
                if last_delim > start + chunk_size // 2:
                    end = last_delim + len(delim)
                    break

        chunk_content = text[start:end].strip()
        if len(chunk_content) >= MIN_CHUNK_CHARS:
            chunks.append({
                "content": chunk_content,
                "char_start": start,
                "char_end": end,
            })

        if end >= len(text):
            break
        start = end - overlap

    return chunks


def estimate_tokens(text: str) -> int:
    """Rough token count estimate (1 token ≈ 4 chars for English)."""
    return max(1, len(text) // 4)


# ───────────────────────────────────────────────────────────────
# Embedding
# ───────────────────────────────────────────────────────────────
async def embed_text(client: httpx.AsyncClient, text: str) -> list[float]:
    """Get embedding via Ollama's nomic-embed-text."""
    resp = await client.post(
        f"{OLLAMA_URL}/api/embeddings",
        json={"model": EMBED_MODEL, "prompt": text},
        timeout=30.0,
    )
    resp.raise_for_status()
    return resp.json()["embedding"]


async def embed_batch(client: httpx.AsyncClient, texts: list[str], concurrency: int = 4) -> list[list[float]]:
    """Embed multiple texts with limited concurrency."""
    semaphore = asyncio.Semaphore(concurrency)

    async def bounded_embed(text: str) -> list[float]:
        async with semaphore:
            return await embed_text(client, text)

    return await asyncio.gather(*[bounded_embed(t) for t in texts])


# ───────────────────────────────────────────────────────────────
# Ingestion
# ───────────────────────────────────────────────────────────────
def content_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()[:64]


async def register_dataset(
    db_conn,
    name: str,
    source_url: str,
    license: str,
    source_type: str = "text",
    description: str = "",
    language: str = "en",
    tags: Optional[list[str]] = None,
    version: str = "v1",
    chunk_strategy: str = f"sentence-{CHUNK_SIZE_CHARS}",
) -> str:
    """Register a dataset or return existing ID."""
    tags = tags or []
    with db_conn.cursor() as cur:
        cur.execute("""
            SELECT id::text FROM s7_rag.datasets WHERE name = %s
        """, (name,))
        row = cur.fetchone()
        if row:
            return row[0]

        cur.execute("""
            INSERT INTO s7_rag.datasets
                (name, version, source_url, source_type, license, description, language, tags, chunk_strategy)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id::text
        """, (name, version, source_url, source_type, license, description, language, tags, chunk_strategy))
        return cur.fetchone()[0]


async def ingest_document(
    db_conn,
    client: httpx.AsyncClient,
    dataset_id: str,
    title: str,
    content: str,
    source_ref: str,
    author: Optional[str] = None,
    published_at: Optional[str] = None,
    metadata: Optional[dict] = None,
) -> dict:
    """
    Ingest a single document: store document record, chunk it, embed each chunk, store chunks.
    Returns {"document_id": str, "chunks_created": int, "tokens": int}.
    """
    metadata = metadata or {}
    doc_hash = content_hash(content)
    byte_size = len(content.encode("utf-8"))
    doc_tokens = estimate_tokens(content)

    # Check if already ingested
    with db_conn.cursor() as cur:
        cur.execute("""
            SELECT id::text FROM s7_rag.documents
            WHERE dataset_id = %s::uuid AND content_hash = %s
        """, (dataset_id, doc_hash))
        existing = cur.fetchone()
        if existing:
            return {"document_id": existing[0], "chunks_created": 0, "tokens": 0, "skipped": True}

        cur.execute("""
            INSERT INTO s7_rag.documents
                (dataset_id, title, source_ref, author, published_at, content_hash,
                 byte_size, token_count, metadata)
            VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
            RETURNING id::text
        """, (dataset_id, title, source_ref, author, published_at, doc_hash,
              byte_size, doc_tokens, json.dumps(metadata)))
        document_id = cur.fetchone()[0]

    # Chunk the content
    chunks = chunk_text(content)

    # Embed all chunks
    chunk_texts = [c["content"] for c in chunks]
    if not chunk_texts:
        return {"document_id": document_id, "chunks_created": 0, "tokens": doc_tokens}

    embeddings = await embed_batch(client, chunk_texts)

    # Store chunks
    with db_conn.cursor() as cur:
        for idx, (chunk, emb) in enumerate(zip(chunks, embeddings)):
            chunk_hash = content_hash(chunk["content"])
            chunk_tokens = estimate_tokens(chunk["content"])
            # Convert embedding list to pgvector format
            embedding_str = "[" + ",".join(str(x) for x in emb) + "]"
            cur.execute("""
                INSERT INTO s7_rag.chunks
                    (document_id, dataset_id, chunk_index, content, content_hash,
                     token_count, char_start, char_end, embedding)
                VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s::vector)
                ON CONFLICT (document_id, chunk_index) DO NOTHING
            """, (document_id, dataset_id, idx, chunk["content"], chunk_hash,
                  chunk_tokens, chunk["char_start"], chunk["char_end"], embedding_str))

    # Refresh dataset counts
    with db_conn.cursor() as cur:
        cur.execute("SELECT s7_rag.refresh_dataset_counts(%s::uuid)", (dataset_id,))

    return {
        "document_id": document_id,
        "chunks_created": len(chunks),
        "tokens": doc_tokens,
    }


# ───────────────────────────────────────────────────────────────
# Retrieval
# ───────────────────────────────────────────────────────────────
async def retrieve(
    db_conn,
    client: httpx.AsyncClient,
    query: str,
    top_k: int = 5,
    dataset_filter: Optional[list[str]] = None,
    method: str = "hybrid",
    vector_weight: float = 0.7,
    lexical_weight: float = 0.3,
) -> list[dict]:
    """Retrieve top-k most relevant chunks for a query."""
    query_emb = await embed_text(client, query)
    query_emb_str = "[" + ",".join(str(x) for x in query_emb) + "]"

    results = []
    with db_conn.cursor() as cur:
        if method == "hybrid":
            cur.execute("""
                SELECT chunk_id, document_id::text, dataset_id::text, content,
                       vector_score, lexical_score, combined_score
                FROM s7_rag.hybrid_search(
                    %s::vector, %s, %s,
                    CASE WHEN %s IS NULL THEN NULL ELSE %s::uuid[] END,
                    %s, %s
                )
            """, (query_emb_str, query, top_k,
                  dataset_filter, dataset_filter,
                  vector_weight, lexical_weight))
        else:
            cur.execute("""
                SELECT c.id, c.document_id::text, c.dataset_id::text, c.content,
                       (1.0 - (c.embedding <=> %s::vector))::FLOAT AS vector_score,
                       0.0::FLOAT AS lexical_score,
                       (1.0 - (c.embedding <=> %s::vector))::FLOAT AS combined_score
                FROM s7_rag.chunks c
                WHERE c.embedding IS NOT NULL
                  AND (%s IS NULL OR c.dataset_id = ANY(%s::uuid[]))
                ORDER BY c.embedding <=> %s::vector
                LIMIT %s
            """, (query_emb_str, query_emb_str, dataset_filter, dataset_filter, query_emb_str, top_k))

        for row in cur.fetchall():
            results.append({
                "chunk_id": row[0],
                "document_id": row[1],
                "dataset_id": row[2],
                "content": row[3],
                "vector_score": float(row[4]) if row[4] is not None else 0.0,
                "lexical_score": float(row[5]) if row[5] is not None else 0.0,
                "combined_score": float(row[6]) if row[6] is not None else 0.0,
            })

    # Log the retrieval
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO s7_rag.retrieval_log
                (query, query_hash, query_embedding, top_k, retrieved_chunks, retrieval_method)
            VALUES (%s, %s, %s::vector, %s, %s::jsonb, %s)
        """, (
            query,
            content_hash(query),
            query_emb_str,
            top_k,
            json.dumps([{"id": r["chunk_id"], "score": r["combined_score"]} for r in results]),
            method,
        ))

    return results


def expand_prompt_with_context(query: str, chunks: list[dict], max_context_chars: int = 4000) -> str:
    """Build a RAG-augmented prompt from retrieved chunks."""
    if not chunks:
        return query

    context_parts = []
    total_chars = 0
    for c in chunks:
        if total_chars + len(c["content"]) > max_context_chars:
            break
        context_parts.append(f"[Source #{c['chunk_id']}]\n{c['content']}")
        total_chars += len(c["content"])

    context_text = "\n\n---\n\n".join(context_parts)
    return (
        f"Use the following retrieved context to answer the question.\n\n"
        f"=== CONTEXT ===\n{context_text}\n=== END CONTEXT ===\n\n"
        f"Question: {query}"
    )
