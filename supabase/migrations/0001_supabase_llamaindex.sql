create extension if not exists "vector" with schema "extensions";

create schema if not exists "llamaindex";


  create table "public"."embeddings" (
    "id" uuid not null default gen_random_uuid(),
    "file_id" uuid not null,
    "created_at" timestamp with time zone not null default (now() AT TIME ZONE 'utc'::text),
    "content" text not null,
    "metadata" jsonb,
    "embedding" extensions.vector(768)
      );


CREATE UNIQUE INDEX embeddings_pkey ON public.embeddings USING btree (id);

CREATE INDEX public_embeddings_embedding_idx ON public.embeddings USING ivfflat (embedding extensions.vector_cosine_ops) WITH (lists='128');

CREATE INDEX public_embeddings_file_id_idx ON public.embeddings USING btree (file_id);

alter table "public"."embeddings" add constraint "embeddings_pkey" PRIMARY KEY using index "embeddings_pkey";

alter table "public"."embeddings" add constraint "embeddings_file_id_fkey" FOREIGN KEY (file_id) REFERENCES storage.objects(id) ON DELETE CASCADE not valid;

alter table "public"."embeddings" validate constraint "embeddings_file_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION llamaindex.embeddings_apply_metadata()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    IF NEW.metadata ? 'fileId' THEN
        NEW.file_id := NEW.metadata ->> 'fileId';
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION llamaindex.get_outdated_embeddings(bucket text)
 RETURNS TABLE(file_id uuid, bucket_id uuid, path_tokens text[])
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    RETURN QUERY
    SELECT f.id, f.bucket_id, f.path_tokens
    FROM llamaindex.outdated_embeddings AS f
    WHERE f.bucket_id = bucket;
END;
$function$
;

create or replace view "llamaindex"."outdated_embeddings" as  SELECT f.id,
    f.bucket_id,
    f.name,
    f.owner,
    f.created_at,
    f.updated_at,
    f.last_accessed_at,
    f.metadata,
    f.path_tokens,
    f.version,
    f.owner_id,
    f.user_metadata
   FROM (storage.objects f
     LEFT JOIN public.embeddings e ON ((e.file_id = f.id)))
  WHERE ((e.file_id IS NULL) OR (f.updated_at > e.created_at));


CREATE OR REPLACE FUNCTION public.match_documents(query_embedding extensions.vector, match_count integer, filter jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(id uuid, file_id uuid, created_at timestamp with time zone, content text, metadata jsonb, embedding extensions.vector, similarity double precision)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

grant delete on table "public"."embeddings" to "anon";

grant insert on table "public"."embeddings" to "anon";

grant references on table "public"."embeddings" to "anon";

grant select on table "public"."embeddings" to "anon";

grant trigger on table "public"."embeddings" to "anon";

grant truncate on table "public"."embeddings" to "anon";

grant update on table "public"."embeddings" to "anon";

grant delete on table "public"."embeddings" to "authenticated";

grant insert on table "public"."embeddings" to "authenticated";

grant references on table "public"."embeddings" to "authenticated";

grant select on table "public"."embeddings" to "authenticated";

grant trigger on table "public"."embeddings" to "authenticated";

grant truncate on table "public"."embeddings" to "authenticated";

grant update on table "public"."embeddings" to "authenticated";

grant delete on table "public"."embeddings" to "service_role";

grant insert on table "public"."embeddings" to "service_role";

grant references on table "public"."embeddings" to "service_role";

grant select on table "public"."embeddings" to "service_role";

grant trigger on table "public"."embeddings" to "service_role";

grant truncate on table "public"."embeddings" to "service_role";

grant update on table "public"."embeddings" to "service_role";

CREATE TRIGGER llamaindex_embeddings_apply_metadata BEFORE INSERT OR UPDATE ON public.embeddings FOR EACH ROW EXECUTE FUNCTION llamaindex.embeddings_apply_metadata();


