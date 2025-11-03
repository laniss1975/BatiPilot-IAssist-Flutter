# 🏗️ BâtiPilot IAssist - Documentation Synthétique pour Sessions Futures

**Date de création:** 02 Novembre 2025
**Dernière mise à jour:** 03 Novembre 2025 (Documentation IA & Architecture Prompts)
**Statut du projet:** En développement (Recréation Flutter)
**Stack:** Flutter + Supabase + Riverpod + Architecture IA modulaire

---

## 📋 TABLE DES MATIÈRES

1. [Objectif Global](#objectif-global)
2. [État Actuel](#état-actuel)
3. [Phases Implémentées](#phases-implémentées)
4. [Architecture Système](#architecture-système)
5. [Structure du Projet](#structure-du-projet)
6. [Phases Restantes](#phases-restantes)
7. [Prochaines Étapes](#prochaines-étapes)
8. [Ressources](#ressources)

---

## 🎯 OBJECTIF GLOBAL

**BâtiPilot IAssist** est une application mobile **Flutter** (desktop & mobile) pour les professionnels du bâtiment permettant de :

1. **Créer des devis détaillés** avec calcul automatique des surfaces
2. **Gérer des projets** de rénovation/construction
3. **Générer des factures** (Acompte, Situation, Solde)
4. **Bénéficier d'un assistant IA intégré** qui aide activement à la saisie et l'analyse
5. **Edition comptabilité** accès aux écritures bancaires, analyses, pré-bilan, calcul taxes (TVA, et autres)

**Principes clés :**
- ✅ **L'IA est au cœur du système** (pas juste un chatbot à côté)
- ✅ **Architecture modulaire et extensible** (support de multiples fournisseurs IA)
- ✅ **Interface intuitive** pour les artisans du BTP
- ✅ **Calculs précis** des surfaces nettes (déduction menuiseries, ouvertures)
- ✅ **Traçabilité complète** (historique devis, factures, comptabilité)
- ✅ **PDF professionnels** personnalisables

---

## 📊 ÉTAT ACTUEL

**Statut:** PHASE 3 (Module Projet) **EN COURS** 🔄 (~75% complété)

### ✅ Fonctionnalités Implémentées

**Infrastructure :**
- ✅ Projet Flutter configuré (Windows app)
- ✅ Connexion Supabase fonctionnelle
- ✅ Authentification utilisateur
- ✅ RLS (Row Level Security) sur les tables principales
- ✅ Riverpod pour state management

**Sélecteur de Modèles IA :**
- ✅ Badge affichant le modèle actif
- ✅ Dropdown pour changer de modèle instantanément
- ✅ Modèles chargés dynamiquement depuis Supabase
- ✅ Configuration multi-fournisseur extensible

**Assistant IA Backend :**
- ✅ Edge Function `assist_flut` (TypeScript/Deno)
- ✅ Support multi-fournisseur (Google, OpenAI, Anthropic, DeepSeek, etc.)
- ✅ Gestion des clés API sécurisée
- ✅ Parse réponse JSON avec contextUpdate et navigationSignal

**PHASE 2 - Historique des Chats (COMPLÉTÉE) ✅**
- ✅ Sélecteur de chats en haut du header (full width)
- ✅ Liste déroulante affichant tous les chats utilisateur
- ✅ Bouton "+" pour créer une nouvelle discussion
- ✅ Icône crayon pour renommer un chat
- ✅ Icône poubelle pour supprimer un chat (avec confirmation)
- ✅ Titre auto-généré: "Discussion du DD/MM/YY à HHhMM"
- ✅ Chargement automatique de l'historique au démarrage de l'app
- ✅ Chargement complet des messages du chat sélectionné
- ✅ Support multi-chats via Riverpod StateNotifier
- ✅ Persistence complète en Supabase
- ✅ Tri par date décroissante (plus récents en premier)

**PHASE 3 - Module Projet (EN COURS) 🔄**

*Modèles de Données:*
- ✅ `Project` - Modèle projet complet avec métadonnées (devisNumber, projectName, status, etc.)
- ✅ `ProjectMetadata` - Métadonnées JSONB (description, clientsData, adresseChantier, occupant, etc.)
- ✅ `Company` - Modèle entreprise (name, address, siret, tva, etc.)
- ✅ `Client` - Modèle client (nom, prenom, adresse, clientTypeId, etc.)
- ✅ `ClientType` - Modèle type de client (Particulier, Société, Gestionnaire, etc.)

*Providers:*
- ✅ `projectProvider` - État du projet courant (StateNotifier)
- ✅ `companiesProvider` - Liste des entreprises (AsyncNotifier)
- ✅ `clientsProvider` - Liste des clients (AsyncNotifier)
- ✅ `clientTypesProvider` - Liste des types de clients (FutureProvider)
- ✅ `userSettingsProvider` - Paramètres utilisateur (companyId sauvegardé)

*Interface Utilisateur (ProjectDetailsView):*

**Section 1: Informations Générales (disposition 2 colonnes)**
- Colonne Gauche:
  - ✅ Sélecteur entreprise + carte info + bouton "Créer entreprise"
  - ✅ Statut du devis (Brouillon/Accepté) avec switch
  - ✅ Référence bon de commande (readonly si brouillon)
  - ✅ Date de confirmation (readonly si brouillon)

- Colonne Droite:
  - ✅ Sélecteur client + carte info avec type + bouton "Créer client"
  - ✅ Bouton "Ajouter à la liste" (ajoute le client à clientsData)
  - ✅ Champ "Liste des Clients" (textarea 6 lignes)

**Section 2: Détails du Projet**
- ✅ Numéro de devis + bouton génération automatique (format: AAMM-N)
- ✅ Date du devis (DatePicker)
- ✅ Nom du projet + bouton génération automatique (format: "Devis n° XXX - Client - Description")
- ✅ Description du projet (textarea 4 lignes)

**Section 3: Informations Chantier**
- ✅ Adresse du chantier (textarea 4 lignes)
- ✅ Occupant (1 ligne)
- ✅ Informations complémentaires (textarea 4 lignes)

*Fonctionnalités Métier:*
- ✅ Génération automatique numéro de devis (lecture depuis Supabase pour incrément)
- ✅ Génération automatique nom de projet (extraction clientsData ligne 2 + description ligne 1)
- ✅ Ajout client à la liste avec type + nom + adresse formatés
- ✅ Mise à jour en temps réel avec ValueKey (fix bug TextFormField)
- ✅ Sauvegarde selectedCompanyId dans user_settings
- ✅ Dialogs d'ajout rapide entreprise/client

### 🔄 En Cours (PHASE 3 - Restant à faire)

- ⏳ Bouton "Sauvegarder projet" + méthode `saveProject()` (persistence Supabase)
- ⏳ Provider `projectsHistoryProvider` (liste des projets sauvegardés)
- ⏳ Widget `ProjectSelector` (créer/charger/sélectionner projets)
- ⏳ Méthode `loadProject()` (charger projet existant depuis DB)

### ⏳ À Faire (Phases futures)

- ⏳ Module Bien (surfaces, menuiseries, déductions)
- ⏳ Module Travaux (prestations, calculs)
- ⏳ Module Facturation
- ⏳ Module Comptabilité
- ⏳ Export PDF

---

## ✅ PHASES IMPLÉMENTÉES

### PHASE 1 : Infrastructure & Sélecteur de Modèles IA (Complétée)

**Fichiers :**
- ✅ `lib/ui/widgets/right_pane.dart` - Chat UI + Sélecteur modèles
- ✅ `lib/providers/active_model_provider.dart` - Gestion modèle actif
- ✅ `lib/providers/ai_chat_provider.dart` - Gestion messages chat
- ✅ `supabase/functions/assist_flut/index.ts` - Edge Function IA
- ✅ `supabase/functions/ai-keys-manager/index.ts` - Gestion clés API

**Description :** Infrastructure de base avec support multi-fournisseur IA et sélecteur de modèles.

---

### PHASE 2 : Historique des Chats (Complétée) ✅

**Fichiers créés :**
- ✅ `lib/models/ai_chat_model.dart` - Modèle AiChat (id, title, userId, moduleName, etc.)
- ✅ `lib/providers/ai_chats_history_provider.dart` - StateNotifier pour l'historique
- ✅ `lib/ui/widgets/chat_selector.dart` - Widget sélecteur avec renommage et suppression

**Fichiers modifiés :**
- ✅ `lib/providers/ai_chat_provider.dart` - Ajout `loadChat()`, `createNewChat()`, `clearCurrentChat()`
- ✅ `lib/ui/widgets/right_pane.dart` - Intégration ChatSelector en haut du header
- ✅ `lib/ui/pages/home_page.dart` - Chargement historique au démarrage + après connexion

**Fonctionnalités :**
1. **Sélecteur de chats** - Dropdown montrant tous les chats de l'utilisateur
2. **Créer nouveau chat** - Bouton "+" avec titre auto-généré (format: "Discussion du 02/11/25 à 14h30")
3. **Renommer chat** - Icône crayon dans le dropdown
4. **Supprimer chat** - Icône poubelle avec confirmation
5. **Charger chat** - Click sur un chat charge tous ses messages
6. **Historique auto-chargé** - Au démarrage de l'app et après connexion
7. **Tri chronologique** - Plus récents en premier (DESC par updated_at)

**Tables Supabase utilisées :**
- ✅ `ai_chats_flut` - Conversations (id, user_id, title, module_name, created_at, updated_at)
- ✅ `ai_chat_messages_flut` - Messages (id, chat_id, role, content, meta, created_at)

**Architecture :**
```
User selects chat → ChatSelector watches aiChatsHistoryProvider
                 → Click triggers aiChatProvider.notifier.loadChat()
                 → Loads all messages for that chat
                 → Updates UI automatically
                 → Rename/Delete via dialog + notifier update
```

---

### PHASE 3 : Module Projet (En Cours - ~75%) 🔄

**Fichiers créés :**
- ✅ `lib/models/project_model.dart` - Modèle Project + ProjectMetadata
- ✅ `lib/models/company_model.dart` - Modèle Company
- ✅ `lib/models/client_model.dart` - Modèle Client
- ✅ `lib/models/client_type_model.dart` - Modèle ClientType
- ✅ `lib/providers/project_provider.dart` - ProjectNotifier (gestion état projet)
- ✅ `lib/providers/reference_data_provider.dart` - Providers pour companies, clients, clientTypes
- ✅ `lib/providers/user_settings_provider.dart` - Sauvegarde préférences utilisateur
- ✅ `lib/ui/views/project_details_view.dart` - Interface principale du projet
- ✅ `lib/ui/dialogs/add_company_dialog.dart` - Dialog ajout rapide entreprise
- ✅ `lib/ui/dialogs/add_client_dialog.dart` - Dialog ajout rapide client

**Fonctionnalités complètes :**

1. **Génération automatique numéro de devis**
   - Méthode `generateDevisNumber()` dans ProjectNotifier
   - Format: AAMM-N (ex: 2511-1 pour Novembre 2025, devis #1)
   - Lecture depuis Supabase (table `devis_save`) pour auto-incrémenter
   - Fix bug affichage avec ValueKey

2. **Génération automatique nom de projet**
   - Méthode `generateProjectName()` dans ProjectNotifier
   - Format: "Devis n° [NUMERO] - [NOM_CLIENT] - [DESCRIPTION]"
   - Extraction client depuis clientsData (ligne 2) ou fallback sur clientId
   - Extraction description (1ère ligne de descriptionProjet)
   - Génère numéro de devis automatiquement si vide

3. **Gestion liste des clients**
   - Méthode `addClientToList()` dans ProjectNotifier
   - Récupère client depuis clientsProvider
   - Récupère type depuis clientTypesProvider
   - Format ajouté:
     ```
     [Type de Client]
     [Nom Complet]
     [Adresse - Code Postal Ville]
     ```
   - Stockage dans `metadata.clientsData`

4. **Interface utilisateur complète**
   - Disposition 2 colonnes (Société/Statut à gauche, Clients à droite)
   - 3 sections : Informations Générales / Détails Projet / Informations Chantier
   - Tous les champs métier présents et fonctionnels
   - Cartes info avec détails (Company et Client avec type)
   - Boutons de génération automatique fonctionnels

5. **Types de clients**
   - Modèle ClientType (id, name, userId, createdAt)
   - Provider clientTypesProvider
   - Affichage du type dans carte client
   - Utilisation du vrai type lors de l'ajout à la liste

**Tables Supabase utilisées :**
- ✅ `devis_save` - Projets/devis sauvegardés (auto-incrément numéro)
- ✅ `companies` - Entreprises
- ✅ `clients` - Clients
- ✅ `client_types` - Types de clients (Particulier, Société, etc.)
- ✅ `user_settings` - Paramètres utilisateur (selectedCompanyId)

**Commits clés :**
- `feat: Add "Informations Chantier" section` - Section chantier avec 3 champs
- `fix: Fix devis number field not updating` - Correction ValueKey pour TextFormField
- `feat: Add project name generation and client list management` - Génération nom + liste clients
- `feat: Add client type support and display in UI` - Support complet types clients
- `refactor: Reorganize "Informations Générales" section layout` - Disposition 2 colonnes

**Restant à faire pour compléter PHASE 3 :**
- ⏳ Méthode `saveProject()` - Persistence en base
- ⏳ Provider `projectsHistoryProvider` - Liste projets sauvegardés
- ⏳ Widget `ProjectSelector` - Sélectionner/charger projets
- ⏳ Méthode `loadProject()` - Charger projet depuis DB

---

## 🏗️ ARCHITECTURE SYSTÈME

### Stack Technique

| Couche | Technologie | Détails |
|--------|-------------|---------|
| **Frontend** | Flutter (Dart) | App mobile/desktop Windows |
| **UI** | Material + Custom Widgets | `lib/ui/widgets/` |
| **State Management** | Riverpod (AsyncNotifier) | Providers décentralisés |
| **Backend** | Supabase | PostgreSQL + Auth |
| **Edge Functions** | TypeScript/Deno | `supabase/functions/` |
| **IA** | Multi-provider support | Via Edge Functions (extensible) |
| **Base de Données** | PostgreSQL (Supabase) | Tables normalisées + JSONB |

### Architecture en Couches

```
┌─────────────────────────────────────────┐
│         COUCHE PRÉSENTATION             │
│  Pages + Widgets + UI Components        │
│  Location: lib/ui/                      │
└──────────────────┬──────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│     COUCHE LOGIQUE (Riverpod)           │
│  Providers, State Management            │
│  Location: lib/providers/               │
└──────────────────┬──────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│      COUCHE SERVICES & CALCULS          │
│  Services metier, Calculs surfaces      │
│  Location: lib/services/                │
└──────────────────┬──────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│    COUCHE DONNEES (Supabase + Local)    │
│  Base de donnees, LocalStorage          │
│  Location: supabase/ + local storage    │
└─────────────────────────────────────────┘
```

### Providers Riverpod

**IA & Chat:**
- **aiChatProvider** - État du chat courant (messages, chat actif)
- **aiChatsHistoryProvider** - Historique de tous les chats utilisateur
- **activeModelProvider** - Modèle IA sélectionné
- **aiProvidersProvider** - Fournisseurs IA disponibles
- **aiModelsProvider** - Modèles disponibles par fournisseur
- **userApiKeysProvider** - Clés API de l'utilisateur

**Projet (PHASE 3):**
- **projectProvider** - État du projet courant (StateNotifier)
- **companiesProvider** - Liste entreprises (AsyncNotifier)
- **clientsProvider** - Liste clients (AsyncNotifier)
- **clientTypesProvider** - Types de clients (FutureProvider)
- **userSettingsProvider** - Paramètres utilisateur (AsyncNotifier)

---

## 📁 STRUCTURE DU PROJET

```
C:\Users\AL75\StudioProjects\test1/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── ai_chat_model.dart               ✅ (PHASE 2)
│   │   ├── assistant_models.dart
│   │   ├── ai_model_model.dart
│   │   ├── project_model.dart               ✅ (PHASE 3)
│   │   ├── company_model.dart               ✅ (PHASE 3)
│   │   ├── client_model.dart                ✅ (PHASE 3)
│   │   ├── client_type_model.dart           ✅ (PHASE 3)
│   │   └── ...
│   ├── providers/
│   │   ├── ai_chat_provider.dart            ✅ (PHASE 1 + 2)
│   │   ├── ai_chats_history_provider.dart   ✅ (PHASE 2)
│   │   ├── active_model_provider.dart
│   │   ├── auth_provider.dart
│   │   ├── project_provider.dart            ✅ (PHASE 3)
│   │   ├── reference_data_provider.dart     ✅ (PHASE 3)
│   │   ├── user_settings_provider.dart      ✅ (PHASE 3)
│   │   └── ...
│   ├── ui/
│   │   ├── pages/
│   │   │   └── home_page.dart              ✅ (PHASE 2 modified)
│   │   ├── views/
│   │   │   └── project_details_view.dart   ✅ (PHASE 3)
│   │   ├── widgets/
│   │   │   ├── right_pane.dart             ✅ (PHASE 1 + 2)
│   │   │   ├── chat_selector.dart          ✅ (PHASE 2)
│   │   │   ├── left_pane.dart
│   │   │   └── ...
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── dialogs/
│   │       ├── add_company_dialog.dart      ✅ (PHASE 3)
│   │       └── add_client_dialog.dart       ✅ (PHASE 3)
│   ├── services/
│   ├── assistant/
│   │   ├── assistant_controller.dart
│   │   └── tools_registry.dart
│   └── integrations/
│
├── supabase/
│   ├── functions/
│   │   ├── assist_flut/
│   │   │   └── index.ts                   ✅
│   │   ├── ai-keys-manager/
│   │   │   └── index.ts                   ✅
│   │   └── _shared/
│   │       └── cors.ts
│   │
│   └── migrations/
│       ├── create_ai_models.sql
│       ├── create_user_api_keys.sql
│       └── ...
│
└── pubspec.yaml
```

### Fichiers Clés

| Fichier | Chemin | Utilité |
|---------|--------|---------|
| Chat UI + Sélecteur modèles | `lib/ui/widgets/right_pane.dart` | Interface principale du chat |
| Sélecteur chats (PHASE 2) | `lib/ui/widgets/chat_selector.dart` | Sélection + actions sur chats |
| Historique chats (PHASE 2) | `lib/providers/ai_chats_history_provider.dart` | Gestion de l'historique |
| Assistant IA | `supabase/functions/assist_flut/index.ts` | Appels API IA |
| Home page | `lib/ui/pages/home_page.dart` | Initialisation + loading historique |
| **Interface Projet (PHASE 3)** | `lib/ui/views/project_details_view.dart` | Interface principale du projet |
| **Provider Projet (PHASE 3)** | `lib/providers/project_provider.dart` | Gestion état + génération auto |
| **Providers Ref Data (PHASE 3)** | `lib/providers/reference_data_provider.dart` | Companies, Clients, ClientTypes |

---

## 🔮 PHASES RESTANTES

### PHASE 3 : Module Projet (EN COURS - ~75%) 🔄

**Objectif :** Créer/éditer/sauvegarder des projets de devis

**Composants complétés ✅:**
- ✅ Interface projet (3 sections complètes)
- ✅ Sélection entreprise + client
- ✅ Métadonnées complètes (tous les champs)
- ✅ Génération auto numéro de devis
- ✅ Génération auto nom de projet
- ✅ Gestion liste clients multi

**Composants restants ⏳:**
- ⏳ Sauvegarder projet (bouton + méthode saveProject)
- ⏳ Charger projets existants (ProjectSelector + loadProject)
- ⏳ Provider projectsHistoryProvider

### PHASE 4 : Module Bien (À FAIRE)

**Objectif :** Gérer surfaces et déductions

**Fonctionnalités :**
- Définir pièces (dimensions, hauteur, etc.)
- Ajouter menuiseries (portes, fenêtres) → déductions automatiques
- Calculs automatiques des surfaces nettes

### PHASE 5 : Module Travaux (À FAIRE)

**Objectif :** Ajouter prestations avec calculs

**Composants :**
- Liste hierarchique services
- Calcul automatique quantites
- Calcul HT, TVA, TTC

### PHASE 6 : Module Facturation (À FAIRE)

**Objectif :** Créer factures progressives (Acompte, Situation, Solde)

### PHASE 7 : Module Comptabilité (À FAIRE)

**Objectif :** Gérer transactions et catégorisations

### PHASE 8 : Export PDF (À FAIRE)

**Objectif :** Génération de devis et factures PDF

---

## 🚀 PROCHAINES ÉTAPES

**Session prochaine (Architecture IA-First) :**

### Priorité 1: Implémenter les Tools (contextUpdate)

L'objectif est de rendre l'IA pleinement opérationnelle pour exécuter des actions.

1. **Implémenter les Tools manquants dans `tools_registry.dart`:**
   - ✅ `UPDATE_PROJECT` - Mettre à jour les champs du projet
   - ✅ `UPDATE_METADATA` - Mettre à jour les métadonnées
   - ✅ `GENERATE_DEVIS_NUMBER` - Générer numéro automatique
   - ✅ `GENERATE_PROJECT_NAME` - Générer nom automatique
   - ✅ `ADD_CLIENT_TO_LIST` - Ajouter client à la liste
   - ✅ `SAVE_PROJECT` - Sauvegarder en BDD
   - ✅ `LOAD_PROJECT` - Charger depuis BDD
   - ✅ `CREATE_COMPANY` - Créer une société
   - ✅ `CREATE_CLIENT` - Créer un client

2. **Enrichir le prompt système:**
   - Ajouter le contenu de `AI_ACTIONS_LOGIC.md` dans le system prompt
   - L'IA doit connaître toutes les actions disponibles
   - L'IA doit connaître les formats de données

3. **Tester l'IA avec des scénarios réels:**
   - "Créer un devis pour M. Dupont Jean"
   - "Générer le numéro et le nom du projet"
   - "Ajouter une société Batiment Pro"

### Priorité 2: Architecture Prompts en BDD (optionnel)

Si temps disponible, commencer l'implémentation de `PROMPT_STORAGE_ARCHITECTURE.md`:

1. **Phase 1: Structure de Base**
   - Créer les tables Supabase (`ai_prompts`, `ai_prompt_suggestions`, `ai_prompt_templates`)
   - Créer les modèles Flutter
   - Créer les providers Riverpod
   - Créer les templates par défaut

2. **Phase 2: Interface Utilisateur**
   - Nouveau module "Gestion des Prompts" dans Paramètres
   - Éditeur de prompts avec prévisualisation

### Priorité 3: Compléter PHASE 3 (Module Projet)

Si les Tools sont fonctionnels, finaliser la PHASE 3:

1. **Compléter les fonctionnalités de persistence:**
   - Widget `ProjectSelector` - Sélectionner/créer/charger projets
   - Provider `projectsHistoryProvider` - Liste des projets sauvegardés
   - Tester le cycle complet: créer → sauvegarder → charger

2. **Puis PHASE 4 : Module Bien** (si PHASE 3 terminée)
   - Gérer surfaces et déductions
   - Pièces, menuiseries, calculs automatiques

---

## 🎓 PROMPT POUR PROCHAINES SESSIONS

```
🏗️ PROJET: BâtiPilot IAssist - Flutter
📍 Chemin: C:\Users\AL75\StudioProjects\test1 (ou BatiPilot-IAssist-Flutter)

✅ PHASES COMPLETEES:
1. Infrastructure + Sélecteur modèles IA
2. Historique des chats
3. Module Projet (~75% - UI complète)

🎯 NOUVELLE PRIORITÉ: Architecture IA-First

📚 DOCUMENTATION CRÉÉE (03/11/2025):
1. AI_ACTIONS_LOGIC.md
   - Documentation exhaustive des 118 actions de l'app
   - Structure BDD, formats, patterns
   - Cas d'usage pour l'IA

2. PROMPT_STORAGE_ARCHITECTURE.md
   - Proposition: stocker prompts en BDD (pas en dur)
   - UI édition prompts + suggestions IA
   - Plan d'implémentation 5 phases

🔧 PROBLÈME IDENTIFIÉ:
- ✅ L'IA reçoit projectState (via assistant_controller)
- ❌ L'IA ne peut PAS modifier les données (Tools sont des stubs)
- ❌ L'IA ne connaît pas les actions disponibles
- ❌ L'IA ne connaît pas les formats de données

⏳ PROCHAINES TÂCHES (Ordre de priorité):

1. 🎯 PRIORITÉ 1: Implémenter les Tools dans tools_registry.dart
   - UPDATE_PROJECT (mettre à jour projet)
   - UPDATE_METADATA (mettre à jour métadonnées)
   - GENERATE_DEVIS_NUMBER (générer numéro)
   - GENERATE_PROJECT_NAME (générer nom)
   - ADD_CLIENT_TO_LIST (ajouter client)
   - CREATE_COMPANY (créer société)
   - CREATE_CLIENT (créer client)
   - SAVE_PROJECT (sauvegarder)
   - LOAD_PROJECT (charger)

2. 🎯 PRIORITÉ 2: Enrichir le system prompt
   - Injecter contenu de AI_ACTIONS_LOGIC.md
   - L'IA doit connaître toutes les actions
   - L'IA doit connaître les formats

3. 🎯 PRIORITÉ 3: Tester avec scénarios réels
   - "Créer un devis pour M. Dupont"
   - "Générer le numéro et le nom"
   - L'IA doit pouvoir créer un client qui n'existe pas

📁 FICHIERS CLÉS:
- lib/assistant/tools_registry.dart → IMPLÉMENTER LES TOOLS ICI
- lib/assistant/assistant_controller.dart → Enrichir system prompt
- AI_ACTIONS_LOGIC.md → RÉFÉRENCE pour toutes les actions
- PROMPT_STORAGE_ARCHITECTURE.md → Roadmap future

🔄 ÉTAT ACTUEL:
- App compilée et lancée ✅
- Interface projet fonctionnelle ✅
- Documentation complète créée ✅
- BESOIN: Tools fonctionnels pour "IA dans l'appli"
```

---

## 📚 DOCUMENTATION DE RÉFÉRENCE

### 1. DOCUMENTATION_COMPLETE_BATIPILOT.md (Partie 1 & 2)
- **Chemin:** `DOCUMENTATION_COMPLETE_BATIPILOT.md` + `DOCUMENTATION_COMPLETE_BATIPILOT_PARTIE2.md`
- **Contenu:** Architecture complète, schéma BD, types, calculs surfaces, modules
- **Statut:** Document React/Web - Concepts métier valides, implémentation à adapter à Flutter

### 2. Attentes_Assistant_IA_BatiPilot.md
- **Chemin:** `Attentes_Assistant_IA_BatiPilot.md`
- **Contenu:** Spécifications de l'assistant IA, signaux, intégration
- **Statut:** Architecture Assistant-first implémentée (assistant_controller, tools_registry)

### 3. SESSION_CONTINUATION_GUIDE.md
- **Chemin:** `SESSION_CONTINUATION_GUIDE.md` (ce fichier)
- **Contenu:** État actuel du projet, phases complétées, prochaines étapes
- **Statut:** Mis à jour en continu

### 4. AI_ACTIONS_LOGIC.md ✅ NOUVEAU (03/11/2025)
- **Chemin:** `AI_ACTIONS_LOGIC.md`
- **Contenu:** Documentation exhaustive de TOUTES les actions disponibles dans l'application
  - Structure complète de la base de données (tables, relations, RLS)
  - Formats de données (numéro devis AAMM-N, nom projet, clientsData, etc.)
  - **118 actions documentées** : Authentification, Sociétés, Clients, Projets, Config IA, Chat
  - Pour chaque action: déclencheur UI, champs, validation, opérations BDD, effets
  - Patterns de comportement (loading, validation, feedback, rafraîchissement)
  - Cas d'usage pour l'IA (scénarios "Créer un devis pour M. Seigneur Alain...")
- **Objectif:** Permettre à l'IA de comprendre et reproduire TOUTES les actions utilisateur
- **Statut:** Complet et prêt à être utilisé pour entraînement IA

### 5. PROMPT_STORAGE_ARCHITECTURE.md ✅ NOUVEAU (03/11/2025)
- **Chemin:** `PROMPT_STORAGE_ARCHITECTURE.md`
- **Contenu:** Proposition complète pour stocker les prompts IA en base de données
  - Schéma BDD: `ai_prompts`, `ai_prompt_suggestions`, `ai_prompt_templates`
  - Types de prompts: system_context, tool_dispatcher, projects_assistant, error_handler
  - Interface utilisateur: Module "Gestion des Prompts IA" dans Paramètres
  - Éditeur de prompts avec coloration syntaxe, variables dynamiques, prévisualisation
  - **Système de suggestions IA**: analyse automatique des conversations pour proposer améliorations
  - Implémentation technique: Providers Riverpod, modèles, intégration AssistantController
  - Plan d'implémentation en 5 phases
- **Objectif:** Permettre à l'utilisateur de modifier les prompts sans redéploiement
- **Statut:** Proposition à valider et implémenter (Phases 1-5)

---

## 📞 RESSOURCES

**Documentation :**
- Flutter: https://docs.flutter.dev
- Supabase: https://supabase.com/docs
- Riverpod: https://riverpod.dev

**Logs Supabase :**
- Dashboard → Edge Functions → assist_flut → Logs

---

**Créé:** 02 Novembre 2025
**Dernière mise à jour:** 03 Novembre 2025 - Documentation IA & Architecture
**Utilisateur:** AL75
**Statut:** Documentation complète créée ✅ - Prêt pour implémentation Tools
**Branche Git:** `claude/session-continuation-setup-011CUjFx7p3rB8tYKXMat9Nm`
