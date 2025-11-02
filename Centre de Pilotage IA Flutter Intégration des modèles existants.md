# Centre de Pilotage IA (Flutter) — Intégration des modèles existants

**Version:** 1.0  
**Public cible:** Équipe Flutter (Riverpod + Supabase)  
**Objectif:** Reprendre le système multi-fournisseurs existant sans casser la compatibilité, avec un **modèle actif global** (un seul modèle utilisé à la fois), **sécurité côté Edge**, **UX simple**.

---

## Table des matières

- [1. Principes et périmètre](#1-principes-et-périmètre)
- [2. Données et compatibilité](#2-données-et-compatibilité)
    - [2.1 Tables réutilisées (existantes)](#21-tables-réutilisées-existantes)
    - [2.2 Nouvelle table (optionnelle, Flutter)](#22-nouvelle-table-optionnelle-flutter)
    - [2.3 Index d’unicité (recommandé)](#23-index-d’unicité-recommandé)
- [3. Sécurité (clés API et Edge Functions)](#3-sécurité-clés-api-et-edge-functions)
- [4. Flux UI — “Centre de Pilotage IA”](#4-flux-ui--centre-de-pilotage-ia)
- [5. API côté Flutter (Supabase Flutter)](#5-api-côté-flutter-supabase-flutter)
    - [5.1 “Mes clés”](#51-mes-clés)
    - [5.2 “Modèle actif (global)”](#52-modèle-actif-global)
    - [5.3 “Prompts système” (optionnel)](#53-prompts-système-optionnel)
- [6. Intégration avec l’Assistant (assist_flut)](#6-intégration-avec-lassistant-assist_flut)
- [7. Recommandations backend (pour l’équipe React/Supabase)](#7-recommandations-backend-pour-l’équipe-reactsupabase)
- [8. Plan d’implémentation (MVP → V2)](#8-plan-d’implémentation-mvp--v2)
- [9. FAQ](#9-faq)

---

## 1. Principes et périmètre

- **Un seul modèle actif global** pour toute l’application Flutter (pas par module).
- **Réutiliser au maximum** les tables existantes :  
  `ai_providers`, `ai_models`, `user_provider_credentials`, `ai_provider_configs`, `ai_system_prompts`.
- **L’utilisateur peut :**
    - Gérer ses clés API pour chaque fournisseur (set/test/status).
    - Choisir un **fournisseur** et un **modèle actif global**.
    - Ajouter ses **modèles “custom”** (sans toucher aux tables globales admin).
    - (Optionnel) Gérer ses **prompts système**.
- **Sécurité** : les clés API **ne sont jamais exposées côté Flutter** ; tous les appels LLM passent par une **Edge Function proxy** (`assist_flut`).
- **Compatibilité** : ne **pas modifier** les tables “admin-only”. Ajouter au besoin une **table Flutter user-scoped** pour les modèles custom.

---

## 2. Données et compatibilité

### 2.1 Tables réutilisées (existantes)

| Table | Usage côté app | RLS |
|------|----------------|-----|
| `ai_providers` | Lecture seule | — |
| | Liste des fournisseurs (OpenAI, Anthropic, Google, Mistral, Grok, …) | |
| `ai_models` | Lecture seule | — |
| | Liste des modèles proposés par l’admin pour chaque provider | |
| `user_provider_credentials` | RLS par user | ✅ |
| | Clés API chiffrées par utilisateur (set/test/status via Edge Function `ai-keys-manager`) | |
| `ai_provider_configs` | RLS par user | ✅ |
| | Choix du modèle actif. Dans Flutter : `module_name = 'global'` | |
| `ai_system_prompts` | RLS par user | ✅ |
| | Prompts système personnalisés (optionnel dans le MVP Flutter) | |

---

### 2.2 Nouvelle table (optionnelle, Flutter)

Pour permettre aux utilisateurs d’ajouter leurs propres modèles **sans modifier `ai_models` (admin-only)**, nous proposons :

```sql
-- Modèles personnalisés par utilisateur (Flutter uniquement)
create table if not exists public.ai_user_models_flut (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_key text not null,          -- 'openai' | 'anthropic' | 'google' | ...
  model_key text not null,             -- identifiant technique (ex: 'gpt-4o-latest')
  model_name text not null,            -- label affiché (ex: 'GPT-4o Latest (Custom)')
  is_active boolean not null default true,  -- juste pour “masquer” un custom si besoin
  created_at timestamptz not null default now(),
  constraint uq_user_model unique (user_id, provider_key, model_key)
);

alter table public.ai_user_models_flut enable row level security;

-- RLS: lecture/écriture restreinte à l’utilisateur
do $$  
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='ai_user_models_flut' and policyname='ai_user_models_flut_select_own'
  ) then
    create policy ai_user_models_flut_select_own
      on public.ai_user_models_flut
      for select to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='ai_user_models_flut' and policyname='ai_user_models_flut_manage_own'
  ) then
    create policy ai_user_models_flut_manage_own
      on public.ai_user_models_flut
      for all to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end   $$;
Usage : l’UI Flutter propose, en plus des modèles globaux (ai_models), les modèles custom de l’utilisateur (ai_user_models_flut).
Avantages : pas de modification des tables admin, pas de conflit avec l’appli React.

2.3 Index d’unicité (recommandé)
Pour garantir une seule config active par couple (user, module) :
sql-- Un seul is_active = true par (user_id, module_name)
create unique index if not exists uq_ai_provider_configs_active
on public.ai_provider_configs(user_id, module_name)
where is_active = true;
Dans Flutter : module_name = 'global'.
Avantages :

Intégrité : évite 2 configs actives simultanées.
Simplicité côté app : activer un modèle = rendre les autres inactifs.


3. Sécurité (clés API et Edge Functions)

Les clés API sont gérées uniquement via l’Edge Function ai-keys-manager (actions : set-key, get-status, test-key).
Ne JAMAIS appeler get-key depuis Flutter. Réservé aux Edge Functions (via x-internal-token).
Tous les appels LLM en production passent par une Edge Function proxy (assist_flut) qui :

Lit la config active (ai_provider_configs) pour module_name='global'
Récupère la clé via ai-keys-manager:get-key côté serveur
Appelle le provider choisi
Renvoie un JSON strict à Flutter




4. Flux UI — “Centre de Pilotage IA”
Une page unique avec trois sections :
Mes clés (par fournisseur)

Affiche l’état : Configurée / Non configurée + date et résultat du dernier test.
Actions : Ajouter/Mettre à jour, Tester, Supprimer.

Modèle actif (global)

Select Fournisseur (ai_providers actifs)
Select Modèle (union : ai_models du provider + ai_user_models_flut de l’utilisateur)
Bouton “Activer ce modèle global”
Bouton “Tester la configuration active” → badge Healthy (vert)
Bouton “Ajouter un modèle custom” (mini-form : model_key + model_name)

Prompts système (optionnel MVP)

Lister les prompts (ai_system_prompts)
CRUD simple + “Activer”
Option : stocker le snapshot dans ai_provider_configs.system_prompt

Visual feedback “Healthy” :
Clé OK + config active testée OK → badge/icone verte.

5. API côté Flutter (Supabase Flutter)
Hypothèses :

Riverpod pour le state
supabase_connection_provider expose le client


5.1 “Mes clés”
Ajouter / Mettre à jour une clé (set-key)
dartfinal client = ref.read(supabaseConnectionProvider).client!;
final resp = await client.functions.invoke('ai-keys-manager', body: {
  'action': 'set-key',
  'provider': 'openai',
  'apiKey': 'sk-xxxxxxxx' // jamais stockée côté app
});
if (resp.data['success'] == true) {
  // OK
}
Tester une clé (test-key)
dartfinal resp = await client.functions.invoke('ai-keys-manager', body: {
  'action': 'test-key',
  'provider': 'openai',
});
final ok = (resp.data['valid']?['ok'] == true);
Voir le statut des clés (get-status)
dartfinal resp = await client.functions.invoke('ai-keys-manager', body: {
  'action': 'get-status',
});
final map = (resp.data['data'] as Map<String, dynamic>);
// ex: { 'openai': true, 'anthropic': false, ... }
Supprimer une clé
Recommandé : ajouter delete-key dans ai-keys-manager.
Fallback (RLS) :
dartawait client
  .from('user_provider_credentials')
  .delete()
  .eq('provider_key', 'openai');

5.2 “Modèle actif (global)”
Charger les providers
dartfinal res = await client
  .from('ai_providers')
  .select('provider_key, provider_name, is_active')
  .eq('is_active', true);
final providers = (res.data as List).cast<Map<String, dynamic>>();
Charger les modèles disponibles
Globaux :
dartfinal modelsGlobal = await client
  .from('ai_models')
  .select('model_key, model_name, is_active, provider_id, provider:ai_providers!inner(provider_key)')
  .eq('is_active', true)
  .eq('provider.provider_key', providerKey);
Custom :
dartfinal modelsCustom = await client
  .from('ai_user_models_flut')
  .select('model_key, model_name, is_active')
  .eq('provider_key', providerKey);
→ Fusionner côté Dart (trier/filtrer doublons par model_key)
Activer un modèle global
dartfinal user = (await client.auth.getUser()).user!;
const module = 'global';

// 1) désactiver l’ancien actif
await client
  .from('ai_provider_configs')
  .update({'is_active': false})
  .eq('user_id', user.id)
  .eq('module_name', module)
  .eq('is_active', true);

// 2) upsert la nouvelle config active
await client
  .from('ai_provider_configs')
  .upsert({
    'user_id': user.id,
    'module_name': module,
    'provider_name': providerKey,
    'model_name': modelKey,
    'system_prompt': null,
    'is_active': true,
  }, onConflict: 'user_id, module_name');
Tester la configuration active
Si ai-config-test existe :
dartfinal resp = await client.functions.invoke('ai-config-test', body: {
  'module': 'global'
});
final healthy = (resp.data['success'] == true) &&
                (resp.data['api_key_ok'] == true) &&
                (resp.data['model_accessible'] == true);
Fallback : test-key + mini-chat via assist_flut
Ajouter un modèle custom
dartawait client.from('ai_user_models_flut').insert({
  'provider_key': providerKey,
  'model_key': modelKeyInput,
  'model_name': modelLabelInput,
});

5.3 “Prompts système” (optionnel)
Charger
dartfinal res = await client
  .from('ai_system_prompts')
  .select('id, name, prompt_content, is_active, created_at')
  .order('created_at');
Créer / Modifier / Supprimer
dartawait client.from('ai_system_prompts').insert({
  'name': 'Assistant Devis Standard',
  'prompt_content': 'Tu es un assistant ...',
  'is_active': false,
});
Activer un prompt (snapshot dans config)
dart// 1) set active prompt
await client
  .from('ai_system_prompts')
  .update({'is_active': false})
  .eq('is_active', true);
await client
  .from('ai_system_prompts')
  .update({'is_active': true})
  .eq('id', promptId);

// 2) snapshot dans la config active
await client
  .from('ai_provider_configs')
  .update({'system_prompt': promptContent})
  .eq('user_id', user.id)
  .eq('module_name', 'global')
  .eq('is_active', true);

6. Intégration avec l’Assistant (assist_flut)
Côté Flutter (AssistantController) :
dartfinal resp = await client.functions.invoke('assist_flut', body: {
  'module_name': 'global',
  'messages': [
    {'role': 'system', 'content': '... (optionnel) ...'},
    {'role': 'user', 'content': userText}
  ],
  'response_format': 'json',
});
Côté Edge (assist_flut) :

Lire config active pour (user_id, module_name='global')
Appeler ai-keys-manager:get-key (avec x-internal-token)
Appeler le fournisseur
Retourner JSON strict (pas de clé)


7. Recommandations backend (pour l’équipe React/Supabase)

get-key : bloquer appel public → exiger x-internal-token + EDGE_FUNCTIONS_SECRET
Unifier endpoints/headers dans ai_providers :

api_headers (jsonb)
api_auth_method (bearer | api_key_header | query_param)


test-key → lire endpoints depuis ai_providers (plus de hardcode)
Ajouter DeepSeek si supporté
Créer ai-config-test (Edge) pour vérifier clé + modèle
Ajouter index unique partiel sur ai_provider_configs (§2.3)
Optionnel : ai_usage_logs (tokens, erreurs, rate limits)
CORS : restreindre Access-Control-Allow-Origin à l’origine Flutter


8. Plan d’implémentation (MVP → V2)
MVP

UI “Centre de Pilotage IA” :

Mes clés (set-key, test-key, get-status)
Modèle actif global : select provider + model (global + custom), activer, tester


assist_flut : route les chats vers le modèle actif (module 'global')
(Option) ai_user_models_flut : activer si besoin

V2

Prompts système (CRUD + activer + snapshot)
ai-config-test (Edge) pour test complet
Diagnostics (historique tests, erreurs)
Monitoring coûts/tokens (ai_usage_logs)


9. FAQ
Pourquoi un modèle actif global ?
→ Simplifier l’UX et éviter les incohérences. Un seul modèle utilisé partout dans Flutter.
Peut-on enregistrer plusieurs modèles ?
Oui. Clés et modèles multiples. Un seul actif.
Pourquoi ai_user_models_flut ?
→ Permet d’ajouter des modèles sans toucher aux tables admin (ai_models). Évite impact sur l’appli web.
Peut-on éviter ai_user_models_flut ?
Oui, en saisissant un model_key libre à l’activation. Recommandé : table pour meilleure UX.
Est-ce que Flutter doit appeler les APIs OpenAI/Anthropic directement ?
Non. Toujours via Edge Functions (assist_flut, ai-keys-manager).