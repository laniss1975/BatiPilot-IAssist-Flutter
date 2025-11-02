import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/ai_chat_model.dart';
import 'package:test1/providers/ai_chat_provider.dart';
import 'package:test1/providers/ai_chats_history_provider.dart';
import 'package:test1/ui/theme/app_theme.dart';

class ChatSelector extends ConsumerStatefulWidget {
  const ChatSelector({super.key});

  @override
  ConsumerState<ChatSelector> createState() => _ChatSelectorState();
}

class _ChatSelectorState extends ConsumerState<ChatSelector> {
  bool _autoLoadedFirstChat = false;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final chatsAsync = ref.watch(aiChatsHistoryProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.messageBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                // Charger le premier chat si aucun n'est sélectionné et pas encore fait
                if (chats.isNotEmpty && chatState.currentChatId == null && !_autoLoadedFirstChat) {
                  _autoLoadedFirstChat = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(aiChatProvider.notifier).loadChat(
                          chatId: chats.first.id,
                          chatTitle: chats.first.title,
                        );
                  });
                }

                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.messageBorder),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButton<String>(
                          value: chatState.currentChatId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const SelectableText(
                            'Selectionner une discussion...',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          items: chats.map((chat) {
                            return DropdownMenuItem<String>(
                              value: chat.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      chat.title,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      _showRenameDialog(context, ref, chat.id, chat.title);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      _showDeleteConfirmation(context, ref, chat.id, chat.title);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (chatId) {
                            if (chatId != null) {
                              final selectedChat =
                                  chats.firstWhere((c) => c.id == chatId);
                              ref.read(aiChatProvider.notifier).loadChat(
                                    chatId: selectedChat.id,
                                    chatTitle: selectedChat.title,
                                  );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Commencer une nouvelle discussion',
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 20),
                          onPressed: () async {
                            await ref.read(aiChatProvider.notifier).createNewChat(
                                  module: 'context',
                                );
                            await ref.read(aiChatsHistoryProvider.notifier).loadChats();
                          },
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => Row(
                children: [
                  const Expanded(
                    child: SizedBox(
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ],
              ),
              error: (err, stack) => Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.errorColor),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.errorColor.withOpacity(0.1),
                      ),
                      child: SelectableText(
                        'Erreur: ${err.toString()}',
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String chatId,
    String chatTitle,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const SelectableText('Supprimer cette discussion ?'),
        content: SelectableText(
          'Etes-vous sur de vouloir supprimer definitivement "$chatTitle" ?\n\nCette action ne peut pas etre annulee.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SelectableText('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ref
                  .read(aiChatsHistoryProvider.notifier)
                  .deleteChat(chatId);

              if (success && context.mounted) {
                if (ref.read(aiChatProvider).currentChatId == chatId) {
                  ref.read(aiChatProvider.notifier).clearCurrentChat();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: SelectableText('Discussion supprimee'),
                    backgroundColor: AppTheme.accentColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const SelectableText(
              'Supprimer',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String chatId,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const SelectableText('Renommer la discussion'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nouveau titre',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) async {
            final newTitle = controller.text.trim();
            if (newTitle.isNotEmpty) {
              Navigator.pop(context);

              final success = await ref
                  .read(aiChatsHistoryProvider.notifier)
                  .renameChat(chatId, newTitle);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: SelectableText('Discussion renommee'),
                    backgroundColor: AppTheme.accentColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SelectableText('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(context);

                final success = await ref
                    .read(aiChatsHistoryProvider.notifier)
                    .renameChat(chatId, newTitle);

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: SelectableText('Discussion renommee'),
                      backgroundColor: AppTheme.accentColor,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const SelectableText('Renommer'),
          ),
        ],
      ),
    );
  }
}
