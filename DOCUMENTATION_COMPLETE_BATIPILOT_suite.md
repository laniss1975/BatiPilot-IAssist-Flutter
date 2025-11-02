# Documentation Complète - BâtiPilot IAssist (Partie 2)

**Suite de la documentation**

---
### 8.5 Hook `useDesignationForm`

```tsx
// src/hooks/useDesignationForm.tsx
export function useDesignationForm() {
  // États pour chaque champ
  const [id, setId] = useState<string>('');
  const [name, setName] = useState<string>('');
  const [type, setType] = useState<string>('');
  const [numero, setNumero] = useState<number | undefined>();
  
  // Dimensions
  const [longueur, setLongueur] = useState<number>(4);
  const [largeur, setLargeur] = useState<number>(3);
  const [hauteur, setHauteur] = useState<number>(2.5);
  const [profondeur, setProfondeur] = useState<number>(1);
  
  // Cases à cocher
  const [useLongueur, setUseLongueur] = useState<boolean>(true);
  const [useLargeur, setUseLargeur] = useState<boolean>(true);
  const [useHauteur, setUseHauteur] = useState<boolean>(false);
  const [useProfondeur, setUseProfondeur] = useState<boolean>(false);
  const [useLineaire, setUseLineaire] = useState<boolean>(false);
  const [usePlinthes, setUsePlinthes] = useState<boolean>(false);
  
  // Menuiseries et autres surfaces
  const [menuiseries, setMenuiseries] = useState<MenuiserieInstance[]>([]);
  const [autresSurfaces, setAutresSurfaces] = useState<AutreSurfaceInstance[]>([]);
  
  /**
   * Règles d'interdépendance des champs
   */
  const handleCheckboxChange = (field: string, value: boolean) => {
    switch (field) {
      case 'useProfondeur':
        if (value) {
          // Si profondeur est cochée, désactiver hauteur et plinthes
          setUseProfondeur(true);
          setUseHauteur(false);
          setUsePlinthes(false);
        } else {
          setUseProfondeur(false);
        }
        break;
      
      case 'useHauteur':
        if (!value) {
          // Si hauteur est décochée, désactiver plinthes
          setUseHauteur(false);
          setUsePlinthes(false);
        } else {
          setUseHauteur(true);
        }
        break;
      
      case 'useLineaire':
        if (value) {
          // Si linéaire est coché, désactiver tous les autres
          setUseLineaire(true);
          setUseLongueur(false);
          setUseLargeur(false);
          setUseHauteur(false);
          setUseProfondeur(false);
          setUsePlinthes(false);
        } else {
          setUseLineaire(false);
        }
        break;
      
      case 'usePlinthes':
        setUsePlinthes(value);
        break;
      
      default:
        break;
    }
  };
  
  /**
   * Charge une désignation existante pour édition
   */
  const loadDesignationForEdit = (designation: Designation) => {
    setId(designation.id);
    setName(designation.name);
    setType(designation.type || '');
    setNumero(designation.numero);
    
    setLongueur(designation.longueur || 4);
    setLargeur(designation.largeur || 3);
    setHauteur(designation.hauteur || 2.5);
    setProfondeur(designation.profondeur || 1);
    
    setUseLongueur(designation.useLongueur || false);
    setUseLargeur(designation.useLargeur || false);
    setUseHauteur(designation.useHauteur || false);
    setUseProfondeur(designation.useProfondeur || false);
    setUseLineaire(designation.useLineaire || false);
    setUsePlinthes(designation.usePlinthes || false);
    
    setMenuiseries(designation.menuiseries || []);
    setAutresSurfaces(designation.autresSurfaces || []);
  };
  
  /**
   * Réinitialise le formulaire
   */
  const resetForm = () => {
    setId('');
    setName('');
    setType('');
    setNumero(undefined);
    setLongueur(4);
    setLargeur(3);
    setHauteur(2.5);
    setProfondeur(1);
    setUseLongueur(true);
    setUseLargeur(true);
    setUseHauteur(false);
    setUseProfondeur(false);
    setUseLineaire(false);
    setUsePlinthes(false);
    setMenuiseries([]);
    setAutresSurfaces([]);
  };
  
  /**
   * Retourne les données du formulaire
   */
  const getData = (): Designation => {
    return {
      id: id || uuid(),
      name,
      type,
      numero,
      longueur: useLongueur ? longueur : null,
      largeur: useLargeur ? largeur : null,
      hauteur: useHauteur ? hauteur : null,
      profondeur: useProfondeur ? profondeur : null,
      useLongueur,
      useLargeur,
      useHauteur,
      useProfondeur,
      useLineaire,
      usePlinthes,
      menuiseries,
      autresSurfaces,
      // Surfaces calculées automatiquement par le hook useCalculatedValues
      surfaceSol: null,
      surfacePlafond: null,
      surfaceMurale: null,
      surfaceGenerique: null,
      perimeter: null,
      lineairePlinthe: null,
      valeurLineaire: null,
      calculatedValues: null
    };
  };
  
  return {
    id, name, setName,
    type, setType,
    numero, setNumero,
    longueur, setLongueur,
    largeur, setLargeur,
    hauteur, setHauteur,
    profondeur, setProfondeur,
    useLongueur, setUseLongueur: (v: boolean) => handleCheckboxChange('useLongueur', v),
    useLargeur, setUseLargeur: (v: boolean) => handleCheckboxChange('useLargeur', v),
    useHauteur, setUseHauteur: (v: boolean) => handleCheckboxChange('useHauteur', v),
    useProfondeur, setUseProfondeur: (v: boolean) => handleCheckboxChange('useProfondeur', v),
    useLineaire, setUseLineaire: (v: boolean) => handleCheckboxChange('useLineaire', v),
    usePlinthes, setUsePlinthes: (v: boolean) => handleCheckboxChange('usePlinthes', v),
    menuiseries, setMenuiseries,
    autresSurfaces, setAutresSurfaces,
    loadDesignationForEdit,
    resetForm,
    getData
  };
}
```

