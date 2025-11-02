Documentation Technique : Boutons/Actions de la Page Projet
Date de création : 29 Octobre 2025
-----
ATTENTION:
Ce document décrit en détail les fonctions d'une appli web sous react, afin de faire bénéficier notre projet ici sous Flutter (adaptation)
Ce qui nous interresse ici, c'est essentiellement les logiques et interractions avec les tables
-----

Fichiers principaux : src/pages/Projet.tsx, src/hooks/useProjectForm.tsx, src/hooks/useProjectOperations.ts, src/services/projectSaveService.ts

1. 🔢 Générer un Numéro de Devis
📍 Localisation
Bouton : <Button onClick={handleGenerateQuoteNumber}>
Fichier : src/pages/Projet.tsx (lignes 201-258)
Icon : <FileText className="h-4 w-4 mr-1" />
Label : "Générer N° Devis"

🎯 Objectif
Générer automatiquement un numéro de devis unique au format YYMM-N (ex: 2510-1 pour octobre 2025, premier devis du mois).

📊 Logique Détaillée
1️⃣ Format du Numéro
YYMM-N
├── YY : Les 2 derniers chiffres de l'année (ex: 25 pour 2025)
├── MM : Le mois sur 2 chiffres (ex: 10 pour octobre)
└── N  : Numéro séquentiel du devis pour ce mois (ex: 1, 2, 3...)
Exemples :

2510-1 : Premier devis d'octobre 2025
2510-5 : Cinquième devis d'octobre 2025
2511-1 : Premier devis de novembre 2025
2️⃣ Algorithme de Génération

const handleGenerateQuoteNumber = async () => {
  setIsGeneratingNumber(true); // Affiche un loader

  try {
    // ÉTAPE 1 : Récupérer la date sélectionnée (ou date actuelle)
    const selectedDate = date || new Date();
    const yearDigits = selectedDate.getFullYear().toString().slice(-2); // "25"
    const month = (selectedDate.getMonth() + 1).toString().padStart(2, '0'); // "10"
    const prefix = `${yearDigits}${month}`; // "2510"

    // ÉTAPE 2 : Rechercher le dernier numéro avec ce préfixe dans la DB
    const { data, error } = await supabase
      .from('devis_save')
      .select('devis_number')
      .like('devis_number', `${prefix}-%`) // WHERE devis_number LIKE '2510-%'
      .order('devis_number', { ascending: false }) // Trier par ordre décroissant
      .limit(1); // Prendre uniquement le dernier

    if (error) throw error;

    let nextNumber = 1; // Par défaut, premier devis du mois

    // ÉTAPE 3 : Si des devis existent déjà ce mois, incrémenter
    if (data && data.length > 0) {
      const lastNumberStr = data[0].devis_number.split('-')[1]; // "5" de "2510-5"
      const lastNumber = parseInt(lastNumberStr, 10); // 5
      nextNumber = lastNumber + 1; // 6
    }

    // ÉTAPE 4 : Formater le nouveau numéro
    const newQuoteNumber = `${prefix}-${nextNumber}`; // "2510-6"
    setQuoteNumber(newQuoteNumber); // Met à jour l'état local

    // ÉTAPE 5 : Synchroniser avec l'état global (ProjectContext)
    dispatch({
      type: ProjectActionType.UPDATE_DEVIS_NUMBER,
      payload: newQuoteNumber,
    });

    // ÉTAPE 6 : Afficher une notification
    toast({
      title: "Numéro généré",
      description: `Nouveau numéro de devis : ${newQuoteNumber}`
    });

    return newQuoteNumber;
  } catch (err) {
    console.error("Erreur lors de la génération du numéro de devis:", err);
    toast({
      title: "Erreur",
      description: "Impossible de générer un numéro de devis. Veuillez réessayer.",
      variant: "destructive"
    });
    return null;
  } finally {
    setIsGeneratingNumber(false); // Masque le loader
  }
};
💾 Stockage et Synchronisation
États Locaux (Composant Projet.tsx)

const [quoteNumber, setQuoteNumber] = useState<string>('');
const [isGeneratingNumber, setIsGeneratingNumber] = useState<boolean>(false);
État Global (ProjectContext)

