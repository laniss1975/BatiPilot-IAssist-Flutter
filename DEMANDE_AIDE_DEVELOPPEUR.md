# Demande d'Assistance Technique : Architecture AI Agent Autonome

**Date :** 5 Novembre 2025
**Projet :** BatiPilot IAssist
**De :** Claude (Développeur principal)
**À :** Développeur externe

---

## 📌 Contexte et présentation

Bonjour,

Je suis Claude, l'architecte et développeur principal de l'application **BatiPilot IAssist**. Je travaille sur un projet ambitieux d'intégration d'IA autonome et j'ai besoin de ton expertise technique sur plusieurs points critiques.

### Qu'est-ce que BatiPilot IAssist ?

**BatiPilot IAssist** est une application de gestion pour les artisans et entreprises du bâtiment, permettant de :
- Créer et gérer des devis de construction/rénovation
- Suivre les projets en cours
- Gérer clients et sociétés
- Automatiser la génération de documents

### Stack technique

- **Frontend :** Flutter (Windows, Android, iOS, Web)
- **Backend :** Supabase (PostgreSQL + Edge Functions Deno/TypeScript)
- **État :** Riverpod (state management)
- **IA :** Multi-providers (OpenAI GPT-4, Google Gemini, Anthropic Claude) - configurable par utilisateur
- **Auth & Database :** Supabase avec Row Level Security (RLS)

### État du projet

L'application est à environ **10-15% de développement**. Les fonctionnalités de base existent (CRUD projets, clients, sociétés, interface UI) mais **l'intégration IA** est le cœur du projet et nécessite une architecture solide.

---

## 🎯 Vision et objectif principal

### La vision unique du projet

> **"Créer une application DANS l'IA, et non l'inverse"**

Ce n'est **PAS** un chatbot ajouté à une application classique.
L'IA doit être un **Agent autonome** capable de :

✅ Naviguer dans l'application comme un utilisateur
✅ Exécuter des actions réelles (créer clients, projets, devis)
✅ Accéder dynamiquement à la documentation dont elle a besoin
✅ Consulter et modifier les données dans la base de données
✅ S'adapter aux évolutions de l'application **sans redéploiement**

### Pourquoi c'est crucial ?

Si l'IA est limitée à un chatbot classique :
- ❌ Faible valeur ajoutée pour l'utilisateur
- ❌ Pas d'automatisation réelle
- ❌ Maintenance de 2 systèmes parallèles (UI + IA)
- ❌ Investissement en développement perdu

Si l'IA est un Agent autonome :
- ✅ Valeur ajoutée énorme : l'utilisateur parle, l'IA agit
- ✅ Automatisation complète des tâches répétitives
- ✅ Un seul système : actions UI = Tools de l'IA
- ✅ Évolutivité maximale sans redéploiement

**C'est LE point crucial du projet.** Si on rate cette intégration, l'investissement est perdu.

---

## ✅ Ce qui a été fait (Phase 1 - Infrastructure)

### 1. Tables et schéma de base de données

**Table `ai_tools` :** Stocke tous les "Tools" (fonctions) que l'IA peut exécuter
```sql
CREATE TABLE ai_tools (
  id uuid,
  key text,                           -- Ex: 'create_client'
  name text,                          -- Ex: 'Create Client'
  description text,                   -- Description pour l'IA
  category text,                      -- 'crud', 'data', 'navigation', 'documentation'

  -- Versioning & sécurité
  version text,
  risk_level enum('low','medium','high','critical'),
  confirmation_policy enum('none','required','required_strong'),
  roles_allowed text[],

  -- Schémas de validation
  parameters_schema jsonb,            -- JSON Schema des paramètres attendus
  returns_schema jsonb,               -- JSON Schema du résultat attendu

  -- Exécution
  execution_type enum('supabase_rpc','supabase_query','flutter_action','storage','http_request','composed'),
  execution_config jsonb,             -- Configuration spécifique selon le type
  timeout_ms integer,
  rate_limit_per_min integer,
  idempotency jsonb,

  -- Gating (contrôle d'accès)
  enabled boolean,
  enabled_from_routes text[],         -- Ex: ['/home','/project_details']
  visibility enum('system','user'),
  user_id uuid,
  is_system boolean
);
```

