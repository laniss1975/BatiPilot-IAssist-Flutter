# Réponse au Retour Technique

**Date :** 5 Novembre 2025
**Auteur :** Claude (Développeur principal)
**Destinataire :** Ami développeur

---

## 🙏 Remerciements

Merci énormément pour ce retour ultra-détaillé et les livrables fournis ! C'est exactement ce dont nous avions besoin. La qualité du code SQL et TypeScript est excellente et production-ready.

---

## ✅ Ce qui a été intégré (Phase 1 - COMPLÉTÉ)

### Migrations SQL

**Fichier :** `supabase/migrations/20251105_ai_tools_and_audit.sql`

✅ Table `ai_tools` complète avec TOUS les champs recommandés :
- `risk_level`, `confirmation_policy`, `roles_allowed`
- `timeout_ms`, `rate_limit_per_min`, `idempotency`
- `returns_schema`, `side_effects`, `streaming_supported`
- `enabled_from_routes`, `depends_on`, `tags`
- `visibility`, `is_system`

✅ Tables d'audit :
- `ai_runs` (sessions Agent)
- `ai_tool_invocations` (chaque appel Tool)
- `ai_messages` (logs messages)

✅ RLS policies :
- Users authentifiés peuvent lire Tools système enabled + leurs propres Tools
- Users peuvent créer/modifier/supprimer UNIQUEMENT leurs Tools perso
- Tools système gérés via service role

✅ Indexes appropriés sur `user_id`, `created_at`, `tool_key`, `run_id`

✅ Triggers `updated_at` automatiques

✅ Table `ai_http_hosts_allowed` (préparée pour v2)

✅ Seed d'un Tool exemple : `create_client`

---

### RPC Functions Postgres

**Fichier :** `supabase/migrations/20251105_rpc_functions.sql`

✅ **`create_client`** : Security invoker + RLS
- Validation nom/prenom requis
- Idempotency via email (si fourni, vérifie doublon)
- Retourne `{success, client_id, message, existing}`

✅ **`create_project`** : Security invoker + RLS
- Validation client_id appartient à user
- Génère numéro devis automatiquement (AAMM-N)
- Retourne `{success, project_id, devis_numero, message}`

✅ **`update_client`** : Security invoker + RLS
- Patch partiel (COALESCE pour ne modifier que champs fournis)
- Vérification ownership

✅ **`update_project`** : Security invoker + RLS
- Patch partiel
- Vérification ownership

✅ **`generate_devis_number`** : Security definer
- Format AAMM-N (ex: 2511-3)
- Compteur par user_id + mois

✅ **`get_prompt`** : Security invoker + RLS
- Récupère prompt depuis `ai_prompts`

**Note :** Toutes les fonctions CRUD sont en `security invoker` pour hériter des RLS. `generate_devis_number` est en `definer` car utilise compteur global.

---

### Modules TypeScript Edge Function

**Fichiers :** `supabase/functions/assist_flut/*.ts`

✅ **`types.ts`** : Définitions TypeScript complètes
- `ToolDefinition` avec tous les champs enrichis
- `ExecuteContext` (supabase client, userId, runId, traceId, currentRoute)
- `ExecuteResult` (ok/error)

✅ **`ajv.ts`** : Validation JSON Schema stricte
- `strict: true`, `allErrors: true`
- `additionalProperties: false`, `coerceTypes: false`
- Formats : email, uri, uuid

✅ **`utils.ts`** : Utilitaires
- `withTimeout()` : Wrapper Promise avec timeout + AbortSignal
- `maskPII()` : Masquage emails et téléphones français

✅ **`rate-limit.ts`** : Rate limiting
- Compte invocations dans `ai_tool_invocations` (dernière minute)
- Retourne `{allowed, retryAfterMs}`
- Fallback permissif en cas d'erreur (ne pas bloquer user)

✅ **`tools-loader.ts`** : Chargement Tools
- Charge Tools système enabled + Tools user enabled
- Gating par `enabled_from_routes` (filtre en mémoire pour v1)

✅ **`executeTool.ts`** : Exécuteur principal ⭐
- Validation Ajv stricte des arguments
- Rate limiting check
- Timeout wrapper
- Support `supabase_rpc`, `supabase_query`, `flutter_action`, `storage`
- Validation du retour avec `returns_schema`
- Logging détaillé dans `ai_tool_invocations`
- Gestion erreurs avec codes structurés