// Dans projectReducer.ts
case ProjectActionType.UPDATE_DEVIS_NUMBER:
  return {
    ...state,
    devis_number: action.payload, // "2510-6"
    isDirty: true // Marque le projet comme modifié
  };
Base de Données (Table devis_save)

// Colonne : devis_number (type: text, NOT NULL, UNIQUE)
// Exemple : '2510-6'
⚠️ Contrainte importante : Le numéro de devis est soumis à une contrainte d'unicité dans la base de données. Si deux utilisateurs tentent de créer un devis avec le même numéro simultanément, la base de données rejettera le second (conflit UNIQUE).

🔄 Synchronisation Bidirectionnelle
Local → Global

// Dans useProjectForm.tsx (lignes 75-87)
useEffect(() => {
  if (quoteNumber !== projectState.devis_number) {
    dispatch({ type: ProjectActionType.SET_DIRTY });
    const updatedProject = { ...projectState, devis_number: quoteNumber };
    dispatch({ type: ProjectActionType.SET_PROJECT, payload: updatedProject });
  }
}, [quoteNumber, dispatch]);
Global → Local

// Synchronisation inverse pour les mises à jour externes (ex: via Clara)
useEffect(() => {
  if (projectState.devis_number !== quoteNumber) {
    setQuoteNumber(projectState.devis_number || '');
  }
}, [projectState.devis_number]);
📤 Sauvegarde en Base de Données
Lors de l'appel à saveProject() dans projectSaveService.ts :


const dataToSave = {
  // ... autres champs
  devis_number: project.devis_number, // "2510-6"
  // ...
};

const { data, error } = await supabase
  .from('devis_save')
  .upsert(dataToSave) // INSERT ou UPDATE
  .select('*')
  .single();
2. 📝 Générer Nom du Projet
📍 Localisation
Bouton : <Button onClick={handleGenerateProjectName}>
Fichier : src/pages/Projet.tsx (lignes 260-323)
Icon : <Edit3 className="h-4 w-4 mr-1" />
Label : "Générer Nom"

🎯 Objectif
Générer automatiquement un nom de projet lisible et descriptif au format :

Devis n° [NUMERO] - [NOM_CLIENT] - [DESCRIPTION]
Exemple :

Devis n° 2510-6 - Dupont Jean - Rénovation complète appartement
📊 Logique Détaillée
Algorithme de Génération

const handleGenerateProjectName = async () => {
  // ÉTAPE 1 : S'assurer qu'un numéro de devis existe
  let currentQuoteNumber = quoteNumber;
  if (!currentQuoteNumber) {
    const generatedNumber = await handleGenerateQuoteNumber(); // Génère si absent
    currentQuoteNumber = generatedNumber || "";
  }

  // ÉTAPE 2 : Extraire le nom du client (ligne 2 de clientDetails)
  let clientName = "Client à définir";

  if (clientDetails.trim() !== '') {
    const lines = clientDetails.split('\n');
    if (lines.length > 1) {
      clientName = lines[1].trim(); // "Dupont Jean"
    }
  }

  // ÉTAPE 3 : Si aucun client n'est présent, utiliser un client par défaut
  if (clientName === "Client à définir" && clients.length > 0) {
    const defaultClient = clients.find(
      client => client.id === "03fd9a5a-45cd-4c6e-be3e-114858d04ffd"
    );
    if (defaultClient) {
      clientName = `${defaultClient.nom || ''}${
        defaultClient.prenom ? ' ' + defaultClient.prenom : ''
      }`;
    }
  }

  // ÉTAPE 4 : Limiter le nom du client à 30 caractères
  if (clientName.length > 30) {
    clientName = clientName.substring(0, 30) + '...';
  }

  // ÉTAPE 5 : Extraire la description (première ligne seulement)
  let description = projectDescription.trim() || "Projet en cours";
  const firstLine = description.split('\n')[0].trim();
  description = firstLine || "Projet en cours";

  // ÉTAPE 6 : Limiter la description à 100 caractères
  if (description.length > 100) {
    description = description.substring(0, 100) + '...';
  }

  // ÉTAPE 7 : Assembler le nom du projet
  const generatedName = `Devis n° ${currentQuoteNumber} - ${clientName} - ${description}`;
  setProjectName(generatedName); // État local

  // ÉTAPE 8 : Synchroniser avec l'état global
  dispatch({
    type: ProjectActionType.UPDATE_PROJECT_NAME,
    payload: generatedName,
  });

  // ÉTAPE 9 : Notification
  toast({
    title: "Nom généré",
    description: "Le nom du projet a été généré avec succès."
  });

  return generatedName;
};
📋 Sources de Données
1. Numéro de Devis

