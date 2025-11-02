-- Migration pour créer la table ai_models
-- Cette table stocke les modèles IA disponibles pour chaque provider

CREATE TABLE IF NOT EXISTS public.ai_models (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_key text NOT NULL, -- Référence au provider (google, openai, etc.)
  model_key text NOT NULL, -- Identifiant unique du modèle (gemini-2.5-pro, gpt-4, etc.)
  model_name text NOT NULL, -- Nom d'affichage (Gemini 2.5 Pro, GPT-4, etc.)
  description text NULL, -- Description du modèle
  context_window integer NULL, -- Taille de la fenêtre de contexte (tokens)
  max_output_tokens integer NULL, -- Nombre maximum de tokens en sortie
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  
  CONSTRAINT ai_models_pkey PRIMARY KEY (id),
  CONSTRAINT ai_models_model_key_unique UNIQUE (model_key),
  CONSTRAINT ai_models_provider_fkey FOREIGN KEY (provider_key) 
    REFERENCES public.ai_providers(provider_key) ON DELETE CASCADE
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_ai_models_provider ON public.ai_models(provider_key);
CREATE INDEX IF NOT EXISTS idx_ai_models_active ON public.ai_models(is_active) WHERE is_active = true;

-- Trigger pour updated_at
CREATE TRIGGER trigger_update_ai_models_updated_at
  BEFORE UPDATE ON public.ai_models
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Activer RLS (lecture publique, écriture admin uniquement)
ALTER TABLE public.ai_models ENABLE ROW LEVEL SECURITY;

-- Politique : tout le monde peut lire les modèles actifs
CREATE POLICY ai_models_select_all 
  ON public.ai_models 
  FOR SELECT 
  USING (is_active = true);

-- Insertion de quelques modèles par défaut
INSERT INTO public.ai_models (provider_key, model_key, model_name, description, context_window, max_output_tokens) VALUES
  -- Google Gemini
  ('google', 'gemini-2.0-flash-exp', 'Gemini 2.0 Flash (Experimental)', 'Modèle rapide et léger', 1000000, 8192),
  ('google', 'gemini-2.5-flash', 'Gemini 2.5 Flash', 'Version rapide de Gemini 2.5', 1000000, 8192),
  ('google', 'gemini-2.5-pro', 'Gemini 2.5 Pro', 'Version premium de Gemini avec raisonnement avancé', 2000000, 8192),
  
  -- OpenAI
  ('openai', 'gpt-4o', 'GPT-4 Omni', 'Modèle multimodal le plus avancé d''OpenAI', 128000, 4096),
  ('openai', 'gpt-4-turbo', 'GPT-4 Turbo', 'Version optimisée de GPT-4', 128000, 4096),
  ('openai', 'gpt-3.5-turbo', 'GPT-3.5 Turbo', 'Modèle rapide et économique', 16385, 4096),
  
  -- Anthropic Claude
  ('anthropic', 'claude-3-5-sonnet-20241022', 'Claude 3.5 Sonnet', 'Équilibre optimal entre intelligence et vitesse', 200000, 8192),
  ('anthropic', 'claude-3-opus-20240229', 'Claude 3 Opus', 'Le plus puissant de la famille Claude', 200000, 4096),
  ('anthropic', 'claude-3-haiku-20240307', 'Claude 3 Haiku', 'Rapide et économique', 200000, 4096)
ON CONFLICT (model_key) DO NOTHING;

COMMENT ON TABLE public.ai_models IS 'Catalogue des modèles IA disponibles';
COMMENT ON COLUMN public.ai_models.model_key IS 'Identifiant unique du modèle utilisé dans les API';
COMMENT ON COLUMN public.ai_models.context_window IS 'Taille maximale du contexte en tokens';
