# Déploiement de l'AI Agent - BatiPilot IAssist

Ce document explique comment déployer et tester l'Agent IA avec tous ses composants.

---

## 📋 Prérequis

- ✅ Compte Supabase avec un projet créé
- ✅ Supabase CLI installé : `npm install -g supabase`
- ✅ Clé API d'au moins un provider LLM (OpenAI, Google Gemini, ou Anthropic Claude)
- ✅ Git installé

---

## 🚀 Étape 1 : Appliquer les Migrations SQL

### 1.1 Migrations déjà appliquées (vérifier)
- `20251105_ai_tools_and_audit.sql` ✅
- `20251105_rpc_functions.sql` ✅
- `20251106_audit_optimizations.sql` ✅
- `20251106_embeddings_pgvector.sql` ✅

### 1.2 Appliquer la nouvelle migration (Tools système)

Dans **Supabase Dashboard > SQL Editor**, exécuter :

```sql
-- Contenu du fichier: supabase/migrations/20251106_insert_system_tools.sql
-- Copier-coller tout le contenu du fichier
```

**Vérification** :
```sql
SELECT key, name, execution_type, enabled
FROM public.ai_tools
WHERE is_system = true;
```

Tu devrais voir **6 tools système** :
- `get_prompt`
- `get_clients`
- `create_client`
- `create_project`
- `get_devis`
- `navigate_to_project_details`

---

## 🔑 Étape 2 : Configurer les Variables d'Environnement

### 2.1 Créer un fichier `.env` local

```bash
cd supabase/functions
cp .env.example .env
```

### 2.2 Remplir les clés API

Éditer `supabase/functions/.env` :

```bash
# Choisir ton provider préféré
DEFAULT_LLM_PROVIDER=openai

# OpenAI (recommandé pour commencer)
OPENAI_API_KEY=sk-proj-...

# OU Google Gemini
# GEMINI_API_KEY=AIza...

# OU Anthropic Claude
# ANTHROPIC_API_KEY=sk-ant-...

# Secret admin (générer avec: openssl rand -hex 32)
X_ADMIN_SECRET=ton_secret_ici
```

### 2.3 Configurer dans Supabase Dashboard

**Supabase Dashboard > Edge Functions > Configuration > Environment Variables**

Ajouter :
- `DEFAULT_LLM_PROVIDER` = `openai`
- `OPENAI_API_KEY` = `sk-proj-...`
- `X_ADMIN_SECRET` = `ton_secret_ici`
- `LLM_TEMPERATURE` = `0.7`
- `LLM_MAX_TOKENS` = `4000`

---

## 📦 Étape 3 : Déployer l'Edge Function

### 3.1 Lier le projet Supabase

```bash
cd /chemin/vers/BatiPilot-IAssist-Flutter
supabase link --project-ref YOUR_PROJECT_REF
```

**Trouver `PROJECT_REF`** : Supabase Dashboard > Settings > General > Reference ID

### 3.2 Déployer la fonction

```bash
supabase functions deploy assist_flut --no-verify-jwt
```

**Note** : `--no-verify-jwt` car on gère l'auth manuellement dans le code (via header Authorization).

**Vérification** :
- Aller dans **Supabase Dashboard > Edge Functions**
- Tu devrais voir `assist_flut` avec statut **Active** ✅

---

## 🧪 Étape 4 : Tester l'Agent

### 4.1 Récupérer l'URL de la fonction

```bash
supabase functions list
```

OU directement : `https://YOUR_PROJECT_REF.supabase.co/functions/v1/assist_flut`

### 4.2 Obtenir un token JWT

**Option A : Via Supabase Dashboard**
- Dashboard > Authentication > Users
- Créer un user de test
- Copier le `access_token` depuis la table `auth.sessions`

**Option B : Via client Supabase (Flutter/Web)**
```dart
final session = await Supabase.instance.client.auth.currentSession;
final token = session?.accessToken;
```

### 4.3 Test avec curl

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/assist_flut \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userMessage": "Crée-moi un client nommé Jean Dupont avec l'\''email jean@dupont.fr",
    "currentRoute": "clients",
    "dryRun": true
  }'
```

**Réponse attendue** (SSE stream) :
```
event: agent_started
data: {"run_id":"...","tools_count":6}

event: plan_ready
data: {"run_id":"...","plan":{"summary":"Créer un client...","steps":[...]}}

event: user_confirmation_requested
data: {"run_id":"...","requires_action":"confirm"}

