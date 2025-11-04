-- =========================
-- Insert System AI Tools (Phase 3) - FIXED VERSION
-- =========================

-- Tool 1: get_prompt (Récupérer la documentation contextuelle)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'get_prompt' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'get_prompt',
      'Récupérer la documentation',
      'Récupère la documentation et le contexte actuels de l''application pour comprendre comment répondre à l''utilisateur. À utiliser systématiquement au début de chaque conversation.',
      'low',
      'none',
      '{
        "type": "object",
        "properties": {},
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "object",
        "properties": {
          "prompt": {"type": "string"},
          "version": {"type": "string"},
          "updated_at": {"type": "string"}
        }
      }'::jsonb,
      'supabase_rpc',
      '{
        "function": "get_current_prompt",
        "args_mapping": {}
      }'::jsonb,
      5000,
      30,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Récupérer la documentation',
      description = 'Récupère la documentation et le contexte actuels de l''application pour comprendre comment répondre à l''utilisateur. À utiliser systématiquement au début de chaque conversation.',
      parameters_schema = '{
        "type": "object",
        "properties": {},
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "function": "get_current_prompt",
        "args_mapping": {}
      }'::jsonb,
      updated_at = now()
    WHERE key = 'get_prompt' AND visibility = 'system';
  END IF;
END $$;

-- Tool 2: get_clients (Lister les clients)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'get_clients' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'get_clients',
      'Lister les clients',
      'Récupère la liste des clients de l''utilisateur. Peut filtrer par nom, prénom, email ou téléphone.',
      'low',
      'none',
      '{
        "type": "object",
        "properties": {
          "search": {
            "type": "string",
            "description": "Terme de recherche (nom, prénom, email ou téléphone)"
          },
          "limit": {
            "type": "integer",
            "description": "Nombre maximum de résultats",
            "default": 50,
            "minimum": 1,
            "maximum": 100
          }
        },
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "nom": {"type": "string"},
            "prenom": {"type": "string"},
            "email": {"type": "string"},
            "telephone": {"type": "string"}
          }
        }
      }'::jsonb,
      'supabase_query',
      '{
        "table": "clients",
        "operation": "select",
        "columns": "id,nom,prenom,email,telephone,created_at",
        "allowed_filters": ["search", "limit"],
        "filter_mapping": {
          "search": {"column": "nom,prenom,email,telephone", "operator": "ilike"},
          "limit": {"type": "limit"}
        }
      }'::jsonb,
      10000,
      60,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Lister les clients',
      description = 'Récupère la liste des clients de l''utilisateur. Peut filtrer par nom, prénom, email ou téléphone.',
      parameters_schema = '{
        "type": "object",
        "properties": {
          "search": {
            "type": "string",
            "description": "Terme de recherche (nom, prénom, email ou téléphone)"
          },
          "limit": {
            "type": "integer",
            "description": "Nombre maximum de résultats",
            "default": 50,
            "minimum": 1,
            "maximum": 100
          }
        },
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "table": "clients",
        "operation": "select",
        "columns": "id,nom,prenom,email,telephone,created_at",
        "allowed_filters": ["search", "limit"],
        "filter_mapping": {
          "search": {"column": "nom,prenom,email,telephone", "operator": "ilike"},
          "limit": {"type": "limit"}
        }
      }'::jsonb,
      updated_at = now()
    WHERE key = 'get_clients' AND visibility = 'system';
  END IF;
END $$;

