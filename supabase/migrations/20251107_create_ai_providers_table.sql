-- Migration pour créer la table ai_providers
-- Cette table stocke les fournisseurs d'IA disponibles (OpenAI, Google, Anthropic, etc.)

CREATE TABLE IF NOT EXISTS public.ai_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_key text NOT NULL, -- Identifiant unique: 'openai', 'google', 'anthropic'
  provider_name text NOT NULL, -- Nom d'affichage: 'OpenAI', 'Google Gemini', 'Anthropic Claude'
  is_active boolean NOT NULL DEFAULT true,
  api_endpoint text NULL, -- URL de base de l'API
  api_headers jsonb NULL, -- Headers HTTP additionnels
  api_auth_method text NULL, -- Méthode d'authentification: 'bearer', 'x-api-key', 'query_param'
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT ai_providers_pkey PRIMARY KEY (id),
  CONSTRAINT ai_providers_provider_key_unique UNIQUE (provider_key)
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_ai_providers_active ON public.ai_providers(is_active) WHERE is_active = true;

-- Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_ai_providers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ai_providers_updated_at
  BEFORE UPDATE ON public.ai_providers
  FOR EACH ROW
  EXECUTE FUNCTION update_ai_providers_updated_at();

-- Activer RLS (lecture publique, écriture admin uniquement)
ALTER TABLE public.ai_providers ENABLE ROW LEVEL SECURITY;

-- Politique : tout le monde peut lire les providers actifs
CREATE POLICY ai_providers_select_all
  ON public.ai_providers
  FOR SELECT
  USING (is_active = true);

-- Insertion des providers par défaut
INSERT INTO public.ai_providers (provider_key, provider_name, api_endpoint, api_auth_method) VALUES
  ('openai', 'OpenAI', 'https://api.openai.com/v1', 'bearer'),
  ('google', 'Google Gemini', 'https://generativelanguage.googleapis.com/v1beta', 'query_param'),
  ('anthropic', 'Anthropic Claude', 'https://api.anthropic.com/v1', 'x-api-key'),
  ('mistral', 'Mistral AI', 'https://api.mistral.ai/v1', 'bearer')
ON CONFLICT (provider_key) DO NOTHING;

COMMENT ON TABLE public.ai_providers IS 'Catalogue des fournisseurs d''IA disponibles (OpenAI, Google, Anthropic, etc.)';
COMMENT ON COLUMN public.ai_providers.provider_key IS 'Identifiant unique du provider (ex: openai, google, anthropic)';
COMMENT ON COLUMN public.ai_providers.api_auth_method IS 'Méthode d''authentification: bearer (Authorization: Bearer), x-api-key (x-api-key header), query_param (key dans URL)';
