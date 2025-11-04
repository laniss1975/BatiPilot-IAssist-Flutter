-- Migration pour créer la fonction RPC ai_activate_global_model
-- Cette fonction active atomiquement un modèle IA pour un utilisateur
-- (désactive l'ancien + active/upsert le nouveau)

CREATE OR REPLACE FUNCTION public.ai_activate_global_model(
  p_provider_name text,
  p_model_name text,
  p_system_prompt text DEFAULT NULL,
  p_module text DEFAULT 'global'
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_user_id uuid;
  v_provider_id uuid;
  v_model_id uuid;
BEGIN
  -- Récupérer l'utilisateur authentifié
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;

  -- Valider que le provider existe
  SELECT id INTO v_provider_id
  FROM public.ai_providers
  WHERE provider_key = p_provider_name
    AND is_active = true
  LIMIT 1;

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Provider % non trouvé ou inactif', p_provider_name;
  END IF;

  -- Valider que le modèle existe
  SELECT id INTO v_model_id
  FROM public.ai_models
  WHERE model_key = p_model_name
    AND provider_key = p_provider_name
    AND is_active = true
  LIMIT 1;

  IF v_model_id IS NULL THEN
    RAISE EXCEPTION 'Modèle % du provider % non trouvé ou inactif', p_model_name, p_provider_name;
  END IF;

  -- Désactiver toutes les configurations du module pour cet utilisateur
  UPDATE public.ai_provider_configs
  SET is_active = false
  WHERE user_id = v_user_id
    AND module_name = p_module;

  -- Upsert la nouvelle configuration active
  INSERT INTO public.ai_provider_configs (
    user_id,
    module_name,
    provider_name,
    model_name,
    selected_provider_id,
    selected_model_id,
    system_prompt,
    is_active
  ) VALUES (
    v_user_id,
    p_module,
    p_provider_name,
    p_model_name,
    v_provider_id,
    v_model_id,
    p_system_prompt,
    true
  )
  ON CONFLICT (user_id, module_name, provider_name, model_name)
  DO UPDATE SET
    selected_provider_id = EXCLUDED.selected_provider_id,
    selected_model_id = EXCLUDED.selected_model_id,
    system_prompt = COALESCE(EXCLUDED.system_prompt, ai_provider_configs.system_prompt),
    is_active = true,
    updated_at = now();
END;
$$;

-- Commentaires pour la documentation
COMMENT ON FUNCTION public.ai_activate_global_model IS 'Active atomiquement un modèle IA pour un utilisateur (désactive l''ancien + upsert le nouveau)';
