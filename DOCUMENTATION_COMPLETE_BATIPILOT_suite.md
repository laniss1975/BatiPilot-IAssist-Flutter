# Documentation Complète - BâtiPilot IAssist (Partie 2)

**Suite de la documentation - Modules Facturation, Comptabilité, PDF et Fonctionnalités Avancées**

---

## 11. Module Facturation

### 11.1 Vue d'Ensemble

Le module Facturation permet de créer différents types de factures à partir d'un devis accepté :

- **Facture d'Acompte** : Facturation partielle initiale
- **Facture de Situation** : Facturation progressive des travaux réalisés
- **Facture de Solde** : Facturation finale du montant restant

### 11.2 Système de Numérotation

```typescript
// Numérotation annuelle: YYYY-NNNN (ex: 2025-0001)
// Numérotation mensuelle: YYYY-MM-NNNN (ex: 2025-01-0001)
// Numérotation par projet: séquence interne au projet (1, 2, 3...)
```

### 11.3 Architecture du Module

```
src/features/invoicing/
├── components/
│   ├── InvoiceHeader.tsx           # En-tête facture
│   ├── InvoiceLinesList.tsx        # Liste des lignes
│   ├── DesignationGroup.tsx        # Groupe par pièce
│   ├── InvoiceLineItem.tsx         # Ligne individuelle
│   ├── InvoiceTotals.tsx           # Totaux
│   └── ConfirmSaveInvoiceModal.tsx # Modal confirmation
├── hooks/
│   ├── useInvoiceData.ts           # Orchestration
│   ├── useInvoiceStorage.ts        # Chargement/sauvegarde
│   ├── useInvoiceCalculations.ts   # Calculs
│   ├── useInvoiceExport.ts         # Export données
│   ├── useInvoiceEdit.ts           # Édition
│   └── useInvoiceTypeLogic.ts      # Logique types
└── types/
    └── typography.ts               # Types facture
```

### 11.4 Logique de Facturation Progressive

```typescript
// Pour chaque ligne de travail:
// - Montant Devis HT: 1000€
// - Déjà Facturé: 300€ (30%)
// - Cette Facture: 400€ (40%)
// - Cumulé Facturé: 700€ (70%)
// - Reste à Facturer: 300€ (30%)

interface LigneFactureCalculs {
  // Montants du devis
  moDevisHT: number;
  foDevisHT: number;
  totalHTDevis: number;
  
  // Pourcentages à facturer (0-100)
  moPercentage: number;
  foPercentage: number;
  
  // Cette facture
  moFactureHT: number;
  foFactureHT: number;
  totalHTFacture: number;
  
  // Déjà facturé (factures précédentes)
  moDejaFactureHT: number;
  foDejaFactureHT: number;
  totalDejaFactureHT: number;
  pourcentageDejaFacture: number;
  
  // Cumulé (y compris cette facture)
  moCumulFactureHT: number;
  foCumulFactureHT: number;
  totalCumulFactureHT: number;
  pourcentageCumulFacture: number;
}
```

### 11.5 Hook Principal `useInvoiceData`

```typescript
export function useInvoiceData(devisId: string) {
  const { projectState, loadProject } = useInvoiceStorage(devisId);
  const calculations = useInvoiceCalculations(projectState);
  const { prepareInvoiceData } = useInvoiceExport(projectState, calculations);
  
  return {
    projectState,
    isLoading: !projectState,
    ...calculations,
    saveInvoice: async (headerData: InvoiceHeader) => {
      const invoiceData = prepareInvoiceData(headerData);
      await saveInvoiceToDatabase(invoiceData);
    }
  };
}
```

---

## 12. Module Comptabilité

### 12.1 Fonctionnalités

- Import CSV de transactions bancaires
- Catégorisation automatique avec règles
- Gestion des catégories (recettes/dépenses)
- Calcul d'indicateurs financiers
- Visualisation graphique
- Export des données

### 12.2 Import CSV avec Détection de Doublons

