import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/reference_data_provider.dart';

Future<void> showAddCompanyDialog(BuildContext context) async {
  await showDialog(
    context: context,
    // On utilise une barrière non-dismissible pour forcer l'utilisateur à utiliser les boutons
    barrierDismissible: false,
    builder: (context) => const AddCompanyDialog(),
  );
}

class AddCompanyDialog extends ConsumerStatefulWidget {
  const AddCompanyDialog({super.key});

  @override
  ConsumerState<AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends ConsumerState<AddCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'name': TextEditingController(),
    'address': TextEditingController(),
    'city': TextEditingController(),
    'postal_code': TextEditingController(),
    'email': TextEditingController(),
    'tel1': TextEditingController(),
    'siret': TextEditingController(),
    'tva_intracom': TextEditingController(),
  };

  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref.read(companiesProvider.notifier).addCompany(
              name: _controllers['name']!.text,
              address: _controllers['address']!.text,
              city: _controllers['city']!.text,
              postalCode: _controllers['postal_code']!.text,
              email: _controllers['email']!.text,
              tel1: _controllers['tel1']!.text,
              siret: _controllers['siret']!.text,
              tvaIntracom: _controllers['tva_intracom']!.text,
            );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer une nouvelle société'),
      // Utiliser une largeur contrainte pour un meilleur affichage sur de grands écrans
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _controllers['name'],
                  decoration: const InputDecoration(labelText: 'Nom de la société *'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['address'], decoration: const InputDecoration(labelText: 'Adresse')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _controllers['postal_code'], decoration: const InputDecoration(labelText: 'Code Postal'))),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: TextFormField(controller: _controllers['city'], decoration: const InputDecoration(labelText: 'Ville'))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['tel1'], decoration: const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['email'], decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _controllers['siret'], decoration: const InputDecoration(labelText: 'SIRET'))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _controllers['tva_intracom'], decoration: const InputDecoration(labelText: 'TVA Intracom.'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer'),
        ),
      ],
    );
  }
}
