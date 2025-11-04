# Rapport Technique : Intégration IA Agent Autonome dans BatiPilot IAssist

**Date :** 4 Novembre 2025
**Auteur :** Claude (AI Assistant)
**Destinataire :** Équipe de développement
**Objet :** Stratégie d'implémentation d'une IA autonome avec Tools dynamiques

---

## 📋 Table des matières

1. [Contexte et présentation du projet](#1-contexte-et-présentation-du-projet)
2. [Vision stratégique : Une IA au cœur de l'application](#2-vision-stratégique--une-ia-au-cœur-de-lapplication)
3. [Travaux effectués jusqu'à présent](#3-travaux-effectués-jusquà-présent)
4. [Problème identifié : Architecture limitante](#4-problème-identifié--architecture-limitante)
5. [Solution proposée : AI Agent autonome avec Tools](#5-solution-proposée--ai-agent-autonome-avec-tools)
6. [Architecture technique détaillée](#6-architecture-technique-détaillée)
7. [Exemple concret de flux utilisateur](#7-exemple-concret-de-flux-utilisateur)
8. [Plan d'implémentation](#8-plan-dimplémentation)
9. [Risques et considérations](#9-risques-et-considérations)
10. [Conclusion et recommandations](#10-conclusion-et-recommandations)

---

## 1. Contexte et présentation du projet

### 1.1 BatiPilot IAssist : Qu'est-ce que c'est ?

**BatiPilot IAssist** est une application Flutter destinée aux **artisans et entreprises du bâtiment** pour la gestion de :
- **Devis de construction et rénovation**
- **Projets en cours**
- **Clients et entreprises**
- **Génération automatisée de documents**

### 1.2 Stack technique

- **Frontend :** Flutter (Windows, Android, iOS, Web)
- **Backend :** Supabase (PostgreSQL + Edge Functions Deno/TypeScript)
- **État :** Riverpod (state management)
- **IA :** Multiple providers (OpenAI, Google Gemini, etc.) configurables par l'utilisateur

### 1.3 État actuel de l'application

L'application est à **~10% de développement**. Les fonctionnalités de base existent (CRUD projets, clients, sociétés) mais l'intégration IA est au stade préliminaire.

---

## 2. Vision stratégique : Une IA au cœur de l'application

### 2.1 Objectif fondamental

> **"Créer une application DANS l'IA, et non l'inverse"**

L'IA ne doit **PAS** être un simple chatbot qui répond à des questions.
L'IA doit être un **Agent autonome** capable de :

✅ **Naviguer dans l'application** comme le ferait un utilisateur
✅ **Exécuter des actions réelles** (créer clients, projets, devis)
✅ **Accéder à toute la documentation** nécessaire dynamiquement
✅ **Consulter et modifier les données** dans Supabase
✅ **S'adapter aux évolutions** de l'application sans redéploiement

### 2.2 Pourquoi c'est crucial ?

Si l'IA est limitée à un simple chatbot :
- ❌ Valeur ajoutée faible pour l'utilisateur
- ❌ Pas d'automatisation réelle
- ❌ Nécessite de maintenir 2 systèmes en parallèle (UI + IA)
- ❌ L'investissement en développement est gaspillé

Si l'IA est un Agent autonome :
- ✅ **Valeur ajoutée énorme** : L'utilisateur parle, l'IA agit
- ✅ **Automatisation complète** des tâches répétitives
- ✅ **Un seul système** : Les actions disponibles dans l'UI = Tools de l'IA
- ✅ **Évolutivité maximale** : Ajouter des fonctionnalités = Ajouter des Tools

---

## 3. Travaux effectués jusqu'à présent

### 3.1 Phase 1 : Infrastructure des prompts (✅ Complété)

**Objectif :** Stocker les prompts système dans la base de données au lieu de les hardcoder.

**Implémentation :**
- ✅ Table `ai_prompts` créée dans Supabase avec RLS policies
- ✅ 6 prompts par défaut définis :
  - `prompt_system` : Prompt principal de l'IA
  - `prompt_details_projet` : Documentation de la page Projet
  - `prompt_formats_donnees` : Formats de données (numéros, noms, etc.)
  - `prompt_actions_societes` : Actions sur les sociétés
  - `prompt_actions_clients` : Actions sur les clients
  - `prompt_tools_disponibles` : Liste des Tools (non fonctionnels pour l'instant)

**Fichiers créés :**
- `supabase/migrations/20251103_create_ai_prompts.sql`
- `lib/models/ai_prompt_model.dart`
- `lib/providers/ai_prompts_provider.dart`

### 3.2 Phase 2 : Interface de gestion (✅ Complété)

**Objectif :** Permettre la gestion des prompts via l'interface utilisateur.

**Implémentation :**
- ✅ Nouvel onglet "Prompts Assistant" dans Settings > AI Control Center
- ✅ Interface CRUD complète (Create, Read, Update, Delete)
- ✅ Validation des clés de prompt
- ✅ Initialisation des prompts par défaut

**Fichiers modifiés :**
- `lib/ui/views/ai_control_center_view_new.dart`
- `lib/ui/widgets/left_pane.dart`

### 3.3 Phase 3 : Intégration dans le flux IA (✅ Complété)

**Objectif :** Faire en sorte que l'IA charge et utilise le prompt système depuis la BDD.

**Implémentation :**
- ✅ `assistant_controller.dart` charge `prompt_system` depuis la BDD
- ✅ Le prompt est envoyé à l'Edge Function dans le body de la requête
- ✅ L'Edge Function `assist_flut` utilise le prompt dynamique au lieu du hardcodé
- ✅ Logs de confirmation : "✅ Prompt système chargé depuis la BDD"

**Fichiers modifiés :**
- `lib/assistant/assistant_controller.dart`
- `supabase/functions/assist_flut/index.ts`

---

## 4. Problème identifié : Architecture limitante

### 4.1 Le constat

Après implémentation des Phases 1-3, l'IA charge bien son prompt système depuis la BDD, **MAIS** :

❌ L'IA ne peut **PAS** charger d'autres prompts dynamiquement
❌ L'IA ne peut **PAS** consulter la structure des tables Supabase
❌ L'IA ne peut **PAS** lire ou écrire dans la base de données
❌ L'IA ne peut **PAS** exécuter d'actions réelles

### 4.2 Pourquoi ?

L'architecture actuelle est un **appel unique au LLM** :

```
┌──────────┐     ┌──────────────┐     ┌─────────┐     ┌──────────┐
│ Flutter  │────▶│ Edge Function│────▶│   LLM   │────▶│ Réponse  │
└──────────┘     └──────────────┘     └─────────┘     └──────────┘
                        │                   ▲
                        │                   │
                        ▼                   │
                 ┌────────────┐             │
                 │   Supabase │─────────────┘
                 │ (Prompt)   │  Prompt statique chargé
                 └────────────┘  AVANT l'appel au LLM
```

**Problème :** Le LLM reçoit UN prompt statique et génère UNE réponse. Il n'a aucune capacité d'action.

### 4.3 Citation du product owner

> "On a donc actuellement une IA presque inutile, réduite, voire lobotomisée, et c'est pas du tout le but de mon travail."

**Diagnostic correct.** L'IA actuelle est un chatbot amélioré, pas un Agent autonome.

---

## 5. Solution proposée : AI Agent autonome avec Tools

### 5.1 Concept : AI Agent avec Function Calling

Un **AI Agent** est une IA qui peut :
1. **Raisonner** sur ce qu'elle doit faire
2. **Décider** quels outils utiliser
3. **Exécuter** des fonctions (Tools)
4. **Observer** les résultats
5. **Répéter** jusqu'à avoir accompli la tâche

C'est le modèle utilisé par **ChatGPT Code Interpreter**, **Claude Code**, **Cursor**, etc.

### 5.2 Architecture proposée : Agent Loop

```
┌──────────┐     ┌────────────────────────────────────────────┐
│ Flutter  │────▶│         Edge Function (Agent Loop)         │
└──────────┘     │                                            │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 1. Charge Tools depuis ai_tools (BDD)│  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 │                    ▼                       │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 2. Envoie au LLM : Prompt + Tools    │  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 │                    ▼                       │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 3. LLM décide : "J'ai besoin de      │  │
                 │  │    get_clients + create_project"     │  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 │                    ▼                       │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 4. Exécute les Tools                 │  │
                 │  │    - Query Supabase                  │  │
                 │  │    - Appelle RPC                     │  │
                 │  │    - Charge prompts                  │  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 │                    ▼                       │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 5. Renvoie résultats au LLM          │  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 │                    ▼                       │
                 │  ┌──────────────────────────────────────┐  │
                 │  │ 6. LLM génère réponse finale         │  │
                 │  └──────────────────────────────────────┘  │
                 │                    │                       │
                 └────────────────────┼───────────────────────┘
                                      │
                                      ▼
                            ┌───────────────────┐
                            │ Flutter reçoit :  │
                            │ - Answer          │
                            │ - Actions to exec │
                            └───────────────────┘
```

### 5.3 Les Tools : Le cœur du système

Un **Tool** est une fonction que l'IA peut appeler. Exemples :

| Tool | Description | Type d'exécution |
|------|-------------|------------------|
| `get_prompt` | Charger un prompt depuis `ai_prompts` | Supabase query |
| `get_table_schema` | Voir la structure d'une table | Supabase metadata |
| `get_clients` | Lister les clients (avec filtres) | Supabase query |
| `create_client` | Créer un nouveau client | Supabase RPC |
| `update_project` | Modifier un projet | Supabase RPC |
| `generate_devis_number` | Générer numéro au format AAMM-N | Supabase function |
| `navigate_to_project` | Envoyer signal de navigation | Flutter action |

---

## 6. Architecture technique détaillée

### 6.1 Nouvelle table : `ai_tools`

Cette table stocke **tous les Tools disponibles** pour l'IA.

```sql
CREATE TABLE ai_tools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),

  -- Identification
  key TEXT NOT NULL UNIQUE,              -- Ex: 'get_clients'
  name TEXT NOT NULL,                    -- Ex: 'Get Clients List'
  description TEXT NOT NULL,             -- Description pour l'IA
  category TEXT,                         -- 'data', 'crud', 'navigation', 'documentation'

  -- Schéma du Tool (pour l'IA)
  parameters_schema JSONB NOT NULL,      -- JSON Schema des paramètres
  examples JSONB,                        -- Exemples d'utilisation

  -- Exécution
  execution_type TEXT NOT NULL,          -- Comment exécuter ce Tool
  execution_config JSONB NOT NULL,       -- Configuration spécifique

  -- Gestion
  enabled BOOLEAN DEFAULT true,
  user_id UUID REFERENCES auth.users(id), -- NULL = Tool système
  is_system BOOLEAN DEFAULT false         -- Protège contre suppression
);
```

### 6.2 Types d'exécution des Tools

#### Type 1 : `supabase_rpc`
Appeler une fonction PostgreSQL (RPC).

**Exemple de Tool :**
```json
{
  "key": "create_client",
  "name": "Create Client",
  "description": "Create a new client in the database",
  "parameters_schema": {
    "type": "object",
    "properties": {
      "nom": {"type": "string"},
      "prenom": {"type": "string"},
      "email": {"type": "string", "format": "email"}
    },
    "required": ["nom", "prenom"]
  },
  "execution_type": "supabase_rpc",
  "execution_config": {
    "function": "create_client",
    "schema": "public"
  }
}
```

**Exécution dans Edge Function :**
```typescript
const result = await supabaseClient.rpc(
  tool.execution_config.function,
  toolArguments
);
```

#### Type 2 : `supabase_query`
Query directe sur une table.

**Exemple de Tool :**
```json
{
  "key": "get_clients",
  "name": "Get Clients",
  "description": "Retrieve clients list with optional filters",
  "parameters_schema": {
    "type": "object",
    "properties": {
      "limit": {"type": "number", "default": 50},
      "search": {"type": "string"}
    }
  },
  "execution_type": "supabase_query",
  "execution_config": {
    "table": "clients",
    "operation": "select",
    "columns": ["id", "nom", "prenom", "email", "telephone"]
  }
}
```

**Exécution dans Edge Function :**
```typescript
let query = supabaseClient
  .from(tool.execution_config.table)
  .select(tool.execution_config.columns.join(','));

if (toolArguments.search) {
  query = query.ilike('nom', `%${toolArguments.search}%`);
}

const { data, error } = await query.limit(toolArguments.limit || 50);
```

#### Type 3 : `flutter_action`
Retourner une action à exécuter côté Flutter (navigation, UI update).

**Exemple de Tool :**
```json
{
  "key": "navigate_to_project_details",
  "name": "Navigate to Project Details",
  "description": "Navigate to the project details page",
  "parameters_schema": {
    "type": "object",
    "properties": {
      "project_id": {"type": "string", "format": "uuid"}
    },
    "required": ["project_id"]
  },
  "execution_type": "flutter_action",
  "execution_config": {
    "action_type": "NAVIGATE_TO_PROJECT_DETAILS",
    "requires_user_confirmation": false
  }
}
```

**Exécution dans Edge Function :**
```typescript
// Le Tool ne s'exécute PAS immédiatement
// On le retourne dans la réponse pour que Flutter l'exécute
actions.push({
  type: tool.execution_config.action_type,
  payload: toolArguments
});
```

#### Type 4 : `composed`
Chaîner plusieurs Tools (pour actions complexes).

**Exemple de Tool :**
```json
{
  "key": "quick_create_devis",
  "name": "Quick Create Devis",
  "description": "Create client + project + devis in one go",
  "execution_type": "composed",
  "execution_config": {
    "steps": [
      {"tool": "create_client", "output_as": "client"},
      {"tool": "create_project", "use_output": "client.id"},
      {"tool": "generate_devis_number"},
      {"tool": "navigate_to_project_details", "use_output": "project.id"}
    ]
  }
}
```

### 6.3 Modification de l'Edge Function `assist_flut`

**Nouveaux composants à ajouter :**

1. **Tool Loader** : Charge les Tools depuis `ai_tools` (filtre par `enabled=true`)
2. **Tool Executor** : Exécute un Tool selon son `execution_type`
3. **Agent Loop** : Boucle LLM → Tools → LLM jusqu'à réponse finale
4. **Response Builder** : Construit la réponse avec answer + actions

**Pseudo-code de l'Agent Loop :**

```typescript
async function agentLoop(userMessage: string, maxIterations: number = 5) {
  // 1. Charger tous les Tools disponibles
  const tools = await loadToolsFromDB(supabaseClient, userId);

  // 2. Construire le prompt initial
  let messages = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userMessage }
  ];

  let iteration = 0;
  let toolsResults = [];

  while (iteration < maxIterations) {
    // 3. Appeler le LLM avec les Tools disponibles
    const llmResponse = await callLLM(messages, tools);

    // 4. Le LLM veut-il utiliser des Tools ?
    if (llmResponse.tool_calls && llmResponse.tool_calls.length > 0) {
      // 5. Exécuter chaque Tool demandé
      for (const toolCall of llmResponse.tool_calls) {
        const tool = tools.find(t => t.key === toolCall.name);
        const result = await executeTool(tool, toolCall.arguments);
        toolsResults.push({ tool: toolCall.name, result });

        // 6. Ajouter le résultat au contexte
        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify(result)
        });
      }

      iteration++;
      // 7. Reboucler : envoyer les résultats au LLM
      continue;
    }

    // 8. Le LLM a fini, il retourne une réponse finale
    return {
      answer: llmResponse.content,
      toolsUsed: toolsResults,
      actions: extractFlutterActions(toolsResults)
    };
  }

  throw new Error('Max iterations reached');
}
```

### 6.4 Interface de gestion des Tools

Un nouvel onglet dans **Settings > AI Control Center > "Tools Management"** :

**Fonctionnalités :**
- 📋 Liste des Tools par catégorie (Data, CRUD, Navigation, Documentation)
- ➕ Créer un nouveau Tool (formulaire)
- ✏️ Modifier un Tool existant
- 🔴 Activer/Désactiver un Tool
- 🧪 Tester un Tool avec des paramètres JSON
- 📊 Voir l'historique d'utilisation des Tools
- 📚 Documentation auto-générée des Tools

**Wireframe (simplifié) :**
```
┌─────────────────────────────────────────────────────────────┐
│ Tools Management                                   [+ New]   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Categories:                  │  Tool Details:              │
│  ☑ Data (5)                   │                             │
│  ☑ CRUD (8)                   │  Name: Get Clients          │
│  ☑ Navigation (3)             │  Key: get_clients           │
│  ☐ Documentation (2)          │  Category: Data             │
│                               │                             │
│  Tools:                       │  Description:               │
│  ────────────────────────     │  Retrieve clients list      │
│  [✓] get_clients              │  with optional filters      │
│  [✓] get_projects             │                             │
│  [✓] get_companies            │  Parameters:                │
│  [✗] get_devis_history        │  {                          │
│  [✓] create_client            │    "limit": 50,             │
│  [✓] create_project           │    "search": ""             │
│  ...                          │  }                          │
│                               │                             │
│                               │  Execution:                 │
│                               │  Type: supabase_query       │
│                               │  Table: clients             │
│                               │                             │
│                               │  [Test Tool]  [Save]  [Del] │
└───────────────────────────────┴─────────────────────────────┘
```

---

## 7. Exemple concret de flux utilisateur

### 7.1 Scénario

L'utilisateur dit à l'IA :
**"Crée-moi un nouveau client Jean Dupont, email jean@dupont.fr, puis crée un projet de rénovation cuisine pour lui."**

### 7.2 Flux détaillé

**1. Flutter → Edge Function**
```json
{
  "userMessage": "Crée-moi un nouveau client Jean Dupont, email jean@dupont.fr, puis crée un projet de rénovation cuisine pour lui.",
  "module": "projet",
  "projectState": {...},
  "systemPrompt": "<prompt_system depuis BDD>"
}
```

**2. Edge Function : Charge les Tools**
```sql
SELECT * FROM ai_tools WHERE enabled = true
```
→ Résultat : 20 Tools disponibles (dont `create_client`, `create_project`, `navigate_to_project_details`)

**3. Edge Function : Envoie au LLM (Iteration 1)**
```json
{
  "messages": [
    {"role": "system", "content": "<systemPrompt>"},
    {"role": "user", "content": "Crée-moi un nouveau client..."}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "create_client",
        "description": "Create a new client in the database",
        "parameters": {
          "type": "object",
          "properties": {
            "nom": {"type": "string"},
            "prenom": {"type": "string"},
            "email": {"type": "string"}
          }
        }
      }
    },
    {...autres tools...}
  ]
}
```

**4. LLM répond : "Je vais utiliser create_client"**
```json
{
  "tool_calls": [
    {
      "id": "call_abc123",
      "name": "create_client",
      "arguments": {
        "nom": "Dupont",
        "prenom": "Jean",
        "email": "jean@dupont.fr"
      }
    }
  ]
}
```

**5. Edge Function : Exécute le Tool**
```typescript
// Trouve le Tool dans la BDD
const tool = tools.find(t => t.key === 'create_client');

// Exécute selon execution_type
const result = await supabaseClient.rpc('create_client', {
  nom: 'Dupont',
  prenom: 'Jean',
  email: 'jean@dupont.fr'
});

// Result:
// { success: true, client_id: 'uuid-xxx-yyy', message: 'Client créé' }
```

**6. Edge Function : Renvoie le résultat au LLM (Iteration 2)**
```json
{
  "messages": [
    {...messages précédents...},
    {
      "role": "tool",
      "tool_call_id": "call_abc123",
      "content": "{\"success\": true, \"client_id\": \"uuid-xxx-yyy\"}"
    }
  ],
  "tools": [...mêmes tools...]
}
```

**7. LLM répond : "Maintenant je crée le projet"**
```json
{
  "tool_calls": [
    {
      "id": "call_def456",
      "name": "create_project",
      "arguments": {
        "client_id": "uuid-xxx-yyy",
        "nom": "Rénovation cuisine",
        "type": "renovation"
      }
    }
  ]
}
```

**8. Edge Function : Exécute le 2ème Tool**
```typescript
const result = await supabaseClient.rpc('create_project', {
  client_id: 'uuid-xxx-yyy',
  nom: 'Rénovation cuisine',
  type: 'renovation'
});

// Result:
// { success: true, project_id: 'uuid-aaa-bbb' }
```

**9. Edge Function : Renvoie au LLM (Iteration 3)**
```json
{
  "messages": [
    {...},
    {
      "role": "tool",
      "tool_call_id": "call_def456",
      "content": "{\"success\": true, \"project_id\": \"uuid-aaa-bbb\"}"
    }
  ]
}
```

**10. LLM répond : Réponse finale**
```json
{
  "content": "✅ J'ai créé le client Jean Dupont (jean@dupont.fr) et son projet \"Rénovation cuisine\". Voulez-vous accéder aux détails du projet ?",
  "tool_calls": null  // Pas d'autres Tools à appeler
}
```

**11. Edge Function → Flutter : Réponse complète**
```json
{
  "answer": "✅ J'ai créé le client Jean Dupont...",
  "contextUpdate": {
    "type": "CLIENT_AND_PROJECT_CREATED",
    "payload": {
      "client_id": "uuid-xxx-yyy",
      "project_id": "uuid-aaa-bbb"
    }
  },
  "actionButtons": [
    {
      "label": "Voir le projet",
      "action": "NAVIGATE_TO_PROJECT_DETAILS",
      "payload": {"project_id": "uuid-aaa-bbb"}
    }
  ],
  "toolsUsed": [
    {"tool": "create_client", "success": true},
    {"tool": "create_project", "success": true}
  ]
}
```

**12. Flutter : Affiche la réponse + boutons d'action**

L'utilisateur peut cliquer sur "Voir le projet" → Navigation automatique.

### 7.3 Résultat

En **UNE seule phrase**, l'utilisateur a :
- ✅ Créé un client
- ✅ Créé un projet lié
- ✅ Reçu une confirmation
- ✅ Accès direct au projet

**Temps pour l'utilisateur : 5 secondes.**
**Sans IA : ~2 minutes (navigation UI, formulaires, etc.).**

---

## 8. Plan d'implémentation

### Phase 1 : Infrastructure des Tools (2-3 jours)

**Tâches :**
1. ✏️ Créer la migration SQL pour `ai_tools`
2. ✏️ Créer le modèle Dart `AiTool`
3. ✏️ Créer le provider Riverpod `AiToolsProvider`
4. ✏️ Définir les 10-15 premiers Tools système (en JSON)
5. ✏️ Script SQL pour insérer les Tools par défaut

**Livrables :**
- `supabase/migrations/20251104_create_ai_tools.sql`
- `lib/models/ai_tool_model.dart`
- `lib/providers/ai_tools_provider.dart`
- `INSERT_TOOLS_DEFAULT.sql`

### Phase 2 : Interface de gestion des Tools (2-3 jours)

**Tâches :**
1. ✏️ Ajouter l'onglet "Tools Management" dans AI Control Center
2. ✏️ Liste des Tools (par catégorie, avec filtres)
3. ✏️ Formulaire de création/édition de Tool
4. ✏️ Éditeur JSON pour `parameters_schema` et `execution_config`
5. ✏️ Fonction "Test Tool" (envoyer des paramètres et voir le résultat)
6. ✏️ Toggle enable/disable

**Livrables :**
- `lib/ui/views/ai_control_center_view_new.dart` (4ème onglet)
- `lib/ui/widgets/tool_editor_widget.dart`
- `lib/ui/widgets/tool_tester_widget.dart`

### Phase 3 : Tool Executor dans Edge Function (3-4 jours)

**Tâches :**
1. ✏️ Créer `loadToolsFromDB()` : Charge les Tools depuis Supabase
2. ✏️ Créer `executeTool()` : Dispatch selon `execution_type`
   - Implémenter `supabase_rpc`
   - Implémenter `supabase_query`
   - Implémenter `flutter_action`
   - Implémenter `composed` (optionnel pour v1)
3. ✏️ Gestion d'erreurs et logs détaillés
4. ✏️ Tests unitaires des exécuteurs

**Livrables :**
- `supabase/functions/assist_flut/tools-loader.ts`
- `supabase/functions/assist_flut/tools-executor.ts`

### Phase 4 : Agent Loop (4-5 jours)

**Tâches :**
1. ✏️ Implémenter la boucle Agent dans `assist_flut/index.ts`
2. ✏️ Formater les Tools pour OpenAI/Gemini (formats différents)
3. ✏️ Parser les `tool_calls` de la réponse LLM
4. ✏️ Gérer les iterations (max 5-10)
5. ✏️ Construire la réponse finale avec `toolsUsed` et `actions`
6. ✏️ Logs détaillés de chaque étape

**Livrables :**
- `supabase/functions/assist_flut/agent-loop.ts`
- `supabase/functions/assist_flut/index.ts` (modifié)

### Phase 5 : Implémentation des premiers Tools système (2-3 jours)

**Tools prioritaires :**

**Catégorie : Documentation**
1. `get_prompt` - Charger un prompt depuis `ai_prompts`
2. `get_table_schema` - Voir la structure d'une table
3. `search_documentation` - Chercher dans les prompts

**Catégorie : Data (lecture seule)**
4. `get_clients` - Lister les clients
5. `get_projects` - Lister les projets
6. `get_companies` - Lister les sociétés
7. `get_project_details` - Détails complets d'un projet

**Catégorie : CRUD**
8. `create_client` - Créer un client
9. `update_client` - Modifier un client
10. `create_project` - Créer un projet
11. `update_project` - Modifier un projet
12. `create_company` - Créer une société

**Catégorie : Navigation**
13. `navigate_to_project_details` - Aller à la page Projet
14. `navigate_to_client_list` - Aller à la liste clients
15. `navigate_to_home` - Retour à l'accueil

**Livrables :**
- Fichier JSON avec tous les Tools
- Script SQL pour les insérer

### Phase 6 : Tests et optimisations (3-4 jours)

**Tâches :**
1. ✏️ Tests end-to-end de scénarios utilisateur
2. ✏️ Mesure de performance (temps de réponse, nombre d'iterations)
3. ✏️ Optimisation du prompt système
4. ✏️ Optimisation de la sélection des Tools (ne pas envoyer TOUS les Tools à chaque fois)
5. ✏️ Gestion du cache (Tools, schémas de tables)
6. ✏️ Documentation utilisateur

**Livrables :**
- Suite de tests
- Rapport de performance
- Documentation utilisateur

### Estimation totale : 16-22 jours de développement

---

## 9. Risques et considérations

### 9.1 Risques techniques

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| **Coût des appels LLM** | Élevé | Élevé | Cache, limiter iterations, choisir modèles économiques |
| **Latence de réponse** | Moyen | Moyen | Optimiser Agent Loop, exécution Tools en parallèle |
| **Erreurs d'exécution Tools** | Élevé | Moyen | Validation stricte des paramètres, rollback si erreur |
| **LLM ne comprend pas les Tools** | Élevé | Faible | Descriptions claires, exemples, prompt engineering |
| **Boucle infinie Agent Loop** | Critique | Faible | Max iterations (5-10), timeout global |
| **Sécurité : SQL injection** | Critique | Faible | Utiliser EXCLUSIVEMENT RPC et queries Supabase (jamais de SQL brut) |

### 9.2 Considérations de sécurité

**Principe : L'IA ne doit jamais exécuter de SQL brut.**

✅ **Sécurisé :**
```typescript
// Via RPC (fonction PostgreSQL pré-définie)
await supabaseClient.rpc('create_client', {nom, prenom, email});

// Via query builder Supabase (protégé contre injection)
await supabaseClient.from('clients').select('*').eq('id', clientId);
```

❌ **INTERDIT :**
```typescript
// SQL brut = DANGER
await supabaseClient.query(`SELECT * FROM clients WHERE nom = '${userInput}'`);
```

**Autres mesures :**
- RLS policies Supabase : L'IA n'accède qu'aux données de l'utilisateur connecté
- Validation des paramètres Tools avant exécution
- Audit log de toutes les actions de l'IA
- Confirmation utilisateur pour actions critiques (suppression, facturation, etc.)

### 9.3 Considérations de coût

**Estimation des coûts LLM (exemple OpenAI GPT-4) :**

- **Prompt système complet :** ~2000 tokens
- **Tools schemas (15 Tools) :** ~1500 tokens
- **Message utilisateur + contexte :** ~500 tokens
- **Réponses LLM (3 iterations) :** ~1000 tokens
- **Total par conversation :** ~5000 tokens

**Coût :**
- GPT-4 Turbo : ~$0.01 / 1K tokens → $0.05 par conversation
- GPT-4o-mini : ~$0.0001 / 1K tokens → $0.0005 par conversation
- Gemini Pro : ~$0.0005 / 1K tokens → $0.0025 par conversation

**Pour 1000 utilisateurs actifs (10 conversations/jour) :**
- GPT-4 Turbo : $500/jour = $15,000/mois
- GPT-4o-mini : $5/jour = $150/mois ✅ Abordable
- Gemini Pro : $25/jour = $750/mois

**Recommandation :** Offrir GPT-4o-mini ou Gemini Pro par défaut, GPT-4 Turbo en option premium.

### 9.4 Considérations UX

**Feedback utilisateur pendant l'Agent Loop :**

Pendant que l'IA exécute des Tools, l'utilisateur doit voir un feedback :

```
┌────────────────────────────────────┐
│ 🤖 BatiPilot Assistant             │
├────────────────────────────────────┤
│ Vous: Crée-moi un client...        │
│                                    │
│ Assistant:                         │
│ ⏳ Création du client en cours...  │
│ ✅ Client créé : Jean Dupont       │
│ ⏳ Création du projet...           │
│ ✅ Projet créé : Rénovation cuisine│
│                                    │
│ ✅ Terminé ! Voulez-vous voir le   │
│    projet ?                        │
│                                    │
│    [Voir le projet] [Continuer]   │
└────────────────────────────────────┘
```

**Implémentation :**
- Flutter reçoit des events SSE (Server-Sent Events) pendant l'Agent Loop
- Chaque Tool exécuté = 1 event → UI update en temps réel

---

## 10. Conclusion et recommandations

### 10.1 Pourquoi cette architecture est nécessaire

L'objectif de BatiPilot IAssist est d'être **une application pilotée par l'IA**, pas une application avec un chatbot annexe.

**Sans AI Agent autonome :**
- ❌ L'IA est un gadget marketing sans valeur réelle
- ❌ Les utilisateurs préfèrent l'interface classique (plus rapide, plus fiable)
- ❌ Maintenance de 2 systèmes parallèles (UI + IA)
- ❌ ROI négatif

**Avec AI Agent autonome :**
- ✅ L'IA devient **LE** moyen principal d'utiliser l'application
- ✅ Gain de temps massif pour les utilisateurs
- ✅ Différenciation forte sur le marché
- ✅ Évolutivité : Chaque nouvelle fonctionnalité = nouveau Tool
- ✅ ROI positif : Les utilisateurs paient pour le gain de productivité

### 10.2 Recommandations

#### Recommandation 1 : Investir dans cette architecture maintenant

**Pourquoi maintenant ?**
- L'application est à 10% de développement : C'est le BON moment
- Refactoriser plus tard sera 10x plus coûteux
- Chaque nouvelle fonctionnalité sera conçue "AI-first"

**Coût estimé :** 16-22 jours de développement
**Bénéfice :** Fondation solide pour toute l'application

#### Recommandation 2 : Approche itérative

**Ne pas tout implémenter d'un coup.**

**Version 1 (MVP) :**
- Agent Loop basique (max 3 iterations)
- 5-8 Tools essentiels (get_clients, create_client, create_project, navigate)
- Interface de gestion simple

**Version 2 :**
- Plus de Tools (15-20)
- Composed Tools
- Optimisations performance

**Version 3 :**
- Tools personnalisés par utilisateur
- Marketplace de Tools
- Analytics et suggestions

#### Recommandation 3 : Documentation et exemples

Pour chaque Tool, fournir :
- Description claire (pour l'IA)
- Schéma JSON des paramètres
- 2-3 exemples concrets
- Tests unitaires

**Exemple de documentation de Tool :**

```markdown
## Tool: create_client

### Description
Crée un nouveau client dans la base de données avec validation automatique.

### Paramètres
- `nom` (string, required) : Nom de famille du client
- `prenom` (string, required) : Prénom du client
- `email` (string, optional) : Email (validé format email)
- `telephone` (string, optional) : Téléphone
- `adresse` (string, optional) : Adresse complète

### Exemples

**Exemple 1 : Client minimal**
```json
{
  "nom": "Dupont",
  "prenom": "Jean"
}
```

**Exemple 2 : Client complet**
```json
{
  "nom": "Martin",
  "prenom": "Sophie",
  "email": "sophie.martin@example.com",
  "telephone": "0612345678",
  "adresse": "15 rue de la Paix, 75002 Paris"
}
```

### Retour
```json
{
  "success": true,
  "client_id": "uuid-xxx-yyy",
  "message": "Client créé avec succès"
}
```

### Cas d'erreur
- Email invalide → `error: "Format email invalide"`
- Client déjà existant → `error: "Un client avec cet email existe déjà"`
```

#### Recommandation 4 : Tests avec utilisateurs réels

Une fois le MVP implémenté :
1. Tester avec 5-10 artisans (beta testers)
2. Analyser les conversations (quels Tools sont utilisés, lesquels manquent)
3. Itérer sur les descriptions de Tools
4. Ajuster le prompt système

### 10.3 Alternatives considérées (et rejetées)

**Alternative 1 : Hardcoder les Tools dans l'Edge Function**
- ❌ Rejet : Nécessite redéploiement pour chaque nouveau Tool
- ❌ Pas scalable pour une app à 10% de développement

**Alternative 2 : Pas d'Agent Loop, juste un LLM qui génère du JSON**
- ❌ Rejet : L'IA ne peut pas charger de documentation dynamiquement
- ❌ Pas d'accès aux données réelles
- ❌ = Architecture actuelle (déjà jugée insuffisante)

**Alternative 3 : Utiliser Langchain ou un framework d'Agents**
- ✅ Possible, mais :
  - Ajoute une dépendance lourde
  - Moins de contrôle sur l'exécution
  - Deno (Edge Functions) a un support limité pour Langchain
- 🔶 Décision : Implémentation custom, plus légère et plus contrôlable

### 10.4 Mot de la fin

Cette architecture d'**AI Agent autonome avec Tools dynamiques** est **LA** solution pour atteindre votre vision :

> **"Une application DANS l'IA"**

C'est ambitieux, mais c'est faisable. C'est exactement ce que font des outils comme Cursor, Claude Code, ou ChatGPT Code Interpreter.

**La différence :** Vous l'intégrez dans VOTRE application métier, pas dans un IDE générique.

**Le marché :** Les artisans du bâtiment n'ont PAS d'outil avec une IA aussi intégrée. C'est une opportunité unique.

**Le risque :** Ne PAS faire cette architecture → BatiPilot IAssist devient une énième app de devis sans différenciation.

---

## Annexes

### Annexe A : Références techniques

- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling)
- [Google Gemini Function Calling](https://ai.google.dev/docs/function_calling)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase RLS Policies](https://supabase.com/docs/guides/auth/row-level-security)

### Annexe B : Glossaire

- **AI Agent :** IA capable de prendre des décisions et d'exécuter des actions
- **Tool / Function :** Fonction que l'IA peut appeler (ex: create_client)
- **Agent Loop :** Boucle itérative LLM → Tools → LLM jusqu'à résolution
- **Function Calling :** Capacité d'un LLM à appeler des fonctions externes
- **RLS (Row Level Security) :** Politique de sécurité Supabase au niveau des lignes
- **RPC (Remote Procedure Call) :** Appel de fonction PostgreSQL depuis le client

### Annexe C : Contacts et ressources

**Documentation du projet :**
- `AI_ACTIONS_LOGIC.md` : Logique des actions IA (obsolète après implémentation Tools)
- `PROMPT_STORAGE_ARCHITECTURE.md` : Architecture des prompts (implémenté)
- `RAPPORT_INTEGRATION_IA_AGENT.md` : Ce document

**Ressources d'aide :**
- [Discord Supabase](https://discord.supabase.com)
- [Communauté Flutter](https://flutter.dev/community)

---

**Prêt pour discussion et validation.**

---

*Document généré le 4 novembre 2025 par Claude (AI Assistant)*
