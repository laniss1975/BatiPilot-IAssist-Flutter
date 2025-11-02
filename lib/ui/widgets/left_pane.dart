import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/ui/providers/ui_providers.dart';
import 'package:test1/ui/views/ai_control_center_view.dart';
import 'package:test1/ui/views/database_connection_view.dart';
import 'package:test1/ui/views/project_details_view.dart';

class LeftPane extends ConsumerWidget {
  const LeftPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(mainModuleProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[100],
        elevation: 0,
        title: _buildModuleSelector(context, ref),
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          Container(
            width: 180,
            color: Colors.blueGrey[50],
            padding: const EdgeInsets.all(8.0),
            child: _buildSideNavigation(activeModule, ref),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildContentView(activeModule, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSelector(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(mainModuleProvider);
    return DropdownButton<MainModule>(
      value: activeModule,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blueGrey[800]),
      underline: Container(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.blueGrey),
      onChanged: (newModule) {
        if (newModule != null) {
          ref.read(mainModuleProvider.notifier).state = newModule;
          if (newModule == MainModule.projets) {
            ref.read(projectViewProvider.notifier).state = ProjectView.details;
          } else if (newModule == MainModule.parametres) {
            ref.read(settingsViewProvider.notifier).state = SettingsView.databaseConnection;
          }
        }
      },
      items: MainModule.values.map((module) {
        return DropdownMenuItem<MainModule>(value: module, child: Text(_getModuleName(module)));
      }).toList(),
    );
  }

  Widget _buildSideNavigation(MainModule module, WidgetRef ref) {
    switch (module) {
      case MainModule.projets:
        final activeView = ref.watch(projectViewProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavigationButton(label: 'Détails du projet', icon: Icons.article_outlined, isSelected: activeView == ProjectView.details, onPressed: () => ref.read(projectViewProvider.notifier).state = ProjectView.details),
            const SizedBox(height: 8),
            _NavigationButton(label: 'Désignations', icon: Icons.layers_outlined, isSelected: activeView == ProjectView.designations, onPressed: () => ref.read(projectViewProvider.notifier).state = ProjectView.designations),
             const SizedBox(height: 8),
            _NavigationButton(label: 'Travaux', icon: Icons.construction_outlined, isSelected: activeView == ProjectView.travaux, onPressed: () => ref.read(projectViewProvider.notifier).state = ProjectView.travaux),
            const SizedBox(height: 8),
            _NavigationButton(label: 'Récapitulatif', icon: Icons.receipt_long_outlined, isSelected: activeView == ProjectView.recapitulatif, onPressed: () => ref.read(projectViewProvider.notifier).state = ProjectView.recapitulatif),
          ],
        );
      case MainModule.parametres:
        final activeView = ref.watch(settingsViewProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavigationButton(label: 'Connexion BD', icon: Icons.storage_outlined, isSelected: activeView == SettingsView.databaseConnection, onPressed: () => ref.read(settingsViewProvider.notifier).state = SettingsView.databaseConnection),
            const SizedBox(height: 8),
            _NavigationButton(label: 'Centre de Pilotage IA', icon: Icons.psychology_alt, isSelected: activeView == SettingsView.aiControlCenter, onPressed: () => ref.read(settingsViewProvider.notifier).state = SettingsView.aiControlCenter),
          ],
        );
      default:
        return const Center(child: Text('Navigation non définie'));
    }
  }

  Widget _buildContentView(MainModule module, WidgetRef ref) {
    switch (module) {
      case MainModule.projets:
        final activeView = ref.watch(projectViewProvider);
        switch (activeView) {
          case ProjectView.details:
            return const ProjectDetailsView();
          case ProjectView.designations:
            return const Center(child: Text('Contenu : Désignations'));
           case ProjectView.travaux:
            return const Center(child: Text('Contenu : Travaux'));
          case ProjectView.recapitulatif:
            return const Center(child: Text('Contenu : Récapitulatif'));
        }
      case MainModule.parametres:
        final activeView = ref.watch(settingsViewProvider);
        switch (activeView) {
          case SettingsView.databaseConnection:
            return const DatabaseConnectionView();
          case SettingsView.aiControlCenter:
            return const AiControlCenterView();
        }
      default:
        return Center(child: Text('Contenu pour : ${_getModuleName(module)}'));
    }
  }

  String _getModuleName(MainModule module) {
    switch (module) {
      case MainModule.accueil: return 'Accueil';
      case MainModule.projets: return 'Projets';
      case MainModule.facturations: return 'Facturations';
      case MainModule.rapports: return 'Rapports';
      case MainModule.comptabilite: return 'Comptabilité';
      case MainModule.parametres: return 'Paramètres';
    }
  }
}

class _NavigationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.blueGrey[800]),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : Colors.blueGrey[800],
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }
}
