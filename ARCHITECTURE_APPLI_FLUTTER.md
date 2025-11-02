# Architecture de l'Application BâtiPilot IAssist (Flutter)

Ce document décrit l'architecture globale, les composants clés et les flux de données de l'application Flutter BâtiPilot IAssist.

## 1. Structure Générale du Projet

Le projet est organisé en plusieurs dossiers clés, principalement dans le répertoire `lib`, qui contient l'ensemble du code source Dart de l'application.

```
/
├── lib/
│   ├── assistant/
│   ├── models/
│   ├── providers/
│   ├── services/
│   ├── ui/
│   └── main.dart
├── pubspec.yaml
└── ... (autres dossiers de plateforme : android, ios, etc.)
```

---

### 1.1. `main.dart`

C'est le point d'entrée de l'application. Il est responsable de l'initialisation des services essentiels et du lancement du premier widget de l'application.

- **`main.dart`**: Configure `Riverpod` avec `ProviderScope` et lance l'application.

---

### 1.2. `/models`

Ce dossier contient les classes de modèle de données (Data Models). Ces classes représentent la structure des objets manipulés dans l'application (projets, clients, etc.) et incluent souvent des méthodes pour la sérialisation/désérialisation (conversion depuis/vers JSON).

- **`project_model.dart`**: Définit la classe `Project`, le cœur de l'application, avec toutes les informations relatives à un devis.
- **`client_model.dart`**: Définit la classe `Client`.
- **`company_model.dart`**: Définit la classe `Company`.
- **`ai_model_model.dart`**: Modèle pour les modèles d'IA disponibles.
- **`user_api_key_model.dart`**: Modèle pour les clés API des utilisateurs.
- **`assistant_models.dart`**: Modèles de données spécifiques à l'assistant IA.
- `designation_model.dart`: Modèle pour les désignations ou descriptions de travaux.
- `travail_model.dart`: Modèle pour les unités de travail ou lots.
- `ai_provider_model.dart`: Modèle pour les fournisseurs de modèles d'IA.


---

### 1.3. `/providers`

Ce répertoire est central pour la gestion de l'état de l'application avec `Riverpod`. Chaque fichier définit un ou plusieurs "providers" qui exposent un état et permettent aux widgets de l'UI de réagir à ses changements.

- **`supabase_connection_provider.dart`**: Gère l'état de la connexion à la base de données Supabase.
- **`auth_provider.dart`**: Gère l'authentification de l'utilisateur (connexion, déconnexion, état de session).
- **`project_provider.dart`**: Gère l'état du projet/devis actuellement ouvert dans l'application.
- **`reference_data_provider.dart`**: Charge et met à disposition les données de référence (listes de clients, sociétés).
- **`user_settings_provider.dart`**: Gère les préférences de l'utilisateur.
- **`ai_chat_provider.dart`**: Gère l'état de la conversation avec l'assistant IA.
- **`active_model_provider.dart`**: Gère le modèle d'IA actuellement sélectionné.
- `user_api_keys_provider.dart`: Gère les clés API de l'utilisateur pour les services d'IA.
- `ai_config_test_provider.dart`: Provider pour tester la configuration des modèles d'IA.


---

### 1.4. `/ui`

Ce dossier contient tout le code relatif à l'interface utilisateur. Il est lui-même subdivisé pour une meilleure organisation.

- **/`pages`**: Contient les widgets qui représentent des écrans complets de l'application (ex: `home_page.dart`).
- **/`views`**: Contient des sections majeures d'une page, souvent complexes et avec leur propre logique (ex: `project_details_view.dart`).
- **/`widgets`**: Contient des composants réutilisables plus petits (boutons, champs de texte customisés, etc.).
- **/`dialogs`**: Contient les boîtes de dialogue de l'application (ex: `add_client_dialog.dart`).
- **/`theme`**: Définit le thème global de l'application (couleurs, polices, etc.) dans `app_theme.dart`.

---

### 1.5. `/services`

Ce dossier contient des classes de service qui encapsulent une logique métier spécifique, souvent liée à des opérations externes (API, stockage local, etc.).

- **`user_preferences_service.dart`**: Service pour interagir avec le stockage local des préférences de l'utilisateur.

---

### 1.6. `/assistant`

Ce dossier regroupe la logique spécifique à l'assistant IA "BâtiPilot IAssist".

