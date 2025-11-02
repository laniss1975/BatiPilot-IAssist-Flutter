import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/project_model.dart';
import 'package:test1/providers/user_settings_provider.dart';
import 'package:test1/providers/reference_data_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:test1/providers/supabase_connection_provider.dart'; // Import du provider de connexion Supabase


const uuid = Uuid();

class ProjectNotifier extends StateNotifier<Project> {
  final Ref _ref;

  ProjectNotifier(this._ref) : super(_initialProject(_ref));

  static Project _initialProject(Ref ref) {
    // Lire l'état actuel (synchrone) des paramètres utilisateur
    final userSettings = ref.watch(userSettingsProvider).value;

    return Project(
      id: uuid.v4(),
      companyId: userSettings?.selectedCompanyId, // Utiliser l'ID sauvegardé
      projectName: 'Nouveau Projet',
      devisNumber: '',
      devisDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: ProjectMetadata(),
    );
  }
  
  void updateProject({
    String? companyId,
    String? clientId,
    String? projectName,
    String? devisNumber,
    DateTime? devisDate,
    DevisStatus? status,
    String? referenceBonCommande,
    DateTime? dateAcceptation,
  }) {
    // Si l'ID de la société change, on le sauvegarde dans Supabase
    if (companyId != null && companyId != state.companyId) {
      _ref.read(userSettingsProvider.notifier).updateSettings(selectedCompanyId: companyId);
    }

    state = state.copyWith(
      companyId: companyId,
      clientId: clientId,
      projectName: projectName,
      devisNumber: devisNumber,
      devisDate: devisDate,
      status: status,
      referenceBonCommande: referenceBonCommande,
      dateAcceptation: dateAcceptation,
      updatedAt: DateTime.now(),
    );
  }

  void updateMetadata({
    String? descriptionProjet,
    String? clientsData,
    String? adresseChantier,
    String? occupant,
    String? infoComplementaire,
  }) {
    state = state.copyWith(
      metadata: state.metadata.copyWith(
        descriptionProjet: descriptionProjet,
        clientsData: clientsData,
        adresseChantier: adresseChantier,
        occupant: occupant,
        infoComplementaire: infoComplementaire,
      ),
      updatedAt: DateTime.now(),
    );
  }
  
  Future<void> generateDevisNumber() async {
    final supabaseClient = _ref.read(supabaseConnectionProvider).client;

    if (supabaseClient == null) {
      // Gérer le cas où Supabase n'est pas connecté
      print('Erreur: Supabase client non disponible.');
      return;
    }

    try {
      final selectedDate = state.devisDate ?? DateTime.now(); // Utilise devisDate si disponible, sinon la date actuelle
      final yearDigits = selectedDate.year.toString().substring(2);
      final month = selectedDate.month.toString().padLeft(2, '0');
      final prefix = '$yearDigits$month'; // Ex: '2510'

      // Rechercher le dernier numéro avec ce préfixe dans la DB
      final response = await supabaseClient
          .from('devis_save') // Nom de la table dans Supabase
          .select('devis_number')
          .like('devis_number', '$prefix-%') // WHERE devis_number LIKE '2510-%'
          .order('devis_number', ascending: false) // Trier par ordre décroissant
          .limit(1);

      int nextNumber = 1;

      if (response.isNotEmpty) {
        final lastDevisNumber = response[0]['devis_number'] as String;
        final parts = lastDevisNumber.split('-');
        if (parts.length == 2) {
          final lastNumber = int.tryParse(parts[1]);
          if (lastNumber != null) {
            nextNumber = lastNumber + 1;
          }
        }
      }

      final newQuoteNumber = '$prefix-$nextNumber';

      state = state.copyWith(devisNumber: newQuoteNumber, updatedAt: DateTime.now());

      print('Nouveau numéro de devis généré : $newQuoteNumber');
    } catch (e) {
      print('Erreur lors de la génération du numéro de devis : $e');
      // Gérer l'erreur (ex: afficher un message à l'utilisateur)
    }
  }

