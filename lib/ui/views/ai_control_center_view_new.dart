import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/ui/theme/app_theme.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/ui/dialogs/ai_config_dialogs.dart';
import 'package:test1/providers/ai_prompts_provider.dart';
import 'package:test1/models/ai_prompt_model.dart';

// Modèles de données
class ApiKey {
  final String id;
  final String providerKey;
  final String keyAlias;
  final String? description;
  final bool isActive;
  
  ApiKey({
    required this.id,
    required this.providerKey,
    required this.keyAlias,
    this.description,
    required this.isActive,
  });
  
  factory ApiKey.fromJson(Map<String, dynamic> json) => ApiKey(
    id: json['id'],
    providerKey: json['provider_key'],
    keyAlias: json['key_alias'],
    description: json['description'],
    isActive: json['is_active'] ?? true,
  );
}

class ModelConfiguration {
  final String id;
  final String providerKey;
  final String modelKey;
  final String apiKeyId;
  final String configName;
  final String moduleName;
  final bool isActive;
  
  ModelConfiguration({
    required this.id,
    required this.providerKey,
    required this.modelKey,
    required this.apiKeyId,
    required this.configName,
    required this.moduleName,
    required this.isActive,
  });
  
  factory ModelConfiguration.fromJson(Map<String, dynamic> json) => ModelConfiguration(
    id: json['id'],
    providerKey: json['provider_key'],
    modelKey: json['model_key'],
    apiKeyId: json['api_key_id'],
    configName: json['config_name'],
    moduleName: json['module_name'],
    isActive: json['is_active'] ?? false,
  );
}

// Providers
final apiKeysProvider = FutureProvider.autoDispose<List<ApiKey>>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  if (supabase == null) return [];
  
  final response = await supabase
      .from('ai_api_keys')
      .select()
      .order('created_at', ascending: false);
  
  return (response as List).map((e) => ApiKey.fromJson(e)).toList();
});

final modelConfigurationsProvider = FutureProvider.autoDispose<List<ModelConfiguration>>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  if (supabase == null) return [];
  
  final response = await supabase
      .from('ai_model_configurations')
      .select()
      .order('created_at', ascending: false);
  
  return (response as List).map((e) => ModelConfiguration.fromJson(e)).toList();
});

class AiControlCenterView extends ConsumerStatefulWidget {
  const AiControlCenterView({super.key});

  @override
  ConsumerState<AiControlCenterView> createState() => _AiControlCenterViewState();
}

class _AiControlCenterViewState extends ConsumerState<AiControlCenterView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header moderne
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(bottom: BorderSide(color: AppTheme.messageBorder)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.settings_suggest, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Centre de Pilotage IA',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Gérez vos clés API et configurations de modèles',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Tabs
        Container(
          color: AppTheme.surfaceColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.key), text: 'Mes Clés API'),
              Tab(icon: Icon(Icons.settings), text: 'Configurations'),
              Tab(icon: Icon(Icons.edit_note), text: 'Prompts Assistant'),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ApiKeysTab(),
              _ConfigurationsTab(),
              _PromptsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ========== Onglet Clés API ==========
