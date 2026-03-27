-- ==========================================================
-- Tables
-- ==========================================================


-- Create the embeddings table
-- ---------------------------------------------------------
-- The table holds embeddings for chunked text files.
-- Must remain in the `public` schema for compatibility with LlamaIndex.
-- When a file is deleted from the storage.objects table,
-- the corresponding embeddings are also deleted.
CREATE TABLE IF NOT EXISTS public.embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES storage.objects(id) ON DELETE CASCADE,  -- Not unique due to chunking
    created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
    content TEXT NOT NULL,
    metadata JSONB,
    embedding vector(768)  -- For nomic-embed-text (768 dimensions)
);


-- =========================================================
-- Indexes
-- =========================================================

-- Vector similarity index (used by LlamaIndex)
CREATE INDEX IF NOT EXISTS public_embeddings_embedding_idx
    ON public.embeddings
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 128);

-- File lookup index
CREATE INDEX IF NOT EXISTS public_embeddings_file_id_idx
    ON public.embeddings (file_id);

-- =========================================================
-- Views
-- =========================================================

-- View to return files with no or outdated embeddings
CREATE OR REPLACE VIEW llamaindex.outdated_embeddings AS
SELECT f.*
FROM storage.objects AS f
LEFT JOIN public.embeddings AS e
    ON e.file_id = f.id
WHERE e.file_id IS NULL OR f.updated_at > e.created_at;

GRANT SELECT ON llamaindex.outdated_embeddings TO authenticated, service_role, anon;
