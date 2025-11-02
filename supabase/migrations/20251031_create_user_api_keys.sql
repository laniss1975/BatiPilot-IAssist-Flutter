-- Migration pour créer la table user_api_keys
-- Cette table permet à chaque utilisateur d'avoir plusieurs clés API par provider/modèle

CREATE TABLE IF NOT EXISTS public.user_api_keys (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_key text NOT NULL, -- 'google', 'openai', etc.
  model_key text NULL, -- 'gemini-2.5-pro', 'gpt-4', etc. (NULL = valable pour tous les modèles du provider)
  key_name text NOT NULL, -- Nom donné par l'utilisateur (ex: "API Perso", "API Pro")
  notes text NULL, -- Informations supplémentaires (ex: "Payante - limite 1000 req/jour")
  is_active boolean NOT NULL DEFAULT false, -- Une seule clé active par provider/modèle
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  
  CONSTRAINT user_api_keys_pkey PRIMARY KEY (id),
  CONSTRAINT user_api_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Un utilisateur ne peut pas avoir deux clés avec le même nom pour le même provider/modèle
  CONSTRAINT user_api_keys_unique_name UNIQUE (user_id, provider_key, model_key, key_name)
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_user_api_keys_user_id ON public.user_api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_user_api_keys_provider_model ON public.user_api_keys(provider_key, model_key);
CREATE INDEX IF NOT EXISTS idx_user_api_keys_active ON public.user_api_keys(user_id, provider_key, model_key, is_active) WHERE is_active = true;

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_user_api_keys_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_api_keys_updated_at
  BEFORE UPDATE ON public.user_api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_user_api_keys_updated_at();

-- Fonction trigger pour s'assurer qu'une seule clé est active par provider/modèle
CREATE OR REPLACE FUNCTION ensure_single_active_key()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Désactive toutes les autres clés du même utilisateur pour le même provider/modèle
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
  BEFORE INSERT OR UPDATE OF is_active ON public.user_api_keys
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION ensure_single_active_key();

-- Activer RLS (Row Level Security)
ALTER TABLE public.user_api_keys ENABLE ROW LEVEL SECURITY;

-- Politique RLS : Les utilisateurs ne voient que leurs propres clés
CREATE POLICY user_api_keys_select_own 
  ON public.user_api_keys 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY user_api_keys_insert_own 
  ON public.user_api_keys 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_api_keys_update_own 
  ON public.user_api_keys 
  FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY user_api_keys_delete_own 
  ON public.user_api_keys 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- Commentaires pour la documentation
COMMENT ON TABLE public.user_api_keys IS 'Stocke les clés API des utilisateurs pour chaque provider/modèle IA';
COMMENT ON COLUMN public.user_api_keys.provider_key IS 'Identifiant du fournisseur (google, openai, anthropic, etc.)';
COMMENT ON COLUMN public.user_api_keys.model_key IS 'Identifiant du modèle spécifique (NULL = valable pour tous les modèles du provider)';
COMMENT ON COLUMN public.user_api_keys.key_name IS 'Nom donné par l''utilisateur pour identifier cette clé';
COMMENT ON COLUMN public.user_api_keys.notes IS 'Notes/informations sur la clé (ex: limites, type de compte)';
COMMENT ON COLUMN public.user_api_keys.is_active IS 'Indique si cette clé est actuellement utilisée (une seule active par provider/modèle)';
