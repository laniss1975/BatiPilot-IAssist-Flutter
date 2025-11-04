-- =========================
-- Audit Optimizations: Indexes + Purge + Idempotency
-- =========================

-- Indexes additionnels pour performances
CREATE INDEX IF NOT EXISTS ai_runs_status_created_idx
  ON public.ai_runs (status, created_at DESC);

CREATE INDEX IF NOT EXISTS ai_runs_user_status_created_idx
  ON public.ai_runs (user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS ai_tool_invocations_run_success_idx
  ON public.ai_tool_invocations (run_id, success, created_at DESC);

CREATE INDEX IF NOT EXISTS ai_messages_run_role_idx
  ON public.ai_messages (run_id, role, created_at);

-- Ajouter colonnes idempotency_key aux tables métier
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS clients_user_idempotency_uniq
  ON public.clients (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.projets
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS projets_user_idempotency_uniq
  ON public.projets (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Fonction de purge des logs (RGPD 90 jours)
CREATE OR REPLACE FUNCTION purge_ai_logs()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  DELETE FROM public.ai_messages
  WHERE created_at < now() - interval '90 days';

  DELETE FROM public.ai_tool_invocations
  WHERE created_at < now() - interval '90 days';

  DELETE FROM public.ai_runs
  WHERE created_at < now() - interval '90 days';
$$;

-- pg_cron: purge quotidienne à 3h du matin
-- NOTE: pg_cron doit être activé dans Supabase Dashboard > Database > Extensions
-- Si pg_cron pas dispo, utiliser un Edge Scheduled Function à la place
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule('purge_ai_logs_daily', '0 3 * * *',
      $$SELECT purge_ai_logs();$$
    );
  END IF;
END $$;

-- Ajouter colonne context pour stocker état Agent (plan en attente, etc.)
ALTER TABLE public.ai_runs
  ADD COLUMN IF NOT EXISTS context JSONB DEFAULT NULL;

-- Index pour recherche rapide des runs en attente de confirmation
CREATE INDEX IF NOT EXISTS ai_runs_waiting_confirmation_idx
  ON public.ai_runs (user_id, created_at DESC)
  WHERE status = 'waiting_confirmation';
