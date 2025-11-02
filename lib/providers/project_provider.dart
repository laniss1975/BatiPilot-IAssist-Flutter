import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/project_model.dart';
import 'package:test1/providers/user_settings_provider.dart';
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
}

final projectProvider = StateNotifierProvider<ProjectNotifier, Project>((ref) {
  // On s'assure que le projectProvider attend que les userSettings soient chargés
  ref.watch(userSettingsProvider); 
  return ProjectNotifier(ref);
});