### 8.6 Hook `useCalculatedValues`

```tsx
// src/hooks/useCalculatedValues.tsx
export function useCalculatedValues(designation: Designation | null) {
  const { menuiseriesTypes, autresSurfacesTypes } = useReferenceData();
  const [calculatedValues, setCalculatedValues] = useState<CalculatedValues | null>(null);
  
  useEffect(() => {
    if (!designation) {
      setCalculatedValues(null);
      return;
    }
    
    // Calcul des surfaces brutes
    const surfaceSol = designation.useLongueur && designation.useLargeur && designation.longueur && designation.largeur
      ? calculerSurfaceSol(designation.longueur, designation.largeur)
      : null;
    
    const surfacePlafond = designation.useLongueur && designation.useLargeur && designation.longueur && designation.largeur
      ? calculerSurfacePlafond(designation.longueur, designation.largeur)
      : null;
    
    const surfaceMurale = designation.useLongueur && designation.useLargeur && designation.useHauteur && designation.longueur && designation.largeur && designation.hauteur
      ? calculerSurfaceMurale(designation.longueur, designation.largeur, designation.hauteur)
      : null;
    
    const lineairePlinthe = designation.useLongueur && designation.useLargeur && designation.usePlinthes && designation.longueur && designation.largeur
      ? calculerLineairePlinthe(designation.longueur, designation.largeur)
      : null;
    
    // Calcul surfaces nettes
    const nettes = calculerSurfacesNettes(
      { ...designation, surfaceSol, surfacePlafond, surfaceMurale, lineairePlinthe },
      menuiseriesTypes,
      autresSurfacesTypes
    );
    
    setCalculatedValues(nettes);
  }, [
    designation,
    menuiseriesTypes,
    autresSurfacesTypes
  ]);
  
  return calculatedValues;
}
```

---

## 9. Module Travaux et Services

### 9.1 Vue d'Ensemble

