-- Extensions utiles
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Enums
do $$
begin
  if not exists (select 1 from pg_type where typname = 'risk_level_enum') then
    create type risk_level_enum as enum ('low','medium','high','critical');
  end if;
  if not exists (select 1 from pg_type where typname = 'confirmation_policy_enum') then
    create type confirmation_policy_enum as enum ('none','required','required_strong');
  end if;
  if not exists (select 1 from pg_type where typname = 'execution_type_enum') then
    create type execution_type_enum as enum ('supabase_rpc','supabase_query','flutter_action','storage','http_request','composed');
  end if;
  if not exists (select 1 from pg_type where typname = 'visibility_enum') then
    create type visibility_enum as enum ('system','user');
  end if;
end $$;

-- Helpers: updated_at trigger
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- =========================
-- Table: ai_tools
-- =========================
create table if not exists public.ai_tools (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Identification
  key text not null,
  name text not null,
  description text not null,
  category text,                      -- 'data','crud','navigation','documentation', etc.

  -- Versioning & governance
  version text default '1.0.0',
  is_deprecated boolean default false,
  risk_level risk_level_enum not null default 'low',
  confirmation_policy confirmation_policy_enum not null default 'none',
  roles_allowed text[] default null,   -- à relier plus tard au modèle de rôles app

  -- Schémas
  parameters_schema jsonb not null,
  returns_schema jsonb default null,

  -- Exécution
  execution_type execution_type_enum not null,
  execution_config jsonb not null,     -- dépend du type (function/table/filters/etc.)
  timeout_ms integer not null default 10000,
  rate_limit_per_min integer default 60,
  idempotency jsonb default null,      -- ex: {"key_field":"idempotency_key"}
  side_effects boolean default false,
  streaming_supported boolean default false,

  -- Gating
  enabled boolean not null default true,
  enabled_from_routes text[] default null, -- ex: ["/home","/project_details"]
  depends_on text[] default null,
  tags text[] default null,

  -- Visibilité
  visibility visibility_enum not null default 'system',
  user_id uuid references auth.users(id),   -- null si visibility='system'
  is_system boolean not null default false  -- garde-fou
);

-- Unicité par scope (system vs user)
create unique index if not exists ai_tools_key_system_uniq
  on public.ai_tools (key) where visibility = 'system';

create unique index if not exists ai_tools_key_user_uniq
  on public.ai_tools (user_id, key) where visibility = 'user';

-- Index usuels
create index if not exists ai_tools_enabled_idx on public.ai_tools (enabled);
create index if not exists ai_tools_category_idx on public.ai_tools (category);
create index if not exists ai_tools_updated_at_idx on public.ai_tools (updated_at);

-- Trigger updated_at
drop trigger if exists ai_tools_set_updated_at on public.ai_tools;
create trigger ai_tools_set_updated_at
before update on public.ai_tools
for each row execute function set_updated_at();

-- RLS
alter table public.ai_tools enable row level security;

-- Policies:
-- 1) SELECT: tout utilisateur authentifié peut lire
--    - les Tools système enabled
--    - ses propres Tools (enabled ou non)
create policy "ai_tools_select"
on public.ai_tools
for select
to authenticated
using (
  (visibility = 'system' and enabled = true)
  or (user_id = auth.uid())
);

-- 2) INSERT: un utilisateur peut créer des Tools perso (visibility='user', !is_system)
create policy "ai_tools_insert"
on public.ai_tools
for insert
to authenticated
with check (
  visibility = 'user'
  and user_id = auth.uid()
  and is_system = false
);

-- 3) UPDATE: un utilisateur peut modifier ses Tools perso (pas system)
create policy "ai_tools_update"
on public.ai_tools
for update
to authenticated
using (user_id = auth.uid() and is_system = false)
with check (user_id = auth.uid() and is_system = false);

-- 4) DELETE: un utilisateur peut supprimer ses Tools perso (pas system)
create policy "ai_tools_delete"
on public.ai_tools
for delete
to authenticated
using (user_id = auth.uid() and is_system = false);

-- NOTE: La gestion des Tools système (visibility='system', is_system=true) doit se faire via service role
--       (pas de policy d'insert/update/delete pour authenticated sur ces lignes)

-- =========================
-- Tables d'audit / observabilité
-- =========================

-- ai_runs: un run d'agent (session de résolution)
create table if not exists public.ai_runs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  user_id uuid not null default auth.uid(),
  route text,                     -- route Flutter au moment du run
  model text,
  status text,                    -- started/succeeded/failed/cancelled
  iterations int default 0,
  tokens_in int default 0,
  tokens_out int default 0,
  cost_estimate numeric(12,6) default 0,
  error text,
  trace_id text                   -- pour corrélation logs
);