event: agent_finished
data: {"run_id":"...","status":"waiting_confirmation"}
```

### 4.4 Confirmer le plan

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/assist_flut/confirm \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "run_id": "le_run_id_de_la_réponse_précédente",
    "confirmation": true,
    "comment": "OK, go !"
  }'
```

### 4.5 Vérifier l'exécution dans la base

```sql
-- Voir les runs
SELECT id, status, model, iterations, tokens_in, tokens_out
FROM ai_runs
ORDER BY created_at DESC
LIMIT 5;

-- Voir les invocations de Tools
SELECT tool_key, success, created_at
FROM ai_tool_invocations
WHERE run_id = 'YOUR_RUN_ID';

-- Voir les messages (conversation)
SELECT role, substring(content, 1, 100) as preview
FROM ai_messages
WHERE run_id = 'YOUR_RUN_ID'
ORDER BY created_at;
```

---

## 🔍 Étape 5 : Activer pgvector (Embeddings)

### 5.1 Activer l'extension dans Dashboard

**Supabase Dashboard > Database > Extensions**

Chercher `vector` et cliquer **Enable** ✅

### 5.2 Vérifier l'activation

```sql
SELECT * FROM pg_extension WHERE extname = 'vector';
```

---

## 📊 Étape 6 : Monitoring & Logs

### 6.1 Voir les logs de l'Edge Function

**Supabase Dashboard > Edge Functions > assist_flut > Logs**

OU en CLI :
```bash
supabase functions logs assist_flut --tail
```

### 6.2 Requêtes utiles pour debug

```sql
-- Runs qui ont échoué
SELECT id, status, error, created_at
FROM ai_runs
WHERE status = 'failed'
ORDER BY created_at DESC;

-- Tools les plus utilisés
SELECT tool_key, COUNT(*) as usage_count
FROM ai_tool_invocations
GROUP BY tool_key
ORDER BY usage_count DESC;

-- Taux de succès par Tool
SELECT
  tool_key,
  COUNT(*) as total,
  SUM(CASE WHEN success THEN 1 ELSE 0 END) as successes,
  ROUND(100.0 * SUM(CASE WHEN success THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate
FROM ai_tool_invocations
GROUP BY tool_key;
```

---

## ⚠️ Troubleshooting

### Erreur : "Missing API key for provider: openai"
➡️ Vérifier que `OPENAI_API_KEY` est bien dans les Environment Variables de Supabase

### Erreur : "Tool xxx not found"
➡️ Vérifier que les 6 tools système sont bien insérés avec la migration SQL

### Erreur : "CORS error" lors du test depuis Flutter
➡️ Ajouter les CORS headers dans `index.ts` :
```typescript
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
```

### L'Agent ne répond pas (timeout)
➡️ Vérifier les logs : `supabase functions logs assist_flut`
➡️ Augmenter le timeout dans le client HTTP (ex: 120s pour SSE)

---

## ✅ État actuel du projet

**Backend (Supabase) : 85% ✅**
- ✅ Infrastructure SQL (tables, RLS, policies)
- ✅ RPC functions (create_client, create_project, etc.)
- ✅ Edge Function assist_flut (Agent Loop + SSE)
- ✅ Intégration LLM réelle (OpenAI/Gemini/Claude)
- ✅ Endpoints status/confirm
- ✅ Idempotency, rate limiting, audit
- ✅ Embeddings pgvector (infrastructure prête)
- ❌ Seeds de Tools personnalisés (seuls les 6 système sont créés)

**Frontend (Flutter) : 15% ⏳**
- ❌ Modèles Dart (AiTool, AiRun, etc.)
- ❌ Providers Riverpod
- ❌ UI Tools Management
- ❌ Client SSE Flutter
- ❌ Intégration avec l'UI chat existante

---

## 🎯 Prochaines Étapes

1. **Tester le flow complet** avec les 6 tools système (ce document, étape 4)
2. **Développer le Frontend Flutter** (modèles, providers, UI)
3. **Créer des Tools métier** supplémentaires (update_client, delete_project, etc.)
4. **Intégrer les Embeddings** pour la recherche sémantique de Tools
5. **Optimiser les prompts** Planner/Executor selon les résultats

---

## 📞 Support

Si tu rencontres des problèmes ou des erreurs, partage-moi :
1. Les logs de l'Edge Function
2. La requête SQL qui pose problème (si applicable)
3. La réponse curl complète (si test HTTP)

Je pourrai t'aider à débugger ! 🚀