class _ApiKeysTab extends ConsumerWidget {
  const _ApiKeysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeysAsync = ref.watch(apiKeysProvider);

    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vos clés API enregistrées',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddApiKeyDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une clé'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: apiKeysAsync.when(
              data: (keys) {
                if (keys.isEmpty) {
                  return _EmptyStateKeys();
                }
                
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, index) => _ApiKeyCard(apiKey: keys[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyCard extends ConsumerWidget {
  final ApiKey apiKey;
  const _ApiKeyCard({required this.apiKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.messageBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getProviderIcon(apiKey.providerKey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiKey.keyAlias,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getProviderName(apiKey.providerKey),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') _showEditApiKeyDialog(context, ref, apiKey);
                    if (value == 'delete') _deleteApiKey(context, ref, apiKey.id);
                  },
                ),
              ],
            ),
            if (apiKey.description != null) ...[
              const SizedBox(height: 12),
              Text(
                apiKey.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: apiKey.isActive ? AppTheme.accentColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    apiKey.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: apiKey.isActive ? AppTheme.accentColor : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getProviderIcon(String providerKey) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_getIconForProvider(providerKey), color: AppTheme.primaryColor, size: 24),
    );
  }

  IconData _getIconForProvider(String key) {
    switch (key) {
      case 'google': return Icons.g_mobiledata;
      case 'openai': return Icons.psychology;
      case 'anthropic': return Icons.auto_awesome;
      default: return Icons.api;
    }
  }

  String _getProviderName(String key) {
    switch (key) {
      case 'google': return 'Google Gemini';
      case 'openai': return 'OpenAI';
      case 'anthropic': return 'Anthropic Claude';
      case 'mistral': return 'Mistral AI';
      default: return key;
    }
  }
}

class _EmptyStateKeys extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.key_off, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text('Aucune clé API enregistrée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Commencez par ajouter vos clés API', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ========== Onglet Configurations ==========
class _ConfigurationsTab extends ConsumerWidget {
  const _ConfigurationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configurationsAsync = ref.watch(modelConfigurationsProvider);

    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configurations de modèles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddConfigDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle configuration'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: configurationsAsync.when(
              data: (configs) {
                if (configs.isEmpty) {
                  return _EmptyStateConfigs();
                }
                
                return ListView.builder(
                  itemCount: configs.length,
                  itemBuilder: (context, index) => _ConfigurationCard(config: configs[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationCard extends ConsumerWidget {
  final ModelConfiguration config;
  const _ConfigurationCard({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: config.isActive ? AppTheme.primaryColor : AppTheme.messageBorder,
          width: config.isActive ? 2 : 1,
        ),
        boxShadow: [
          if (config.isActive)
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            if (config.isActive)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 28),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.configName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${config.modelKey} • Module: ${config.moduleName}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (!config.isActive)
              TextButton.icon(
                onPressed: () => _activateConfig(ref, config.id),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Activer'),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteConfig(context, ref, config.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateConfigs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.settings_suggest, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text('Aucune configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Créez votre première configuration de modèle', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ========== Dialogs ==========
void _showAddApiKeyDialog(BuildContext context, WidgetRef ref) {
  // TODO: Implémenter le dialog d'ajout de clé
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fonction d\'ajout de clé à implémenter')),
  );
}

void _showEditApiKeyDialog(BuildContext context, WidgetRef ref, ApiKey apiKey) {
  // TODO: Implémenter le dialog d'édition
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fonction d\'édition à implémenter')),
  );
}

void _showAddConfigDialog(BuildContext context, WidgetRef ref) {
  // TODO: Implémenter le dialog de création de configuration
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fonction de création de configuration à implémenter')),
  );
}

Future<void> _deleteApiKey(BuildContext context, WidgetRef ref, String id) async {
  // TODO: Implémenter la suppression
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Suppression à implémenter')),
  );
}

Future<void> _deleteConfig(BuildContext context, WidgetRef ref, String id) async {
  // TODO: Implémenter la suppression
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Suppression à implémenter')),
  );
}

Future<void> _activateConfig(WidgetRef ref, String id) async {
  // TODO: Implémenter l'activation
}

// ========== Onglet Prompts Assistant ==========
class _PromptsTab extends ConsumerStatefulWidget {
  const _PromptsTab();

  @override
  ConsumerState<_PromptsTab> createState() => _PromptsTabState();
}

class _PromptsTabState extends ConsumerState<_PromptsTab> {
  String? _selectedPromptId;
  final _titleController = TextEditingController();
  final _keyController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _keyController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadPrompt(AiPrompt prompt) {
    setState(() {
      _selectedPromptId = prompt.id;
      _titleController.text = prompt.title;
      _keyController.text = prompt.key;
      _contentController.text = prompt.content;
      _isEditing = false;
    });
  }

  void _clearForm() {
    setState(() {
      _selectedPromptId = null;
      _titleController.clear();
      _keyController.clear();
      _contentController.clear();
      _isEditing = true;
    });
  }

  Future<void> _savePrompt() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_selectedPromptId == null) {
        // Créer un nouveau prompt
        await ref.read(aiPromptsProvider.notifier).createPrompt(
              key: _keyController.text.trim(),
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prompt créé avec succès !'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        // Mettre à jour le prompt existant
        await ref.read(aiPromptsProvider.notifier).updatePrompt(
              id: _selectedPromptId!,
              key: _keyController.text.trim(),
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prompt mis à jour avec succès !'),
                backgroundColor: Colors.green),
          );
        }
      }

      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePrompt() async {
    if (_selectedPromptId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le prompt'),
        content: Text(
            'Voulez-vous vraiment supprimer "${_titleController.text}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(aiPromptsProvider.notifier).deletePrompt(_selectedPromptId!);
        _clearForm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prompt supprimé'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptsAsync = ref.watch(aiPromptsProvider);

    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Liste des prompts (gauche)
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Prompts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Nouveau prompt',
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: promptsAsync.when(
                    data: (prompts) {
                      if (prompts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('Aucun prompt',
                                  style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(aiPromptsProvider.notifier)
                                        .initializeDefaultPrompts();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Prompts par défaut créés !'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.download),
                                label: const Text('Initialiser les prompts'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: prompts.length,
                        itemBuilder: (context, index) {
                          final prompt = prompts[index];
                          final isSelected = prompt.id == _selectedPromptId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.messageBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _loadPrompt(prompt),
                              leading: Icon(
                                Icons.edit_note,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[600],
                              ),
                              title: Text(
                                prompt.title,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                prompt.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Erreur: $e',
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Formulaire d'édition (droite)
          Expanded(
            child: _selectedPromptId == null && !_isEditing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.edit_note,
                              size: 80, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Sélectionnez un prompt',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ou créez-en un nouveau',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.messageBorder),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit_note,
                                  color: AppTheme.primaryColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedPromptId == null
                                      ? 'Nouveau Prompt'
                                      : 'Modifier le Prompt',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (_selectedPromptId != null && !_isEditing)
                                TextButton.icon(
                                  onPressed: () => setState(() => _isEditing = true),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Modifier'),
                                ),
                            ],
                          ),
                          const Divider(height: 32),

                          // Titre
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Titre *',
                              hintText: 'Ex: Prompt Système',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _isEditing || _selectedPromptId == null,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Le titre est requis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Clé
                          TextFormField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              labelText: 'Clé *',
                              hintText: 'Ex: prompt_system',
                              border: OutlineInputBorder(),
                              helperText:
                                  'Identifiant unique (ex: prompt_system, prompt_details_projet)',
                            ),
                            enabled: _selectedPromptId == null,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La clé est requise';
                              }
                              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                                return 'Format: minuscules, chiffres et underscores uniquement';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Contenu
                          Expanded(
                            child: TextFormField(
                              controller: _contentController,
                              decoration: const InputDecoration(
                                labelText: 'Contenu *',
                                hintText:
                                    'Écrivez le contenu du prompt...\n\nMarkdown supporté',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: null,
                              expands: true,
                              enabled: _isEditing || _selectedPromptId == null,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Le contenu est requis';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Boutons d'action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_selectedPromptId != null &&
                                  (_isEditing || _selectedPromptId == null))
                                TextButton.icon(
                                  onPressed: _deletePrompt,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Supprimer'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                ),
                              const Spacer(),
                              if (_isEditing || _selectedPromptId == null) ...[
                                TextButton(
                                  onPressed: _selectedPromptId == null
                                      ? _clearForm
                                      : () {
                                          // Recharger le prompt original
                                          final prompts =
                                              ref.read(aiPromptsProvider).value;
                                          if (prompts != null) {
                                            final prompt = prompts.firstWhere(
                                                (p) => p.id == _selectedPromptId);
                                            _loadPrompt(prompt);
                                          }
                                        },
                                  child: const Text('Annuler'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _savePrompt,
                                  icon: const Icon(Icons.save),
                                  label: Text(_selectedPromptId == null
                                      ? 'Créer'
                                      : 'Enregistrer'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