Le module Travaux permet de :
- Associer des **prestations de travaux** à chaque pièce
- Sélectionner des services depuis une base de données hiérarchisée (Type de travaux → Groupe de services → Service)
- Calculer automatiquement les **quantités** en fonction des surfaces disponibles
- Définir les prix main d'œuvre et fourniture
- Calculer les totaux HT, TVA et TTC

### 9.2 Hiérarchie des Services

```mermaid
graph TD
    A[Type de Travaux] --> B[Groupe de Services]
    B --> C[Service]
    
    A1[Peinture] --> B1[Peinture Intérieure]
    A1 --> B2[Peinture Extérieure]
    
    B1 --> C1[Peinture murs acrylique]
    B1 --> C2[Peinture plafond]
    
    B2 --> C3[Ravalement façade]
```

**Exemple concret :**

- **Type de travaux** : "Peinture"
- **Groupe de services** : "Peinture Intérieure"
- **Service** : "Peinture murs acrylique - 2 couches"
  - Prix main d'œuvre : 15 €/m²
  - Prix fourniture : 5 €/m²
  - Unité : M²
  - Surface impactée : Mur

### 9.3 Page Travaux (`src/pages/Travaux.tsx`)

```tsx
export default function Travaux() {
  const { projectState, dispatch } = useProject();
  const [selectedDesignationId, setSelectedDesignationId] = useState<string | null>(null);
  const [isAddSheetOpen, setIsAddSheetOpen] = useState<boolean>(false);
  
  // Données de référence
  const { 
    workTypes, 
    serviceGroups, 
    services,
    loadingWorkTypes,
    loadingServiceGroups,
    loadingServices
  } = useReferenceData();
  
  const selectedDesignation = projectState.project_data.designations.find(
    d => d.id === selectedDesignationId
  );
  
  // Filtrer les travaux de la désignation sélectionnée
  const travauxOfDesignation = projectState.project_data.travaux.filter(
    t => t.designationId === selectedDesignationId
  );
  
  // Handler pour ajouter un travail
  const handleAddTravail = (travail: Travail) => {
    dispatch({ type: ProjectActionType.ADD_TRAVAIL, payload: travail });
    setIsAddSheetOpen(false);
    toast({ title: "Succès", description: "Prestation ajoutée" });
  };
  
  return (
    <div className="container mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">Travaux</h1>
      
      {/* Liste des pièces */}
      <DesignationList 
        designations={projectState.project_data.designations}
        selectedDesignationId={selectedDesignationId}
        setSelectedDesignationId={setSelectedDesignationId}
      />
      
      {/* Détails de la pièce sélectionnée */}
      {selectedDesignation && (
        <>
          <DesignationDetails designation={selectedDesignation} />
          
          {/* Liste des travaux de cette pièce */}
          <Card className="mt-6">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle>Prestations de {selectedDesignation.name}</CardTitle>
              <Button onClick={() => setIsAddSheetOpen(true)}>
                <Plus className="mr-2 h-4 w-4" />
                Ajouter une prestation
              </Button>
            </CardHeader>
            <CardContent>
              {travauxOfDesignation.length === 0 ? (
                <p className="text-muted-foreground text-center py-8">
                  Aucune prestation pour cette pièce
                </p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Prestation</TableHead>
                      <TableHead>Quantité</TableHead>
                      <TableHead>Prix MO</TableHead>
                      <TableHead>Prix FO</TableHead>
                      <TableHead>Total HT</TableHead>
                      <TableHead>Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {travauxOfDesignation.map(travail => (
                      <TableRow key={travail.id}>
                        <TableCell>
                          <div>
                            <div className="font-medium">{travail.titre}</div>
                            <div className="text-sm text-muted-foreground">
                              {travail.description}
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          {travail.quantite} {travail.unit}
                        </TableCell>
                        <TableCell>
                          {formatCurrency(travail.totalMainOeuvreHT)}
                        </TableCell>
                        <TableCell>
                          {formatCurrency(travail.totalFournitureHT)}
                        </TableCell>
                        <TableCell className="font-semibold">
                          {formatCurrency(travail.totalHT)}
                        </TableCell>
                        <TableCell>
                          <Button 
                            variant="ghost" 
                            size="sm"
                            onClick={() => handleDeleteTravail(travail.id)}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </>
      )}
      
      {/* Sheet pour ajouter une prestation */}
      <AddTravauxSheet
        open={isAddSheetOpen}
        onOpenChange={setIsAddSheetOpen}
        designation={selectedDesignation}
        workTypes={workTypes}
        serviceGroups={serviceGroups}
        services={services}
        onAddTravail={handleAddTravail}
      />
    </div>
  );
}
```