**`supabase_query` sécurisé :**
- `allowed_filters` whitelist (field + ops autorisés)
- Pas de WHERE arbitraire
- Limits (default + max)
- Order by (avec possibilité de whitelister fields)

**Execution types implémentés v1 :**
- ✅ `supabase_rpc`
- ✅ `supabase_query` (select only, avec allowed_filters)
- ✅ `flutter_action` (retourne action pour UI)
- ✅ `storage` (upload base64 + get_url)
- ⏳ `http_request` (placeholder v2)
- ⏳ `composed` (placeholder v2)

---

## 📝 Réponses à tes 10 questions

### 1. Auth des Edge Functions

**Réponse :** ✅ OUI, on passe bien le JWT user.

```typescript
// supabase/functions/assist_flut/index.ts (existant)
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_ANON_KEY') ?? '',
  { global: { headers: { Authorization: authHeader } } }
)
```

Tous les Tools hériteront de ce client authentifié → RLS actives.

---

### 2. RPC actuels : security invoker/definer ?

**Réponse :** Nouvelles RPC créées dans cette Phase :
- `create_client`, `create_project`, `update_client`, `update_project`, `get_prompt` → **security invoker** + RLS
- `generate_devis_number` → **security definer** (compteur global, mais contrôle interne avec `auth.uid()`)

**Anciennes RPC :** Pas encore de fonctions CRUD côté SQL avant cette Phase. Les actions étaient des stubs dans Flutter.

---

### 3. Modèle de rôles/permissions

**Réponse :** ❌ PAS ENCORE implémenté dans l'app.

**État actuel :** Chaque user voit uniquement SES données (RLS via `user_id`).

**Futur (Phase 2+) :**
- Multi-users dans une entreprise
- Rôles : owner, admin, editor, viewer
- Lier `roles_allowed` dans ai_tools

**Pour MVP :** `roles_allowed: null` (= tous les users authentifiés)

---

### 4. Protocole SSE

**Réponse :** ❌ AUCUN système SSE pour l'instant.

**État actuel :** Edge Function retourne une réponse unique JSON.

**Plan :**
- **Phase 4 :** Implémenter SSE avec events :
  - `agent_started`, `tool_call_started`, `tool_call_succeeded`, `tool_call_failed`
  - `answer_partial`, `answer_final`, `user_confirmation_requested`
- **Flutter :** Package `sse_client` ou `http` avec StreamedResponse
- **Deno :** `ReadableStream` avec `Content-Type: text/event-stream`

**Question pour toi :** Recommandes-tu un squelette SSE précis pour Deno + Flutter ? Gestion reconnexion ?

---

### 5. http_request / storage / job_async dans v1 ?

**Décision :**
- ✅ **`storage`** : OUI implémenté dans v1 (upload base64 + get_url)
- ⏳ **`http_request`** : NON v1 → v2 (pas de besoin immédiat identifié)
- ⏳ **`job_async`** : NON v1 → v2+ (optimisation future)

**MVP v1 :** `supabase_rpc`, `supabase_query`, `flutter_action`, `storage`

---

### 6. Volume de docs internes (RAG) ?

**Réponse :** Faible pour MVP.

**État actuel :** 6 prompts dans `ai_prompts` (formats, actions, etc.)

**Stratégie :**
- **Phase 1-2 :** Tool `get_prompt` suffit (simple RPC, pas besoin de RAG)
- **Phase 3+ :** Si 50+ documents → RAG avec pgvector + embeddings

**Pour MVP :** Pas de RAG, juste query sur `ai_prompts` où `key LIKE 'doc_%'`

---

### 7. Provider LLM par défaut ?

**État actuel :** Multi-providers configurables par user (OpenAI, Google, Anthropic, etc.)

**Recommandation MVP :**
- **Par défaut suggéré :** GPT-4o-mini ($0.15/1M tokens) ou Gemini 1.5 Flash
- **Premium :** GPT-4 Turbo, Claude 3.5 Sonnet (opt-in)

**Fallback :** Si erreur provider user → Gemini Flash (moins cher + fiable)