```typescript
export function useCsvImport() {
  const [duplicates, setDuplicates] = useState<Transaction[]>([]);
  
  const detectDuplicates = async (newTransactions: Transaction[]) => {
    const { data: existing } = await supabase
      .from('transactions_comptables')
      .select('*')
      .in('date_transaction', newTransactions.map(t => t.date_transaction));
    
    const duplicates = newTransactions.filter(newTx =>
      existing?.some(existingTx =>
        existingTx.date_transaction === newTx.date_transaction &&
        existingTx.montant === newTx.montant &&
        existingTx.description === newTx.description
      )
    );
    
    return duplicates;
  };
  
  return { detectDuplicates, duplicates };
}
```

---

## 13. Génération de PDF

### 13.1 Architecture PDF

```
src/services/pdf/
├── react-pdf/
│   ├── DevisDocument.tsx          # Document devis complet
│   ├── InvoiceDocument.tsx        # Document facture
│   └── components/
│       ├── CoverPage.tsx          # Page de garde
│       ├── DetailsPage.tsx        # Page détails
│       ├── RecapPage.tsx          # Page récap
│       ├── InvoicePage.tsx        # Page facture
│       └── common/
│           ├── PageHeader.tsx
│           ├── PageFooter.tsx
│           └── VerticalSpacer.tsx
├── hooks/
│   ├── usePdfSettings.ts          # Paramètres PDF
│   └── useReactPdfGeneration.tsx  # Génération
└── config/
    └── pdfSettingsTypes.ts        # Types paramètres
```

### 13.2 Personnalisation PDF

```typescript
interface PdfSettings {
  fontFamily: string;
  colors: {
    mainText: string;
    detailsText: string;
    coverLines: string;
    detailsLines: string;
    background: string;
  };
  margins: {
    cover: [number, number, number, number];
    details: [number, number, number, number];
    recap: [number, number, number, number];
  };
  logoSettings: {
    useDefaultLogo: boolean;
    logoUrl: string | null;
    width: number;
    height: number;
    alignment: 'left' | 'center' | 'right';
  };
  printOptions: {
    includeCGV: boolean;
  };
}
```

---

## 14. Import et Export de Données

### 14.1 Import CSV Devis

L'application peut importer des devis depuis des fichiers CSV avec l'assistant IA :

- Reconnaissance automatique des colonnes
- Création automatique des pièces et travaux
- Suggestion de services correspondants
- Validation avant import

### 14.2 Import PDF

- Parsing de PDF via pdfjs-dist
- Extraction de texte
- Analyse par IA pour structuration
- Création du projet

---

## 15. Assistant IA et Automatisation

### 15.1 Modules IA

- **Clara** : Assistant conversationnel principal
- **Document Import AI** : Import intelligent de documents
- **Auto-Categorize** : Catégorisation automatique transactions
- **Gmail Assistant** : Lecture et analyse emails

### 15.2 Signaux IA

```typescript
interface AiSignal {
  type: 'contextUpdate' | 'navigationSignal' | 'actionButtons';
  data: any;
}

// Exemple contextUpdate
{
  type: 'contextUpdate',
  data: {
    project_name: "Rénovation appartement",
    company_id: "uuid-...",
    designations: [...]
  }
}
```

---

## 16. Gestion des Utilisateurs et Permissions

### 16.1 Rôles

```sql
CREATE TYPE app_role AS ENUM ('admin', 'user');
```

### 16.2 RLS Policies

Toutes les tables utilisent Row Level Security pour garantir que :
- Les utilisateurs ne voient que leurs propres données
- Les admins ont accès à tout
- Les données de référence admin sont visibles par tous

---

## 17. Hooks Personnalisés - Référence Complète

### 17.1 Hooks Projet
- `useProject()` : Accès au contexte projet
- `useProjectOperations()` : Sauvegarder/charger/réinitialiser
- `useProjectForm()` : Formulaire métadonnées projet