-- Tool 3: create_client (Créer un client)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'create_client' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      idempotency,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'create_client',
      'Créer un client',
      'Crée un nouveau client dans la base de données. Nécessite au minimum un nom et un prénom. L''email est utilisé pour détecter les doublons.',
      'medium',
      'required',
      '{
        "type": "object",
        "properties": {
          "nom": {
            "type": "string",
            "minLength": 1,
            "description": "Nom de famille du client"
          },
          "prenom": {
            "type": "string",
            "minLength": 1,
            "description": "Prénom du client"
          },
          "email": {
            "type": "string",
            "format": "email",
            "description": "Adresse email du client (optionnel mais recommandé)"
          },
          "telephone": {
            "type": "string",
            "pattern": "^[0-9+\\s\\-\\.\\(\\)]+$",
            "description": "Numéro de téléphone du client"
          },
          "adresse": {
            "type": "string",
            "description": "Adresse postale complète"
          }
        },
        "required": ["nom", "prenom"],
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "nom": {"type": "string"},
          "prenom": {"type": "string"},
          "email": {"type": "string"}
        }
      }'::jsonb,
      'supabase_rpc',
      '{
        "function": "create_client",
        "args_mapping": {
          "nom": "nom",
          "prenom": "prenom",
          "email": "email",
          "telephone": "telephone",
          "adresse": "adresse",
          "idempotency_key": "idempotency_key"
        }
      }'::jsonb,
      10000,
      10,
      '{
        "key_field": "idempotency_key",
        "derive_from": ["nom", "prenom", "email"]
      }'::jsonb,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Créer un client',
      description = 'Crée un nouveau client dans la base de données. Nécessite au minimum un nom et un prénom. L''email est utilisé pour détecter les doublons.',
      parameters_schema = '{
        "type": "object",
        "properties": {
          "nom": {
            "type": "string",
            "minLength": 1,
            "description": "Nom de famille du client"
          },
          "prenom": {
            "type": "string",
            "minLength": 1,
            "description": "Prénom du client"
          },
          "email": {
            "type": "string",
            "format": "email",
            "description": "Adresse email du client (optionnel mais recommandé)"
          },
          "telephone": {
            "type": "string",
            "pattern": "^[0-9+\\s\\-\\.\\(\\)]+$",
            "description": "Numéro de téléphone du client"
          },
          "adresse": {
            "type": "string",
            "description": "Adresse postale complète"
          }
        },
        "required": ["nom", "prenom"],
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "function": "create_client",
        "args_mapping": {
          "nom": "nom",
          "prenom": "prenom",
          "email": "email",
          "telephone": "telephone",
          "adresse": "adresse",
          "idempotency_key": "idempotency_key"
        }
      }'::jsonb,
      idempotency = '{
        "key_field": "idempotency_key",
        "derive_from": ["nom", "prenom", "email"]
      }'::jsonb,
      updated_at = now()
    WHERE key = 'create_client' AND visibility = 'system';
  END IF;
END $$;

-- Tool 4: create_project (Créer un projet/devis)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'create_project' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      idempotency,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'create_project',
      'Créer un projet/devis',
      'Crée un nouveau projet (devis) pour un client existant. Génère automatiquement le numéro de devis au format AAMM-N.',
      'medium',
      'required',
      '{
        "type": "object",
        "properties": {
          "client_id": {
            "type": "string",
            "format": "uuid",
            "description": "ID du client (obligatoire)"
          },
          "nom": {
            "type": "string",
            "minLength": 1,
            "description": "Nom du projet/chantier"
          },
          "type_projet": {
            "type": "string",
            "enum": ["renovation", "construction", "extension", "amenagement"],
            "description": "Type de projet"
          },
          "adresse": {
            "type": "string",
            "description": "Adresse du chantier"
          },
          "description": {
            "type": "string",
            "description": "Description détaillée du projet"
          }
        },
        "required": ["client_id", "nom"],
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "client_id": {"type": "string"},
          "nom": {"type": "string"},
          "devis_number": {"type": "string"}
        }
      }'::jsonb,
      'supabase_rpc',
      '{
        "function": "create_project",
        "args_mapping": {
          "client_id": "client_id",
          "nom": "nom",
          "type_projet": "type_projet",
          "adresse": "adresse",
          "description": "description"
        }
      }'::jsonb,
      10000,
      10,
      '{
        "key_field": "idempotency_key",
        "derive_from": ["client_id", "nom"]
      }'::jsonb,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Créer un projet/devis',
      description = 'Crée un nouveau projet (devis) pour un client existant. Génère automatiquement le numéro de devis au format AAMM-N.',
      parameters_schema = '{
        "type": "object",
        "properties": {
          "client_id": {
            "type": "string",
            "format": "uuid",
            "description": "ID du client (obligatoire)"
          },
          "nom": {
            "type": "string",
            "minLength": 1,
            "description": "Nom du projet/chantier"
          },
          "type_projet": {
            "type": "string",
            "enum": ["renovation", "construction", "extension", "amenagement"],
            "description": "Type de projet"
          },
          "adresse": {
            "type": "string",
            "description": "Adresse du chantier"
          },
          "description": {
            "type": "string",
            "description": "Description détaillée du projet"
          }
        },
        "required": ["client_id", "nom"],
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "function": "create_project",
        "args_mapping": {
          "client_id": "client_id",
          "nom": "nom",
          "type_projet": "type_projet",
          "adresse": "adresse",
          "description": "description"
        }
      }'::jsonb,
      idempotency = '{
        "key_field": "idempotency_key",
        "derive_from": ["client_id", "nom"]
      }'::jsonb,
      updated_at = now()
    WHERE key = 'create_project' AND visibility = 'system';
  END IF;
END $$;