**Stratégie split model (future) :**
- Tool router : modèle petit (gpt-4o-mini)
- Reasoning/rédaction : modèle costaud (GPT-4 / Claude)

---

### 8. Mode "Dry-run/Review" ?

**Réponse :** ✅ OUI, absolument nécessaire.

**Implémentation planifiée (Phase 5) :**
- Champ `confirmation_policy` dans ai_tools (`none`, `required`, `required_strong`)
- Si `required` → Agent génère plan + actions → envoie SSE `user_confirmation_requested`
- Flutter affiche modal : "L'IA veut créer un client Jean Dupont. Confirmer ?"
- User clique OUI → Flutter renvoie confirmation → Agent continue

**Pour MVP :** Tous les Tools CRUD auront `confirmation_policy: required` par défaut.

**Question pour toi :** Comment gérer confirmation côté Agent Loop ? Pause + attente callback Flutter ?

---

### 9. Contrainte RGPD ?

**Contexte :** App BtoB, données clients finaux (nom, email, tel, adresse).

**Contraintes identifiées :**
- Logs IA : Anonymiser PII dans `ai_messages`
- Rétention : 90 jours max
- DPA avec fournisseurs LLM
- Option "Ne pas envoyer données au LLM" (mode local)

**Implémenté :**
- ✅ Fonction `maskPII()` dans utils.ts (emails, téléphones FR)
- ✅ Logs messages utilisent `maskPII()` avant insertion

**TODO Phase 6 :**
- CRON job purge logs > 90j
- Mention légale dans Settings
- Paramètre "Pas d'envoi LLM" (données restent locales)

---

### 10. Tests automatisés des Tools ?

**État actuel :** ❌ Aucun test automatisé.

**Plan Phase 6 :**
- Tests unitaires de chaque Tool (fixtures Supabase)
- "Golden tasks" = scénarios de référence ("Créer client + projet")
- Tests de non-régression
- Harness de tests avec jeux de données

**Question pour toi :** Framework de tests recommandé pour Deno Edge Functions ? Deno.test + mock Supabase ?

---

## ❓ Questions pour toi (8 questions)

### Q1 : Validation Ajv - Exemple "self-repair"

Tu mentionnes le pattern "error repair" où le LLM se corrige automatiquement.

**Implémentation actuelle :**
```typescript
// executeTool.ts:56-61
if (!valid) {
  const details = validate.errors;
  await logInvocation(ctx, tool, rawArgs, null, false, { code: 'VALIDATION_ERROR', message: JSON.stringify(details) });
  return { ok: false, error: { code: 'VALIDATION_ERROR', message: 'Invalid arguments', details } };
}
```

**Question :**
Dans l'Agent Loop, quand je reçois `{ ok: false, error: {...} }`, je dois :
1. Renvoyer l'erreur au LLM avec un message `role: 'tool', tool_call_id: xxx, content: error`
2. Le LLM essaie de corriger et relance le Tool
3. Max combien de tentatives ? 2-3 ?

Peux-tu me donner le pseudo-code précis de l'Agent Loop avec error repair ?

---

### Q2 : Gating par route - Implémentation

Tu proposes gating par route Flutter.

**Implémentation actuelle (tools-loader.ts) :**
```typescript
if (currentRoute) {
  tools = tools.filter((t: any) => {
    if (!t.enabled_from_routes || t.enabled_from_routes.length === 0) return true;
    return t.enabled_from_routes.includes(currentRoute);
  });
}
```

**Questions :**
- Flutter envoie `current_route: "/project_details"` dans le body de la requête ?
- Format exact : `"/project_details"` ou `"ProjectDetailsView"` ?
- Tools globaux (enabled_from_routes = null) → visibles partout ?

---

### Q3 : Sélection sémantique (embeddings)

Tu recommandes top-k sémantique pour limiter les Tools envoyés au LLM.

**Questions :**
- **Quand recalculer embeddings ?** À chaque modification de Tool (trigger SQL) ou cache avec invalidation manuelle ?
- **Quelle fonction d'embedding ?** `text-embedding-3-small` (OpenAI) ? `text-embedding-gecko` (Google) ? Gemini Embedding ?
- **Top-k = combien ?** 5-7 Tools max ? Ou dynamique selon complexité requête ?
- **Query pour top-k ?** Le user message sert de query ? Ou on extrait l'intent d'abord ?
- **Implémentation v1 ou v2 ?** Si v1, je peux implémenter maintenant. Sinon, on garde gating par route uniquement pour v1.

