import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/assistant/assistant_controller.dart';
import 'package:test1/providers/ai_chat_provider.dart';
import 'package:test1/providers/active_model_provider.dart';
import 'package:test1/providers/reference_data_provider.dart';
import 'package:test1/providers/user_api_keys_provider.dart';
import 'package:test1/ui/theme/app_theme.dart';
import 'package:test1/ui/widgets/chat_selector.dart';

class RightPane extends ConsumerWidget {
  const RightPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(aiChatProvider);
    final activeConfig = ref.watch(activeModelProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(left: BorderSide(color: AppTheme.messageBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Sélecteur de chats (EN HAUT)
          const ChatSelector(),
          
          // Header moderne
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(bottom: BorderSide(color: AppTheme.messageBorder, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Assistant IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(child: _ModelSelector()),
                        ],
                      ),
                      Text('BâtiPilot IAssist', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: chatState.messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return message.role == 'user'
                          ? _UserMessage(text: message.content)
                          : _AssistantMessage(message: message);
                    },
                  ),
          ),
          
          const _InputBar(),
        ],
      ),
    );
  }
}

// Widget de sélection du modèle actif
class _ModelSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeConfig = ref.watch(activeModelProvider);
    final availableKeysAsync = ref.watch(userApiKeysProvider);
    final modelsAsync = ref.watch(aiModelsProvider);
    final providersAsync = ref.watch(aiProvidersProvider);

    return availableKeysAsync.when(
      data: (keys) {
        // Filtrer les clés actives (une par provider/model)
        final activeKeys = keys.where((k) => k.isActive).toList();

        if (activeKeys.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Aucune clé active',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          );
        }

        return modelsAsync.when(
          data: (models) {
            return providersAsync.when(
              data: (providers) {
                // Construire la liste des modèles disponibles (ceux avec une clé active)
                final availableModels = <Map<String, String>>[];
                for (final key in activeKeys) {
                  final model = models.where(
                    (m) => m.modelKey == key.modelKey && m.providerKey == key.providerKey
                  ).firstOrNull;
                  final provider = providers.where((p) => p.providerKey == key.providerKey).firstOrNull;
                  
                  if (model != null && provider != null) {
                    availableModels.add({
                      'providerKey': key.providerKey,
                      'modelKey': key.modelKey ?? '',
                      'modelName': model.modelName,
                      'providerName': provider.providerName,
                    });
                  }
                }

                if (availableModels.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Erreur config',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                return activeConfig.when(
                  data: (config) {
                    // Trouver le modèle actuellement sélectionné
                    final currentModel = config != null
                        ? availableModels.where((m) => m['modelName'] == config.modelName).firstOrNull
                        : null;

                    final displayModel = currentModel ?? availableModels.first;

                    return PopupMenuButton<Map<String, String>>(
                      tooltip: '${displayModel['providerName']} - ${displayModel['modelName']}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: config != null ? AppTheme.accentColor : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayModel['modelName'] ?? 'Sélectionner',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => availableModels.map((model) {
                        final isSelected = currentModel != null && 
                                          model['modelKey'] == currentModel['modelKey'] &&
                                          model['providerKey'] == currentModel['providerKey'];
                        return PopupMenuItem<Map<String, String>>(
                          value: model,
                          child: Row(
                            children: [
                              if (isSelected) const Icon(Icons.check, size: 16, color: AppTheme.accentColor),
                              if (isSelected) const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model['modelName']!,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? AppTheme.accentColor : null,
                                      ),
                                    ),
                                    Text(
                                      model['providerName']!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onSelected: (model) async {
                        try {
                          await ref.read(activeModelProvider.notifier).setActiveModel(
                            model['providerKey']!,
                            model['modelKey']!,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Modèle activé : ${model['modelName']}'),
                                backgroundColor: AppTheme.accentColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                  error: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Erreur',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
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
            child: const Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text('Commencez une conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Posez une question à votre assistant', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _InputBar extends ConsumerStatefulWidget {
  const _InputBar();

  @override
  ConsumerState<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<_InputBar> {
  final _textController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref.read(assistantControllerProvider).handleUserMessage(
            text: text,
            module: 'context',
            context: context,
          );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.messageBorder, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton d'attachement
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {},
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
          
          // Champ de texte
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent) {
                    // Entrée seule = envoyer
                    if (event.logicalKey.keyLabel == 'Enter' && 
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                    }
                  }
                },
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    hintText: 'Entrée pour envoyer, Shift+Entrée pour nouvelle ligne',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.messageBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.messageBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Bouton d'envoi
          Container(
            decoration: BoxDecoration(
              color: _isSending ? Colors.grey[300] : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              onPressed: _isSending ? null : _sendMessage,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  final AiMessage message;
  const _AssistantMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final actionButtons = (message.meta?['actionButtons'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de l'assistant
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          
          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.assistantMessageBg,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.messageBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.content,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
                
                // Boutons d'action
                if (actionButtons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actionButtons.map((btnData) {
                        final label = (btnData['label'] ?? 'Action').toString();
                        return ActionChip(
                          label: Text(label, style: const TextStyle(color: AppTheme.primaryColor)),
                          onPressed: () {},
                          backgroundColor: AppTheme.backgroundColor,
                          side: const BorderSide(color: AppTheme.messageBorder),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  final String text;
  const _UserMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.userMessageBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