currentQuoteNumber // État local ou généré
2. Nom du Client
Source prioritaire : clientDetails (ligne 2)


const clientDetails = `Particulier
Dupont Jean
12 rue de la Paix - 75001 Paris`;

// Extraction : lines[1] → "Dupont Jean"
Source secondaire : Client par défaut (si clientDetails est vide)


const defaultClient = clients.find(
  client => client.id === "03fd9a5a-45cd-4c6e-be3e-114858d04ffd"
);
3. Description du Projet
Source : projectDescription (première ligne seulement)


const projectDescription = `Rénovation complète appartement
Travaux de peinture et électricité`;

// Extraction : firstLine → "Rénovation complète appartement"
💾 Stockage et Synchronisation
États Locaux

const [projectName, setProjectName] = useState<string>('');
const [projectDescription, setProjectDescription] = useState<string>('');
const [clientDetails, setClientDetails] = useState<string>('');
État Global (ProjectContext)

case ProjectActionType.UPDATE_PROJECT_NAME:
  return {
    ...state,
    project_name: action.payload,
    isDirty: true
  };
Base de Données (devis_save)

// Colonne : project_name (type: text, NOT NULL)
// Exemple : "Devis n° 2510-6 - Dupont Jean - Rénovation complète appartement"
🔄 Synchronisation Bidirectionnelle

// Local → Global
useEffect(() => {
  if (projectName !== projectState.project_name) {
    dispatch({ type: ProjectActionType.SET_DIRTY });
    const updatedProject = { ...projectState, project_name: projectName };
    dispatch({ type: ProjectActionType.SET_PROJECT, payload: updatedProject });
  }
}, [projectName, dispatch]);

// Global → Local
useEffect(() => {
  if (projectState.project_name !== projectName) {
    setProjectName(projectState.project_name || '');
  }
}, [projectState.project_name]);
3. ➕ Ajouter Client (dans "Liste/données des clients")
📍 Localisation
Bouton : <Button onClick={handleAddClient}>
Fichier : src/pages/Projet.tsx (lignes 153-199)
Icon : <PlusCircle className="h-4 w-4 mr-1" />
Label : "Ajouter Client"

🎯 Objectif
Ajouter les informations d'un client sélectionné dans le Textarea "Liste/données des clients", en formatant les données de manière lisible.

📊 Logique Détaillée
Algorithme d'Ajout

const handleAddClient = () => {
  // ÉTAPE 1 : Validation - Un client doit être sélectionné
  if (!selectedClientId) {
    toast({
      title: "Erreur",
      description: "Veuillez sélectionner un client avant de l'ajouter à la liste.",
      variant: "destructive"
    });
    return;
  }

  // ÉTAPE 2 : Récupérer les détails du client depuis la liste complète
  if (!selectedClient) {
    toast({
      title: "Erreur",
      description: "Client introuvable.",
      variant: "destructive"
    });
    return;
  }

  // ÉTAPE 3 : Récupérer le type de client
  const clientType = clientTypes.find(type => type.id === selectedClient.client_type_id);
  const clientTypeName = clientType ? clientType.name : "Client";

  // ÉTAPE 4 : Formater les informations du client
  const clientName = `${selectedClient.nom || ''}${
    selectedClient.prenom ? ' ' + selectedClient.prenom : ''
  }`;
  const clientAddress = `${selectedClient.adresse || ''} - ${
    selectedClient.code_postal || ''
  } ${selectedClient.ville || ''}`.trim();

  // ÉTAPE 5 : Formatter selon que c'est le premier client ou non
  let formattedClientInfo = '';

  if (clientDetails.trim() === '') {
    // Premier client
    formattedClientInfo = `${clientTypeName}\n${clientName}\n${clientAddress}`;
  } else {
    // Clients additionnels (séparation avec saut de ligne double)
    formattedClientInfo = `${clientDetails}\n\n${clientTypeName}\n${clientName}\n${clientAddress}`;
  }

  // ÉTAPE 6 : Mettre à jour le textarea
  setClientDetails(formattedClientInfo);

  // ÉTAPE 7 : Notification
  toast({
    title: "Client ajouté",
    description: `${clientName} a été ajouté à la liste des clients.`
  });
};
📋 Format de Sortie
Premier Client
Particulier
Dupont Jean
12 rue de la Paix - 75001 Paris
Clients Multiples
Particulier
Dupont Jean
12 rue de la Paix - 75001 Paris

