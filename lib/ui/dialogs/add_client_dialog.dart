import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/reference_data_provider.dart';

Future<void> showAddClientDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AddClientDialog(),
  );
}

class AddClientDialog extends ConsumerStatefulWidget {
  const AddClientDialog({super.key});

  @override
  ConsumerState<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends ConsumerState<AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'nom': TextEditingController(),
    'prenom': TextEditingController(),
    'adresse': TextEditingController(),
    'code_postal': TextEditingController(),
    'ville': TextEditingController(),
    'tel1': TextEditingController(),
    'email': TextEditingController(),
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
        await ref.read(clientsProvider.notifier).addClient(
              nom: _controllers['nom']!.text,
              prenom: _controllers['prenom']!.text,
              adresse: _controllers['adresse']!.text,
              codePostal: _controllers['code_postal']!.text,
              ville: _controllers['ville']!.text,
              tel1: _controllers['tel1']!.text,
              email: _controllers['email']!.text,
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
      title: const Text('Créer un nouveau client'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _controllers['nom'],
                        decoration: const InputDecoration(labelText: 'Nom *'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Champ requis' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _controllers['prenom'], decoration: const InputDecoration(labelText: 'Prénom'))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['adresse'], decoration: const InputDecoration(labelText: 'Adresse')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _controllers['code_postal'], decoration: const InputDecoration(labelText: 'Code Postal'))),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: TextFormField(controller: _controllers['ville'], decoration: const InputDecoration(labelText: 'Ville'))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['tel1'], decoration: const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: 16),
                TextFormField(controller: _controllers['email'], decoration: const InputDecoration(labelText: 'Email')),
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
