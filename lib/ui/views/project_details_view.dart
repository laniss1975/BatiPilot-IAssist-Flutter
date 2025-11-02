import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:test1/models/client_model.dart';
import 'package:test1/models/company_model.dart';
import 'package:test1/models/project_model.dart';
import 'package:test1/providers/project_provider.dart';
import 'package:test1/providers/reference_data_provider.dart';
import 'package:test1/ui/dialogs/add_company_dialog.dart';
import 'package:test1/ui/dialogs/add_client_dialog.dart';

class ProjectDetailsView extends ConsumerWidget {
  const ProjectDetailsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final isAccepted = project.status == DevisStatus.accepte;

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 800 ? 64.0 : 24.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24.0),
            child: Column(
              children: [
                _SectionCard(
                  title: 'Informations Générales',
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCompanySection(context, ref)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildStatusSection(context, ref)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildClientSection(context, ref)),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildTextFormField(
                                  label: 'Référence Bon de Commande',
                                  initialValue: project.referenceBonCommande ?? '',
                                  onChanged: (value) => ref.read(projectProvider.notifier).updateProject(referenceBonCommande: value),
                                  readOnly: !isAccepted,
                                  hint: isAccepted ? 'Entrez la référence...' : 'N/A',
                                ),
                                const SizedBox(height: 24),
                                _buildDatePickerField(
                                  context: context,
                                  label: 'Date de confirmation',
                                  selectedDate: project.dateAcceptation,
                                  onDateSelected: (date) => ref.read(projectProvider.notifier).updateProject(dateAcceptation: date),
                                  enabled: isAccepted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Détails du Projet',
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              label: 'Numéro du devis',
                              initialValue: project.devisNumber,
                              onChanged: (value) => ref.read(projectProvider.notifier).updateProject(devisNumber: value),
                              suffixIcon: IconButton(icon: const Icon(Icons.auto_awesome), tooltip: 'Générer', onPressed: ref.read(projectProvider.notifier).generateDevisNumber),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePickerField(
                              context: context,
                              label: 'Date du devis',
                              selectedDate: project.devisDate,
                              onDateSelected: (date) => ref.read(projectProvider.notifier).updateProject(devisDate: date),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTextFormField(
                        label: 'Nom du projet',
                        initialValue: project.projectName,
                        onChanged: (value) => ref.read(projectProvider.notifier).updateProject(projectName: value),
                        suffixIcon: IconButton(icon: const Icon(Icons.edit_note), tooltip: 'Générer le nom', onPressed: () {}),
                      ),
                      const SizedBox(height: 24),
                      _buildTextFormField(
                        label: 'Description du projet',
                        initialValue: project.metadata.descriptionProjet,
                        onChanged: (value) => ref.read(projectProvider.notifier).updateMetadata(descriptionProjet: value),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Informations Chantier',
                  child: Column(
                    children: [
                      _buildTextFormField(
                        label: 'Adresse du chantier',
                        initialValue: project.metadata.adresseChantier,
                        onChanged: (value) => ref.read(projectProvider.notifier).updateMetadata(adresseChantier: value),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      _buildTextFormField(
                        label: 'Occupant',
                        initialValue: project.metadata.occupant,
                        onChanged: (value) => ref.read(projectProvider.notifier).updateMetadata(occupant: value),
                      ),
                      const SizedBox(height: 24),
                      _buildTextFormField(
                        label: 'Informations complémentaires',
                        initialValue: project.metadata.infoComplementaire,
                        onChanged: (value) => ref.read(projectProvider.notifier).updateMetadata(infoComplementaire: value),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets de Sections ---
  Widget _buildCompanySection(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final companiesAsync = ref.watch(companiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Société', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
              tooltip: 'Créer une nouvelle société',
              onPressed: () => showAddCompanyDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        companiesAsync.when(
          data: (companies) {
            final selectedCompany = companies.firstWhere((c) => c.id == project.companyId, orElse: () => Company(id: '', name: '', createdAt: DateTime.now(), userId: ''));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown(
                  hint: 'Sélectionner une société',
                  value: project.companyId,
                  items: companies.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (id) => ref.read(projectProvider.notifier).updateProject(companyId: id),
                ),
                if (project.companyId != null && selectedCompany.id.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoCard(context, selectedCompany),
                ]
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Erreur: $err'),
        ),
      ],
    );
  }

  Widget _buildClientSection(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final clientsAsync = ref.watch(clientsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Client', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
              tooltip: 'Créer un nouveau client',
              onPressed: () => showAddClientDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        clientsAsync.when(
          data: (clients) {
            final selectedClient = clients.firstWhere((c) => c.id == project.clientId, orElse: () => Client(id: '', nom: '', createdAt: DateTime.now(), userId: ''));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown(
                  hint: 'Sélectionner un client',
                  value: project.clientId,
                  items: clients.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.fullName))).toList(),
                  onChanged: (id) => ref.read(projectProvider.notifier).updateProject(clientId: id),
                ),
                if (project.clientId != null && selectedClient.id.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoCard(context, selectedClient),
                ]
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Erreur: $err'),
        ),
      ],
    );
  }
  
  Widget _buildStatusSection(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    bool isAccepted = project.status == DevisStatus.accepte;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Statut du devis', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isAccepted ? 'Accepté' : 'Brouillon', style: TextStyle(fontWeight: FontWeight.bold, color: isAccepted ? Theme.of(context).primaryColor : Colors.black87)),
              Switch(value: isAccepted, onChanged: (val) => ref.read(projectProvider.notifier).updateProject(status: val ? DevisStatus.accepte : DevisStatus.brouillon)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helpers génériques ---
  
  Widget _buildDatePickerField({required BuildContext context, required String label, DateTime? selectedDate, required void Function(DateTime) onDateSelected, bool enabled = true}) {
    final formattedDate = selectedDate != null ? DateFormat.yMMMMd('fr_FR').format(selectedDate) : 'Aucune date';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: enabled ? Colors.black : Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null && picked != selectedDate) {
              onDateSelected(picked);
            }
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formattedDate),
                const Icon(Icons.calendar_today, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDropdown({required String hint, String? value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, hint: Text(hint), items: items, onChanged: onChanged)),
    );
  }
  
  Widget _buildInfoCard(BuildContext context, dynamic data) {
    IconData icon;
    String title;
    List<String> details = [];

    if (data is Company) {
      icon = Icons.business;
      title = data.name;
      if (data.address != null && data.address!.isNotEmpty) details.add(data.address!);
      if (data.tel1 != null && data.tel1!.isNotEmpty) details.add('Tél: ${data.tel1}');
      if (data.email != null && data.email!.isNotEmpty) details.add('Email: ${data.email}');
    } else if (data is Client) {
      icon = Icons.person;
      title = data.fullName;
      final addressParts = [data.adresse, data.codePostal, data.ville].where((s) => s != null && s.isNotEmpty).join(', ');
      if (addressParts.isNotEmpty) details.add(addressParts);
      if (data.tel1 != null && data.tel1!.isNotEmpty) details.add('Tél: ${data.tel1}');
      if (data.email != null && data.email!.isNotEmpty) details.add('Email: ${data.email}');
    } else {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Colors.blueGrey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.blueGrey[100]!)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2.0), child: Icon(icon, color: Colors.blueGrey, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...details.map((line) => Text(line, style: Theme.of(context).textTheme.bodySmall)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextFormField({required String label, required String initialValue, ValueChanged<String>? onChanged, String? hint, bool readOnly = false, int maxLines = 1, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: readOnly ? Colors.grey : Colors.black)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }
}