**Tables d'audit/observabilité :**
- `ai_runs` : Chaque session d'Agent (run_id, user_id, model, status, tokens, cost, trace_id)
- `ai_tool_invocations` : Chaque appel de Tool (run_id, tool_key, args, result, duration, success)
- `ai_messages` : Logs des messages (role, content, avec PII masqué)

**RLS Policies :** Sécurité stricte
- Users authentifiés peuvent lire les Tools système enabled + leurs propres Tools
- Users peuvent créer/modifier/supprimer uniquement leurs Tools perso
- Tools système gérés via service role uniquement

**Statut :** ✅ Migrations SQL appliquées et testées

---

### 2. Fonctions RPC PostgreSQL

Fonctions métier en `security invoker` (héritent des RLS) :

```sql
-- Créer un client avec idempotency via email
create_client(nom, prenom, email?, telephone?, adresse?, idempotency_key?)
  → {success, client_id, message, existing}

-- Créer un projet avec génération auto du numéro devis
create_project(client_id, nom, type_projet?, adresse?, description?)
  → {success, project_id, devis_numero, message}

-- Modifier client (patch partiel)
update_client(client_id, nom?, prenom?, email?, telephone?, adresse?)
  → {success, client_id, message}

-- Modifier projet (patch partiel)
update_project(project_id, nom?, type_projet?, adresse?, description?, status?)
  → {success, project_id, message}

-- Générer numéro devis (format AAMM-N, ex: 2511-3)
generate_devis_number() → text

-- Récupérer un prompt depuis ai_prompts
get_prompt(prompt_key) → {success, prompt}
```

**Statut :** ✅ RPC functions créées et testées

---

### 3. Modules TypeScript Edge Function

**Architecture modulaire :**

**`types.ts`** : Définitions TypeScript
- `ToolDefinition` : Type complet d'un Tool avec tous les champs
- `ExecuteContext` : Contexte d'exécution (supabase client, userId, runId, currentRoute, signal)
- `ExecuteResult` : Résultat d'exécution (ok/error)

**`ajv.ts`** : Validation JSON Schema stricte
- Ajv en mode strict (`additionalProperties: false`, `coerceTypes: false`)
- Formats supportés : email, uri, uuid

**`utils.ts`** : Utilitaires
- `withTimeout()` : Wrapper Promise avec timeout + AbortSignal
- `maskPII()` : Masquage automatique emails et téléphones (RGPD)

**`rate-limit.ts`** : Rate limiting
- Compte invocations dans `ai_tool_invocations` (dernière minute)
- Retourne `{allowed, retryAfterMs}`
- Fallback permissif en cas d'erreur (ne pas bloquer l'utilisateur)

**`tools-loader.ts`** : Chargement des Tools
- Charge Tools système enabled + Tools user enabled
- Gating par route (`enabled_from_routes`)

**`executeTool.ts`** : Exécuteur principal ⭐
- Validation Ajv stricte des arguments
- Rate limiting check
- Timeout wrapper avec AbortController
- Support de 4 `execution_type` :
  - `supabase_rpc` : Appel fonction PostgreSQL
  - `supabase_query` : Query SELECT avec `allowed_filters` whitelist
  - `flutter_action` : Retourne action pour UI (navigation, etc.)
  - `storage` : Upload/download Supabase Storage
- Validation du résultat avec `returns_schema`
- Logging détaillé dans `ai_tool_invocations`

**Statut :** ✅ Modules TypeScript créés et testés

---

## 🚧 Ce qui reste à faire

### Phase 2 : Modèles Dart + Provider + UI (3-4 jours)

**Tâches :**
1. Créer modèles Dart : `AiTool`, `AiRun`, `AiToolInvocation`
2. Créer `AiToolsProvider` (Riverpod) avec CRUD
3. Créer UI "Tools Management" dans Settings > AI Control Center :
   - Liste des Tools (par catégorie, avec filtres)
   - Formulaire création/édition Tool
   - Éditeur JSON pour `parameters_schema` et `execution_config`
   - Testeur de Tool (envoyer args → voir résultat)
   - Toggle enable/disable

**Statut :** 🔜 Prochaine étape

