-- Trigger: Apply metadata before insert or update
-- ---------------------------------------------------------
-- LlamaIndex inserts embeddings automatically; this trigger
-- allows customizing the insert by populating columns based on the provided document metadata.
CREATE TRIGGER llamaindex_embeddings_apply_metadata
BEFORE INSERT OR UPDATE ON public.embeddings
FOR EACH ROW
EXECUTE FUNCTION llamaindex.embeddings_apply_metadata();