### 9.4 Composant `AddTravauxSheet`

```tsx
// src/components/travaux/AddTravauxSheet.tsx
interface AddTravauxSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  designation: Designation | null;
  workTypes: WorkType[];
  serviceGroups: ServiceGroup[];
  services: Service[];
  onAddTravail: (travail: Travail) => void;
}

export function AddTravauxSheet({
  open,
  onOpenChange,
  designation,
  workTypes,
  serviceGroups,
  services,
  onAddTravail
}: AddTravauxSheetProps) {
  // État du formulaire
  const [selectedWorkTypeId, setSelectedWorkTypeId] = useState<string>('');
  const [selectedServiceGroupId, setSelectedServiceGroupId] = useState<string>('');
  const [selectedServiceId, setSelectedServiceId] = useState<string>('');
  const [titre, setTitre] = useState<string>('');
  const [description, setDescription] = useState<string>('');
  const [quantite, setQuantite] = useState<number>(0);
  const [unit, setUnit] = useState<UnitEnum>('M²');
  const [prixMainOeuvre, setPrixMainOeuvre] = useState<number>(0);
  const [prixFourniture, setPrixFourniture] = useState<number>(0);
  const [tauxTVA, setTauxTVA] = useState<number>(20);
  const [destinataire, setDestinataire] = useState<string>('Pièce');
  
  // Filtrage des groupes en fonction du type sélectionné
  const filteredServiceGroups = serviceGroups.filter(
    g => g.work_type_id === selectedWorkTypeId
  );
  
  // Filtrage des services en fonction du groupe sélectionné
  const filteredServices = services.filter(
    s => s.group_id === selectedServiceGroupId
  );
  
  // Service sélectionné
  const selectedService = services.find(s => s.id === selectedServiceId);
  
  // Pré-remplissage automatique lors de la sélection d'un service
  useEffect(() => {
    if (selectedService) {
      setTitre(selectedService.name);
      setDescription(selectedService.description || '');
      setUnit(selectedService.unit);
      setPrixMainOeuvre(selectedService.labor_price);
      setPrixFourniture(selectedService.supply_price);
      
      // Proposition quantité basée sur la surface correspondante
      if (designation) {
        const surfaceCorrespondante = getSurfaceCorrespondante(
          designation,
          selectedService.surface_impactee
        );
        if (surfaceCorrespondante) {
          setQuantite(surfaceCorrespondante);
        }
      }
    }
  }, [selectedService, designation]);
  
  // Calculs automatiques
  const totalMainOeuvreHT = quantite * prixMainOeuvre;
  const totalFournitureHT = quantite * prixFourniture;
  const totalHT = totalMainOeuvreHT + totalFournitureHT;
  const totalTVA = totalHT * (tauxTVA / 100);
  const totalTTC = totalHT + totalTVA;
  
  // Handler pour ajouter
  const handleAdd = () => {
    if (!selectedService || !designation) return;
    
    const newTravail: Travail = {
      id: uuid(),
      designationId: designation.id,
      serviceId: selectedService.id,
      serviceName: selectedService.name,
      serviceDescription: selectedService.description || '',
      workTypeId: selectedWorkTypeId,
      workTypeName: workTypes.find(w => w.id === selectedWorkTypeId)?.name || '',
      serviceGroupId: selectedServiceGroupId,
      serviceGroupName: serviceGroups.find(g => g.id === selectedServiceGroupId)?.name || '',
      titre,
      description,
      quantite,
      unit,
      prixMainOeuvre,
      prixFourniture,
      tauxTVA,
      totalMainOeuvreHT,
      totalFournitureHT,
      totalHT,
      totalTVA,
      totalTTC,
      surfaceImpactee: selectedService.surface_impactee,
      destinataire,
      created_at: new Date().toISOString()
    };
    
    onAddTravail(newTravail);
  };
  
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-2xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>
            Ajouter une prestation à {designation?.name}
          </SheetTitle>
        </SheetHeader>
        
        <div className="space-y-6 py-6">
          {/* Sélection hiérarchique des services */}
          <ServiceSelectors
            workTypes={workTypes}
            serviceGroups={filteredServiceGroups}
            services={filteredServices}
            selectedWorkTypeId={selectedWorkTypeId}
            selectedServiceGroupId={selectedServiceGroupId}
            selectedServiceId={selectedServiceId}
            onWorkTypeChange={setSelectedWorkTypeId}
            onServiceGroupChange={setSelectedServiceGroupId}
            onServiceChange={setSelectedServiceId}
          />
          
          <Separator />
          
          {/* Formulaire de détails */}
          <TravauxFormFields
            titre={titre}
            setTitre={setTitre}
            description={description}
            setDescription={setDescription}
            quantite={quantite}
            setQuantite={setQuantite}
            unit={unit}
            setUnit={setUnit}
            prixMainOeuvre={prixMainOeuvre}
            setPrixMainOeuvre={setPrixMainOeuvre}
            prixFourniture={prixFourniture}
            setPrixFourniture={setPrixFourniture}
            tauxTVA={tauxTVA}
            setTauxTVA={setTauxTVA}
            destinataire={destinataire}
            setDestinataire={setDestinataire}
          />
          
          {/* Dimensions disponibles */}
          {designation && (
            <DimensionsDisponibles 
              designation={designation}
              onSelectDimension={(value, unit) => {
                setQuantite(value);
                setUnit(unit);
              }}
            />
          )}
          
          {/* Résumé des totaux */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Totaux</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between">
                <span>Main d'œuvre HT:</span>
                <span className="font-semibold">{formatCurrency(totalMainOeuvreHT)}</span>
              </div>
              <div className="flex justify-between">
                <span>Fourniture HT:</span>
                <span className="font-semibold">{formatCurrency(totalFournitureHT)}</span>
              </div>
              <Separator />
              <div className="flex justify-between">
                <span>Total HT:</span>
                <span className="font-semibold">{formatCurrency(totalHT)}</span>
              </div>
              <div className="flex justify-between">
                <span>TVA ({tauxTVA}%):</span>
                <span className="font-semibold">{formatCurrency(totalTVA)}</span>
              </div>
              <Separator />
              <div className="flex justify-between text-lg">
                <span className="font-bold">Total TTC:</span>
                <span className="font-bold">{formatCurrency(totalTTC)}</span>
              </div>
            </CardContent>
          </Card>
        </div>
        
        <SheetFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button onClick={handleAdd} disabled={!selectedService}>
            Ajouter la prestation
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
```