- **`assistant_controller.dart`**: Le contrôleur principal qui orchestre les interactions avec l'IA.
- **`tools_registry.dart`**: Registre des "outils" que l'IA peut utiliser pour interagir avec l'application.
## 2. Gestion de l'État (Riverpod Providers)

### 2.1. `auth_provider.dart`

Ce fichier gère l'authentification de l'utilisateur.

- **`authStateProvider`**: Un `StreamProvider` qui écoute les changements d'état d'authentification de Supabase (connexion, déconnexion) et expose l'objet `AuthState`.
- **`authNotifierProvider`**: Un `StateNotifierProvider` qui expose `AuthNotifier`. Ce dernier contient la logique pour :
    - `signIn()`: Connecter un utilisateur avec email/mot de passe.
    - `signOut()`: Déconnecter l'utilisateur.
    - `autoSignIn()`: Tenter une connexion automatique si des identifiants sont sauvegardés dans le stockage sécurisé.
    - Gère la persistance des identifiants dans le `FlutterSecureStorage`.

### 2.2. `user_settings_provider.dart`

Ce fichier gère la récupération et la mise à jour des préférences de l'utilisateur stockées dans la base de données.

- **`userSettingsProvider`**: Un `AsyncNotifierProvider` qui :
    - Récupère les paramètres de l'utilisateur (`UserSettings`) depuis la table `user_settings` de Supabase.
    - Fournit une méthode `updateSettings()` pour sauvegarder les modifications (par exemple, la dernière société sélectionnée) dans la base de données.

### 2.3. `project_provider.dart`

Ce fichier est crucial car il gère l'état du projet ou devis actuellement en cours d'édition.

- **`projectProvider`**: Un `StateNotifierProvider` qui expose `ProjectNotifier`. Ce dernier gère un objet `Project` et permet de :
    - `updateProject()`: Mettre à jour les propriétés principales du projet (nom, client, statut, etc.).
    - `updateMetadata()`: Mettre à jour les métadonnées du projet (description, adresse, etc.).
    - `generateDevisNumber()`: Contient la logique pour générer un numéro de devis unique en interrogeant Supabase.
    - Initialise un nouveau projet avec des valeurs par défaut, notamment en utilisant le `selectedCompanyId` des `userSettingsProvider`.

### 2.4. `reference_data_provider.dart`

Ce fichier a pour rôle de charger et de fournir les listes de données "de référence" qui sont utilisées dans les menus déroulants et autres sélecteurs de l'application.

- **`companiesProvider`**: Un `AsyncNotifierProvider` qui charge la liste de toutes les `Company` depuis la table `companies` de Supabase.
- **`clientsProvider`**: Un `AsyncNotifierProvider` qui charge la liste de tous les `Client` depuis la table `clients` de Supabase.
- **`aiProvidersProvider`**: Un `FutureProvider` qui charge la liste des fournisseurs de modèles d'IA actifs (`AiProvider`) depuis la table `ai_providers`.
- **`aiModelsProvider`**: Un `FutureProvider` qui charge la liste des modèles d'IA actifs (`AiModel`) depuis la table `ai_models`.

### 2.5. `ai_chat_provider.dart`

Ce fichier gère l'état d'une session de conversation avec l'assistant IA.

- **`aiChatProvider`**: Un `StateNotifierProvider` qui expose `AiChatNotifier`. Ce dernier gère l'état du chat (`AiChatState`) et contient la logique pour :
    - `ensureCurrentChat()`: S'assurer qu'une session de chat est active et en créer une dans la table `ai_chats_flut` si nécessaire.
    - `addUserMessage()`: Ajouter un message de l'utilisateur à la conversation et le sauvegarder dans la table `ai_chat_messages_flut`.
    - `addAssistantMessage()`: Ajouter une réponse de l'assistant à la conversation.

### 2.6. `active_model_provider.dart`

Ce fichier gère quel modèle d'Intelligence Artificielle est actuellement actif pour l'utilisateur.

- **`activeModelProvider`**: Un `AsyncNotifierProvider` qui :
    - Récupère la configuration du modèle actif (`ActiveModelConfig`) pour l'utilisateur depuis la table `ai_provider_configs`.
    - Fournit une méthode `setActiveModel()` qui appelle une fonction RPC (`ai_activate_global_model`) dans Supabase pour changer atomiquement le modèle actif.