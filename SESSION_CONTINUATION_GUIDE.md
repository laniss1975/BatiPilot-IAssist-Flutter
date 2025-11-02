# 🏗️ BâtiPilot IAssist - Documentation Synthétique pour Sessions Futures

**Date de création:** 02 Novembre 2025  
**Dernière mise à jour:** 02 Novembre 2025 (PHASE 2 Complétée)  
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

**Statut:** PHASE 2 (Historique des Chats) **COMPLÉTÉE** ✅

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

### 🔄 En Cours

- 🔄 UI de base (widgets, navigation, pages)

### ⏳ À Faire (Phases futures)

- ⏳ Module Projet (création/édition)
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

- **aiChatProvider** - État du chat courant (messages, chat actif)
- **aiChatsHistoryProvider** - Historique de tous les chats utilisateur
- **activeModelProvider** - Modèle IA sélectionné
- **aiProvidersProvider** - Fournisseurs IA disponibles
- **aiModelsProvider** - Modèles disponibles par fournisseur
- **userApiKeysProvider** - Clés API de l'utilisateur

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
│   │   └── ...
│   ├── providers/
│   │   ├── ai_chat_provider.dart            ✅ (PHASE 1 + 2)
│   │   ├── ai_chats_history_provider.dart   ✅ (PHASE 2)
│   │   ├── active_model_provider.dart
│   │   ├── auth_provider.dart
│   │   └── ...
│   ├── ui/
│   │   ├── pages/
│   │   │   └── home_page.dart              ✅ (PHASE 2 modified)
│   │   ├── widgets/
│   │   │   ├── right_pane.dart             ✅ (PHASE 1 + 2)
│   │   │   ├── chat_selector.dart          ✅ (PHASE 2)
│   │   │   ├── left_pane.dart
│   │   │   └── ...
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── dialogs/
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

---

## 🔮 PHASES RESTANTES

### PHASE 3 : Module Projet (À FAIRE)

**Objectif :** Créer/éditer des projets de devis

**Composants :**
- Page projet (créer nouveau, charger existant)
- Sélection entreprise + client
- Métadonnées (numéro devis, date, description)
- Sauvegarder/charger projets

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

**Session prochaine :**

1. ✅ **Vérifier l'état du projet** (compilation, app lancée)
2. ⏳ **PHASE 3 : Module Projet**
   - Créer page pour créer/charger projets
   - Interface sélection entreprise + client
   - Persistence Supabase

---

## 🎓 PROMPT POUR PROCHAINES SESSIONS

```
🏗️ PROJET: BâtiPilot IAssist - Flutter
📍 Chemin: C:\Users\AL75\StudioProjects\test1

✅ PHASES COMPLETEES:
1. Infrastructure + Sélecteur modèles IA
2. Historique des chats (NOUVEAU)
   - Sélecteur chats en dropdown
   - Créer/renommer/supprimer chats
   - Titre auto: "Discussion du DD/MM/YY à HHhMM"
   - Chargement au démarrage
   - Multi-chats avec messages complets

📁 FICHIERS CLÉS:
- lib/ui/widgets/chat_selector.dart → Sélecteur + actions
- lib/providers/ai_chats_history_provider.dart → Gestion historique
- lib/providers/ai_chat_provider.dart → Chat courant + loadChat()
- lib/models/ai_chat_model.dart → Modèle AiChat

📊 TABLES SUPABASE:
- ai_chats_flut → Conversations
- ai_chat_messages_flut → Messages

🔄 ÉTAT ACTUEL:
- App compilée et lancée ✅
- Historique des chats fonctionnel ✅
- Prêt pour PHASE 3 (Module Projet)

⏳ PROCHAINE PHASE:
PHASE 3 - Module Projet (création/édition devis)
```

---

## 📚 DOCUMENTATION DE RÉFÉRENCE

### 1. DOCUMENTATION_COMPLETE_BATIPILOT.md
- **Chemin:** `C:\Users\AL75\StudioProjects\test1\DOCUMENTATION_COMPLETE_BATIPILOT.md`
- **Contenu:** Architecture complète, schéma BD, types, calculs surfaces, modules
- **Statut:** Document React/Web - Concepts metier valides, implementation à adapter à Flutter

### 2. Attentes de l'Assistant IA  BatiPilot IAssist Flutter.md
- **Chemin:** Fichier spécifié dans SESSION_CONTINUATION_GUIDE.md
- **Contenu:** Spécifications de l'assistant IA, signaux, integration
- **Statut:** À adapter pour architecture Flutter

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
**Dernière mise à jour:** 02 Novembre 2025  
**Utilisateur:** AL75  
**Statut:** PHASE 2 Completée ✅
