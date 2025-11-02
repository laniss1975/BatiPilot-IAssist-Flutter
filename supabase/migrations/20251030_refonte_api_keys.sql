-- Migration: Refonte du système de clés API pour support multi-clés par modèle

-- 1. Créer la nouvelle table user_api_keys
CREATE TABLE IF NOT EXISTS public.user_api_keys (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_key text NOT NULL,
  model_key text NULL, -- Null = clé valable pour tous les modèles du provider
  key_name text NOT NULL, -- Ex: "API Perso", "API Pro", "API Test"
  api_key_encrypted text NOT NULL,
  notes text NULL, -- Ex: "Clé payante professionnelle", "Clé gratuite limitée"
  is_active boolean NOT NULL DEFAULT false, -- Une seule clé active par modèle
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  
  CONSTRAINT user_api_keys_pkey PRIMARY KEY (id),
  CONSTRAINT user_api_keys_unique_name UNIQUE (user_id, provider_key, model_key, key_name),
  CONSTRAINT user_api_keys_user_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_user_api_keys_user_provider ON public.user_api_keys(user_id, provider_key);
CREATE INDEX IF NOT EXISTS idx_user_api_keys_active ON public.user_api_keys(user_id, is_active) WHERE is_active = true;

-- RLS (Row Level Security)
ALTER TABLE public.user_api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own API keys"
  ON public.user_api_keys
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own API keys"
  ON public.user_api_keys
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own API keys"
  ON public.user_api_keys
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own API keys"
  ON public.user_api_keys
  FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger pour updated_at
CREATE TRIGGER update_user_api_keys_updated_at
  BEFORE UPDATE ON public.user_api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 2. Fonction pour s'assurer qu'une seule clé est active par modèle
CREATE OR REPLACE FUNCTION public.ensure_single_active_key()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Désactiver toutes les autres clés pour ce user/provider/model
    UPDATE public.user_api_keys
    SET is_active = false
    WHERE user_id = NEW.user_id
      AND provider_key = NEW.provider_key
      AND (model_key = NEW.model_key OR (model_key IS NULL AND NEW.model_key IS NULL))
      AND id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ensure_single_active_key
  BEFORE INSERT OR UPDATE ON public.user_api_keys
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION public.ensure_single_active_key();

-- 3. Migrer les anciennes données si elles existent (optionnel)
-- Si vous avez déjà des clés dans l'ancien système, on peut les migrer ici
-- À adapter selon votre ancien schéma

COMMENT ON TABLE public.user_api_keys IS 'Stockage des clés API utilisateur avec support multi-clés par modèle';
COMMENT ON COLUMN public.user_api_keys.model_key IS 'NULL signifie que la clé est valable pour tous les modèles du provider';
COMMENT ON COLUMN public.user_api_keys.key_name IS 'Nom personnalisé de la configuration (ex: API Perso, API Pro)';
COMMENT ON COLUMN public.user_api_keys.notes IS 'Notes/informations sur cette clé (ex: payante, gratuite, limites)';
COMMENT ON COLUMN public.user_api_keys.is_active IS 'Indique si cette clé est actuellement utilisée pour ce modèle';