---

### Phase 3 : Agent Loop (5-6 jours) ⚠️ CRITIQUE

**C'est le cœur du système.** L'Agent Loop permet à l'IA de :
1. Recevoir un message utilisateur
2. Charger les Tools disponibles (gating par route)
3. Décider quels Tools utiliser
4. Exécuter les Tools
5. Analyser les résultats
6. Répéter jusqu'à accomplir la tâche
7. Retourner une réponse finale

**Architecture :**
```
User → Edge Function (Agent Loop) → LLM
          ↓                           ↓
       [Tools]              "J'ai besoin de create_client"
          ↓                           ↓
     Exécute                  Reçoit résultat
       create_client                  ↓
          ↓                    Continue ou Répond
       Résultat
          └──────────────────────────→
```

**Tâches :**
1. Implémenter boucle itérative (max 5-10 iterations)
2. Formater Tools pour LLM (OpenAI et Gemini ont formats différents)
3. Parser `tool_calls` de la réponse LLM
4. Appeler `executeTool()` pour chaque tool_call
5. Gérer les erreurs avec "self-repair" (LLM corrige ses erreurs)
6. Construire réponse finale avec `{answer, toolsUsed, actions}`

**Statut :** 🔜 À faire

---

### Phase 4 : SSE (Server-Sent Events) pour UX temps réel (2-3 jours)

Pendant que l'Agent Loop s'exécute (peut prendre plusieurs secondes), l'utilisateur doit voir la progression en temps réel.

**Events SSE à envoyer :**
- `agent_started` : Agent démarre
- `tool_call_started` : Tool en cours d'exécution
- `tool_call_succeeded` : Tool terminé avec succès
- `tool_call_failed` : Tool a échoué
- `answer_partial` : Chunk de réponse (streaming)
- `answer_final` : Réponse finale
- `user_confirmation_requested` : L'IA demande confirmation pour une action critique

**UI Flutter (exemple) :**
```
┌────────────────────────────────────┐
│ 🤖 BatiPilot Assistant             │
├────────────────────────────────────┤
│ Vous: Crée-moi un client Jean...  │
│                                    │
│ Assistant:                         │
│ ⏳ Création du client en cours...  │
│ ✅ Client créé : Jean Dupont       │
│ ⏳ Création du projet...           │
│ ✅ Projet créé : Rénovation cuisine│
│                                    │
│ ✅ Terminé !                       │
│    [Voir le projet]                │
└────────────────────────────────────┘
```

**Statut :** 🔜 À faire

---

### Phase 5 : Seeds Tools système + Confirmation flow (3-4 jours)

**Créer les Tools essentiels :**
1. `get_prompt` : Charger un prompt depuis ai_prompts (documentation)
2. `get_clients` : Lister clients avec filtres
3. `create_client` : Créer client (avec confirmation)
4. `update_client` : Modifier client
5. `create_project` : Créer projet (avec confirmation)
6. `update_project` : Modifier projet
7. `navigate_to_project_details` : Navigation Flutter
8. `generate_devis_number` : Générer numéro

**Confirmation flow :**
- Si Tool a `confirmation_policy: required` → Agent envoie SSE `user_confirmation_requested`
- Flutter affiche modal : "L'IA veut créer un client Jean Dupont. Confirmer ?"
- User clique OUI → Flutter renvoie confirmation → Agent continue
- User clique NON → Agent abandonne et informe l'utilisateur

**Statut :** 🔜 À faire

---

### Phase 6 : Tests + Optimisations (4-5 jours)

**Tests :**
- Tests unitaires de chaque Tool
- "Golden tasks" (scénarios de référence)
- Tests de non-régression
- Tests end-to-end du flux complet

**Optimisations :**
- Cache des Tools (TTL 5 min)
- Sélection intelligente des Tools (ne pas tout envoyer au LLM)
- Split model (petit modèle pour routing, gros modèle pour reasoning)
- Compression des prompts

**Statut :** 🔜 À faire

---

## ❓ Points bloquants et demande d'aide

Voici les **8 points techniques critiques** sur lesquels j'ai besoin de ton expertise pour avancer efficacement.

### Q1 : Agent Loop avec "self-repair" - Implémentation détaillée

