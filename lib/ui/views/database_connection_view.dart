import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

class DatabaseConnectionView extends ConsumerStatefulWidget {
  const DatabaseConnectionView({super.key});

  @override
  ConsumerState<DatabaseConnectionView> createState() => _DatabaseConnectionViewState();
}

class _DatabaseConnectionViewState extends ConsumerState<DatabaseConnectionView> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  bool _isLoading = false;

  void _connect() {
    setState(() => _isLoading = true);
    ref
        .read(supabaseConnectionProvider.notifier)
        .connect(_urlController.text, _anonKeyController.text)
        .whenComplete(() {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _disconnect() {
    ref.read(supabaseConnectionProvider.notifier).disconnect();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(supabaseConnectionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Connexion Supabase', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(height: 32),
                  
                  if (connectionState.status == ConnectionStatus.connected)
                    _buildConnectedView(connectionState.url), // Utilise la nouvelle propriété
                  
                  if (connectionState.status == ConnectionStatus.disconnected)
                    _buildDisconnectedView(),

                  if (connectionState.status == ConnectionStatus.error)
                    _buildErrorView(connectionState.errorMessage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'Supabase URL', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _anonKeyController, decoration: const InputDecoration(labelText: 'Supabase Anon Key', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _connect,
          icon: _isLoading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.power),
          label: Text(_isLoading ? 'Connexion...' : 'Tester & Enregistrer la connexion'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ],
    );
  }

  Widget _buildConnectedView(String? url) {
    return Column(
      children: [
        const ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green, size: 40),
          title: Text('Connecté avec succès !'),
          subtitle: Text('L\'application est synchronisée avec votre base de données.'),
        ),
        Text('Connecté à : ${url ?? 'URL non disponible'}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _disconnect,
          icon: const Icon(Icons.power_off),
          label: const Text('Se déconnecter'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }

  Widget _buildErrorView(String? error) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.error, color: Colors.red[700], size: 40),
          title: const Text('Échec de la connexion'),
          subtitle: Text('Vérifiez vos identifiants et votre connexion réseau.\nErreur: $error'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            ref.read(supabaseConnectionProvider.notifier).disconnect(); // Réinitialise l'état
          },
          child: const Text('Réessayer'),
        ),
      ],
    );
  }
}
