# Architecture de Stockage des Prompts en Base de Données
## Proposition Technique - BatiPilot IAssist

> **Objectif:** Stocker les prompts système dans Supabase (et non en dur dans le code) et permettre à l'utilisateur de les modifier via l'interface. L'IA doit également pouvoir suggérer des améliorations.

---

## TABLE DES MATIÈRES

1. [Vision et Objectifs](#1-vision-et-objectifs)
2. [Schéma de Base de Données](#2-schéma-de-base-de-données)
3. [Types de Prompts](#3-types-de-prompts)
4. [Interface Utilisateur](#4-interface-utilisateur)
5. [Système de Suggestions IA](#5-système-de-suggestions-ia)
6. [Implémentation Technique](#6-implémentation-technique)
7. [Plan d'Implémentation](#7-plan-dimplémentation)

---

## 1. VISION ET OBJECTIFS

### 1.1 Pourquoi Stocker les Prompts en BDD ?

**Problèmes actuels:**
- Prompts système codés en dur dans le code Flutter ou les Edge Functions
- Impossibles à modifier sans redéployer l'application
- Pas de personnalisation par utilisateur
- Difficile d'itérer et d'améliorer les prompts

**Bénéfices attendus:**
- ✅ **Personnalisation:** Chaque utilisateur peut adapter les prompts à son métier
- ✅ **Évolution:** Amélioration continue des prompts sans redéploiement
- ✅ **Versioning:** Historique des modifications, retour en arrière possible
- ✅ **A/B Testing:** Tester différentes versions de prompts
- ✅ **Suggestions IA:** L'IA peut proposer des améliorations basées sur l'usage
- ✅ **Multi-modules:** Prompts différents par module (Projets, Rapports, etc.)

---

### 1.2 Principes de Conception

**1. Simplicité d'utilisation:**
- Interface WYSIWYG pour éditer les prompts
- Prévisualisation en temps réel
- Templates par défaut fournis

**2. Sécurité:**
- Prompts liés à l'utilisateur (`user_id`)
- RLS activé sur la table
- Validation côté serveur

**3. Flexibilité:**
- Prompts globaux (tous modules) ou spécifiques (un module)
- Variables dynamiques remplaçables (ex: `{PROJECT_STATE}`, `{USER_NAME}`)
- Support multi-langues (futur)

**4. Intelligence:**
- L'IA analyse les conversations pour détecter les incompréhensions
- Suggestions d'améliorations basées sur les données réelles
- Apprentissage continu

---

## 2. SCHÉMA DE BASE DE DONNÉES

### 2.1 Table: `ai_prompts`

```sql
CREATE TABLE ai_prompts (
  -- Identifiants
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),

  -- Classification
  prompt_key TEXT NOT NULL,
    -- ex: "system_context", "tool_dispatcher", "error_handler"
  module TEXT NOT NULL,
    -- ex: "global", "projets", "rapports", "comptabilite"
  category TEXT,
    -- ex: "system", "tools", "user_interaction"

  -- Versioning
  version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  parent_id UUID REFERENCES ai_prompts(id),
    -- Pour tracker l'historique des versions

  -- Contenu
  title TEXT NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
    -- Le prompt complet (peut contenir des variables)
  variables JSONB,
    -- Liste des variables utilisées: ["PROJECT_STATE", "USER_NAME"]

  -- Métadonnées
  usage_count INTEGER DEFAULT 0,
    -- Nombre de fois utilisé
  success_rate DECIMAL(5,2),
    -- Taux de succès (basé sur feedback utilisateur)
  last_used_at TIMESTAMP,

  -- Relations
  user_id UUID REFERENCES auth.users(id) NOT NULL,

  -- Contraintes
  UNIQUE(prompt_key, module, version, user_id)
);

-- Index pour performance
CREATE INDEX idx_prompts_user_active ON ai_prompts(user_id, is_active);
CREATE INDEX idx_prompts_key_module ON ai_prompts(prompt_key, module);
CREATE INDEX idx_prompts_parent ON ai_prompts(parent_id);

-- RLS
ALTER TABLE ai_prompts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own prompts"
  ON ai_prompts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own prompts"
  ON ai_prompts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own prompts"
  ON ai_prompts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own prompts"
  ON ai_prompts FOR DELETE
  USING (auth.uid() = user_id);
```

---

### 2.2 Table: `ai_prompt_suggestions`

```sql
CREATE TABLE ai_prompt_suggestions (
  -- Identifiants
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),

  -- Relation
  prompt_id UUID REFERENCES ai_prompts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) NOT NULL,

  -- Suggestion
  suggestion_type TEXT NOT NULL,
    -- "improvement", "clarification", "variable_add", "context_add"
  suggested_content TEXT NOT NULL,
  reasoning TEXT,
    -- Pourquoi l'IA propose cette modification

  -- Données d'analyse
  based_on_conversations INTEGER,
    -- Nombre de conversations analysées
  confidence_score DECIMAL(3,2),
    -- Score de confiance (0.00 à 1.00)

  -- État
  status TEXT DEFAULT 'pending',
    -- "pending", "accepted", "rejected", "modified"
  reviewed_at TIMESTAMP,
  review_notes TEXT
);

-- Index
CREATE INDEX idx_suggestions_prompt ON ai_prompt_suggestions(prompt_id);
CREATE INDEX idx_suggestions_user_status ON ai_prompt_suggestions(user_id, status);

-- RLS
ALTER TABLE ai_prompt_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own suggestions"
  ON ai_prompt_suggestions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own suggestions"
  ON ai_prompt_suggestions FOR UPDATE
  USING (auth.uid() = user_id);
```

---

### 2.3 Table: `ai_prompt_templates`

```sql
CREATE TABLE ai_prompt_templates (
  -- Identifiants
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),

  -- Classification
  template_key TEXT NOT NULL UNIQUE,
  module TEXT NOT NULL,
  category TEXT,

  -- Contenu
  title TEXT NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
  variables JSONB,

  -- Métadonnées
  is_default BOOLEAN DEFAULT false,
    -- Templates système par défaut
  language TEXT DEFAULT 'fr',
    -- Support multi-langues
  tags TEXT[]
    -- Tags pour recherche: ["devis", "client", "generation"]
);

-- Index
CREATE INDEX idx_templates_module ON ai_prompt_templates(module);
CREATE INDEX idx_templates_default ON ai_prompt_templates(is_default);

-- Pas de RLS: templates accessibles à tous
```

> **Note:** Les templates sont des prompts "par défaut" fournis par l'application. Quand un utilisateur se connecte pour la première fois, on copie les templates dans sa table `ai_prompts` personnelle.

---

## 3. TYPES DE PROMPTS

### 3.1 Prompt Système Global (system_context)

**Prompt Key:** `system_context`
**Module:** `global`
**Catégorie:** `system`

**Rôle:**
- Définit le contexte général de l'IA
- Explique le rôle de l'IA dans l'application
- Décrit l'architecture de l'application
- Liste les capacités disponibles

**Exemple de contenu:**
```
Tu es l'assistant IA de BatiPilot IAssist, une application de gestion de devis pour artisans du bâtiment.

## Ton rôle:
- Aider l'utilisateur à créer et gérer des devis
- Automatiser les tâches répétitives (génération de numéros, noms de projets, etc.)
- Proposer des suggestions intelligentes basées sur le contexte
- Exécuter des actions via des Tools (UPDATE_PROJECT, ADD_TRAVAIL, etc.)

## Architecture de l'application:
{PROJECT_STRUCTURE}

## Actions disponibles:
{AVAILABLE_TOOLS}

## Données actuelles:
{PROJECT_STATE}

## Règles importantes:
- Toujours confirmer avant de supprimer des données
- Proposer de créer un client s'il n'existe pas
- Générer automatiquement les numéros de devis au format AAMM-N
- Utiliser le format clientsData pour les listes de clients multiples
```

**Variables:**
- `{PROJECT_STRUCTURE}`: Injecté depuis AI_ACTIONS_LOGIC.md
- `{AVAILABLE_TOOLS}`: Liste des Tools disponibles
- `{PROJECT_STATE}`: État actuel du projet (JSON)

---

### 3.2 Prompt de Dispatch d'Actions (tool_dispatcher)

**Prompt Key:** `tool_dispatcher`
**Module:** `global`
**Catégorie:** `tools`

**Rôle:**
- Explique comment utiliser les Tools
- Donne des exemples d'appels
- Définit les formats attendus

**Exemple de contenu:**
```
## Utilisation des Tools (contextUpdate)

Pour exécuter une action, tu dois renvoyer un objet `contextUpdate` dans ta réponse:

```json
{
  "action": "UPDATE_PROJECT",
  "payload": {
    "companyId": "uuid-123",
    "clientId": "uuid-456"
  }
}
```

## Actions disponibles:

### UPDATE_PROJECT
Met à jour les données du projet.
Payload:
- companyId (string, optional)
- clientId (string, optional)
- projectName (string, optional)
- devisNumber (string, optional)
- devisDate (string ISO 8601, optional)
- status (string: "brouillon" | "accepte", optional)

Exemple:
```json
{"action": "UPDATE_PROJECT", "payload": {"status": "accepte"}}
```

### GENERATE_DEVIS_NUMBER
Génère un numéro de devis au format AAMM-N.
Payload: {} (vide)

### ADD_TRAVAIL
Ajoute une prestation au devis.
Payload:
- designation (string, required)
- description (string, optional)
- quantity (number, optional)
- unitPrice (number, optional)

## Règles:
- Un seul contextUpdate par réponse
- Valider les données avant d'envoyer
- Confirmer l'action à l'utilisateur dans ta réponse texte
```

---

### 3.3 Prompt Spécifique Module Projets (projects_assistant)

**Prompt Key:** `projects_assistant`
**Module:** `projets`
**Catégorie:** `user_interaction`

**Rôle:**
- Instructions spécifiques au module Projets
- Ton et langage adaptés à la création de devis
- Raccourcis et alias spécifiques

**Exemple de contenu:**
```
## Assistant Module Projets

Tu aides l'utilisateur à créer et gérer des projets/devis.

## Vocabulaire métier:
- "Devis" = "Projet" = "Quote"
- "Client" peut être: Particulier, Société, Syndic, Maître d'oeuvre
- "Prestation" = "Travail" = "Ligne de devis"

## Workflows courants:

### 1. Créer un nouveau devis:
1. Vérifier si client existe → créer si nécessaire
2. Générer le numéro de devis
3. Sélectionner la société
4. Générer le nom du projet
5. Confirmer à l'utilisateur

### 2. Ajouter une prestation:
1. Vérifier qu'un projet est ouvert
2. Extraire les infos de la prestation
3. Appeler ADD_TRAVAIL
4. Confirmer

### 3. Accepter un devis:
1. Changer le statut à "accepte"
2. Demander la référence de bon de commande
3. Demander la date de confirmation
4. Confirmer

## Exemples de requêtes utilisateur:
- "Créer un devis pour M. Dupont"
- "Ajouter une prestation de plomberie"
- "Le devis est accepté, ref BC-2024-123"
- "Générer le nom du projet"

## Ton:
- Professionnel mais accessible
- Concis et direct
- Confirmer chaque action
```

---

### 3.4 Prompt de Gestion des Erreurs (error_handler)

**Prompt Key:** `error_handler`
**Module:** `global`
**Catégorie:** `system`

**Rôle:**
- Comment gérer les erreurs
- Messages d'erreur à l'utilisateur
- Actions de récupération

**Exemple de contenu:**
```
## Gestion des Erreurs

### Types d'erreurs:

1. **Client non trouvé:**
   - Message: "Je n'ai pas trouvé de client '[NOM]'. Souhaitez-vous le créer ?"
   - Action proposée: Ouvrir le dialog de création avec pré-remplissage

2. **Projet non ouvert:**
   - Message: "Aucun projet n'est ouvert. Voulez-vous en créer un ou en charger un existant ?"
   - Actions: Nouveau projet | Charger un projet

3. **Données manquantes:**
   - Message: "Il manque [CHAMP] pour compléter cette action. Pouvez-vous le fournir ?"
   - Ne pas bloquer, proposer une alternative

4. **Erreur BDD:**
   - Message: "Une erreur est survenue lors de [ACTION]. Réessayons."
   - Log l'erreur pour analyse
   - Proposer retry

### Règles:
- Jamais afficher les détails techniques à l'utilisateur
- Toujours proposer une solution ou alternative
- Être empathique et encourageant
```

---

## 4. INTERFACE UTILISATEUR

### 4.1 Nouveau Module: Gestion des Prompts

**Navigation:**
- Paramètres → "Gestion des Prompts IA"

**Structure:**
```
┌─────────────────────────────────────────────────────┐
│  Gestion des Prompts IA                             │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐  ┌──────────────────────────┐    │
│  │  Modules    │  │  Liste des Prompts       │    │
│  │             │  │                          │    │
│  │  ● Global   │  │  [+] Nouveau prompt      │    │
│  │  ○ Projets  │  │                          │    │
│  │  ○ Rapports │  │  ┌────────────────────┐  │    │
│  │  ○ Imports  │  │  │ System Context     │  │    │
│  │             │  │  │ Module: global     │  │    │
│  │             │  │  │ Actif  [Edit] [••] │  │    │
│  │             │  │  └────────────────────┘  │    │
│  │             │  │                          │    │
│  │             │  │  ┌────────────────────┐  │    │
│  │             │  │  │ Tool Dispatcher    │  │    │
│  │             │  │  │ Module: global     │  │    │
│  │             │  │  │ Actif  [Edit] [••] │  │    │
│  │             │  │  └────────────────────┘  │    │
│  │             │  │                          │    │
│  │             │  │  [1 suggestion en attente]│   │
│  └─────────────┘  └──────────────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

### 4.2 Éditeur de Prompt

**Dialog:** "Modifier le Prompt"

```
┌──────────────────────────────────────────────────┐
│  Modifier le Prompt                        [X]   │
├──────────────────────────────────────────────────┤
│                                                  │
│  Titre:  [System Context                    ]   │
│                                                  │
│  Description:                                    │
│  [Prompt système définissant le rôle de l'IA]   │
│                                                  │
│  Module:  [Global ▼]                             │
│  Catégorie: [System ▼]                           │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Contenu du Prompt:                         │ │
│  │                                            │ │
│  │ Tu es l'assistant IA de BatiPilot...      │ │
│  │                                            │ │
│  │ ## Ton rôle:                               │ │
│  │ - Aider l'utilisateur...                   │ │
│  │                                            │ │
│  │ {PROJECT_STATE} <-- Variable détectée      │ │
│  │                                            │ │
│  │                                            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  Variables détectées: PROJECT_STATE, USER_NAME   │
│                                                  │
│  [ ] Activer ce prompt                           │
│  [ ] Créer une nouvelle version (versioning)     │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Prévisualisation:                          │ │
│  │                                            │ │
│  │ Tu es l'assistant IA de BatiPilot...      │ │
│  │ Projet actuel: Devis n° 2511-1            │ │
│  │                                            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  [Annuler]  [Tester avec l'IA]  [Enregistrer]   │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Fonctionnalités:**
- **Coloration syntaxique:** Variables en surbrillance `{VARIABLE}`
- **Auto-complétion:** Liste des variables disponibles
- **Validation:** Vérifier que les variables existent
- **Prévisualisation:** Affiche le prompt avec les variables remplacées
- **Tester:** Envoyer un message test à l'IA avec ce prompt
- **Versioning:** Option pour créer une nouvelle version au lieu d'écraser

---

### 4.3 Gestion des Suggestions

**Section:** "Suggestions d'amélioration"

```
┌──────────────────────────────────────────────────┐
│  Suggestions d'amélioration (3 en attente)       │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Suggestion #1  [IA]  Confiance: 85%    │   │
│  │                                          │   │
│  │  Pour: System Context                    │   │
│  │  Type: Amélioration                      │   │
│  │                                          │   │
│  │  Basée sur 47 conversations analysées    │   │
│  │                                          │   │
│  │  💡 Raisonnement:                        │   │
│  │  J'ai remarqué que les utilisateurs     │   │
│  │  confondent souvent "devis" et "facture".│   │
│  │  Je suggère d'ajouter une clarification │   │
│  │  dans le prompt système.                 │   │
│  │                                          │   │
│  │  📝 Modification proposée:               │   │
│  │  + Ajouter après "## Vocabulaire métier:"│   │
│  │  + "IMPORTANT: Un devis n'est PAS une   │   │
│  │  +  facture. Le devis est l'estimation  │   │
│  │  +  avant travaux, la facture vient     │   │
│  │  +  après réalisation."                  │   │
│  │                                          │   │
│  │  [Rejeter]  [Modifier]  [Accepter]      │   │
│  │                                          │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Suggestion #2  [IA]  Confiance: 72%    │   │
│  │  ...                                     │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Actions:**
- **Accepter:** Applique la suggestion et crée une nouvelle version du prompt
- **Modifier:** Ouvre l'éditeur avec la suggestion pré-remplie (pour ajustement)
- **Rejeter:** Archive la suggestion avec possibilité de notes

---

## 5. SYSTÈME DE SUGGESTIONS IA

### 5.1 Comment l'IA Génère des Suggestions

**Déclencheur:**
- Analyse périodique des conversations (ex: toutes les 50 messages)
- Détection de patterns d'incompréhension
- Feedback utilisateur négatif

**Processus:**

1. **Collecte de données:**
   ```dart
   // Récupérer les N dernières conversations
   final conversations = await supabase
     .from('ai_messages')
     .select('chat_id, content, role')
     .order('created_at', ascending: false)
     .limit(100);
   ```

2. **Analyse par l'IA:**
   ```dart
   final analysisPrompt = '''
   Analyse ces conversations pour identifier:
   1. Les incompréhensions récurrentes
   2. Les questions répétitives
   3. Les erreurs de l'IA
   4. Les manques d'informations

   Pour chaque problème identifié, propose une amélioration du prompt système.

   Conversations:
   $conversations

   Prompt actuel:
   $currentPrompt

   Réponds au format JSON:
   {
     "suggestions": [
       {
         "type": "improvement",
         "reasoning": "...",
         "suggested_content": "...",
         "confidence": 0.85
       }
     ]
   }
   ''';

   final response = await callAI(analysisPrompt);
   final suggestions = parseSuggestions(response);
   ```

3. **Sauvegarde des suggestions:**
   ```dart
   for (final suggestion in suggestions) {
     await supabase.from('ai_prompt_suggestions').insert({
       'prompt_id': promptId,
       'user_id': userId,
       'suggestion_type': suggestion.type,
       'suggested_content': suggestion.content,
       'reasoning': suggestion.reasoning,
       'confidence_score': suggestion.confidence,
       'based_on_conversations': conversationCount,
     });
   }
   ```

4. **Notification utilisateur:**
   - Badge sur le module "Gestion des Prompts"
   - Notification in-app: "3 suggestions d'amélioration disponibles"

---

### 5.2 Types de Suggestions

**1. Amélioration (improvement):**
- Ajout de précisions au prompt existant
- Rendre le prompt plus clair
- Ajouter des exemples

**2. Clarification (clarification):**
- Résoudre une ambiguïté détectée
- Préciser un terme métier
- Ajouter des définitions

**3. Ajout de variable (variable_add):**
- Suggérer d'injecter une nouvelle variable
- Ex: "Ajouter `{CLIENT_HISTORY}` pour contextualiser"

**4. Ajout de contexte (context_add):**
- Suggérer d'ajouter des informations de contexte
- Ex: "Ajouter la liste des derniers projets"

---

### 5.3 Critères de Qualité des Suggestions

**Une bonne suggestion doit:**
- ✅ Avoir un score de confiance > 70%
- ✅ Être basée sur au moins 10 conversations
- ✅ Résoudre un problème identifié et quantifié
- ✅ Inclure un raisonnement clair
- ✅ Proposer une modification précise et applicable

**Rejet automatique si:**
- ❌ Confiance < 50%
- ❌ Basée sur < 5 conversations
- ❌ Modification trop générique
- ❌ Contradiction avec le prompt actuel

---

## 6. IMPLÉMENTATION TECHNIQUE

### 6.1 Provider Riverpod: `aiPromptsProvider`

```dart
// lib/providers/ai_prompts_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/ai_prompt_model.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/providers/auth_provider.dart';

class AiPromptsNotifier extends AsyncNotifier<List<AiPrompt>> {
  @override
  Future<List<AiPrompt>> build() async {
    final supabaseClient = ref.watch(supabaseConnectionProvider).client;
    final authState = ref.watch(authStateProvider);

    if (supabaseClient == null || authState.value?.session?.user == null) {
      return [];
    }

    final response = await supabaseClient
      .from('ai_prompts')
      .select()
      .eq('is_active', true)
      .order('module', ascending: true);

    return response.map((item) => AiPrompt.fromJson(item)).toList();
  }

  /// Récupère un prompt spécifique par key et module
  Future<AiPrompt?> getPrompt(String promptKey, {String module = 'global'}) async {
    final supabaseClient = ref.read(supabaseConnectionProvider).client;
    if (supabaseClient == null) return null;

    final response = await supabaseClient
      .from('ai_prompts')
      .select()
      .eq('prompt_key', promptKey)
      .eq('module', module)
      .eq('is_active', true)
      .maybeSingle();

    return response != null ? AiPrompt.fromJson(response) : null;
  }

  /// Ajoute ou met à jour un prompt
  Future<void> upsertPrompt({
    required String promptKey,
    required String module,
    required String title,
    required String content,
    String? description,
    String? category,
    List<String>? variables,
    bool createVersion = false,
  }) async {
    final supabaseClient = ref.read(supabaseConnectionProvider).client;
    if (supabaseClient == null) throw Exception('Supabase non connecté');

    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non authentifié');

    if (createVersion) {
      // Désactiver l'ancien prompt
      await supabaseClient
        .from('ai_prompts')
        .update({'is_active': false})
        .eq('prompt_key', promptKey)
        .eq('module', module)
        .eq('user_id', userId);

      // Récupérer le dernier numéro de version
      final lastVersion = await supabaseClient
        .from('ai_prompts')
        .select('version')
        .eq('prompt_key', promptKey)
        .eq('module', module)
        .eq('user_id', userId)
        .order('version', ascending: false)
        .limit(1);

      final newVersion = lastVersion.isNotEmpty
        ? (lastVersion[0]['version'] as int) + 1
        : 1;

      // Créer nouvelle version
      await supabaseClient.from('ai_prompts').insert({
        'prompt_key': promptKey,
        'module': module,
        'title': title,
        'content': content,
        'description': description,
        'category': category,
        'variables': variables,
        'version': newVersion,
        'is_active': true,
        'user_id': userId,
      });
    } else {
      // Mise à jour directe
      await supabaseClient
        .from('ai_prompts')
        .update({
          'title': title,
          'content': content,
          'description': description,
          'category': category,
          'variables': variables,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('prompt_key', promptKey)
        .eq('module', module)
        .eq('user_id', userId);
    }

    ref.invalidateSelf();
  }

  /// Remplace les variables dans le contenu du prompt
  String replaceVariables(String content, Map<String, String> variables) {
    String result = content;

    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });

    return result;
  }

  /// Incrémente le compteur d'utilisation
  Future<void> incrementUsage(String promptId) async {
    final supabaseClient = ref.read(supabaseConnectionProvider).client;
    if (supabaseClient == null) return;

    await supabaseClient.rpc('increment_prompt_usage', params: {
      'prompt_id': promptId,
    });
  }
}

final aiPromptsProvider = AsyncNotifierProvider<AiPromptsNotifier, List<AiPrompt>>(
  AiPromptsNotifier.new
);
```

---

### 6.2 Fonction SQL: Incrémenter l'usage

```sql
CREATE OR REPLACE FUNCTION increment_prompt_usage(prompt_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE ai_prompts
  SET
    usage_count = usage_count + 1,
    last_used_at = now()
  WHERE id = prompt_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### 6.3 Modèle: `AiPrompt`

```dart
// lib/models/ai_prompt_model.dart

class AiPrompt {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String promptKey;
  final String module;
  final String? category;

  final int version;
  final bool isActive;
  final String? parentId;

  final String title;
  final String? description;
  final String content;
  final List<String>? variables;

  final int usageCount;
  final double? successRate;
  final DateTime? lastUsedAt;

  final String userId;

  AiPrompt({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.promptKey,
    required this.module,
    this.category,
    required this.version,
    required this.isActive,
    this.parentId,
    required this.title,
    this.description,
    required this.content,
    this.variables,
    required this.usageCount,
    this.successRate,
    this.lastUsedAt,
    required this.userId,
  });

  factory AiPrompt.fromJson(Map<String, dynamic> json) {
    return AiPrompt(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      promptKey: json['prompt_key'] as String,
      module: json['module'] as String,
      category: json['category'] as String?,
      version: json['version'] as int,
      isActive: json['is_active'] as bool,
      parentId: json['parent_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      content: json['content'] as String,
      variables: json['variables'] != null
        ? List<String>.from(json['variables'] as List)
        : null,
      usageCount: json['usage_count'] as int,
      successRate: json['success_rate'] != null
        ? (json['success_rate'] as num).toDouble()
        : null,
      lastUsedAt: json['last_used_at'] != null
        ? DateTime.parse(json['last_used_at'] as String)
        : null,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'prompt_key': promptKey,
    'module': module,
    'category': category,
    'version': version,
    'is_active': isActive,
    'parent_id': parentId,
    'title': title,
    'description': description,
    'content': content,
    'variables': variables,
    'usage_count': usageCount,
    'success_rate': successRate,
    'last_used_at': lastUsedAt?.toIso8601String(),
    'user_id': userId,
  };
}
```

---

### 6.4 Intégration dans AssistantController

```dart
// lib/assistant/assistant_controller.dart

Future<AssistantResponse> _callRealModel({
  required String userMessage,
  required String module,
}) async {
  final supabase = _ref.read(supabaseConnectionProvider).client;
  final projectState = _ref.read(projectProvider).toJson();

  // 🆕 RÉCUPÉRER LES PROMPTS DEPUIS LA BDD
  final systemPrompt = await _ref.read(aiPromptsProvider.notifier)
    .getPrompt('system_context', module: 'global');

  final modulePrompt = await _ref.read(aiPromptsProvider.notifier)
    .getPrompt('${module}_assistant', module: module);

  final toolsPrompt = await _ref.read(aiPromptsProvider.notifier)
    .getPrompt('tool_dispatcher', module: 'global');

  // Remplacer les variables
  final variablesMap = {
    'PROJECT_STATE': jsonEncode(projectState),
    'USER_NAME': supabase?.auth.currentUser?.email ?? 'Utilisateur',
    'AVAILABLE_TOOLS': _getAvailableToolsList(),
    'PROJECT_STRUCTURE': _getProjectStructure(),
  };

  final finalSystemPrompt = systemPrompt != null
    ? _ref.read(aiPromptsProvider.notifier)
        .replaceVariables(systemPrompt.content, variablesMap)
    : _defaultSystemPrompt; // Fallback

  final finalModulePrompt = modulePrompt != null
    ? _ref.read(aiPromptsProvider.notifier)
        .replaceVariables(modulePrompt.content, variablesMap)
    : '';

  final finalToolsPrompt = toolsPrompt != null
    ? _ref.read(aiPromptsProvider.notifier)
        .replaceVariables(toolsPrompt.content, variablesMap)
    : '';

  // Incrémenter usage
  if (systemPrompt != null) {
    await _ref.read(aiPromptsProvider.notifier)
      .incrementUsage(systemPrompt.id);
  }

  // Envoyer à l'Edge Function
  final response = await supabase!.functions.invoke(
    'assist_flut',
    body: {
      'module': module,
      'userMessage': userMessage,
      'systemPrompt': finalSystemPrompt,
      'modulePrompt': finalModulePrompt,
      'toolsPrompt': finalToolsPrompt,
      'projectState': projectState,
    },
  );

  return AssistantResponse.fromJson(response.data);
}

String _getAvailableToolsList() {
  // Retourner la liste des Tools disponibles
  return '''
  - UPDATE_PROJECT
  - UPDATE_METADATA
  - GENERATE_DEVIS_NUMBER
  - GENERATE_PROJECT_NAME
  - ADD_CLIENT_TO_LIST
  - ADD_TRAVAIL
  - SAVE_PROJECT
  - LOAD_PROJECT
  ''';
}

String _getProjectStructure() {
  // Retourner la structure depuis AI_ACTIONS_LOGIC.md
  // (à charger depuis un fichier asset ou depuis la BDD)
  return '''[Contenu de AI_ACTIONS_LOGIC.md]''';
}
```

---

## 7. PLAN D'IMPLÉMENTATION

### Phase 1: Structure de Base (Semaine 1)

**Tasks:**
1. ✅ Créer les tables Supabase:
   - `ai_prompts`
   - `ai_prompt_suggestions`
   - `ai_prompt_templates`

2. ✅ Créer les modèles Flutter:
   - `AiPrompt`
   - `AiPromptSuggestion`
   - `AiPromptTemplate`

3. ✅ Créer les providers Riverpod:
   - `aiPromptsProvider`
   - `aiPromptSuggestionsProvider`
   - `aiPromptTemplatesProvider`

4. ✅ Créer les templates par défaut:
   - `system_context`
   - `tool_dispatcher`
   - `projects_assistant`
   - `error_handler`

5. ✅ Script de migration:
   - Copier les templates vers la table utilisateur au premier login

---

### Phase 2: Interface Utilisateur (Semaine 2)

**Tasks:**
1. ✅ Créer le nouveau module "Gestion des Prompts" dans Paramètres
2. ✅ Liste des prompts par module
3. ✅ Créer le dialog "Éditeur de Prompt"
4. ✅ Détection et validation des variables
5. ✅ Prévisualisation avec remplacement de variables
6. ✅ Bouton "Tester avec l'IA"
7. ✅ Gestion du versioning

---

### Phase 3: Intégration dans AssistantController (Semaine 3)

**Tasks:**
1. ✅ Modifier `_callRealModel` pour utiliser les prompts de la BDD
2. ✅ Implémenter le remplacement de variables
3. ✅ Incrémenter `usage_count` à chaque utilisation
4. ✅ Gérer les fallbacks si prompts manquants
5. ✅ Tests de bout en bout

---

### Phase 4: Système de Suggestions (Semaine 4)

**Tasks:**
1. ✅ Créer Edge Function `analyze_conversations`
2. ✅ Implémenter la logique d'analyse IA
3. ✅ Créer le provider `aiPromptSuggestionsProvider`
4. ✅ UI pour afficher les suggestions
5. ✅ Actions: Accepter / Modifier / Rejeter
6. ✅ Notification badge
7. ✅ Tests et ajustements

---

### Phase 5: Améliorations et Optimisations (Semaine 5)

**Tasks:**
1. ✅ Coloration syntaxique dans l'éditeur
2. ✅ Auto-complétion des variables
3. ✅ Historique des versions (UI)
4. ✅ Export/Import de prompts (JSON)
5. ✅ Recherche et filtres
6. ✅ Tags pour organisation
7. ✅ Support multi-langues (préparation)

---

## 8. EXEMPLES D'UTILISATION

### 8.1 Charger un Prompt

```dart
final systemPrompt = await ref.read(aiPromptsProvider.notifier)
  .getPrompt('system_context', module: 'global');

print(systemPrompt?.content);
```

---

### 8.2 Créer/Modifier un Prompt

```dart
await ref.read(aiPromptsProvider.notifier).upsertPrompt(
  promptKey: 'custom_greeting',
  module: 'global',
  title: 'Message d\'accueil personnalisé',
  content: 'Bonjour {USER_NAME}, bienvenue dans {PROJECT_NAME} !',
  description: 'Salutation personnalisée pour l\'utilisateur',
  category: 'user_interaction',
  variables: ['USER_NAME', 'PROJECT_NAME'],
  createVersion: false, // Écrase la version existante
);
```

---

### 8.3 Remplacer les Variables

```dart
final promptContent = systemPrompt.content;

final replaced = ref.read(aiPromptsProvider.notifier).replaceVariables(
  promptContent,
  {
    'PROJECT_STATE': jsonEncode(projectState),
    'USER_NAME': 'Jean Dupont',
  },
);

print(replaced);
```

---

### 8.4 Générer une Suggestion (Pseudo-code)

```dart
// Dans une Edge Function ou un job périodique

final conversations = await fetchRecentConversations(userId, limit: 100);

final analysisPrompt = '''
Analyse ces conversations et propose des améliorations pour le prompt système.

Conversations: $conversations
Prompt actuel: $currentPromptContent

Réponds au format JSON avec des suggestions.
''';

final response = await callAI(analysisPrompt);
final suggestions = parseSuggestions(response);

for (final suggestion in suggestions) {
  await supabase.from('ai_prompt_suggestions').insert({
    'prompt_id': promptId,
    'user_id': userId,
    'suggestion_type': suggestion.type,
    'suggested_content': suggestion.content,
    'reasoning': suggestion.reasoning,
    'confidence_score': suggestion.confidence,
    'based_on_conversations': conversations.length,
  });
}

// Notifier l'utilisateur
await sendNotification(userId, '${suggestions.length} nouvelles suggestions disponibles');
```

---

## 9. SÉCURITÉ ET BONNES PRATIQUES

### 9.1 Validation des Prompts

**Règles:**
- Limiter la taille max du contenu (ex: 10 000 caractères)
- Valider que les variables utilisées sont dans la whitelist
- Échapper les caractères dangereux (injection)
- Vérifier que les prompts ne contiennent pas de secrets (API keys, etc.)

```dart
bool validatePrompt(String content, List<String>? variables) {
  // Taille max
  if (content.length > 10000) {
    throw Exception('Le contenu est trop long (max 10 000 caractères)');
  }

  // Variables autorisées
  final allowedVariables = [
    'PROJECT_STATE',
    'USER_NAME',
    'AVAILABLE_TOOLS',
    'PROJECT_STRUCTURE',
    'CLIENT_HISTORY',
  ];

  if (variables != null) {
    for (final variable in variables) {
      if (!allowedVariables.contains(variable)) {
        throw Exception('Variable non autorisée: $variable');
      }
    }
  }

  // Détecter les secrets potentiels
  final secretPatterns = [
    RegExp(r'sk-[a-zA-Z0-9]{32,}'), // API keys OpenAI
    RegExp(r'supabase.*key', caseSensitive: false),
    RegExp(r'password', caseSensitive: false),
  ];

  for (final pattern in secretPatterns) {
    if (pattern.hasMatch(content)) {
      throw Exception('Le prompt semble contenir des informations sensibles');
    }
  }

  return true;
}
```

---

### 9.2 Performance

**Cache des prompts:**
- Charger les prompts au démarrage de l'app
- Mettre en cache en mémoire
- Invalider le cache uniquement lors de modifications

```dart
class AiPromptsCache {
  final Map<String, AiPrompt> _cache = {};
  DateTime? _lastFetch;

  Future<AiPrompt?> getPrompt(String key, {String module = 'global'}) async {
    final cacheKey = '$key:$module';

    // Vérifier cache (valide 1h)
    if (_cache.containsKey(cacheKey) &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < Duration(hours: 1)) {
      return _cache[cacheKey];
    }

    // Fetch depuis BDD
    final prompt = await _fetchFromDB(key, module);

    if (prompt != null) {
      _cache[cacheKey] = prompt;
      _lastFetch = DateTime.now();
    }

    return prompt;
  }

  void invalidate() {
    _cache.clear();
    _lastFetch = null;
  }
}
```

---

## 10. CONCLUSION

Cette architecture permet:
- ✅ Flexibilité totale des prompts sans redéploiement
- ✅ Personnalisation par utilisateur
- ✅ Amélioration continue via suggestions IA
- ✅ Versioning et traçabilité
- ✅ Interface intuitive pour l'édition

**Prochaines étapes:**
1. Valider l'architecture avec l'utilisateur
2. Commencer la Phase 1 (création des tables et modèles)
3. Implémenter progressivement les phases suivantes

**Questions ouvertes:**
- Faut-il permettre le partage de prompts entre utilisateurs ?
- Faut-il créer un "marketplace" de prompts ?
- Quelle fréquence pour l'analyse automatique des suggestions ?

---

**Version:** 1.0
**Date:** 2 novembre 2025
**Auteur:** Claude (IA)
**Status:** Proposition à valider