**Contexte :** Quand un Tool échoue (erreur de validation, timeout, etc.), je veux que le LLM puisse se corriger automatiquement.

**Question :**
Peux-tu me donner le **pseudo-code précis** de l'Agent Loop avec error repair ?

**Ce que je pense faire :**
```typescript
// Iteration 1: LLM demande create_client avec args invalides
llmResponse = await callLLM(messages, tools);
toolCall = llmResponse.tool_calls[0];
result = await executeTool(toolCall); // → {ok: false, error: {code: 'VALIDATION_ERROR', details: [...]}}

// Iteration 2: Renvoyer l'erreur au LLM
messages.push({
  role: 'tool',
  tool_call_id: toolCall.id,
  content: JSON.stringify(result.error)
});

llmResponse2 = await callLLM(messages, tools); // LLM corrige et réessaie

// Max combien d'itérations ? 2-3 tentatives max ?
```

**Questions précises :**
- Format du message d'erreur à renvoyer au LLM : JSON brut ou texte explicatif ?
- Max tentatives de correction : 2 ? 3 ? 5 ?
- Si après N tentatives ça échoue toujours, on fait quoi ? Abandon et message user ?

---

### Q2 : SSE (Server-Sent Events) - Architecture Deno + Flutter

**Contexte :** Je veux streamer les events de progression pendant l'Agent Loop.

**Questions Deno (Edge Function) :**
- Peux-tu me fournir un **squelette TypeScript minimal** pour implémenter SSE dans Deno ?
- Format des events : JSON sur chaque ligne ?
  ```
  event: tool_call_started
  data: {"run_id":"xxx","tool_key":"create_client","args":{...}}

  event: tool_call_succeeded
  data: {"run_id":"xxx","tool_key":"create_client","result":{...}}
  ```
- Heartbeat : envoyer des pings toutes les 30s pour maintenir la connexion ?
- Comment gérer proprement la fermeture du stream ?

**Questions Flutter :**
- Package recommandé : `sse_client` (pub.dev) ou `http` avec `StreamedResponse` ?
- Gestion reconnexion : si connexion drop pendant Agent Loop, comment Flutter récupère ?
- Buffering : si l'UI est occupée, les events SSE sont bufferisés automatiquement ou risque de perte ?

**Livrable attendu :** Un squelette minimal Deno SSE + exemple Flutter listener

---

### Q3 : Planification explicite (Plan avant exécution)

**Contexte :** Pour des tâches complexes ("Crée-moi un client ET un projet"), je veux que l'IA génère d'abord un plan, puis l'exécute.

**Approche 1 (2 appels LLM) :**
1. Premier appel : "Génère un plan JSON pour : <user_message>"
   → Réponse : `{steps: [{tool: 'create_client', args: {...}}, {tool: 'create_project', args: {...}}]}`
2. Confirmation utilisateur du plan (optionnel)
3. Deuxième appel : "Exécute ce plan" avec Tools disponibles

**Approche 2 (1 appel + instruction) :**
1. Un seul appel avec prompt : "Think step by step. First, output a detailed plan (in JSON), then execute each step."
2. Parser la réponse pour extraire le plan
3. Exécuter chaque step du plan

**Question :**
- Quelle approche recommandes-tu ?
- Approche 1 = double coût LLM mais plus propre
- Approche 2 = 1 seul appel mais parsing plus fragile

**Livrable attendu :** Un exemple de prompt pour "planification" + logique de parsing du plan

---

### Q4 : Sélection intelligente des Tools (éviter de tout envoyer au LLM)

**Contexte :** Si j'ai 50+ Tools dans la BDD, envoyer TOUS les Tools au LLM à chaque requête :
- Coûte cher en tokens
- Réduit la qualité de sélection (trop de choix)

**Stratégies de gating :**
1. **Par route Flutter** : Si user est sur `/project_details`, ne charger que les Tools avec `enabled_from_routes` contenant `/project_details`
2. **Par sémantique (embeddings)** : Indexer `name + description` des Tools en embeddings, faire un top-k (5-7) basé sur le user message

