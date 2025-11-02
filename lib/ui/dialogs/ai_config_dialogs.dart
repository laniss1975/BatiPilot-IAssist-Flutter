import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/ui/theme/app_theme.dart';
import 'package:test1/providers/reference_data_provider.dart';

// Dialog pour ajouter/modifier une clé API
class AddEditApiKeyDialog extends ConsumerStatefulWidget {
  final String? keyId; // null = nouveau, non-null = édition
  final String? initialProviderKey;
  final String? initialAlias;
  final String? initialDescription;
  
  const AddEditApiKeyDialog({
    super.key,
    this.keyId,
    this.initialProviderKey,
    this.initialAlias,
    this.initialDescription,
  });

  @override
  ConsumerState<AddEditApiKeyDialog> createState() => _AddEditApiKeyDialogState();
}

class _AddEditApiKeyDialogState extends ConsumerState<AddEditApiKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keyController = TextEditingController();
  String? _selectedProvider;
  bool _isLoading = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _aliasController.text = widget.initialAlias ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _selectedProvider = widget.initialProviderKey;
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _descriptionController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabase = ref.read(supabaseConnectionProvider).client!;
      
      if (widget.keyId == null) {
        // Nouvelle clé
        await supabase.from('ai_api_keys').insert({
          'provider_key': _selectedProvider,
          'key_alias': _aliasController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          'encrypted_key': _keyController.text.trim(), // TODO: chiffrer côté serveur
        });
      } else {
        // Mise à jour
        final data = {
          'key_alias': _aliasController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        };
        
        if (_keyController.text.trim().isNotEmpty) {
          data['encrypted_key'] = _keyController.text.trim();
        }
        
        await supabase
            .from('ai_api_keys')
            .update(data)
            .eq('id', widget.keyId!);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true); // Retourne true pour signaler le succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.keyId == null ? 'Clé ajoutée avec succès' : 'Clé mise à jour'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(aiProvidersProvider);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.keyId == null ? 'Ajouter une clé API' : 'Modifier la clé API',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Configurez votre accès aux modèles IA',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Provider
              providersAsync.when(
                data: (providers) => DropdownButtonFormField<String>(
                  value: _selectedProvider,
                  decoration: const InputDecoration(
                    labelText: 'Fournisseur *',
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: providers.map((p) => DropdownMenuItem(
                    value: p.providerKey,
                    child: Text(p.providerName),
                  )).toList(),
                  onChanged: widget.keyId == null ? (value) => setState(() => _selectedProvider = value) : null,
                  validator: (value) => value == null ? 'Champ requis' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Erreur: $e'),
              ),
              const SizedBox(height: 20),
              
              // Alias
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la clé *',
                  hintText: 'ex: API Perso, API Pro',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) => value?.trim().isEmpty ?? true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 20),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'ex: Clé API professionnelle - facturation mensuelle',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              
              // Clé API
              TextFormField(
                controller: _keyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: widget.keyId == null ? 'Clé API *' : 'Nouvelle clé API (laisser vide pour conserver)',
                  hintText: 'sk-...',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                validator: widget.keyId == null 
                    ? (value) => value?.trim().isEmpty ?? true ? 'Champ requis' : null
                    : null,
              ),
              const SizedBox(height: 32),
              
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(widget.keyId == null ? 'Ajouter' : 'Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog pour créer une configuration
class AddConfigurationDialog extends ConsumerStatefulWidget {
  const AddConfigurationDialog({super.key});

  @override
  ConsumerState<AddConfigurationDialog> createState() => _AddConfigurationDialogState();
}

class _AddConfigurationDialogState extends ConsumerState<AddConfigurationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _configNameController = TextEditingController();
  String? _selectedProvider;
  String? _selectedModel;
  String? _selectedApiKeyId;
  String _selectedModule = 'global';
  bool _isLoading = false;

  @override
  void dispose() {
    _configNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabase = ref.read(supabaseConnectionProvider).client!;
      
      await supabase.from('ai_model_configurations').insert({
        'provider_key': _selectedProvider,
        'model_key': _selectedModel,
        'api_key_id': _selectedApiKeyId,
        'config_name': _configNameController.text.trim(),
        'module_name': _selectedModule,
        'is_active': false,
      });
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration créée avec succès'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(aiProvidersProvider);
    final modelsAsync = ref.watch(aiModelsProvider);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings, color: AppTheme.secondaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouvelle configuration',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Associez un modèle à une clé API',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Nom de la configuration
                TextFormField(
                  controller: _configNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la configuration *',
                    hintText: 'ex: Gemini 2.5 Pro Personnel',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 20),
                
                // Provider
                providersAsync.when(
                  data: (providers) => DropdownButtonFormField<String>(
                    value: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur *',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: providers.map((p) => DropdownMenuItem(
                      value: p.providerKey,
                      child: Text(p.providerName),
                    )).toList(),
                    onChanged: (value) => setState(() {
                      _selectedProvider = value;
                      _selectedModel = null;
                      _selectedApiKeyId = null;
                    }),
                    validator: (value) => value == null ? 'Champ requis' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Erreur: $e'),
                ),
                const SizedBox(height: 20),
                
                // Model
                if (_selectedProvider != null)
                  modelsAsync.when(
                    data: (models) {
                      final filteredModels = models.where((m) => m.providerKey == _selectedProvider).toList();
                      return DropdownButtonFormField<String>(
                        value: _selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Modèle *',
                          prefixIcon: Icon(Icons.memory),
                        ),
                        items: filteredModels.map((m) => DropdownMenuItem(
                          value: m.modelKey,
                          child: Text(m.modelName),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedModel = value),
                        validator: (value) => value == null ? 'Champ requis' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Erreur: $e'),
                  ),
                if (_selectedProvider != null) const SizedBox(height: 20),
                
                // API Key selection
                if (_selectedProvider != null)
                  _ApiKeySelector(
                    providerKey: _selectedProvider!,
                    selectedKeyId: _selectedApiKeyId,
                    onChanged: (value) => setState(() => _selectedApiKeyId = value),
                  ),
                const SizedBox(height: 20),
                
                // Module
                DropdownButtonFormField<String>(
                  value: _selectedModule,
                  decoration: const InputDecoration(
                    labelText: 'Module *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text('Global')),
                    DropdownMenuItem(value: 'rapports', child: Text('Rapports')),
                    DropdownMenuItem(value: 'imports', child: Text('Imports')),
                  ],
                  onChanged: (value) => setState(() => _selectedModule = value!),
                ),
                const SizedBox(height: 32),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: const Text('Créer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget pour sélectionner une clé API
class _ApiKeySelector extends ConsumerWidget {
  final String providerKey;
  final String? selectedKeyId;
  final ValueChanged<String?> onChanged;

  const _ApiKeySelector({
    required this.providerKey,
    required this.selectedKeyId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchApiKeys(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        
        if (snapshot.hasError) {
          return Text('Erreur: ${snapshot.error}');
        }
        
        final keys = snapshot.data ?? [];
        
        if (keys.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aucune clé API pour ce fournisseur. Ajoutez-en une d\'abord.',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          );
        }
        
        return DropdownButtonFormField<String>(
          value: selectedKeyId,
          decoration: const InputDecoration(
            labelText: 'Clé API à utiliser *',
            prefixIcon: Icon(Icons.vpn_key),
          ),
          items: keys.map((k) => DropdownMenuItem(
            value: k['id'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k['key_alias']),
                if (k['description'] != null)
                  Text(
                    k['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Champ requis' : null,
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchApiKeys(WidgetRef ref) async {
    final supabase = ref.read(supabaseConnectionProvider).client!;
    final response = await supabase
        .from('ai_api_keys')
        .select('id, key_alias, description')
        .eq('provider_key', providerKey)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }
}
