-- Migration pour créer la table ai_provider_configs
-- Cette table stocke les configurations actives de modèles IA par utilisateur et par module

CREATE TABLE IF NOT EXISTS public.ai_provider_configs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  module_name text NOT NULL DEFAULT 'global', -- 'global', 'chat', 'completion', etc.

  -- Champs utilisés par le code existant (backward compatibility)
  provider_name text NOT NULL, -- 'openai', 'google', 'anthropic' (provider_key)
  model_name text NOT NULL, -- 'gpt-4o', 'gemini-2.5-pro', etc. (model_key)

  -- Champs optionnels pour migration progressive vers UUIDs (intégrité FK)
  selected_provider_id uuid NULL,
  selected_model_id uuid NULL,

  system_prompt text NULL, -- Prompt système optionnel
  is_active boolean NOT NULL DEFAULT false, -- Une seule config active par user/module
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT ai_provider_configs_pkey PRIMARY KEY (id),
  CONSTRAINT ai_provider_configs_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT ai_provider_configs_selected_provider_fkey FOREIGN KEY (selected_provider_id)
    REFERENCES public.ai_providers(id) ON DELETE SET NULL,
  CONSTRAINT ai_provider_configs_selected_model_fkey FOREIGN KEY (selected_model_id)
    REFERENCES public.ai_models(id) ON DELETE SET NULL,

  -- Une seule combinaison provider/model par user/module
  CONSTRAINT ai_provider_configs_unique_config UNIQUE (user_id, module_name, provider_name, model_name)
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_ai_provider_configs_user_module
  ON public.ai_provider_configs(user_id, module_name);
CREATE INDEX IF NOT EXISTS idx_ai_provider_configs_active
  ON public.ai_provider_configs(user_id, module_name, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ai_provider_configs_provider_name
  ON public.ai_provider_configs(provider_name);

-- Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_ai_provider_configs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ai_provider_configs_updated_at
  BEFORE UPDATE ON public.ai_provider_configs
  FOR EACH ROW
  EXECUTE FUNCTION update_ai_provider_configs_updated_at();

-- Trigger pour s'assurer qu'une seule config est active par user/module
CREATE OR REPLACE FUNCTION ensure_single_active_config()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Désactive toutes les autres configs du même user/module
    UPDATE public.ai_provider_configs
    SET is_active = false
    WHERE user_id = NEW.user_id
      AND module_name = NEW.module_name
      AND id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ensure_single_active_config
  BEFORE INSERT OR UPDATE OF is_active ON public.ai_provider_configs
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION ensure_single_active_config();

-- Activer RLS (Row Level Security)
ALTER TABLE public.ai_provider_configs ENABLE ROW LEVEL SECURITY;

-- Politique RLS : Les utilisateurs ne voient que leurs propres configurations
CREATE POLICY ai_provider_configs_user_policy
  ON public.ai_provider_configs
  FOR ALL
  USING (auth.uid() = user_id);

-- Commentaires pour la documentation
COMMENT ON TABLE public.ai_provider_configs IS 'Configurations actives de modèles IA par utilisateur et par module (global, chat, etc.)';
COMMENT ON COLUMN public.ai_provider_configs.module_name IS 'Nom du module: global, chat, completion, etc. Permet d''avoir différentes configs par contexte';
COMMENT ON COLUMN public.ai_provider_configs.provider_name IS 'Clé du provider (openai, google, anthropic) - utilisé par le code existant';
COMMENT ON COLUMN public.ai_provider_configs.model_name IS 'Clé du modèle (gpt-4o, gemini-2.5-pro, etc.) - utilisé par le code existant';
COMMENT ON COLUMN public.ai_provider_configs.selected_provider_id IS 'FK vers ai_providers (optionnel pour migration progressive)';
COMMENT ON COLUMN public.ai_provider_configs.selected_model_id IS 'FK vers ai_models (optionnel pour migration progressive)';
COMMENT ON COLUMN public.ai_provider_configs.is_active IS 'Indique si cette config est actuellement active (une seule active par user/module)';
