import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Niveau 1 : Les Modules Principaux ---
enum MainModule {
  accueil,
  projets,
  facturations,
  rapports,
  comptabilite,
  parametres,
}

final mainModuleProvider = StateProvider<MainModule>((ref) {
  return MainModule.projets;
});

// --- Niveau 2 : Les Vues par Module ---

// Vues pour le module "Projets"
enum ProjectView {
  details,
  designations,
  travaux,
  recapitulatif,
}

final projectViewProvider = StateProvider<ProjectView>((ref) {
  return ProjectView.details;
});

// Vues pour le module "Paramètres"
enum SettingsView {
  databaseConnection,
  aiControlCenter, // Nouvelle vue
}

final settingsViewProvider = StateProvider<SettingsView>((ref) {
  return SettingsView.databaseConnection;
});