### 17.2 Hooks Bien
- `useDesignationForm()` : Formulaire pièce
- `useDesignationHandlers()` : Handlers CRUD pièces
- `useCalculatedValues()` : Calculs surfaces
- `usePropertyForm()` : Formulaire bien

### 17.3 Hooks Facturation
- `useInvoiceData()` : Orchestration facture
- `useInvoiceStorage()` : Chargement/localStorage
- `useInvoiceCalculations()` : Calculs montants
- `useInvoiceExport()` : Export données
- `useInvoiceTypeLogic()` : Logique types facture

### 17.4 Hooks IA
- `useAiPromptSuggestions()` : Suggestions prompts
- `useAiServiceSuggestions()` : Suggestions services
- `useAiSignals()` : Gestion signaux Clara

---

## 18. Composants Clés

### 18.1 Composants ShadCN/UI

L'application utilise les composants ShadCN configurés dans `src/components/ui/` :

- `Button`, `Input`, `Select`, `Textarea`
- `Card`, `Table`, `Sheet`, `Dialog`
- `Tabs`, `Accordion`, `Separator`
- `Toast` (via Sonner)

### 18.2 Composants Métier

- **Bien** : `PropertyForm`, `DesignationForm`, `MenuiserieList`, `AutreSurfaceList`
- **Travaux** : `AddTravauxSheet`, `ServiceSelectors`, `TravauxFormFields`
- **Facturation** : `InvoiceHeader`, `InvoiceLineItem`, `InvoiceTotals`

---

## 19. Services et Utilitaires

### 19.1 Services API

```typescript
// src/services/projectSaveService.ts
export async function saveProject(projectState: ProjectState): Promise<void>
export async function loadProject(projectId: string): Promise<ProjectState>

// src/services/invoice/invoiceSaveService.ts
export async function saveInvoice(invoiceData: InvoiceData): Promise<string>

// src/services/referenceDataService.ts
export async function fetchServices(): Promise<Service[]>
export async function createService(service: Service): Promise<string>
```

### 19.2 Utilitaires de Calcul

```typescript
// src/utils/calculationsUtil.ts
export function calculerSurfaceSol(l: number, w: number): number
export function calculerSurfacesNettes(...): CalculatedValues
export function calculerSurfacesMenuiseries(...): {...}
```

### 19.3 Utilitaires de Formatage

```typescript
// Formatage devise
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'EUR'
  }).format(amount);
}

// Formatage date
export function formatDate(dateString: string): string {
  return format(new Date(dateString), 'dd/MM/yyyy', { locale: fr });
}
```

---

## 20. Bonnes Pratiques et Conventions

### 20.1 Conventions de Code

1. **Nommage** :
   - Components : PascalCase
   - Hooks : camelCase avec préfixe `use`
   - Constants : UPPER_SNAKE_CASE
   - Types : PascalCase

2. **Organisation** :
   - 1 composant = 1 fichier
   - Hooks groupés par fonctionnalité
   - Services séparés de la logique métier

3. **TypeScript** :
   - Typage strict
   - Interfaces pour objets complexes
   - Union types pour énumérations
   - Pas de `any`

### 20.2 Performance

1. **useMemo** pour calculs coûteux
2. **useCallback** pour handlers
3. **React.memo** pour composants purs
4. Lazy loading des composants volumineux

### 20.3 Tests

Recommandations pour les tests :
- Tests unitaires des fonctions de calcul
- Tests d'intégration des hooks
- Tests E2E des flux critiques (création devis, facturation)

---

## Conclusion

Cette documentation couvre l'ensemble de l'architecture et des fonctionnalités de **BâtiPilot IAssist**. Pour toute question ou contribution, référez-vous aux fichiers de documentation dans `src/documentation/`.

**Ressources supplémentaires** :
- `CONTEXTE_ASSISTANT_DEVIS.md` : Guide IA
- `GUIDE_IMPORT_CSV_DEVIS_V4.md` : Guide import CSV
- `src/documentation/*.md` : Registres détaillés

**Version** : 1.0  
**Dernière mise à jour** : 27 Octobre 2025