**Questions :**
- **Embeddings :**
  - Quelle fonction d'embedding recommandes-tu ? `text-embedding-3-small` (OpenAI) ? `text-embedding-gecko` (Google) ?
  - Quand recalculer embeddings ? Trigger SQL à chaque modification de Tool ? Ou cache avec invalidation manuelle ?
  - Top-k = combien ? 5 Tools ? 7 Tools ? Dynamique selon complexité requête ?
  - Le user message sert directement de query pour le top-k ou faut-il extraire l'intent d'abord ?

- **Implémentation :**
  - À implémenter dès v1 (MVP) ou v2 (optimisation) ?
  - Si v1, je peux utiliser pgvector (extension Supabase) ?

**Livrable attendu :** Recommandation stratégie + exemple de query pgvector si pertinent

---

### Q5 : Idempotency - Implémentation précise

**Contexte :** Pour éviter créations en double (ex: user clique 2 fois "Créer client"), je veux supporter l'idempotency.

**Questions :**
- **Génération `idempotency_key` :**
  - Côté Agent (UUID aléatoire à chaque Tool call) ?
  - Côté Flutter (hash de user_message + timestamp) ?
  - Fourni explicitement par l'utilisateur ?

- **Stockage :**
  - Ajouter colonne `idempotency_key` dans tables métier (clients, projets) ?
  - OU table dédiée `idempotency_log(key, tool_key, result, created_at, expires_at)` ?

- **Durée de validité :**
  - 24h ? 7 jours ? 30 jours ?

- **Gestion collision :**
  - Si key existe déjà : retourner entité existante (`{success: true, client_id: xxx, existing: true}`) ?
  - Ou erreur explicite `IDEMPOTENCY_CONFLICT` ?

**État actuel :**
La RPC `create_client` a une idempotency basique via `email` (si fourni, vérifie doublon). Mais pas de support générique `idempotency_key`.

**Livrable attendu :** Recommandation architecture + exemple SQL/TypeScript

---

### Q6 : Tables d'audit - Rétention et optimisations

**Contexte :** Les tables `ai_runs`, `ai_tool_invocations`, `ai_messages` vont grossir rapidement.

**Questions :**
- **Indexes additionnels recommandés ?**
  Au-delà de ceux déjà créés (user_id, created_at, run_id, tool_key)

- **Stratégie de purge (RGPD = 90 jours max) :**
  - CRON job Supabase (SQL scheduled function) quotidien ?
  - Query : `DELETE FROM ai_messages WHERE created_at < now() - interval '90 days'` ?
  - Faire en CASCADE sur `ai_runs` → supprime automatiquement `ai_tool_invocations` et `ai_messages` liés ?

- **Compression :**
  - Compresser `ai_messages.content` (gzip) côté application ?
  - Ou laisser Postgres gérer avec TOAST ?

- **Analyse coûts :**
  - Estimes-tu combien de MB/user/mois pour les logs ? (pour anticiper coûts Supabase)

**Livrable attendu :** Recommandations optimisations + exemple CRON SQL

---

### Q7 : Gestion des confirmations utilisateur dans Agent Loop

**Contexte :** Si un Tool a `confirmation_policy: required`, l'Agent doit :
1. Générer le plan d'action
2. Envoyer SSE `user_confirmation_requested` à Flutter
3. **PAUSE** en attendant la réponse de Flutter
4. Si OUI : continuer exécution
5. Si NON : abandonner et informer user

**Questions :**
- **Architecture de pause :**
  - L'Edge Function attend (bloque) la réponse Flutter ? (risque timeout 60s Supabase)
  - OU l'Edge Function retourne immédiatement `{status: 'awaiting_confirmation', run_id, plan}`, puis Flutter fait un 2ème appel avec `{run_id, confirmation: true}` pour reprendre ?

- **Stockage état :**
  - Si approche "2 appels", stocker l'état de l'Agent dans `ai_runs` (status='awaiting_confirmation', context=jsonb) ?
  - Comment sérialiser le contexte (messages LLM, Tools en cours, etc.) ?

- **Timeout confirmation :**
  - Si user ne répond pas dans X minutes, expirer le run ?

**Livrable attendu :** Recommandation architecture + pseudo-code

---

### Q8 : Formats Tools pour LLM (OpenAI vs Gemini vs Anthropic)

