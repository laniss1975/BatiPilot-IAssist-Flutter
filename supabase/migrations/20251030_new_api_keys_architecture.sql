-- Migration: Nouvelle architecture pour gestion flexible des clés API

-- 1. Créer la nouvelle table pour les clés API avec alias
CREATE TABLE IF NOT EXISTS public.ai_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_key TEXT NOT NULL,
  key_alias TEXT NOT NULL, -- "API Perso", "API Pro", etc.
  description TEXT, -- Informations sur la clé
  encrypted_key TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Un utilisateur peut avoir plusieurs clés pour le même provider
  CONSTRAINT ai_api_keys_unique_alias UNIQUE (user_id, provider_key, key_alias)
);

-- 2. Créer la nouvelle table de configurations
CREATE TABLE IF NOT EXISTS public.ai_model_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_key TEXT NOT NULL,
  model_key TEXT NOT NULL,
  api_key_id UUID NOT NULL REFERENCES public.ai_api_keys(id) ON DELETE CASCADE,
  config_name TEXT NOT NULL, -- Nom de la configuration
  module_name TEXT NOT NULL DEFAULT 'global',
  is_active BOOLEAN NOT NULL DEFAULT false,
  system_prompt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Une seule config active par module et par utilisateur
  CONSTRAINT ai_model_configurations_unique_name UNIQUE (user_id, config_name)
);

-- 3. Indexes pour performance
CREATE INDEX IF NOT EXISTS idx_ai_api_keys_user_provider ON public.ai_api_keys(user_id, provider_key);
CREATE INDEX IF NOT EXISTS idx_ai_model_configurations_user_module ON public.ai_model_configurations(user_id, module_name);
CREATE INDEX IF NOT EXISTS idx_ai_model_configurations_active ON public.ai_model_configurations(user_id, module_name, is_active);

-- 4. Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_ai_tables_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ai_api_keys_updated_at
  BEFORE UPDATE ON public.ai_api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_ai_tables_updated_at();

CREATE TRIGGER ai_model_configurations_updated_at
  BEFORE UPDATE ON public.ai_model_configurations
  FOR EACH ROW
  EXECUTE FUNCTION update_ai_tables_updated_at();

-- 5. RLS (Row Level Security)
ALTER TABLE public.ai_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_configurations ENABLE ROW LEVEL SECURITY;

-- Policies pour ai_api_keys
CREATE POLICY "Users can view their own API keys"
  ON public.ai_api_keys FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own API keys"
  ON public.ai_api_keys FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own API keys"
  ON public.ai_api_keys FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own API keys"
  ON public.ai_api_keys FOR DELETE
  USING (auth.uid() = user_id);

-- Policies pour ai_model_configurations
CREATE POLICY "Users can view their own configurations"
  ON public.ai_model_configurations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own configurations"
  ON public.ai_model_configurations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own configurations"
  ON public.ai_model_configurations FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own configurations"
  ON public.ai_model_configurations FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Fonction pour garantir qu'une seule config est active par module
CREATE OR REPLACE FUNCTION ensure_single_active_config()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Désactiver toutes les autres configs du même module
    UPDATE public.ai_model_configurations
    SET is_active = false
    WHERE user_id = NEW.user_id
      AND module_name = NEW.module_name
      AND id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_active_config_trigger
  AFTER INSERT OR UPDATE OF is_active ON public.ai_model_configurations
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION ensure_single_active_config();