### 9.5 Composant `DimensionsDisponibles`

```tsx
// Composant pour afficher et sélectionner les dimensions calculées
interface DimensionsDisponiblesProps {
  designation: Designation;
  onSelectDimension: (value: number, unit: UnitEnum) => void;
}

export function DimensionsDisponibles({ 
  designation, 
  onSelectDimension 
}: DimensionsDisponiblesProps) {
  const { calculatedValues } = useCalculatedValues(designation);
  
  const dimensions = [
    { 
      label: 'Surface Sol Nette', 
      value: calculatedValues?.surfaceSolNette, 
      unit: 'M²' as UnitEnum 
    },
    { 
      label: 'Surface Plafond Nette', 
      value: calculatedValues?.surfacePlafondNette, 
      unit: 'M²' as UnitEnum 
    },
    { 
      label: 'Surface Murale Nette', 
      value: calculatedValues?.surfaceMuraleNette, 
      unit: 'M²' as UnitEnum 
    },
    { 
      label: 'Surface Générique Nette', 
      value: calculatedValues?.surfaceGeneriqueNette, 
      unit: 'M²' as UnitEnum 
    },
    { 
      label: 'Linéaire Plinthes Net', 
      value: calculatedValues?.lineairePlintheNet, 
      unit: 'Ml' as UnitEnum 
    },
    { 
      label: 'Surface Plinthes', 
      value: calculatedValues?.surfacePlinthes, 
      unit: 'M²' as UnitEnum 
    },
    { 
      label: 'Valeur Linéaire', 
      value: designation.valeurLineaire, 
      unit: 'Ml' as UnitEnum 
    }
  ].filter(d => d.value !== null && d.value > 0);
  
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm font-medium">
          Dimensions disponibles (cliquez pour utiliser)
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-2">
          {dimensions.map((dim, index) => (
            <Button
              key={index}
              variant="outline"
              className="justify-between"
              onClick={() => onSelectDimension(dim.value!, dim.unit)}
            >
              <span className="text-sm">{dim.label}</span>
              <span className="font-semibold">
                {dim.value!.toFixed(2)} {dim.unit}
              </span>
            </Button>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
```