Professionnel
Entreprise SARL Martin
45 avenue de la République - 69000 Lyon
Structure :

[TYPE_CLIENT_1]
[NOM_PRENOM_1]
[ADRESSE_1]

[TYPE_CLIENT_2]
[NOM_PRENOM_2]
[ADRESSE_2]
💾 Stockage et Synchronisation
États Locaux

const [selectedClientId, setSelectedClientId] = useState<string>('');
const [clientDetails, setClientDetails] = useState<string>('');
Données de Référence

// Hook useClients() fournit :
const {
  clients,              // Liste complète des clients
  clientTypes,          // Liste des types de clients
  isLoadingClients,     // État de chargement
  refreshClients        // Fonction de rafraîchissement
} = useClients();

// Client sélectionné (calculé)
const selectedClient = clients.find(client => client.id === selectedClientId);
État Global (ProjectContext)

// Stocké dans project_data.metadata.clientsData
case ProjectActionType.UPDATE_METADATA:
  return {
    ...state,
    project_data: {
      ...state.project_data,
      metadata: {
        ...state.project_data.metadata,
        clientsData: action.payload.clientsData, // Le textarea formaté
        // ... autres champs metadata
      }
    },
    isDirty: true
  };
Base de Données (devis_save)

{
  "project_data": {
    "metadata": {
      "clientsData": "Particulier\nDupont Jean\n12 rue de la Paix - 75001 Paris",
      "descriptionProjet": "...",
      "adresseChantier": "...",
      "occupant": "...",
      "infoComplementaire": "..."
    }
  }
}
🔄 Synchronisation avec la Métadata

// Dans useProjectForm.tsx (lignes 121-138)
useEffect(() => {
  if (
    // ... autres conditions
    clientDetails !== (projectState.project_data.metadata.clientsData || '')
  ) {
    const updatedMetadata = {
      descriptionProjet: projectDescription,
      clientsData: clientDetails, // ← Synchronisation ici
      adresseChantier: address,
      occupant: occupants,
      infoComplementaire: additionalInfo,
    };
    dispatch({ type: ProjectActionType.UPDATE_METADATA, payload: updatedMetadata });
  }
}, [clientDetails, /* autres dépendances */]);
📤 Création d'un Nouveau Client
Modal : CreateClientModal
Fichier : src/components/client/CreateClientModal.tsx

Workflow de Création

