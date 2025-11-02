import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/user_api_key_model.dart';
import 'package:test1/providers/active_model_provider.dart';
import 'package:test1/providers/reference_data_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/providers/user_api_keys_provider.dart';
import 'package:test1/ui/theme/app_theme.dart';

class AiControlCenterView extends ConsumerStatefulWidget {
  const AiControlCenterView({super.key});

  @override
  ConsumerState<AiControlCenterView> createState() => _AiControlCenterViewState();
}

class _AiControlCenterViewState extends ConsumerState<AiControlCenterView> {
  String? _selectedProviderKey;
  String? _selectedModelKey;

  void _showError(BuildContext context, dynamic error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Erreur'),
          ],
        ),
        content: SelectableText(
          error.toString(),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(aiProvidersProvider);
    final modelsAsync = ref.watch(aiModelsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Centre de Pilotage IA', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text('Gérez vos modèles et clés API', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),

          // Sélection du provider
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.business, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Text('1. Choisissez un fournisseur', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Ajouter un fournisseur',
                            onPressed: () => _showAddProviderDialog(context, ref),
                          ),
                          if (_selectedProviderKey != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              tooltip: 'Supprimer ce fournisseur',
                              onPressed: () => _confirmDeleteProvider(context, ref),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  providersAsync.when(
                    data: (providers) => DropdownButtonFormField<String>(
                      value: _selectedProviderKey,
                      decoration: const InputDecoration(
                        hintText: 'Sélectionnez un fournisseur',
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: providers.map((provider) {
                        return DropdownMenuItem(
                          value: provider.providerKey,
                          child: Text(provider.providerName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProviderKey = value;
                          _selectedModelKey = null;
                        });
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Erreur: $e', style: const TextStyle(color: AppTheme.errorColor)),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedProviderKey != null) ...[
            const SizedBox(height: 24),

            // Sélection du modèle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.model_training, color: AppTheme.primaryColor),
                            const SizedBox(width: 12),
                            Text('2. Choisissez un modèle', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Ajouter un modèle',
                              onPressed: () => _showAddModelDialog(context, ref),
                            ),
                            if (_selectedModelKey != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                tooltip: 'Supprimer ce modèle',
                                onPressed: () => _confirmDeleteModel(context, ref),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    modelsAsync.when(
                      data: (models) {
                        final filteredModels = models.where((m) => m.providerKey == _selectedProviderKey).toList();
                        return DropdownButtonFormField<String>(
                          value: _selectedModelKey,
                          decoration: const InputDecoration(
                            hintText: 'Sélectionnez un modèle',
                            prefixIcon: Icon(Icons.model_training),
                          ),
                          items: filteredModels.map((model) {
                            return DropdownMenuItem(
                              value: model.modelKey,
                              child: Text(model.modelName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedModelKey = value;
                            });
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Erreur: $e', style: const TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedModelKey != null) ...[
              const SizedBox(height: 24),
              _ModelKeysManager(
                providerKey: _selectedProviderKey!,
                modelKey: _selectedModelKey!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAddProviderDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final keyController = TextEditingController();
    final endpointController = TextEditingController();
    final authMethodController = TextEditingController(text: 'bearer');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un fournisseur'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'Identifiant (provider_key) *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: endpointController,
                  decoration: const InputDecoration(labelText: 'Endpoint API *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: authMethodController.text,
                  decoration: const InputDecoration(labelText: 'Méthode d\'auth'),
                  items: const [
                    DropdownMenuItem(value: 'bearer', child: Text('Bearer Token')),
                    DropdownMenuItem(value: 'api_key_header', child: Text('API Key Header')),
                    DropdownMenuItem(value: 'query_param', child: Text('Query Parameter')),
                  ],
                  onChanged: (v) => authMethodController.text = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final client = ref.read(supabaseConnectionProvider).client;
                await client!.from('ai_providers').insert({
                  'provider_key': keyController.text.trim(),
                  'provider_name': nameController.text.trim(),
                  'api_endpoint': endpointController.text.trim(),
                  'api_auth_method': authMethodController.text,
                });
                ref.invalidate(aiProvidersProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fournisseur ajouté !'), backgroundColor: AppTheme.accentColor),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  _showError(context, e);
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProvider(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fournisseur ?'),
        content: const Text('Tous les modèles et clés associés seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              try {
                final client = ref.read(supabaseConnectionProvider).client;
                await client!.from('ai_providers').delete().eq('provider_key', _selectedProviderKey!);
                ref.invalidate(aiProvidersProvider);
                setState(() {
                  _selectedProviderKey = null;
                  _selectedModelKey = null;
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fournisseur supprimé'), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  _showError(context, e);
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddModelDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final keyController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un modèle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du modèle *'),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Identifiant (model_key) *'),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final client = ref.read(supabaseConnectionProvider).client;
                await client!.from('ai_models').insert({
                  'provider_key': _selectedProviderKey,
                  'model_key': keyController.text.trim(),
                  'model_name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                ref.invalidate(aiModelsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modèle ajouté !'), backgroundColor: AppTheme.accentColor),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  _showError(context, e);
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteModel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le modèle ?'),
        content: const Text('Toutes les clés associées seront supprimées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              try {
                final client = ref.read(supabaseConnectionProvider).client;
                await client!.from('ai_models').delete().eq('model_key', _selectedModelKey!);
                ref.invalidate(aiModelsProvider);
                setState(() => _selectedModelKey = null);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modèle supprimé'), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  _showError(context, e);
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _ModelKeysManager extends ConsumerWidget {
  final String providerKey;
  final String modelKey;

  const _ModelKeysManager({
    required this.providerKey,
    required this.modelKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identifier = ModelIdentifier(providerKey: providerKey, modelKey: modelKey);
    final keysAsync = ref.watch(modelApiKeysProvider(identifier));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text('3. Gérez vos clés API', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddKeyDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une clé'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            keysAsync.when(
              data: (keys) {
                if (keys.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.key_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Aucune clé API configurée', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('Ajoutez votre première clé pour utiliser ce modèle', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: keys.map((key) => _ApiKeyCard(apiKey: key)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Erreur: $e', style: const TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKeyDialog(BuildContext context, WidgetRef ref) {
    final keyNameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une clé API'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la configuration *',
                  hintText: 'Ex: API Perso, API Pro, API Test',
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Clé API *',
                  hintText: 'Collez votre clé API ici',
                ),
                obscureText: true,
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Ex: Clé payante, limite 1000 req/jour',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await ref.read(apiKeysNotifierProvider.notifier).addKey(
                    providerKey: providerKey,
                    modelKey: modelKey,
                    keyName: keyNameController.text.trim(),
                    apiKey: apiKeyController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clé ajoutée avec succès !'), backgroundColor: AppTheme.accentColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.errorColor),
                            SizedBox(width: 12),
                            Text('Erreur'),
                          ],
                        ),
                        content: SelectableText(
                          e.toString(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyCard extends ConsumerWidget {
  final UserApiKey apiKey;

  const _ApiKeyCard({required this.apiKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: apiKey.isActive ? 2 : 0,
      color: apiKey.isActive ? AppTheme.primaryColor.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Indicateur actif
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: apiKey.isActive ? AppTheme.accentColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            
            // Icône
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: apiKey.isActive 
                    ? AppTheme.accentColor.withOpacity(0.1) 
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                apiKey.isActive ? Icons.check_circle : Icons.key,
                color: apiKey.isActive ? AppTheme.accentColor : Colors.grey[600],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(apiKey.keyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      if (apiKey.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  if (apiKey.notes != null && apiKey.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(apiKey.notes!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ],
              ),
            ),
            
            // Actions
            if (!apiKey.isActive)
              TextButton.icon(
                onPressed: () async {
                  await ref.read(apiKeysNotifierProvider.notifier).setActiveKey(apiKey.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clé activée !'), backgroundColor: AppTheme.accentColor),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Activer'),
              ),
            
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () => _showEditDialog(context, ref),
            ),
            
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              tooltip: 'Supprimer',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final keyNameController = TextEditingController(text: apiKey.keyName);
    final notesController = TextEditingController(text: apiKey.notes);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la clé API'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyNameController,
                decoration: const InputDecoration(labelText: 'Nom de la configuration'),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await ref.read(apiKeysNotifierProvider.notifier).updateKey(
                    keyId: apiKey.id,
                    keyName: keyNameController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clé modifiée !'), backgroundColor: AppTheme.accentColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la clé ?'),
        content: Text('Voulez-vous vraiment supprimer "${apiKey.keyName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              try {
                await ref.read(apiKeysNotifierProvider.notifier).deleteKey(apiKey.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clé supprimée'), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