-- Tool 5: get_devis (Lister les devis/projets)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'get_devis' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'get_devis',
      'Lister les devis/projets',
      'Récupère la liste des devis/projets de l''utilisateur. Peut filtrer par client, statut ou recherche textuelle.',
      'low',
      'none',
      '{
        "type": "object",
        "properties": {
          "client_id": {
            "type": "string",
            "format": "uuid",
            "description": "Filtrer par ID client"
          },
          "search": {
            "type": "string",
            "description": "Recherche dans le nom du projet ou numéro de devis"
          },
          "limit": {
            "type": "integer",
            "description": "Nombre maximum de résultats",
            "default": 50,
            "minimum": 1,
            "maximum": 100
          }
        },
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "client_id": {"type": "string"},
            "nom": {"type": "string"},
            "devis_number": {"type": "string"},
            "type_projet": {"type": "string"}
          }
        }
      }'::jsonb,
      'supabase_query',
      '{
        "table": "devis_save",
        "operation": "select",
        "columns": "id,client_id,nom,devis_number,type_projet,adresse,created_at",
        "allowed_filters": ["client_id", "search", "limit"],
        "filter_mapping": {
          "client_id": {"column": "client_id", "operator": "eq"},
          "search": {"column": "nom,devis_number", "operator": "ilike"},
          "limit": {"type": "limit"}
        }
      }'::jsonb,
      10000,
      60,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Lister les devis/projets',
      description = 'Récupère la liste des devis/projets de l''utilisateur. Peut filtrer par client, statut ou recherche textuelle.',
      parameters_schema = '{
        "type": "object",
        "properties": {
          "client_id": {
            "type": "string",
            "format": "uuid",
            "description": "Filtrer par ID client"
          },
          "search": {
            "type": "string",
            "description": "Recherche dans le nom du projet ou numéro de devis"
          },
          "limit": {
            "type": "integer",
            "description": "Nombre maximum de résultats",
            "default": 50,
            "minimum": 1,
            "maximum": 100
          }
        },
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "table": "devis_save",
        "operation": "select",
        "columns": "id,client_id,nom,devis_number,type_projet,adresse,created_at",
        "allowed_filters": ["client_id", "search", "limit"],
        "filter_mapping": {
          "client_id": {"column": "client_id", "operator": "eq"},
          "search": {"column": "nom,devis_number", "operator": "ilike"},
          "limit": {"type": "limit"}
        }
      }'::jsonb,
      updated_at = now()
    WHERE key = 'get_devis' AND visibility = 'system';
  END IF;
END $$;

-- Tool 6: navigate_to_project_details (Navigation Flutter)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ai_tools WHERE key = 'navigate_to_project_details' AND visibility = 'system') THEN
    INSERT INTO public.ai_tools (
      id,
      key,
      name,
      description,
      risk_level,
      confirmation_policy,
      parameters_schema,
      returns_schema,
      execution_type,
      execution_config,
      timeout_ms,
      rate_limit_per_min,
      enabled,
      enabled_from_routes,
      visibility,
      is_system,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'navigate_to_project_details',
      'Naviguer vers un projet',
      'Demande à l''application Flutter de naviguer vers la page de détails d''un projet/devis spécifique.',
      'low',
      'none',
      '{
        "type": "object",
        "properties": {
          "project_id": {
            "type": "string",
            "format": "uuid",
            "description": "ID du projet/devis vers lequel naviguer"
          }
        },
        "required": ["project_id"],
        "additionalProperties": false
      }'::jsonb,
      '{
        "type": "object",
        "properties": {
          "action": {"type": "string"},
          "payload": {"type": "object"}
        }
      }'::jsonb,
      'flutter_action',
      '{
        "action_type": "navigate",
        "route": "/project-details",
        "params_mapping": {
          "project_id": "projectId"
        }
      }'::jsonb,
      2000,
      30,
      true,
      NULL,
      'system',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE public.ai_tools SET
      name = 'Naviguer vers un projet',
      description = 'Demande à l''application Flutter de naviguer vers la page de détails d''un projet/devis spécifique.',
      parameters_schema = '{
        "type": "object",
        "properties": {
          "project_id": {
            "type": "string",
            "format": "uuid",
            "description": "ID du projet/devis vers lequel naviguer"
          }
        },
        "required": ["project_id"],
        "additionalProperties": false
      }'::jsonb,
      execution_config = '{
        "action_type": "navigate",
        "route": "/project-details",
        "params_mapping": {
          "project_id": "projectId"
        }
      }'::jsonb,
      updated_at = now()
    WHERE key = 'navigate_to_project_details' AND visibility = 'system';
  END IF;
END $$;

-- Verify insertion
SELECT
  key,
  name,
  execution_type,
  risk_level,
  confirmation_policy,
  enabled
FROM public.ai_tools
WHERE is_system = true
ORDER BY key;
