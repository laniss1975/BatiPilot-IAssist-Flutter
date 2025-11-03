-- Migration: Création de la table ai_prompts pour stocker les prompts système
-- Date: 03 Novembre 2025
-- Description: Table unique pour stocker tous les prompts de l'assistant IA

-- Créer la table ai_prompts
CREATE TABLE IF NOT EXISTS ai_prompts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Identifiant unique du prompt (ex: "prompt_system", "prompt_details_projet")
  key TEXT NOT NULL,

  -- Titre lisible pour l'UI (ex: "Prompt Système", "Détails Projet")
  title TEXT NOT NULL,

  -- Contenu du prompt (markdown supporté)
  content TEXT NOT NULL,

  -- Propriétaire du prompt
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Contrainte: une seule clé par utilisateur
  UNIQUE(key, user_id)
);

-- Index pour améliorer les performances
CREATE INDEX idx_ai_prompts_user_id ON ai_prompts(user_id);
CREATE INDEX idx_ai_prompts_key ON ai_prompts(key);
CREATE INDEX idx_ai_prompts_user_key ON ai_prompts(user_id, key);

-- Activer Row Level Security
ALTER TABLE ai_prompts ENABLE ROW LEVEL SECURITY;

-- Politique: Les utilisateurs peuvent voir leurs propres prompts
CREATE POLICY "Users can view their own prompts"
  ON ai_prompts
  FOR SELECT
  USING (auth.uid() = user_id);

-- Politique: Les utilisateurs peuvent créer leurs propres prompts
CREATE POLICY "Users can create their own prompts"
  ON ai_prompts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Politique: Les utilisateurs peuvent modifier leurs propres prompts
CREATE POLICY "Users can update their own prompts"
  ON ai_prompts
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Politique: Les utilisateurs peuvent supprimer leurs propres prompts
CREATE POLICY "Users can delete their own prompts"
  ON ai_prompts
  FOR DELETE
  USING (auth.uid() = user_id);

-- Fonction trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_ai_prompts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger
CREATE TRIGGER ai_prompts_updated_at
  BEFORE UPDATE ON ai_prompts
  FOR EACH ROW
  EXECUTE FUNCTION update_ai_prompts_updated_at();

-- Commentaires pour documentation
COMMENT ON TABLE ai_prompts IS 'Table contenant tous les prompts système pour l''assistant IA';
COMMENT ON COLUMN ai_prompts.key IS 'Identifiant unique du prompt (ex: prompt_system, prompt_details_projet)';
COMMENT ON COLUMN ai_prompts.title IS 'Titre lisible affiché dans l''interface utilisateur';
COMMENT ON COLUMN ai_prompts.content IS 'Contenu complet du prompt (markdown supporté)';