---

## 10. Module Récapitulatif

### 10.1 Vue d'Ensemble

Le module Récapitulatif affiche :
- **Toutes les prestations** groupées par pièce
- **Totaux par pièce** (HT, TVA, TTC)
- **Totaux généraux du devis**
- **Ventilation par taux de TVA**

### 10.2 Page Récapitulatif (`src/pages/Recapitulatif.tsx`)

```tsx
export default function Recapitulatif() {
  const { projectState } = useProject();
  const { generateDevisPDF } = usePdfGeneration();
  
  // Groupement des travaux par désignation
  const travauxParDesignation = useMemo(() => {
    const grouped: { [designationId: string]: Travail[] } = {};
    
    projectState.project_data.travaux.forEach(travail => {
      if (!grouped[travail.designationId]) {
        grouped[travail.designationId] = [];
      }
      grouped[travail.designationId].push(travail);
    });
    
    return grouped;
  }, [projectState.project_data.travaux]);
  
  // Calcul totaux par désignation
  const calculateDesignationTotals = (travaux: Travail[]) => {
    return {
      totalHT: travaux.reduce((sum, t) => sum + t.totalHT, 0),
      totalTVA: travaux.reduce((sum, t) => sum + t.totalTVA, 0),
      totalTTC: travaux.reduce((sum, t) => sum + t.totalTTC, 0)
    };
  };
  
  // Calcul totaux généraux
  const totauxGeneraux = useMemo(() => {
    const allTravaux = projectState.project_data.travaux;
    return {
      totalHT: allTravaux.reduce((sum, t) => sum + t.totalHT, 0),
      totalTVA: allTravaux.reduce((sum, t) => sum + t.totalTVA, 0),
      totalTTC: allTravaux.reduce((sum, t) => sum + t.totalTTC, 0)
    };
  }, [projectState.project_data.travaux]);
  
  // Ventilation par taux de TVA
  const totauxParTauxTVA = useMemo(() => {
    const ventilation: {
      [taux: string]: {
        totalHT: number;
        totalTVA: number;
        totalTTC: number;
      };
    } = {};
    
    projectState.project_data.travaux.forEach(travail => {
      const taux = travail.tauxTVA.toString();
      if (!ventilation[taux]) {
        ventilation[taux] = { totalHT: 0, totalTVA: 0, totalTTC: 0 };
      }
      ventilation[taux].totalHT += travail.totalHT;
      ventilation[taux].totalTVA += travail.totalTVA;
      ventilation[taux].totalTTC += travail.totalTTC;
    });
    
    return ventilation;
  }, [projectState.project_data.travaux]);
  
  return (
    <div className="container mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Récapitulatif du Devis</h1>
        <Button onClick={generateDevisPDF}>
          <FileText className="mr-2 h-4 w-4" />
          Générer le PDF
        </Button>
      </div>
      
      {/* Informations générales */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Informations Générales</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-muted-foreground">Numéro de devis</p>
            <p className="font-semibold">{projectState.devis_number}</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Date</p>
            <p className="font-semibold">{formatDate(projectState.devis_date)}</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Nom du projet</p>
            <p className="font-semibold">{projectState.project_name}</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Statut</p>
            <StatusBadge status={projectState.status} />
          </div>
        </CardContent>
      </Card>
      
      {/* Détail par pièce */}
      {projectState.project_data.designations.map(designation => {
        const travaux = travauxParDesignation[designation.id] || [];
        if (travaux.length === 0) return null;
        
        const totaux = calculateDesignationTotals(travaux);
        
        return (
          <Card key={designation.id} className="mb-4">
            <CardHeader>
              <CardTitle className="flex justify-between items-center">
                <span>{designation.name}</span>
                <span className="text-primary">
                  {formatCurrency(totaux.totalHT)} HT
                </span>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Prestation</TableHead>
                    <TableHead>Quantité</TableHead>
                    <TableHead className="text-right">Prix MO</TableHead>
                    <TableHead className="text-right">Prix FO</TableHead>
                    <TableHead className="text-right">Total HT</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {travaux.map(travail => (
                    <TableRow key={travail.id}>
                      <TableCell>
                        <div>
                          <div className="font-medium">{travail.titre}</div>
                          {travail.description && (
                            <div className="text-sm text-muted-foreground">
                              {travail.description}
                            </div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {travail.quantite} {travail.unit}
                      </TableCell>
                      <TableCell className="text-right">
                        {formatCurrency(travail.totalMainOeuvreHT)}
                      </TableCell>
                      <TableCell className="text-right">
                        {formatCurrency(travail.totalFournitureHT)}
                      </TableCell>
                      <TableCell className="text-right font-semibold">
                        {formatCurrency(travail.totalHT)}
                      </TableCell>
                    </TableRow>
                  ))}
                  {/* Total de la pièce */}
                  <TableRow className="bg-muted/50">
                    <TableCell colSpan={4} className="text-right font-semibold">
                      Sous-total {designation.name}
                    </TableCell>
                    <TableCell className="text-right font-bold">
                      {formatCurrency(totaux.totalHT)}
                    </TableCell>
                  </TableRow>
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        );
      })}
      
      {/* Totaux généraux */}
      <Card>
        <CardHeader>
          <CardTitle>Totaux Généraux</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Ventilation par taux de TVA */}
          <div>
            <h3 className="font-semibold mb-2">Ventilation par taux de TVA</h3>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Taux TVA</TableHead>
                  <TableHead className="text-right">Total HT</TableHead>
                  <TableHead className="text-right">Montant TVA</TableHead>
                  <TableHead className="text-right">Total TTC</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {Object.entries(totauxParTauxTVA).map(([taux, totaux]) => (
                  <TableRow key={taux}>
                    <TableCell>{taux}%</TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(totaux.totalHT)}
                    </TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(totaux.totalTVA)}
                    </TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(totaux.totalTTC)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          
          <Separator />
          
          {/* Totaux finaux */}
          <div className="space-y-2 text-lg">
            <div className="flex justify-between">
              <span>Total HT:</span>
              <span className="font-semibold">
                {formatCurrency(totauxGeneraux.totalHT)}
              </span>
            </div>
            <div className="flex justify-between">
              <span>Total TVA:</span>
              <span className="font-semibold">
                {formatCurrency(totauxGeneraux.totalTVA)}
              </span>
            </div>
            <Separator />
            <div className="flex justify-between text-2xl">
              <span className="font-bold">Total TTC:</span>
              <span className="font-bold text-primary">
                {formatCurrency(totauxGeneraux.totalTTC)}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

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