---

### Q4 : Tables d'audit - Indexes et rétention

**Questions :**
- **Indexes additionnels recommandés ?** Au-delà de ceux déjà créés (user_id, created_at, run_id, tool_key)
- **Stratégie de purge :** CRON job Supabase (SQL scheduled function) quotidien pour `DELETE WHERE created_at < now() - interval '90 days'` ?
- **Compression `ai_messages.content` ?** Gzip côté application ou laisser Postgres gérer ?
- **Analyse coûts stockage :** Estimes-tu combien de MB/user/mois pour les logs ? (pour anticiper coûts Supabase)

---

### Q5 : SSE + Flutter - Détails techniques

**Questions Flutter :**
- **Package recommandé :** `sse_client` (pub.dev) ou `http` avec `StreamedResponse` ?
- **Gestion reconnexion :** Si connexion drop pendant Agent Loop, comment Flutter récupère ? Faut-il un `resume_run_id` ?
- **Buffering :** Si Flutter UI occupée, les events SSE sont-ils bufferisés automatiquement ou risque de perte ?
- **Format event SSE :** JSON sur chaque ligne ? Exemple :
  ```
  event: tool_call_started
  data: {"run_id":"xxx","tool_key":"create_client","args":{...}}

  event: tool_call_succeeded
  data: {"run_id":"xxx","tool_key":"create_client","result":{...}}
  ```

**Questions Deno :**
- **Implémentation ReadableStream :** Tu as un squelette simple à partager ?
- **Heartbeat :** Envoyer des pings toutes les 30s pour maintenir connexion ?

---

### Q6 : Mode "Plan explicite" - Approche

Tu recommandes que le LLM génère un plan avant exécution.

**Approche 1 (2 appels LLM) :**
1. Premier appel : "Génère un plan JSON pour : <user_message>" → `{steps: [{tool, args}, ...]}`
2. Confirmation user du plan
3. Deuxième appel : "Exécute ce plan" avec Tools disponibles

**Approche 2 (1 appel + instruction) :**
1. Un seul appel avec prompt : "Think step by step. Output a plan first (in JSON), then execute each step."
2. Parser la réponse pour extraire le plan + exécuter

**Question :** Quelle approche recommandes-tu ?

**Contrainte :** Si 2 appels, ça double les coûts LLM. Mais approche 2 risque parsing fragile.

---

### Q7 : http_request - Whitelist hosts (v2)

Si on implémente `http_request` en v2 :

**Questions :**
- **Stockage whitelist :** Table `ai_http_hosts_allowed` (déjà créée) ou dans `execution_config` du Tool ?
- **Gestion :** Admin only peut ajouter hosts ? Ou chaque Tool peut définir ses hosts autorisés ?
- **Headers sensibles :** Comment gérer API keys (ex: appel API externe) ? Stocker dans Vault Supabase ?

---

### Q8 : Idempotency - Implémentation précise

**Questions :**
- **Génération `idempotency_key` :**
  - Côté Agent (UUID aléatoire) ?
  - Côté Flutter (hash de user_message + timestamp) ?
  - Fourni explicitement par Tool caller ?
- **Stockage :**
  - Ajouter colonne `idempotency_key` dans tables métier (clients, projets) ?
  - Ou table dédiée `idempotency_log(key, tool_key, result, expires_at)` ?
- **Durée validité :** 24h ? 7 jours ?
- **Gestion collision :** Si key existe :
  - Retourner entité existante (ex: `{success: true, client_id: xxx, existing: true}`)
  - Ou erreur `IDEMPOTENCY_CONFLICT` ?

**Implémentation actuelle (RPC `create_client`) :**
- Idempotency via `email` (si fourni, vérifie doublon)
- Pas encore de support `idempotency_key` générique

---

## 🔄 Prochaines étapes immédiates

### Étape A : Appliquer les migrations (TOI)

**Tu dois faire :**
```bash
# Depuis ton environnement Supabase local ou Dashboard
supabase db push

# Ou via Dashboard :
# - Copier contenu de 20251105_ai_tools_and_audit.sql
# - Exécuter dans SQL Editor
# - Idem pour 20251105_rpc_functions.sql
```

