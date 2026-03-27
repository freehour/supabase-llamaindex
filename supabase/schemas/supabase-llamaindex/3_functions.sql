-- Function to match documents based on a query embedding and optional metadata filter
-- Returns the top 'match_count' documents ordered by similarity to the query embedding.
-- The 'filter' parameter allows for additional filtering based on document metadata using json containment.
-- Must be in the public schema to be compatible with llamaindex.
CREATE OR REPLACE FUNCTION public.match_documents(
    query_embedding vector(768),
    match_count int,
    filter jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    id uuid,
    file_id uuid,
    created_at timestamptz,
    content text,
    metadata jsonb,
    embedding vector(768),
    similarity float
)
SET search_path = ''
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
    SELECT
        id,
        file_id,
        created_at,
        content,
        metadata,
        embedding,
        1 - (embedding OPERATOR(extensions.<=>) query_embedding) AS similarity
    FROM public.embeddings
    WHERE metadata @> filter
    ORDER BY embedding OPERATOR(extensions.<=>) query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;


-- Function extracts the 'fileId' from metadata and assigns it to reference file_id.
-- LlamaIndex inserts embeddings automatically with a user defined metadata;
-- this function is triggered before insert to populate the file_id column from the metadata.
CREATE OR REPLACE FUNCTION llamaindex.embeddings_apply_metadata()
RETURNS trigger
SET search_path = ''
AS $$
BEGIN
    IF NEW.metadata ? 'fileId' THEN
        NEW.file_id := NEW.metadata ->> 'fileId';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to return files in the specified bucket with no or outdated embeddings
CREATE OR REPLACE FUNCTION llamaindex.get_outdated_embeddings(bucket text)
RETURNS TABLE (
    file_id uuid,
    bucket_id uuid,
    path_tokens text[]
)
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT f.id, f.bucket_id, f.path_tokens
    FROM llamaindex.outdated_embeddings AS f
    WHERE f.bucket_id = bucket;
END;
$$ LANGUAGE plpgsql;
