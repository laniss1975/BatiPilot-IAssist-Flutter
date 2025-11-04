-- =========================
-- RPC Functions pour les Tools
-- =========================

-- Function: create_client
-- Security: invoker (hérite des RLS de l'utilisateur authentifié)
create or replace function public.create_client(
  nom text,
  prenom text,
  email text default null,
  telephone text default null,
  adresse text default null,
  idempotency_key text default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_client_id uuid;
  v_existing_id uuid;
begin
  -- Validation basique
  if nom is null or trim(nom) = '' then
    return jsonb_build_object(
      'success', false,
      'error', 'Le nom est requis'
    );
  end if;

  if prenom is null or trim(prenom) = '' then
    return jsonb_build_object(
      'success', false,
      'error', 'Le prénom est requis'
    );
  end if;

  -- Idempotency: Si email fourni, vérifier si client existe déjà
  if email is not null and email != '' then
    select id into v_existing_id
    from public.clients
    where clients.email = create_client.email
      and clients.user_id = auth.uid()
    limit 1;

    if found then
      return jsonb_build_object(
        'success', true,
        'client_id', v_existing_id,
        'message', 'Client existe déjà (idempotent)',
        'existing', true
      );
    end if;
  end if;

  -- Créer le client
  insert into public.clients (user_id, nom, prenom, email, telephone, adresse)
  values (auth.uid(), nom, prenom, email, telephone, adresse)
  returning id into v_client_id;

  return jsonb_build_object(
    'success', true,
    'client_id', v_client_id,
    'message', 'Client créé avec succès',
    'existing', false
  );
exception
  when others then
    return jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
end;
$$;

-- Function: create_project
-- Security: invoker
create or replace function public.create_project(
  client_id uuid,
  nom text,
  type_projet text default 'renovation',
  adresse text default null,
  description text default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_project_id uuid;
  v_devis_numero text;
begin
  -- Validation
  if client_id is null then
    return jsonb_build_object(
      'success', false,
      'error', 'client_id est requis'
    );
  end if;

  if nom is null or trim(nom) = '' then
    return jsonb_build_object(
      'success', false,
      'error', 'Le nom du projet est requis'
    );
  end if;

  -- Vérifier que le client appartient à l'utilisateur
  if not exists (
    select 1 from public.clients
    where id = client_id
      and user_id = auth.uid()
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'Client non trouvé ou non autorisé'
    );
  end if;

  -- Générer numéro de devis (format AAMM-N)
  select public.generate_devis_number() into v_devis_numero;

  -- Créer le projet
  insert into public.projets (
    user_id, client_id, nom, type_projet, adresse, description, devis_numero, status
  )
  values (
    auth.uid(), client_id, nom, type_projet, adresse, description, v_devis_numero, 'brouillon'
  )
  returning id into v_project_id;

  return jsonb_build_object(
    'success', true,
    'project_id', v_project_id,
    'devis_numero', v_devis_numero,
    'message', 'Projet créé avec succès'
  );
exception
  when others then
    return jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
end;
$$;

-- Function: update_client
-- Security: invoker
create or replace function public.update_client(
  client_id uuid,
  nom text default null,
  prenom text default null,
  email text default null,
  telephone text default null,
  adresse text default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_updated_count int;
begin
  -- Vérifier que le client appartient à l'utilisateur
  if not exists (
    select 1 from public.clients
    where id = client_id
      and user_id = auth.uid()
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'Client non trouvé ou non autorisé'
    );
  end if;

  -- Update avec COALESCE pour ne modifier que les champs fournis
  update public.clients
  set
    nom = coalesce(update_client.nom, clients.nom),
    prenom = coalesce(update_client.prenom, clients.prenom),
    email = coalesce(update_client.email, clients.email),
    telephone = coalesce(update_client.telephone, clients.telephone),
    adresse = coalesce(update_client.adresse, clients.adresse),
    updated_at = now()
  where id = client_id
    and user_id = auth.uid();

  get diagnostics v_updated_count = row_count;

  if v_updated_count = 0 then
    return jsonb_build_object(
      'success', false,
      'error', 'Client non modifié'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'client_id', client_id,
    'message', 'Client modifié avec succès'
  );
exception
  when others then
    return jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
end;
$$;

-- Function: update_project
-- Security: invoker
create or replace function public.update_project(
  project_id uuid,
  nom text default null,
  type_projet text default null,
  adresse text default null,
  description text default null,
  status text default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_updated_count int;
begin
  -- Vérifier que le projet appartient à l'utilisateur
  if not exists (
    select 1 from public.projets
    where id = project_id
      and user_id = auth.uid()
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'Projet non trouvé ou non autorisé'
    );
  end if;

  -- Update
  update public.projets
  set
    nom = coalesce(update_project.nom, projets.nom),
    type_projet = coalesce(update_project.type_projet, projets.type_projet),
    adresse = coalesce(update_project.adresse, projets.adresse),
    description = coalesce(update_project.description, projets.description),
    status = coalesce(update_project.status, projets.status),
    updated_at = now()
  where id = project_id
    and user_id = auth.uid();

  get diagnostics v_updated_count = row_count;

  if v_updated_count = 0 then
    return jsonb_build_object(
      'success', false,
      'error', 'Projet non modifié'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'project_id', project_id,
    'message', 'Projet modifié avec succès'
  );
exception
  when others then
    return jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
end;
$$;

-- Function: generate_devis_number
-- Security: definer (car utilise compteur global)
-- Format: AAMM-N (ex: 2511-1 pour novembre 2025, 1er devis du mois)
create or replace function public.generate_devis_number()
returns text
language plpgsql
security definer
as $$
declare
  v_year_month text;
  v_count int;
  v_numero text;
begin
  -- Format AAMM (ex: 2511 pour novembre 2025)
  v_year_month := to_char(now(), 'YYMM');

  -- Compter les devis du mois pour cet utilisateur
  select count(*) + 1 into v_count
  from public.projets
  where user_id = auth.uid()
    and devis_numero like v_year_month || '-%';

  -- Construire le numéro
  v_numero := v_year_month || '-' || v_count::text;

  return v_numero;
end;
$$;

-- Function: get_prompt (pour Tool de documentation)
-- Security: invoker
create or replace function public.get_prompt(
  prompt_key text
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_prompt record;
begin
  select * into v_prompt
  from public.ai_prompts
  where key = prompt_key
    and user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'Prompt non trouvé'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'prompt', row_to_json(v_prompt)
  );
end;
$$;