**Vérifications :**
- Table `ai_tools` créée avec tous les champs
- Tables `ai_runs`, `ai_tool_invocations`, `ai_messages` créées
- RPC functions disponibles (tester `SELECT public.create_client('Dupont', 'Jean')`)

---

### Étape B : Je crée les modèles Dart + Provider (MOI - Phase 2)

**Fichiers à créer :**
- `lib/models/ai_tool_model.dart`
- `lib/models/ai_run_model.dart`
- `lib/models/ai_tool_invocation_model.dart`
- `lib/providers/ai_tools_provider.dart`

**UI :**
- Onglet "Tools Management" dans AI Control Center
- Liste Tools + formulaire création/édition
- Testeur de Tool (envoyer args JSON → voir résultat)

---

### Étape C : Je modifie l'Edge Function pour Agent Loop (MOI - Phase 4)

**Modifications dans `assist_flut/index.ts` :**
- Charger Tools via `loadToolsForRoute()`
- Implémenter Agent Loop basique (max 3 iterations pour MVP)
- Formater Tools pour LLM (OpenAI + Gemini ont formats différents)
- Parser `tool_calls` de la réponse LLM
- Appeler `executeTool()` pour chaque tool_call
- Renvoyer résultats au LLM
- Réponse finale avec `{answer, toolsUsed, actions}`

---

### Étape D : SSE (MOI - Phase 4)

**Après tes réponses à Q5**, je pourrai implémenter :
- SSE côté Deno (ReadableStream)
- SSE client côté Flutter
- Events : `agent_started`, `tool_call_started`, etc.

---

### Étape E : Seed Tools système (MOI - Phase 5)

**Tools prioritaires MVP :**
1. `get_prompt` - Charger prompt depuis ai_prompts
2. `get_clients` - Lister clients (supabase_query avec allowed_filters)
3. `create_client` - Créer client (déjà seedé)
4. `update_client` - Modifier client
5. `create_project` - Créer projet
6. `update_project` - Modifier projet
7. `navigate_to_project_details` - Navigation Flutter
8. `generate_devis_number` - Générer numéro

---

## 💡 Tes offres d'aide - Priorisation

Tu proposes :
1. ✅ **Migrations SQL** → FAIT (intégré)
2. ✅ **Squelette TypeScript executeTool()** → FAIT (intégré)
3. ⏳ **Prompt "planification"** → OUI SVP (après réponse Q6)
4. ⏳ **Protocole SSE + reducer Flutter** → OUI SVP (après réponses Q5)

**Demande immédiate :**
Peux-tu me fournir les **2 derniers** (Prompt planification + SSE) une fois que tu auras répondu à mes 8 questions ?

---

## 📊 État d'avancement global

| Phase | Tâches | État | Durée estimée |
|-------|--------|------|---------------|
| **Phase 1** | Infrastructure (SQL + TS) | ✅ COMPLÉTÉ | 3-4j → **2j** (grâce à toi!) |
| **Phase 2** | UI Tools Management | ⏳ EN COURS | 2-3j |
| **Phase 3** | Tool Executor | ✅ COMPLÉTÉ | 4-5j → **2j** (grâce à toi!) |
| **Phase 4** | Agent Loop + SSE | 🔜 NEXT | 5-6j |
| **Phase 5** | Tools système + Confirmation | 🔜 | 3-4j |
| **Phase 6** | Tests + Audit + Optim | 🔜 | 4-5j |

**Total révisé :** 21-27 jours → **Gain de 5 jours grâce à ton aide !**

---

## 🎯 Conclusion

Ton retour et tes livrables ont **considérablement accéléré** le développement. La Phase 1 et une grosse partie de la Phase 3 sont déjà complétées grâce à ton code de qualité.

**Prochaines actions :**
1. **TOI :** Appliquer les migrations SQL
2. **TOI :** Répondre aux 8 questions ci-dessus
3. **MOI :** Créer modèles Dart + Provider + UI (Phase 2)
4. **TOI (optionnel) :** Fournir prompt planification + squelette SSE
5. **MOI :** Agent Loop + SSE (Phase 4)

**Merci encore pour cette collaboration de haute qualité !** 🙌

---

*Document généré le 5 novembre 2025 par Claude (Développeur principal)*
