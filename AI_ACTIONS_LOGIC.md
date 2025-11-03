# Guide de Logique des Actions - BatiPilot IAssist
## Documentation pour l'IA - Tous les Actions et Formats

> **Objectif:** Ce document permet à l'IA de comprendre TOUTES les actions disponibles dans l'application, leurs formats de données, et comment les exécuter. L'IA doit être capable de reproduire chaque action que l'utilisateur peut faire manuellement.

---

## TABLE DES MATIÈRES

1. [Structure de la Base de Données](#1-structure-de-la-base-de-données)
2. [Formats de Données](#2-formats-de-données)
3. [Actions: Authentification](#3-actions-authentification)
4. [Actions: Gestion des Sociétés](#4-actions-gestion-des-sociétés)
5. [Actions: Gestion des Clients](#5-actions-gestion-des-clients)
6. [Actions: Types de Clients](#6-actions-types-de-clients)
7. [Actions: Gestion des Projets](#7-actions-gestion-des-projets)
8. [Actions: Configuration IA](#8-actions-configuration-ia)
9. [Actions: Chat et Historique](#9-actions-chat-et-historique)
10. [Patterns de Comportement](#10-patterns-de-comportement)

---

## 1. STRUCTURE DE LA BASE DE DONNÉES

### Tables Supabase et leurs Relations

```
┌─────────────────┐
│   users         │ (Supabase Auth)
│   - id (uuid)   │
└─────────────────┘
         │
         │ user_id (FK)
         │
    ┌────┴────────────────────────────────────┐
    │                                         │
┌───▼──────────┐                    ┌────────▼────────┐
│  companies   │                    │   clients       │
│  - id (uuid) │                    │   - id (uuid)   │
│  - name      │                    │   - nom         │
│  - address   │                    │   - prenom      │
│  - city      │                    │   - adresse     │
│  - email     │                    │   - ville       │
│  - tel1      │                    │   - tel1        │
│  - siret     │                    │   - email       │
│  - user_id   │                    │   - client_type_id │
└──────────────┘                    │   - user_id     │
                                    └─────────────────┘
                                             │
                                             │ client_type_id (FK)
                                             │
                                    ┌────────▼─────────┐
                                    │  client_types    │
                                    │  - id (uuid)     │
                                    │  - name          │
                                    │  - user_id       │
                                    └──────────────────┘

┌─────────────────┐
│  devis_save     │ (Projects/Quotes)
│  - id (uuid)    │
│  - project_name │
│  - devis_number │
│  - company_id   │
│  - client_id    │
│  - status       │
│  - user_id      │
└─────────────────┘

┌───────────────────┐
│  ai_providers     │
│  - id (uuid)      │
│  - provider_key   │ (ex: "gemini", "openai")
│  - provider_name  │
│  - api_endpoint   │
│  - auth_method    │
│  - user_id        │
└───────────────────┘
         │
         │ provider_key (FK)
         │
    ┌────┴──────────────────────┐
    │                           │
┌───▼──────────┐       ┌────────▼───────────┐
│  ai_models   │       │  ai_api_keys       │
│  - id (uuid) │       │  - id (uuid)       │
│  - model_key │       │  - provider_key    │
│  - model_name│       │  - key_alias       │
│  - provider  │       │  - encrypted_key   │
│  - user_id   │       │  - is_active       │
└──────────────┘       │  - user_id         │
                       └────────────────────┘

┌──────────────────────────┐
│  ai_model_configurations │
│  - id (uuid)             │
│  - config_name           │
│  - provider_key          │
│  - model_key             │
│  - api_key_id            │
│  - module                │ ("global", "rapports", "imports")
│  - is_active             │
│  - user_id               │
└──────────────────────────┘

┌─────────────────────┐
│  ai_chats_history   │
│  - id (uuid)        │
│  - user_id          │
│  - title            │
│  - module           │
│  - created_at       │
│  - updated_at       │
└─────────────────────┘
         │
         │ chat_id (FK)
         │
┌────────▼──────────┐
│  ai_messages      │
│  - id (uuid)      │
│  - chat_id        │
│  - role           │ ("user" ou "assistant")
│  - content        │
│  - created_at     │
└───────────────────┘

┌─────────────────────┐
│  user_settings      │
│  - id (uuid)        │
│  - user_id          │
│  - selected_company │
│  - created_at       │
│  - updated_at       │
└─────────────────────┘
```

### Politiques RLS (Row Level Security)

**Toutes les tables** utilisent RLS avec la politique suivante:
- **SELECT:** `auth.uid() = user_id`
- **INSERT:** `auth.uid() = user_id`
- **UPDATE:** `auth.uid() = user_id`
- **DELETE:** `auth.uid() = user_id`

> **Important pour l'IA:** Toute opération de base de données nécessite que l'utilisateur soit authentifié. Le `user_id` est automatiquement récupéré via `supabase.auth.currentUser?.id`.

---

## 2. FORMATS DE DONNÉES

### 2.1 Format: Numéro de Devis

**Format:** `AAMM-N`
- `AA`: Année sur 2 chiffres (ex: "25" pour 2025)
- `MM`: Mois sur 2 chiffres (ex: "11" pour novembre)
- `N`: Numéro séquentiel (incrémenté depuis la BDD)

**Exemples:**
- `2511-1` : Premier devis de novembre 2025
- `2511-47` : 47ème devis de novembre 2025
- `2512-1` : Premier devis de décembre 2025

**Logique de génération:**
1. Extraire AA et MM de `project.devisDate` (ou `DateTime.now()` si null)
2. Construire le préfixe: `"$AA$MM"`
3. Requête BDD: `SELECT devis_number FROM devis_save WHERE devis_number LIKE '2511-%' ORDER BY devis_number DESC LIMIT 1`
4. Parser le dernier numéro (ex: "2511-46" → 46)
5. Incrémenter: `nextNumber = 47`
6. Nouveau numéro: `"2511-47"`

**Code de référence:** `lib/providers/project_provider.dart:80-125`

---

### 2.2 Format: Nom de Projet

**Format:** `Devis n° [NUMERO] - [NOM_CLIENT] - [DESCRIPTION]`

**Composants:**
- `[NUMERO]`: Numéro de devis (auto-généré si vide)
- `[NOM_CLIENT]`: Priorité:
  1. **Ligne 2 de `clientsData`** (si présent et non vide)
  2. **`fullName` du client sélectionné** (si `clientId` non null)
  3. **"Client à définir"** (si rien de disponible)
- `[DESCRIPTION]`: Première ligne de `descriptionProjet` (optionnel)

**Exemples:**
- `Devis n° 2511-1 - M. DUPONT Jean - Rénovation salle de bain`
- `Devis n° 2511-2 - SAS BATIMENT PRO`
- `Devis n° 2511-3 - Client à définir - Extension cuisine`

**Logique:**
1. Si `devisNumber` vide → appeler `generateDevisNumber()`
2. Extraire nom client (priorité: ligne 2 de clientsData > clientId > défaut)
3. Extraire description (première ligne de descriptionProjet)
4. Assembler: `"Devis n° $numero - $client${description.isNotEmpty ? ' - $description' : ''}"`

**Code de référence:** `lib/providers/project_provider.dart:127-178`

---

### 2.3 Format: Données Clients (clientsData)

**Format:** Multi-lignes avec structure répétée

```
[TYPE_CLIENT]
[NOM_COMPLET]
[ADRESSE_COMPLETE]

[TYPE_CLIENT]
[NOM_COMPLET]
[ADRESSE_COMPLETE]

...
```

**Exemple concret:**
```
Particulier
M. SEIGNEUR Alain
12 Rue de la Paix - 75000 Paris

Société
SAS RENOVATION PRO
45 Avenue des Champs - 75008 Paris

Maître d'oeuvre
M. ARCHITECTE Pierre
10 Boulevard Haussmann - 75009 Paris
```

**Règles:**
- Chaque client = 3 lignes + 1 ligne vide
- Ligne 1: Type de client (depuis table `client_types`)
- Ligne 2: Nom complet (`client.fullName` = `"${client.prenom} ${client.nom}".trim()`)
- Ligne 3: Adresse complète (`"${adresse} - ${codePostal} ${ville}"` ou "Adresse non renseignée")
- Ligne 4: Ligne vide (séparateur)

**Utilisation:**
- **Pour affichage:** Parse les lignes et affiche dans un `TextFormField` multiline
- **Pour extraction nom client:** Prendre la 2ème ligne du premier bloc (ligne index 1)

**Code de référence:** `lib/providers/project_provider.dart:180-236`

---

### 2.4 Format: Statut de Devis

**Enum:** `DevisStatus` (`lib/models/project_model.dart`)

**Valeurs:**
- `brouillon`: Devis en cours de rédaction (default)
- `accepte`: Devis accepté par le client

**Effet sur UI:**
- Si `brouillon`:
  - Switch désactivé (gris)
  - "Référence Bon de Commande" en readOnly
  - "Date de confirmation" désactivée
- Si `accepte`:
  - Switch activé (bleu)
  - "Référence Bon de Commande" éditable
  - "Date de confirmation" sélectionnable

**Stockage BDD:** Colonne `status` dans table `devis_save` (text)

---

### 2.5 Format: Dates

**Format d'affichage:** `DateFormat.yMMMMd('fr_FR')`
- Exemple: "15 novembre 2025"

**Format stockage BDD:** ISO 8601
- Exemple: "2025-11-15T10:30:00.000Z"

**Conversion:**
- **Vers BDD:** `date.toIso8601String()`
- **Depuis BDD:** `DateTime.parse(json['created_at'])`

---

## 3. ACTIONS: AUTHENTIFICATION

### 3.1 ACTION: Se Connecter (Login)

**Déclencheur UI:** Bouton "Connexion" (HomePage)

**Étapes:**

#### Étape 1/2: Connexion à l'appli

**Modale affichée:** Dialog "Connexion à l'appli (1/2)"

**Champs:**
- `email` (TextField, requis)
- `password` (TextField avec obscureText, requis)
- `rememberMe` (Checkbox, optionnel, défaut: true)

**Action "Suivant":**
- Valide que les champs ne sont pas vides
- Passe à l'étape 2/2

---

#### Étape 2/2: Paramètres Supabase

**Modale affichée:** Dialog "Paramètres Supabase (2/2)"

**Champs:**
- `url` (TextField, requis, placeholder: "https://...")
- `key` (TextField, requis, placeholder: "Supabase ANON Key")
- `rememberServer` (Checkbox, optionnel, défaut: true)

**Action "Se connecter":**

1. **Validation:**
   - Vérifie que `url` et `key` ne sont pas vides

2. **Connexion Supabase:**
   ```dart
   await ref.read(supabaseConnectionProvider.notifier).connect(url, key, rememberServer);
   ```

3. **Authentification:**
   ```dart
   await ref.read(authNotifierProvider.notifier).signIn(email, password, rememberMe);
   ```

4. **Chargement historique:**
   ```dart
   await ref.read(aiChatsHistoryProvider.notifier).loadChats();
   ```

5. **Feedback:**
   - Succès: SnackBar "Connexion réussie !"
   - Erreur: SnackBar avec message d'erreur

**Effet:**
- Utilisateur connecté
- UI passe en mode "authentifié"
- Historique des chats chargé
- Accès aux modules de l'application

**Code de référence:** `lib/ui/pages/home_page.dart:94-213`

---

### 3.2 ACTION: Se Déconnecter (Logout)

**Déclencheur UI:** IconButton "Se deconnecter" (en haut à droite)

**Action:**

```dart
await ref.read(authNotifierProvider.notifier).signOut();
```

**Effet:**
- Session Supabase terminée
- Utilisateur déconnecté
- UI revient à l'écran de connexion
- Données en mémoire effacées

**Code de référence:** `lib/ui/pages/home_page.dart:216`

---

## 4. ACTIONS: GESTION DES SOCIÉTÉS

### 4.1 ACTION: Créer une Société

**Déclencheur UI:** Bouton "Créer une nouvelle société" (ProjectDetailsView)

**Modale affichée:** Dialog "Créer une nouvelle société"

**Champs du formulaire:**
- `name` (TextField, **REQUIS**)
- `address` (TextField, optionnel)
- `postalCode` (TextField, optionnel)
- `city` (TextField, optionnel)
- `tel1` (TextField, optionnel)
- `email` (TextField, optionnel)
- `siret` (TextField, optionnel)
- `tva_intracom` (TextField, optionnel)

**Action "Créer":**

1. **Validation:**
   - Vérifie que `name` n'est pas vide

2. **Appel Provider:**
   ```dart
   await ref.read(companiesProvider.notifier).addCompany(
     name: name,
     address: address,
     city: city,
     postalCode: postalCode,
     email: email,
     tel1: tel1,
     siret: siret,
     tvaIntracom: tvaIntracom,
   );
   ```

3. **Opération BDD (dans le provider):**
   ```dart
   final userId = supabaseClient.auth.currentUser?.id;

   await supabaseClient.from('companies').insert({
     'name': name,
     'address': address,
     'city': city,
     'postal_code': postalCode,
     'email': email,
     'tel1': tel1,
     'siret': siret,
     'tva_intracom': tvaIntracom,
     'user_id': userId,
   });

   ref.invalidateSelf(); // Recharge la liste
   ```

4. **Feedback:**
   - Succès: SnackBar "Société créée avec succès !"
   - Erreur: SnackBar avec message d'erreur
   - Dialog se ferme

**Effet:**
- Nouvelle société insérée dans la table `companies`
- Liste des sociétés rafraîchie automatiquement
- Société disponible dans le dropdown de sélection

**Table BDD:** `companies`

**Code de référence:**
- Dialog: `lib/ui/dialogs/add_company_dialog.dart`
- Provider: `lib/providers/reference_data_provider.dart:22-51`

---

### 4.2 ACTION: Sélectionner une Société

**Déclencheur UI:** Dropdown "Sélectionner une société" (ProjectDetailsView)

**Action:**

```dart
ref.read(projectProvider.notifier).updateProject(companyId: selectedCompanyId);
```

**Effet:**
- `project.companyId` est mis à jour
- Sauvegarde de l'ID dans `user_settings.selected_company_id` (pour persistance)
- UI affiche la carte d'information de la société:
  - Nom (gras)
  - Adresse complète
  - Téléphone
  - Email

**Persistance:**
```dart
// Si la société change, on sauvegarde dans Supabase
await _ref.read(userSettingsProvider.notifier).updateSettings(
  selectedCompanyId: companyId
);
```

**Table BDD:**
- Lecture: `companies`
- Écriture: `user_settings` (selected_company_id)

**Code de référence:** `lib/ui/views/project_details_view.dart:186-238`

---

## 5. ACTIONS: GESTION DES CLIENTS

### 5.1 ACTION: Créer un Client

**Déclencheur UI:** Bouton "Créer un nouveau client" (ProjectDetailsView)

**Modale affichée:** Dialog "Créer un nouveau client"

**Champs du formulaire:**
- `nom` (TextField, **REQUIS**)
- `prenom` (TextField, optionnel)
- `adresse` (TextField, optionnel)
- `codePostal` (TextField, optionnel)
- `ville` (TextField, optionnel)
- `tel1` (TextField, optionnel)
- `email` (TextField, optionnel)

**Action "Créer":**

1. **Validation:**
   - Vérifie que `nom` n'est pas vide

2. **Appel Provider:**
   ```dart
   await ref.read(clientsProvider.notifier).addClient(
     nom: nom,
     prenom: prenom,
     adresse: adresse,
     codePostal: codePostal,
     ville: ville,
     tel1: tel1,
     email: email,
   );
   ```

3. **Opération BDD (dans le provider):**
   ```dart
   final userId = supabaseClient.auth.currentUser?.id;

   await supabaseClient.from('clients').insert({
     'nom': nom,
     'prenom': prenom,
     'adresse': adresse,
     'code_postal': codePostal,
     'ville': ville,
     'tel1': tel1,
     'email': email,
     'user_id': userId,
   });

   ref.invalidateSelf(); // Recharge la liste
   ```

4. **Feedback:**
   - Succès: SnackBar "Client créé avec succès !"
   - Erreur: SnackBar avec message d'erreur
   - Dialog se ferme

**Effet:**
- Nouveau client inséré dans la table `clients`
- Liste des clients rafraîchie automatiquement
- Client disponible dans le dropdown de sélection

**Table BDD:** `clients`

**Code de référence:**
- Dialog: `lib/ui/dialogs/add_client_dialog.dart`
- Provider: `lib/providers/reference_data_provider.dart:67-94`

---

### 5.2 ACTION: Sélectionner un Client

**Déclencheur UI:** Dropdown "Sélectionner un client" (ProjectDetailsView)

**Action:**

```dart
ref.read(projectProvider.notifier).updateProject(clientId: selectedClientId);
```

**Effet:**
- `project.clientId` est mis à jour
- UI affiche la carte d'information du client:
  - Type de client (badge coloré)
  - Nom complet
  - Adresse complète
  - Code postal + Ville
  - Téléphone
  - Email
- Bouton "Ajouter à la liste" devient visible

**Table BDD:** `clients` (lecture seule)

**Code de référence:** `lib/ui/views/project_details_view.dart:244-358`

---

### 5.3 ACTION: Ajouter un Client à la Liste

**Déclencheur UI:** Bouton "Ajouter à la liste" (ProjectDetailsView, visible uniquement si client sélectionné)

**Pré-requis:**
- Un client doit être sélectionné (`project.clientId != null`)

**Action:**

```dart
await ref.read(projectProvider.notifier).addClientToList();
```

**Logique (dans le provider):**

1. **Récupération du client:**
   ```dart
   final clients = await _ref.read(clientsProvider.future);
   final client = clients.firstWhere((c) => c.id == state.clientId);
   ```

2. **Récupération du type de client:**
   ```dart
   String clientType = 'Type non défini';
   if (client.clientTypeId != null) {
     final clientTypes = await _ref.read(clientTypesProvider.future);
     final type = clientTypes.firstWhere((ct) => ct.id == client.clientTypeId);
     clientType = type.name;
   }
   ```

3. **Formatage de l'adresse:**
   ```dart
   final addressParts = [
     client.adresse,
     '${client.codePostal ?? ''} ${client.ville ?? ''}'.trim()
   ].where((s) => s != null && s.isNotEmpty).join(' - ');
   ```

4. **Construction du format client:**
   ```dart
   final formattedClient = '''
$clientType
${client.fullName}
${addressParts.isNotEmpty ? addressParts : 'Adresse non renseignée'}

''';
   ```

5. **Ajout aux données existantes:**
   ```dart
   final updatedClientsData = state.metadata.clientsData + formattedClient;

   state = state.copyWith(
     metadata: state.metadata.copyWith(clientsData: updatedClientsData),
     updatedAt: DateTime.now(),
   );
   ```

**Effet:**
- Client ajouté au champ `clientsData` (textarea multi-clients)
- Respecte le format: Type\nNom\nAdresse\n\n
- Peut ajouter plusieurs clients successifs
- Utilisé pour générer le nom de projet (ligne 2 = premier client)

**Cas d'usage:**
- Projets avec plusieurs intervenants (Maître d'oeuvre, Particulier, Syndic...)
- Permet de lister tous les clients concernés par le devis

**Table BDD:** Aucune (données stockées dans `project.metadata.clientsData`)

**Code de référence:** `lib/providers/project_provider.dart:180-236`

---

## 6. ACTIONS: TYPES DE CLIENTS

### 6.1 Informations sur les Types

**Table BDD:** `client_types`

**Structure:**
```sql
CREATE TABLE client_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),
  name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id)
);
```

**Exemples de types:**
- Particulier
- Société
- Syndic
- Maître d'oeuvre
- Collectivité

**Utilisation:**
- Dropdown dans le dialog "Créer un client" (à implémenter)
- Affiché dans la carte d'information du client
- Utilisé dans le format `clientsData`

**Code de référence:**
- Model: `lib/models/client_type_model.dart`
- Provider: `lib/providers/reference_data_provider.dart:99-106`

---

## 7. ACTIONS: GESTION DES PROJETS

### 7.1 ACTION: Générer un Numéro de Devis

**Déclencheur UI:** IconButton "Générer" (à côté du champ "Numéro du devis")

**Action:**

```dart
await ref.read(projectProvider.notifier).generateDevisNumber();
```

**Logique:**

1. **Déterminer la date de référence:**
   ```dart
   final selectedDate = state.devisDate ?? DateTime.now();
   ```

2. **Construire le préfixe AAMM:**
   ```dart
   final yearDigits = selectedDate.year.toString().substring(2); // "25"
   final month = selectedDate.month.toString().padLeft(2, '0'); // "11"
   final prefix = '$yearDigits$month'; // "2511"
   ```

3. **Rechercher le dernier numéro en BDD:**
   ```dart
   final response = await supabaseClient
     .from('devis_save')
     .select('devis_number')
     .like('devis_number', '$prefix-%') // WHERE devis_number LIKE '2511-%'
     .order('devis_number', ascending: false)
     .limit(1);
   ```

4. **Calculer le prochain numéro:**
   ```dart
   int nextNumber = 1;

   if (response.isNotEmpty) {
     final lastDevisNumber = response[0]['devis_number'] as String;
     final parts = lastDevisNumber.split('-'); // ["2511", "46"]
     if (parts.length == 2) {
       final lastNumber = int.tryParse(parts[1]); // 46
       if (lastNumber != null) {
         nextNumber = lastNumber + 1; // 47
       }
     }
   }
   ```

5. **Générer le nouveau numéro:**
   ```dart
   final newQuoteNumber = '$prefix-$nextNumber'; // "2511-47"
   ```

6. **Mettre à jour l'état:**
   ```dart
   state = state.copyWith(
     devisNumber: newQuoteNumber,
     updatedAt: DateTime.now()
   );
   ```

**Effet:**
- Champ "Numéro du devis" mis à jour automatiquement (grâce au ValueKey)
- Visible dans l'UI immédiatement
- Utilisé pour générer le nom de projet

**Table BDD:** `devis_save` (lecture pour trouver le dernier numéro)

**Format de sortie:** `AAMM-N` (ex: "2511-47")

**Code de référence:** `lib/providers/project_provider.dart:80-125`

---

### 7.2 ACTION: Générer le Nom du Projet

**Déclencheur UI:** IconButton "Générer le nom" (à côté du champ "Nom du Projet")

**Action:**

```dart
await ref.read(projectProvider.notifier).generateProjectName();
```

**Logique:**

1. **Générer le numéro de devis si nécessaire:**
   ```dart
   if (state.devisNumber.isEmpty) {
     await generateDevisNumber();
   }
   ```

2. **Déterminer le nom du client (priorité):**

   **Option A: Extraire depuis `clientsData` (ligne 2):**
   ```dart
   String clientName = 'Client à définir';

   if (state.metadata.clientsData.isNotEmpty) {
     final lines = state.metadata.clientsData
       .split('\n')
       .where((l) => l.trim().isNotEmpty)
       .toList();

     if (lines.length >= 2) {
       clientName = lines[1].trim(); // Ligne 2 = nom du client
     }
   }
   ```

   **Option B: Utiliser `clientId` si pas de clientsData:**
   ```dart
   else if (state.clientId != null) {
     try {
       final clients = await _ref.read(clientsProvider.future);
       final client = clients.firstWhere((c) => c.id == state.clientId);
       clientName = client.fullName;
     } catch (e) {
       // Garder "Client à définir"
     }
   }
   ```

3. **Extraire la description (première ligne):**
   ```dart
   String description = '';
   if (state.metadata.descriptionProjet.isNotEmpty) {
     description = state.metadata.descriptionProjet.split('\n').first.trim();
   }
   ```

4. **Assembler le nom complet:**
   ```dart
   final generatedName = 'Devis n° ${state.devisNumber} - $clientName${description.isNotEmpty ? ' - $description' : ''}';
   ```

5. **Mettre à jour l'état:**
   ```dart
   state = state.copyWith(
     projectName: generatedName,
     updatedAt: DateTime.now()
   );
   ```

**Effet:**
- Champ "Nom du Projet" mis à jour automatiquement (grâce au ValueKey)
- Format: `Devis n° 2511-1 - M. DUPONT Jean - Rénovation salle de bain`

**Dépendances:**
- `devisNumber` (auto-généré si vide)
- `clientsData` (priorité) ou `clientId` (fallback)
- `descriptionProjet` (optionnel)

**Code de référence:** `lib/providers/project_provider.dart:127-178`

---

### 7.3 ACTION: Changer le Statut du Devis

**Déclencheur UI:** Switch "Brouillon" / "Accepté" (ProjectDetailsView)

**Action:**

```dart
ref.read(projectProvider.notifier).updateProject(
  status: isAccepted ? DevisStatus.accepte : DevisStatus.brouillon
);
```

**Effet:**

**Si statut = `brouillon`:**
- Switch en position OFF (gris)
- Texte "Brouillon" (noir)
- Champ "Référence Bon de Commande" en readOnly (grisé)
- Champ "Date de confirmation" désactivé (grisé)

**Si statut = `accepte`:**
- Switch en position ON (bleu)
- Texte "Accepté" (bleu)
- Champ "Référence Bon de Commande" éditable
- Champ "Date de confirmation" sélectionnable (date picker)

**Table BDD:** `devis_save` (colonne `status`)

**Code de référence:** `lib/ui/views/project_details_view.dart:148-182`

---

### 7.4 ACTION: Sélectionner la Date du Devis

**Déclencheur UI:** Champ "Date du devis" (avec icône calendrier)

**Action:**

1. **Ouvrir le date picker:**
   ```dart
   final DateTime? picked = await showDatePicker(
     context: context,
     initialDate: project.devisDate ?? DateTime.now(),
     firstDate: DateTime(2000),
     lastDate: DateTime(2101),
   );
   ```

2. **Mettre à jour si sélectionné:**
   ```dart
   if (picked != null) {
     ref.read(projectProvider.notifier).updateProject(devisDate: picked);
   }
   ```

**Effet:**
- `project.devisDate` mis à jour
- Affichage formaté: "15 novembre 2025"
- **Attention:** Modifier cette date peut nécessiter de régénérer le numéro de devis (car le préfixe AAMM change)

**Code de référence:** `lib/ui/views/project_details_view.dart:130-146`

---

### 7.5 ACTION: Sélectionner la Date de Confirmation

**Déclencheur UI:** Champ "Date de confirmation" (avec icône calendrier)

**Pré-requis:** Le statut doit être `accepte`

**Action:**

1. **Ouvrir le date picker:**
   ```dart
   final DateTime? picked = await showDatePicker(
     context: context,
     initialDate: project.dateAcceptation ?? DateTime.now(),
     firstDate: DateTime(2000),
     lastDate: DateTime(2101),
   );
   ```

2. **Mettre à jour si sélectionné:**
   ```dart
   if (picked != null) {
     ref.read(projectProvider.notifier).updateProject(dateAcceptation: picked);
   }
   ```

**Effet:**
- `project.dateAcceptation` mis à jour
- Affichage formaté: "15 novembre 2025"
- Champ visible/éditable uniquement si `status == accepte`

**Code de référence:** `lib/ui/views/project_details_view.dart:130-146`

---

### 7.6 ACTION: Modifier les Métadonnées du Projet

**Champs concernés:**
- Description du projet (multiline, 4 lignes)
- Adresse du chantier (multiline, 4 lignes)
- Occupant (single line)
- Informations complémentaires (multiline, 4 lignes)
- Liste des clients (multiline, 6 lignes, géré par "Ajouter à la liste")

**Action:**

```dart
ref.read(projectProvider.notifier).updateMetadata(
  descriptionProjet: value,    // ou null si non modifié
  adresseChantier: value,      // ou null si non modifié
  occupant: value,             // ou null si non modifié
  infoComplementaire: value,   // ou null si non modifié
  clientsData: value,          // ou null si non modifié (rarement manuel)
);
```

**Effet:**
- `project.metadata` mis à jour
- `project.updatedAt` automatiquement mis à jour
- Modifications visibles immédiatement dans l'UI

**Table BDD:** Aucune pour le moment (données en mémoire dans `projectProvider`)

**Code de référence:**
- Provider: `lib/providers/project_provider.dart:61-78`
- UI: `lib/ui/views/project_details_view.dart:438-555`

---

## 8. ACTIONS: CONFIGURATION IA

### 8.1 ACTION: Ajouter un Fournisseur IA

**Déclencheur UI:** Bouton "Ajouter un fournisseur" (AI Control Center)

**Modale affichée:** Dialog "Ajouter un fournisseur"

**Champs du formulaire:**
- `name` (TextField, **REQUIS**, label: "Nom de la société *")
- `provider_key` (TextField, **REQUIS**, label: "Identifiant (provider_key) *")
- `api_endpoint` (TextField, **REQUIS**, label: "Endpoint API *")
- `auth_method` (Dropdown, optionnel, défaut: "bearer")
  - Options: "bearer", "api_key_header", "query_param"

**Action "Ajouter":**

1. **Validation:**
   - Vérifie que `name`, `provider_key`, et `api_endpoint` ne sont pas vides

2. **Opération BDD:**
   ```dart
   final userId = supabase.auth.currentUser?.id;

   await supabase.from('ai_providers').insert({
     'provider_name': name,
     'provider_key': providerKey,
     'api_endpoint': endpoint,
     'auth_method': authMethod,
     'user_id': userId,
   });
   ```

3. **Rafraîchissement:**
   ```dart
   ref.invalidate(aiProvidersProvider);
   ```

4. **Feedback:**
   - Succès: SnackBar "Fournisseur ajouté avec succès !"
   - Dialog se ferme

**Effet:**
- Nouveau fournisseur dans table `ai_providers`
- Disponible dans les dropdowns de sélection
- Peut maintenant ajouter des modèles pour ce fournisseur

**Table BDD:** `ai_providers`

**Code de référence:** `lib/ui/views/ai_control_center_view.dart` (méthode `_showAddProviderDialog`)

---

### 8.2 ACTION: Ajouter un Modèle IA

**Déclencheur UI:** Bouton "Ajouter un modèle" (AI Control Center)

**Pré-requis:** Un fournisseur doit être sélectionné

**Modale affichée:** Dialog "Ajouter un modèle"

**Champs du formulaire:**
- `model_name` (TextField, **REQUIS**)
- `model_key` (TextField, **REQUIS**)
- `description` (TextField multiline, optionnel, 2 lignes)

**Action "Ajouter":**

1. **Validation:**
   - Vérifie que `model_name` et `model_key` ne sont pas vides

2. **Opération BDD:**
   ```dart
   final userId = supabase.auth.currentUser?.id;

   await supabase.from('ai_models').insert({
     'model_name': modelName,
     'model_key': modelKey,
     'provider_key': selectedProviderKey,
     'description': description,
     'user_id': userId,
   });
   ```

3. **Rafraîchissement:**
   ```dart
   ref.invalidate(aiModelsProvider);
   ```

4. **Feedback:**
   - Succès: SnackBar "Modèle ajouté avec succès !"
   - Dialog se ferme

**Effet:**
- Nouveau modèle dans table `ai_models`
- Associé au fournisseur sélectionné
- Disponible pour créer des clés API

**Table BDD:** `ai_models`

**Code de référence:** `lib/ui/views/ai_control_center_view.dart` (méthode `_showAddModelDialog`)

---

### 8.3 ACTION: Ajouter une Clé API

**Déclencheur UI:** Bouton "Ajouter une clé" (AI Control Center)

**Pré-requis:** Un modèle doit être sélectionné

**Modale affichée:** Dialog "Ajouter une clé API"

**Champs du formulaire:**
- `provider` (Dropdown, **REQUIS**, désactivé en mode édition)
- `alias` (TextField, **REQUIS**, hint: "ex: API Perso, API Pro")
- `description` (TextField multiline, optionnel, 2 lignes)
- `key` (TextField avec obscureText + toggle, **REQUIS** pour nouveau)

**Action "Ajouter":**

1. **Validation:**
   - Vérifie que `provider`, `alias`, et `key` ne sont pas vides

2. **Opération BDD:**
   ```dart
   final userId = supabase.auth.currentUser?.id;

   await supabase.from('ai_api_keys').insert({
     'provider_key': providerKey,
     'key_alias': alias,
     'encrypted_key': key, // TODO: Chiffrement à implémenter
     'description': description,
     'is_active': false, // Par défaut inactive
     'user_id': userId,
   });
   ```

3. **Feedback:**
   - Succès: SnackBar "Clé API ajoutée avec succès !"
   - Dialog se ferme

**Effet:**
- Nouvelle clé dans table `ai_api_keys`
- Status: inactive par défaut
- Peut être activée avec le bouton "Activer"

**Table BDD:** `ai_api_keys`

**Code de référence:** `lib/ui/dialogs/ai_config_dialogs.dart` (AddEditApiKeyDialog)

---

### 8.4 ACTION: Activer une Clé API

**Déclencheur UI:** Bouton "Activer" (sur une carte de clé inactive)

**Action:**

```dart
await ref.read(apiKeysNotifierProvider.notifier).setActiveKey(apiKeyId);
```

**Logique:**

1. **Désactiver les autres clés du même fournisseur:**
   ```dart
   await supabase
     .from('ai_api_keys')
     .update({'is_active': false})
     .eq('provider_key', providerKey)
     .eq('user_id', userId);
   ```

2. **Activer la clé sélectionnée:**
   ```dart
   await supabase
     .from('ai_api_keys')
     .update({'is_active': true})
     .eq('id', apiKeyId);
   ```

3. **Rafraîchir:**
   ```dart
   ref.invalidateSelf();
   ```

**Effet:**
- Une seule clé active par fournisseur
- Badge "Active" affiché sur la clé
- Utilisée pour les appels API

**Table BDD:** `ai_api_keys` (colonne `is_active`)

**Code de référence:** `lib/providers/api_keys_provider.dart`

---

### 8.5 ACTION: Créer une Configuration de Modèle

**Déclencheur UI:** Bouton "Nouvelle configuration" (AI Control Center NEW)

**Modale affichée:** Dialog "Nouvelle configuration"

**Champs du formulaire:**
- `config_name` (TextField, **REQUIS**, hint: "ex: Gemini 2.5 Pro Personnel")
- `provider` (Dropdown, **REQUIS**)
- `model` (Dropdown, **REQUIS**, filtré par provider)
- `api_key` (Dropdown custom, **REQUIS**, affiche les clés actives)
- `module` (Dropdown, **REQUIS**, défaut: "global")
  - Options: "global", "rapports", "imports"

**Action "Créer":**

1. **Validation:**
   - Tous les champs requis remplis

2. **Opération BDD:**
   ```dart
   final userId = supabase.auth.currentUser?.id;

   await supabase.from('ai_model_configurations').insert({
     'config_name': configName,
     'provider_key': providerKey,
     'model_key': modelKey,
     'api_key_id': apiKeyId,
     'module': module,
     'is_active': false,
     'user_id': userId,
   });
   ```

3. **Feedback:**
   - Succès: SnackBar "Configuration créée !"
   - Dialog se ferme

**Effet:**
- Nouvelle configuration dans table `ai_model_configurations`
- Associe un modèle à une clé API pour un module spécifique
- Peut être activée pour utilisation

**Table BDD:** `ai_model_configurations`

**Code de référence:** `lib/ui/dialogs/ai_config_dialogs.dart` (AddConfigurationDialog)

---

## 9. ACTIONS: CHAT ET HISTORIQUE

### 9.1 ACTION: Créer une Nouvelle Discussion

**Déclencheur UI:** Bouton "+" (Chat Selector)

**Action:**

```dart
await ref.read(aiChatProvider.notifier).createNewChat(module: 'context');
await ref.read(aiChatsHistoryProvider.notifier).loadChats();
```

**Logique:**

1. **Insertion en BDD:**
   ```dart
   final userId = supabase.auth.currentUser?.id;

   final response = await supabase.from('ai_chats_history').insert({
     'user_id': userId,
     'title': 'Nouvelle conversation',
     'module': module,
   }).select().single();

   final chatId = response['id'];
   ```

2. **Mise à jour de l'état:**
   ```dart
   state = state.copyWith(
     currentChatId: chatId,
     currentChatTitle: 'Nouvelle conversation',
     messages: [],
   );
   ```

3. **Rafraîchissement de la liste:**
   ```dart
   await ref.read(aiChatsHistoryProvider.notifier).loadChats();
   ```

**Effet:**
- Nouvelle entrée dans table `ai_chats_history`
- Chat vide créé et sélectionné
- Prêt à recevoir des messages

**Table BDD:** `ai_chats_history`

**Code de référence:** `lib/ui/widgets/chat_selector.dart:49-52`

---

### 9.2 ACTION: Sélectionner une Discussion

**Déclencheur UI:** Dropdown "Selectionner une discussion..."

**Action:**

```dart
await ref.read(aiChatProvider.notifier).loadChat(chatId, chatTitle);
```

**Logique:**

1. **Charger les messages du chat:**
   ```dart
   final response = await supabase
     .from('ai_messages')
     .select()
     .eq('chat_id', chatId)
     .order('created_at', ascending: true);

   final messages = response.map((item) => ChatMessage.fromJson(item)).toList();
   ```

2. **Mise à jour de l'état:**
   ```dart
   state = state.copyWith(
     currentChatId: chatId,
     currentChatTitle: chatTitle,
     messages: messages,
   );
   ```

**Effet:**
- Historique des messages affiché
- Chat actif
- Peut envoyer de nouveaux messages

**Table BDD:** `ai_messages` (lecture)

**Code de référence:** `lib/providers/ai_chat_provider.dart`

---

### 9.3 ACTION: Renommer une Discussion

**Déclencheur UI:** Icône "edit" dans le dropdown des chats

**Modale affichée:** Dialog "Renommer la discussion"

**Champs:**
- `chatTitle` (TextField, focus automatique)

**Action "Renommer":**

1. **Validation:**
   - Vérifie que le titre n'est pas vide après trim

2. **Opération BDD:**
   ```dart
   await supabase
     .from('ai_chats_history')
     .update({'title': newTitle, 'updated_at': DateTime.now().toIso8601String()})
     .eq('id', chatId);
   ```

3. **Rafraîchir la liste:**
   ```dart
   await ref.read(aiChatsHistoryProvider.notifier).loadChats();
   ```

4. **Feedback:**
   - SnackBar "Discussion renommée !"

**Effet:**
- Titre du chat mis à jour
- Visible dans le dropdown
- `updated_at` mis à jour

**Table BDD:** `ai_chats_history`

**Code de référence:** `lib/ui/widgets/chat_selector.dart:98-121`

---

### 9.4 ACTION: Supprimer une Discussion

**Déclencheur UI:** Icône "delete" dans le dropdown des chats

**Modale affichée:** Dialog de confirmation "Supprimer cette discussion ?"

**Content:** "Etes-vous sûr de vouloir supprimer définitivement "[chatTitle]" ?\n\nCette action ne peut pas être annulée."

**Action "Supprimer":**

1. **Suppression en cascade (BDD):**
   ```dart
   // Supprimer les messages associés
   await supabase
     .from('ai_messages')
     .delete()
     .eq('chat_id', chatId);

   // Supprimer le chat
   await supabase
     .from('ai_chats_history')
     .delete()
     .eq('id', chatId);
   ```

2. **Nettoyer l'état si c'était le chat actif:**
   ```dart
   if (ref.read(aiChatProvider).currentChatId == chatId) {
     ref.read(aiChatProvider.notifier).clearChat();
   }
   ```

3. **Rafraîchir la liste:**
   ```dart
   await ref.read(aiChatsHistoryProvider.notifier).loadChats();
   ```

4. **Feedback:**
   - SnackBar "Discussion supprimée"

**Effet:**
- Chat et ses messages supprimés définitivement
- Si c'était le chat actif, UI revient à l'état vide

**Tables BDD:** `ai_chats_history`, `ai_messages`

**Code de référence:** `lib/ui/widgets/chat_selector.dart:123-144`

---

### 9.5 ACTION: Envoyer un Message

**Déclencheur UI:** Bouton "Send" (icône) dans la barre d'input

**Action:**

```dart
await ref.read(assistantControllerProvider).handleUserMessage(
  text: messageText,
  module: 'context',
  context: context,
);
```

**Logique complète:**

1. **Sauvegarder le message utilisateur:**
   ```dart
   await supabase.from('ai_messages').insert({
     'chat_id': currentChatId,
     'role': 'user',
     'content': text,
   });
   ```

2. **Envoyer à l'Edge Function:**
   ```dart
   final projectState = ref.read(projectProvider).toJson();

   final response = await supabase.functions.invoke('assist_flut', body: {
     'module': module,
     'userMessage': text,
     'projectState': projectState,
   });

   final assistantResponse = AssistantResponse.fromJson(response.data);
   ```

3. **Traiter la réponse:**
   ```dart
   // Sauvegarder la réponse de l'IA
   await supabase.from('ai_messages').insert({
     'chat_id': currentChatId,
     'role': 'assistant',
     'content': assistantResponse.text,
   });

   // Exécuter les contextUpdate (Tools)
   if (assistantResponse.contextUpdate != null) {
     await _tools.dispatch(assistantResponse.contextUpdate!, ref, context);
   }

   // Gérer les navigationSignal
   if (assistantResponse.navigationSignal != null) {
     // Naviguer vers un module/vue spécifique
   }
   ```

4. **Mettre à jour l'UI:**
   ```dart
   state = state.copyWith(
     messages: [
       ...state.messages,
       ChatMessage(role: 'user', content: text),
       ChatMessage(role: 'assistant', content: assistantResponse.text),
     ],
   );
   ```

**Effet:**
- Message utilisateur + réponse IA affichés dans le chat
- Sauvegardés en BDD
- Actions exécutées si l'IA en a renvoyé (contextUpdate)
- Navigation possible si l'IA l'a demandé

**Tables BDD:** `ai_messages` (insert x2)

**Code de référence:**
- UI: `lib/ui/widgets/right_pane.dart:267-290`
- Controller: `lib/assistant/assistant_controller.dart`

---

### 9.6 ACTION: Sélectionner un Modèle Actif

**Déclencheur UI:** PopupMenuButton "Sélectionner un modèle" (en haut du chat)

**Action:**

```dart
await ref.read(activeModelProvider.notifier).setActiveModel(providerKey, modelKey);
```

**Logique:**

1. **Récupérer la configuration active:**
   ```dart
   final response = await supabase
     .from('ai_model_configurations')
     .select()
     .eq('provider_key', providerKey)
     .eq('model_key', modelKey)
     .eq('module', 'global')
     .eq('is_active', true)
     .maybeSingle();
   ```

2. **Si pas de configuration active, la créer:**
   ```dart
   if (response == null) {
     // Créer une configuration par défaut
   }
   ```

3. **Mettre à jour l'état:**
   ```dart
   state = ModelInfo(
     providerKey: providerKey,
     modelKey: modelKey,
     modelName: modelName,
     providerName: providerName,
   );
   ```

4. **Feedback:**
   - SnackBar "Modèle activé : [modelName]"
   - Couleur du bouton passe au vert (config active)

**Effet:**
- Modèle utilisé pour les prochains messages
- Edge Function utilise ce modèle pour les réponses
- Indicateur visuel mis à jour (vert si OK, orange si pas de config)

**Code de référence:** `lib/ui/widgets/right_pane.dart:71-166`

---

## 10. PATTERNS DE COMPORTEMENT

### 10.1 Pattern: Chargement Asynchrone

**Toutes les opérations de BDD** suivent ce pattern:

```dart
Future<void> actionName() async {
  setState(() => isLoading = true); // Afficher spinner

  try {
    // Opération Supabase
    await supabase.from('table').operation();

    // Rafraîchir les données
    ref.invalidate(someProvider);

    // Feedback succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action réussie !'))
    );

    // Fermer dialog si applicable
    if (context.mounted) Navigator.of(context).pop();

  } catch (e) {
    // Feedback erreur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e'))
    );
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
```

**Éléments clés:**
- `isLoading` contrôle l'affichage du spinner
- `try-catch` pour gérer les erreurs
- `SnackBar` pour le feedback utilisateur
- `ref.invalidate` pour recharger les données
- Vérifier `mounted` avant `setState`

---

### 10.2 Pattern: Validation de Formulaire

**Tous les dialogs** utilisent un `GlobalKey<FormState>`:

```dart
final _formKey = GlobalKey<FormState>();

TextFormField(
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ requis';
    }
    return null;
  },
),

// Au moment de submit:
void _submit() async {
  if (!_formKey.currentState!.validate()) {
    return; // Arrêter si validation échoue
  }

  // Continuer avec l'action
}
```

**Règles:**
- Validation uniquement sur submit (pas sur blur)
- Message générique: "Champ requis"
- Trim les valeurs avant vérification

---

### 10.3 Pattern: Rafraîchissement Automatique

**Utilisation de `ref.invalidate` ou `ref.invalidateSelf`:**

```dart
// Dans un dialog ou widget externe:
await ref.read(companiesProvider.notifier).addCompany(...);
// → Le provider appelle ref.invalidateSelf() en interne
// → Tous les widgets qui watch companiesProvider se rebuilent

// Alternative directe:
await supabase.from('companies').insert(...);
ref.invalidate(companiesProvider); // Force le rechargement
```

**Widgets concernés:**
- Dropdowns (listes de sociétés, clients, etc.)
- Cartes d'information
- Listes de chats

---

### 10.4 Pattern: Feedback Utilisateur

**Toutes les actions** donnent un feedback:

```dart
// Succès:
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('Action réussie !'),
    backgroundColor: Colors.green,
  ),
);

// Erreur:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Erreur : $errorMessage'),
    backgroundColor: Colors.red,
  ),
);
```

**Messages standardisés:**
- Création: "[Entité] créé(e) avec succès !"
- Suppression: "[Entité] supprimé(e)"
- Modification: "[Entité] modifié(e) avec succès !"
- Activation: "[Entité] activé(e) : [nom]"

---

### 10.5 Pattern: Gestion des États Loading

**Boutons et UI** s'adaptent pendant le chargement:

```dart
ElevatedButton(
  onPressed: isLoading ? null : _submit, // Désactiver si loading
  child: isLoading
    ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : const Text('Action'),
)
```

**Également dans les dialogs:**
- Actions buttons désactivées pendant loading
- Spinner visible
- Impossible de fermer le dialog pendant l'opération

---

### 10.6 Pattern: Persistance de Sélection

**Certaines sélections** sont sauvegardées pour persistance:

```dart
// Société sélectionnée:
if (companyId != null && companyId != state.companyId) {
  await _ref.read(userSettingsProvider.notifier).updateSettings(
    selectedCompanyId: companyId
  );
}

// Au démarrage:
final userSettings = ref.watch(userSettingsProvider).value;
final initialCompanyId = userSettings?.selectedCompanyId;
```

**Bénéfice:**
- L'utilisateur retrouve sa société par défaut au prochain lancement
- Stocké dans table `user_settings`

---

## 11. CAS D'USAGE: Scénarios IA

### Scénario 1: "Créer un devis pour M. Seigneur Alain..."

**Intent utilisateur:** Créer un nouveau projet/devis

**Actions IA recommandées:**

1. **Vérifier si le client existe:**
   ```dart
   final clients = await ref.read(clientsProvider.future);
   final client = clients.firstWhere(
     (c) => c.nom.toLowerCase().contains('seigneur') && c.prenom?.toLowerCase().contains('alain'),
     orElse: () => null,
   );
   ```

2. **Si client n'existe pas → Proposer création:**
   - Afficher: "Je n'ai pas trouvé de client 'M. Seigneur Alain' dans votre base. Souhaitez-vous le créer ?"
   - Pré-remplir le modal avec: `nom: "Seigneur"`, `prenom: "Alain"`
   - Attendre confirmation de l'utilisateur

3. **Si client existe → Sélectionner automatiquement:**
   ```dart
   await contextUpdate({
     "action": "UPDATE_PROJECT",
     "payload": {
       "clientId": client.id
     }
   });
   ```

4. **Générer le numéro de devis:**
   ```dart
   await contextUpdate({
     "action": "GENERATE_DEVIS_NUMBER",
     "payload": {}
   });
   ```

5. **Confirmer à l'utilisateur:**
   - "J'ai créé un nouveau devis (n° 2511-47) pour M. SEIGNEUR Alain. Que souhaitez-vous ajouter ?"

---

### Scénario 2: "Ajouter une prestation de plomberie..."

**Intent utilisateur:** Ajouter un travail au devis

**Actions IA recommandées:**

1. **Vérifier qu'un projet est ouvert:**
   ```dart
   if (projectState.devisNumber.isEmpty) {
     return "Veuillez d'abord créer ou sélectionner un projet.";
   }
   ```

2. **Extraire les informations de la prestation:**
   - Désignation: "Plomberie"
   - Détails additionnels depuis le contexte utilisateur

3. **Appeler le Tool:**
   ```dart
   await contextUpdate({
     "action": "ADD_TRAVAIL",
     "payload": {
       "designation": "Plomberie",
       "description": "...",
     }
   });
   ```

4. **Confirmer:**
   - "J'ai ajouté la prestation 'Plomberie' au devis n° 2511-47."

---

### Scénario 3: "Quelle est l'adresse du client actuel ?"

**Intent utilisateur:** Obtenir des informations

**Actions IA recommandées:**

1. **Lire le projectState:**
   ```dart
   final clientId = projectState.clientId;
   ```

2. **Si pas de client:**
   - "Aucun client n'est sélectionné pour ce projet."

3. **Si client sélectionné:**
   - Récupérer depuis les données (projectState contient les infos du client)
   - Répondre: "Le client actuel est M. DUPONT Jean, domicilié au 12 Rue de la Paix, 75000 Paris."

---

## 12. RÉSUMÉ: Actions Disponibles pour l'IA

**Actions implémentées (via UI):**
- ✅ Créer une société
- ✅ Sélectionner une société
- ✅ Créer un client
- ✅ Sélectionner un client
- ✅ Ajouter un client à la liste
- ✅ Générer un numéro de devis
- ✅ Générer un nom de projet
- ✅ Modifier le statut du devis
- ✅ Modifier les métadonnées du projet
- ✅ Créer/renommer/supprimer des discussions
- ✅ Envoyer des messages

**Actions à implémenter (Tools manquants):**
- ❌ UPDATE_PROJECT (mettre à jour project via contextUpdate)
- ❌ UPDATE_METADATA (mettre à jour metadata via contextUpdate)
- ❌ GENERATE_DEVIS_NUMBER (via contextUpdate)
- ❌ GENERATE_PROJECT_NAME (via contextUpdate)
- ❌ ADD_CLIENT_TO_LIST (via contextUpdate)
- ❌ ADD_TRAVAIL (ajouter une prestation)
- ❌ SAVE_PROJECT (sauvegarder en BDD)
- ❌ LOAD_PROJECT (charger depuis BDD)

---

## 13. NEXT STEPS: Architecture Prompts en BDD

**Objectif:** Stocker les prompts système dans Supabase, pas en dur dans le code.

**Table proposée:** `ai_prompts`

```sql
CREATE TABLE ai_prompts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),

  prompt_key TEXT NOT NULL, -- ex: "system_context", "tool_dispatcher"
  module TEXT NOT NULL, -- ex: "global", "projets", "rapports"
  version INTEGER NOT NULL DEFAULT 1,

  title TEXT NOT NULL,
  content TEXT NOT NULL, -- Le prompt complet
  is_active BOOLEAN DEFAULT true,

  user_id UUID REFERENCES auth.users(id),

  UNIQUE(prompt_key, module, user_id)
);
```

**Fonctionnalités à ajouter:**
1. **UI de gestion des prompts** (nouveau module dans Paramètres)
2. **Provider pour charger les prompts:** `aiPromptsProvider`
3. **Éditeur de prompt** avec syntaxe highlighting (optionnel)
4. **Système de versions** (historique des modifications)
5. **Suggestions d'amélioration par l'IA:**
   - Analyser les conversations
   - Détecter les incompréhensions
   - Proposer des ajouts au prompt système

**Utilisation:**
```dart
final systemPrompt = await ref.read(aiPromptsProvider).getPrompt('system_context', module: 'global');

// Envoyer à l'Edge Function
await supabase.functions.invoke('assist_flut', body: {
  'systemPrompt': systemPrompt,
  'userMessage': userMessage,
  'projectState': projectState,
});
```

---

## FIN DU DOCUMENT

**Version:** 1.0
**Date:** 2 novembre 2025
**Auteur:** Claude (IA)
**Objectif:** Documentation complète de toutes les actions de l'application pour entraînement et intégration IA.

**Ce document doit être mis à jour** à chaque ajout de nouvelle fonctionnalité ou modification de logique existante.