graph TD
    A[Utilisateur clique sur<br/>'Ajouter Société'] --> B[Modal s'ouvre]
    B --> C[Remplir formulaire]
    C --> D{Validation OK?}
    D -->|Non| E[Afficher erreur]
    D -->|Oui| F[Appel API Supabase]
    F --> G{Succès?}
    G -->|Non| H[Toast erreur]
    G -->|Oui| I[Fermer modal]
    I --> J[refreshClients]
    J --> K[Sélectionner automatiquement<br/>le nouveau client]
    K --> L[Toast succès]
Code de Création

// Callback après création réussie
const handleClientCreated = async (clientId: string) => {
  // ÉTAPE 1 : Rafraîchir la liste des clients
  await refreshClients();

  // ÉTAPE 2 : Sélectionner automatiquement le nouveau client
  setSelectedClientId(clientId);

  // ÉTAPE 3 : Notification
  toast({
    title: "Succès",
    description: "Le client a été créé et sélectionné automatiquement."
  });
};
Insertion en Base de Données

// Dans CreateClientModal.tsx (lignes 138-145)
const { data, error } = await supabase
  .from('clients')
  .insert([{
    ...formData, // Données du formulaire
    user_id: user.id // ID de l'utilisateur connecté
  }])
  .select()
  .single();
Table : clients
Colonnes :

id (uuid, PK, auto-généré)
user_id (uuid, NOT NULL, FK vers auth.users)
nom (text, NOT NULL)
prenom (text, nullable)
client_type_id (uuid, NOT NULL, FK vers client_types)
adresse (text, nullable)
code_postal (text, nullable)
ville (text, nullable)
tel1 (text, nullable)
tel2 (text, nullable)
email (text, nullable)
infos_complementaires (text, nullable)
autre_info (text, nullable)
created_at (timestamp, default: now())
📊 Diagramme de Flux Complet

graph TD
    A[Page Projet chargée] --> B{ProjectContext existe?}
    B -->|Non| C[Initialiser projet vide]
    B -->|Oui| D[Charger état global]

    D --> E[Synchronisation useProjectForm]
    E --> F[États locaux initialisés]

    F --> G[Utilisateur clique sur<br/>'Générer N° Devis']
    G --> H[handleGenerateQuoteNumber]
    H --> I[Query Supabase devis_save]
    I --> J[Calculer nextNumber]
    J --> K[Nouveau numéro: YYMM-N]
    K --> L[setQuoteNumber local]
    L --> M[Dispatch UPDATE_DEVIS_NUMBER]
    M --> N[ProjectContext mis à jour]

    F --> O[Utilisateur clique sur<br/>'Générer Nom']
    O --> P[handleGenerateProjectName]
    P --> Q{Numéro devis existe?}
    Q -->|Non| H
    Q -->|Oui| R[Extraire nom client]
    R --> S[Extraire description]
    S --> T[Assembler nom projet]
    T --> U[setProjectName local]
    U --> V[Dispatch UPDATE_PROJECT_NAME]
    V --> N

    F --> W[Utilisateur sélectionne client]
    W --> X[Utilisateur clique sur<br/>'Ajouter Client']
    X --> Y[handleAddClient]
    Y --> Z[Formater infos client]
    Z --> AA[Append ou remplacer clientDetails]
    AA --> AB[setClientDetails local]
    AB --> AC[useEffect détecte changement]
    AC --> AD[Dispatch UPDATE_METADATA]
    AD --> N

    N --> AE{Utilisateur clique<br/>'Enregistrer'?}
    AE -->|Oui| AF[saveProject service]
    AF --> AG[UPSERT devis_save]
    AG --> AH[Retour données DB]
    AH --> AI[Dispatch SET_PROJECT complet]
    AI --> AJ[isDirty = false]
🔐 Sécurité et Permissions
Row-Level Security (RLS)
Table clients

-- Les utilisateurs ne voient que leurs propres clients
CREATE POLICY "Users can view their own clients"
ON public.clients FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- Les utilisateurs peuvent créer leurs propres clients
CREATE POLICY "Users can create their own clients"
ON public.clients FOR INSERT
WITH CHECK (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));
Table devis_save

-- Les utilisateurs ne voient que leurs propres projets
CREATE POLICY "Users can view their own projects"
ON public.devis_save FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- Les utilisateurs peuvent créer leurs propres projets
CREATE POLICY "Users can create their own projects"
ON public.devis_save FOR INSERT
WITH CHECK (auth.uid() = user_id);
⚠️ Points d'Attention et Bonnes Pratiques
1. Gestion des Conditions de Course

// Attendre la session utilisateur avant d'effectuer des opérations
const { session, loading: authLoading } = useAuthSession();