**Contexte :** Chaque provider LLM a un format différent pour Function Calling.

**OpenAI :**
```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "create_client",
        "description": "...",
        "parameters": { /* JSON Schema */ }
      }
    }
  ]
}
```

**Google Gemini :**
```json
{
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "create_client",
          "description": "...",
          "parameters": { /* JSON Schema mais format légèrement différent */ }
        }
      ]
    }
  ]
}
```

**Anthropic Claude :**
```json
{
  "tools": [
    {
      "name": "create_client",
      "description": "...",
      "input_schema": { /* JSON Schema */ }
    }
  ]
}
```

**Questions :**
- Dois-je créer une fonction `formatToolsForProvider(tools, providerKey)` qui convertit ?
- As-tu un exemple de code TypeScript pour cette conversion ?
- Parsing des `tool_calls` : même question (formats différents selon provider)

**Livrable attendu :** Fonction helper TypeScript pour formatter + parser tool_calls

---

## 📊 Récapitulatif et priorisation

### Ce qui est DÉJÀ fait ✅
- ✅ Infrastructure SQL complète (tables + RPC + RLS)
- ✅ Modules TypeScript (validation, rate limiting, exécution Tools)
- ✅ Sécurité de base (JWT, RLS, PII masking)

### Ce qu'il RESTE à faire 🚧
| Phase | Tâches | Durée | Bloquant ? |
|-------|--------|-------|------------|
| **Phase 2** | Dart models + Provider + UI Tools | 3-4j | Non |
| **Phase 3** | **Agent Loop** | 5-6j | **OUI** ⚠️ |
| **Phase 4** | SSE temps réel | 2-3j | **OUI** ⚠️ |
| **Phase 5** | Seeds Tools + Confirmation | 3-4j | Non |
| **Phase 6** | Tests + Optimisations | 4-5j | Non |

**Total estimé :** 17-24 jours

### Aide demandée en PRIORITÉ

| Question | Priorité | Bloquant ? |
|----------|----------|------------|
| **Q1** : Agent Loop avec self-repair | 🔴 P0 | OUI |
| **Q2** : SSE Deno + Flutter | 🔴 P0 | OUI |
| **Q3** : Planification explicite | 🟠 P1 | Non |
| **Q7** : Gestion confirmations | 🟠 P1 | Non |
| **Q8** : Formats Tools LLM | 🟠 P1 | Non |
| **Q4** : Sélection intelligente Tools | 🟡 P2 | Non |
| **Q5** : Idempotency | 🟡 P2 | Non |
| **Q6** : Audit rétention | 🟢 P3 | Non |

---

## 🙏 Résumé de ma demande

Bonjour et merci d'avoir pris le temps de lire ce document !

Je développe une application Flutter + Supabase avec une IA Agent autonome capable d'exécuter des actions réelles (créer clients, projets, etc.). L'infrastructure de base (SQL, TypeScript, validation, sécurité) est déjà en place.

**J'ai besoin de ton aide sur 8 points techniques, dont 2 prioritaires et bloquants :**

### 🔴 URGENT (Bloquants pour continuer)

1. **Q1 - Agent Loop avec self-repair :** Pseudo-code détaillé de la boucle itérative avec gestion erreurs
2. **Q2 - SSE Deno + Flutter :** Squelette minimal pour streamer events de progression

### 🟠 IMPORTANT (Non bloquants mais nécessaires pour MVP)

3. **Q3 - Planification explicite :** Approche et exemple de prompt
4. **Q7 - Gestion confirmations :** Architecture pause/resume Agent
5. **Q8 - Formats Tools LLM :** Fonction helper pour OpenAI/Gemini/Claude

### 🟡 MOYEN (Optimisations futures)

6. **Q4 - Sélection intelligente Tools :** Stratégie embeddings + top-k
7. **Q5 - Idempotency :** Architecture stockage + durée validité
8. **Q6 - Audit rétention :** CRON purge + optimisations

**Peux-tu m'aider au minimum sur Q1 et Q2 pour débloquer la Phase 3 ?**

Merci infiniment pour ton temps et ton expertise ! 🙏

---

*Document généré le 5 novembre 2025 par Claude (Développeur principal)*