create index if not exists ai_runs_user_created_idx on public.ai_runs (user_id, created_at desc);
create index if not exists ai_runs_trace_idx on public.ai_runs (trace_id);

drop trigger if exists ai_runs_set_updated_at on public.ai_runs;
create trigger ai_runs_set_updated_at
before update on public.ai_runs
for each row execute function set_updated_at();

alter table public.ai_runs enable row level security;

-- RLS: l'utilisateur voit uniquement ses runs
create policy "ai_runs_select_own"
on public.ai_runs
for select
to authenticated
using (user_id = auth.uid());

create policy "ai_runs_insert_own"
on public.ai_runs
for insert
to authenticated
with check (user_id = auth.uid());

create policy "ai_runs_update_own"
on public.ai_runs
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ai_tool_invocations: chaque appel de Tool dans un run
create table if not exists public.ai_tool_invocations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  run_id uuid not null references public.ai_runs(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  tool_key text not null,
  args jsonb,
  result_summary jsonb,
  duration_ms int,
  success boolean,
  error_code text,
  error_message text
);

create index if not exists ai_tool_invocations_run_idx on public.ai_tool_invocations (run_id);
create index if not exists ai_tool_invocations_user_created_idx on public.ai_tool_invocations (user_id, created_at desc);
create index if not exists ai_tool_invocations_tool_created_idx on public.ai_tool_invocations (tool_key, created_at desc);

drop trigger if exists ai_tool_invocations_set_updated_at on public.ai_tool_invocations;
create trigger ai_tool_invocations_set_updated_at
before update on public.ai_tool_invocations
for each row execute function set_updated_at();

alter table public.ai_tool_invocations enable row level security;

-- RLS: l'utilisateur voit seulement ses invocations
create policy "ai_tool_invocations_select_own"
on public.ai_tool_invocations
for select
to authenticated
using (user_id = auth.uid());

create policy "ai_tool_invocations_insert_own"
on public.ai_tool_invocations
for insert
to authenticated
with check (user_id = auth.uid());

create policy "ai_tool_invocations_update_own"
on public.ai_tool_invocations
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ai_messages: logs des messages (system/user/assistant/tool) - optionnellement masqués
create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  run_id uuid not null references public.ai_runs(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  role text not null,              -- 'system' | 'user' | 'assistant' | 'tool' | 'error'
  content text not null,
  content_hash text,
  token_count int default 0
);

create index if not exists ai_messages_run_idx on public.ai_messages (run_id, created_at);
create index if not exists ai_messages_user_created_idx on public.ai_messages (user_id, created_at);

alter table public.ai_messages enable row level security;
create policy "ai_messages_select_own"
on public.ai_messages
for select
to authenticated
using (user_id = auth.uid());
create policy "ai_messages_insert_own"
on public.ai_messages
for insert
to authenticated
with check (user_id = auth.uid());

-- =========================
-- (Optionnel) Whitelist HTTP pour future http_request
-- =========================
create table if not exists public.ai_http_hosts_allowed (
  host text primary key,
  methods_allowed text[] not null default array['GET','POST']::text[],
  headers_allowed text[] default array[]::text[],
  enabled boolean not null default true
);

-- =========================
-- Seed minimal d'un Tool système (exemple)
-- =========================
insert into public.ai_tools (
  key, name, description, category,
  version, risk_level, confirmation_policy,
  parameters_schema, returns_schema,
  execution_type, execution_config,
  timeout_ms, rate_limit_per_min,
  side_effects, streaming_supported,
  enabled, enabled_from_routes, tags,
  visibility, user_id, is_system
) values (
  'create_client',
  'Create Client',
  'Create a new client with minimal fields; idempotent via email if provided.',
  'crud',
  '1.0.0', 'medium', 'required',
  '{
    "type":"object",
    "properties":{
      "nom":{"type":"string","minLength":1},
      "prenom":{"type":"string","minLength":1},
      "email":{"type":"string","format":"email"},
      "telephone":{"type":"string"},
      "idempotency_key":{"type":"string"}
    },
    "required":["nom","prenom"],
    "additionalProperties":false
  }'::jsonb,
  '{
    "type":"object",
    "properties":{
      "success":{"type":"boolean"},
      "client_id":{"type":"string","format":"uuid"},
      "message":{"type":"string"}
    },
    "required":["success"],
    "additionalProperties":false
  }'::jsonb,
  'supabase_rpc',
  '{
    "function":"create_client",
    "schema":"public"
  }'::jsonb,
  8000, 30,
  true, false,
  true, array['/clients','/home'], array['clients','crud'],
  'system', null, true
) on conflict do nothing;