if (authLoading) {
  return <div>Chargement...</div>;
}
2. Contrainte d'Unicité du Numéro de Devis
Le numéro de devis est UNIQUE dans la base de données
En cas de conflit (deux utilisateurs génèrent le même numéro simultanément), la base de données rejettera le second
Solution recommandée : Ajouter un mécanisme de retry avec incrémentation
3. Validation des Données Avant Sauvegarde

if (!currentProjectState.company_id ||
    !currentProjectState.client_id ||
    !currentProjectState.devis_number ||
    !currentProjectState.project_name) {
  toast({
    title: 'Sauvegarde impossible',
    description: 'Veuillez renseigner tous les champs obligatoires.',
    variant: 'destructive',
  });
  return null;
}
4. Synchronisation Bidirectionnelle
Local → Global : Via useEffect dans useProjectForm
Global → Local : Via useEffect inverse pour Clara ou autres modifications externes
5. Gestion de l'État isDirty

// Marquer le projet comme modifié à chaque changement
dispatch({ type: ProjectActionType.SET_DIRTY });

// Réinitialiser après sauvegarde réussie
isDirty: false
📚 Résumé des Fichiers Impliqués
Fichier	Rôle	Principales Fonctions
Projet.tsx	Composant UI principal	handleGenerateQuoteNumber(), handleGenerateProjectName(), handleAddClient(), handleCompanyCreated(), handleClientCreated()
useProjectForm.tsx	Hook de synchronisation formulaire	Synchronisation bidirectionnelle états locaux ↔ ProjectContext
useProjectOperations.ts	Hook des opérations de haut niveau	handleSaveProject(), handleLoadProject(), handleNewProject(), versions centralisées de génération
projectSaveService.ts	Service de persistance DB	saveProject(), loadProject(), listProjects(), deleteProject()
CreateClientModal.tsx	Modal de création client	Formulaire de création, validation, insertion DB, callback onClientCreated()
ProjectContext.tsx	Contexte global du projet	Provider, état global ProjectState
projectReducer.ts	Réducteur d'actions	Gestion des actions UPDATE_DEVIS_NUMBER, UPDATE_PROJECT_NAME, UPDATE_METADATA, etc.
useReferenceData.ts	Hook de données de référence	useCompanies(), useClients(), chargement des tables companies, clients, client_types
🎯 Cas d'Usage Complets
Scénario 1 : Création d'un Nouveau Devis
Utilisateur ouvre la page "Projet"
Sélectionne une société
Clique sur "Générer N° Devis" → 2510-1
Sélectionne un type de client
Sélectionne un client existant
Clique sur "Ajouter Client" → Client ajouté dans le textarea
Remplit la description du projet
Clique sur "Générer Nom" → Devis n° 2510-1 - Dupont Jean - Rénovation complète
Remplit les autres champs (adresse chantier, occupants, etc.)
Clique sur "Enregistrer" → Projet sauvegardé en DB avec id auto-généré
Scénario 2 : Création d'un Nouveau Client à la Volée
Utilisateur est sur la page "Projet"
Clique sur "Ajouter Client" (bouton à côté du Select)
Modal CreateClientModal s'ouvre
Remplit le formulaire (nom, prénom, type, adresse, etc.)
Clique sur "Créer le client"
Client inséré dans la table clients avec user_id de l'utilisateur connecté
Modal se ferme automatiquement
refreshClients() est appelé pour recharger la liste
Le nouveau client est automatiquement sélectionné dans le Select
Toast de confirmation affiché
📝 Conclusion
Ces trois actions (Générer N° Devis, Générer Nom, Ajouter Client) sont au cœur du workflow de création de devis dans BâtiPilot IAssist. Elles orchestrent :

La génération automatique de numéros uniques
La composition intelligente de noms de projets
La gestion multi-clients avec formatage lisible
La synchronisation temps réel entre UI, mémoire et base de données
La création dynamique de clients sans quitter le formulaire
Toutes ces opérations respectent les politiques RLS de Supabase, garantissant que chaque utilisateur ne voit et ne manipule que ses propres données (sauf administrateurs).

📅 Document créé le : 29 Octobre 2025
📝 Version : 1.0
🔄 Dernière mise à jour : 29 Octobre 2025