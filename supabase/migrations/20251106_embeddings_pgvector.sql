-- =========================
-- AI Tool Embeddings for Semantic Search (V2)
-- =========================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Table for tool embeddings
CREATE TABLE IF NOT EXISTS public.ai_tool_embeddings (
  tool_id UUID PRIMARY KEY REFERENCES public.ai_tools(id) ON DELETE CASCADE,
  embedding vector(1536) NOT NULL,
  text_summary TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index IVFFLAT (create after inserting sufficient rows, lists=100 for ~1000 rows)
-- Note: This index should be created manually after you have at least 100-200 embeddings
-- CREATE INDEX ai_tool_embeddings_ivfflat_idx
--   ON public.ai_tool_embeddings USING ivfflat (embedding vector_l2_ops)
--   WITH (lists = 100);

-- RLS: embeddings are not sensitive, readable by all authenticated users
ALTER TABLE public.ai_tool_embeddings ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read embeddings
DO $policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'ai_tool_embeddings'
    AND policyname = 'select_all_auth'
  ) THEN
    CREATE POLICY select_all_auth
      ON public.ai_tool_embeddings
      FOR SELECT TO authenticated
      USING (true);
  END IF;
END $policy$;

-- Block direct insert/update from authenticated users (only via Edge Function with service role)
DO $policy2$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'ai_tool_embeddings'
    AND policyname = 'block_insert_auth'
  ) THEN
    CREATE POLICY block_insert_auth
      ON public.ai_tool_embeddings
      FOR INSERT TO authenticated
      WITH CHECK (false);
  END IF;
END $policy2$;

DO $policy3$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'ai_tool_embeddings'
    AND policyname = 'block_update_auth'
  ) THEN
    CREATE POLICY block_update_auth
      ON public.ai_tool_embeddings
      FOR UPDATE TO authenticated
      USING (false)
      WITH CHECK (false);
  END IF;
END $policy3$;

-- RPC function for semantic search
-- Returns top-k tools matching the query embedding, filtered by route
CREATE OR REPLACE FUNCTION public.match_ai_tools(
  query_embedding vector(1536),
  route TEXT,
  match_count INT DEFAULT 5
)
RETURNS TABLE (tool_id UUID, distance FLOAT4)
LANGUAGE sql
STABLE
AS $$
  SELECT e.tool_id, (e.embedding <=> query_embedding)::float4 AS distance
  FROM public.ai_tool_embeddings e
  JOIN public.ai_tools t ON t.id = e.tool_id
  WHERE t.enabled = true
    AND (t.enabled_from_routes IS NULL OR route = ANY(t.enabled_from_routes))
  ORDER BY e.embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.match_ai_tools TO authenticated;