  Future<void> generateProjectName() async {
    try {
      // 1. Générer le numéro de devis si besoin
      if (state.devisNumber.isEmpty) {
        await generateDevisNumber();
      }

      // 2. Récupérer le NOM du client (priorité: clientsData 2ème ligne)
      String clientName = 'Client à définir';

      if (state.metadata.clientsData.isNotEmpty) {
        // Extraire la 2ème ligne de clientsData
        final lines = state.metadata.clientsData
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.length >= 2) {
          clientName = lines[1].trim(); // 2ème ligne = nom du 1er client
        }
      }
      // Fallback: utiliser clientId si pas de clientsData
      else if (state.clientId != null) {
        try {
          final clients = await _ref.read(clientsProvider.future);
          final client = clients.firstWhere(
            (c) => c.id == state.clientId,
            orElse: () => throw Exception('Client non trouvé'),
          );
          clientName = client.fullName;
        } catch (e) {
          print('Erreur lors de la récupération du client: $e');
          // Garder "Client à définir"
        }
      }

      // 3. Extraire la description (1ère ligne)
      String description = '';
      if (state.metadata.descriptionProjet.isNotEmpty) {
        description = state.metadata.descriptionProjet.split('\n').first.trim();
      }

      // 4. Assembler le nom du projet
      final generatedName = 'Devis n° ${state.devisNumber} - $clientName${description.isNotEmpty ? ' - $description' : ''}';

      // 5. Mettre à jour l'état
      state = state.copyWith(projectName: generatedName, updatedAt: DateTime.now());

      print('Nom du projet généré : $generatedName');
    } catch (e) {
      print('Erreur lors de la génération du nom du projet : $e');
    }
  }

  Future<void> addClientToList() async {
    // Vérifier qu'un client est sélectionné
    if (state.clientId == null) {
      print('Aucun client sélectionné');
      return;
    }

    try {
      // Récupérer le client depuis le provider
      final clients = await _ref.read(clientsProvider.future);
      final client = clients.firstWhere(
        (c) => c.id == state.clientId,
        orElse: () => throw Exception('Client non trouvé'),
      );

      // Formater le client au format attendu
      // Ligne 1: Type de client
      // Ligne 2: Nom complet du client
      // Ligne 3: Adresse complète

      // Récupérer le type de client
      String clientType = 'Type non défini';
      if (client.clientTypeId != null) {
        try {
          final clientTypes = await _ref.read(clientTypesProvider.future);
          final type = clientTypes.firstWhere(
            (ct) => ct.id == client.clientTypeId,
            orElse: () => throw Exception('Type non trouvé'),
          );
          clientType = type.name;
        } catch (e) {
          print('Erreur lors de la récupération du type de client: $e');
          // Garder "Type non défini"
        }
      }

      final addressParts = [
        client.adresse,
        '${client.codePostal ?? ''} ${client.ville ?? ''}'.trim()
      ].where((s) => s != null && s.isNotEmpty).join(' - ');

      final formattedClient = '$clientType\n${client.fullName}\n${addressParts.isNotEmpty ? addressParts : 'Adresse non renseignée'}\n\n';

      // Ajouter au clientsData existant
      final updatedClientsData = state.metadata.clientsData + formattedClient;

      // Mettre à jour l'état
      state = state.copyWith(
        metadata: state.metadata.copyWith(clientsData: updatedClientsData),
        updatedAt: DateTime.now(),
      );

      print('Client ajouté à la liste : ${client.fullName}');
    } catch (e) {
      print('Erreur lors de l\'ajout du client à la liste : $e');
    }
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, Project>((ref) {
  // On s'assure que le projectProvider attend que les userSettings soient chargés
  ref.watch(userSettingsProvider); 
  return ProjectNotifier(ref);
});
