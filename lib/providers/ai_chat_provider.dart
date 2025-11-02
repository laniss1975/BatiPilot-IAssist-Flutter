import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test1/models/ai_chat_model.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// --- Modèles de Données Locaux ---

// Représentation d'un message dans l'UI
class AiMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.meta,
    required this.createdAt,
  });

  /// Crée un AiMessage depuis une ligne de la BD
  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      meta: json['meta'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// L'état géré par notre notifier
class AiChatState {
  final String? currentChatId;
  final String? currentChatTitle;
  final String module;
  final List<AiMessage> messages;
  final bool isLoading;

  AiChatState({
    this.currentChatId,
    this.currentChatTitle,
    this.module = 'context',
    this.messages = const [],
    this.isLoading = false,
  });

  AiChatState copyWith({
    String? currentChatId,
    String? currentChatTitle,
    String? module,
    List<AiMessage>? messages,
    bool? isLoading,
  }) {
    return AiChatState(
      currentChatId: currentChatId ?? this.currentChatId,
      currentChatTitle: currentChatTitle ?? this.currentChatTitle,
      module: module ?? this.module,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// --- StateNotifier et Provider ---

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(AiChatState());

  SupabaseClient? get _supabase => _ref.read(supabaseConnectionProvider).client;
  String? get _userId => _ref.read(authStateProvider).value?.session?.user.id;

  /// Crée un nouveau chat vide
  Future<void> createNewChat({required String module}) async {
    final client = _supabase;
    final userId = _userId;
    if (client == null || userId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final title = AiChat.generateDefaultTitle();
      final response = await client.from('ai_chats_flut').insert({
        'user_id': userId,
        'module_name': module,
        'title': title,
      }).select().single();

      state = AiChatState(
        currentChatId: response['id'],
        currentChatTitle: response['title'],
        module: module,
        messages: [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Charge un chat existant avec tous ses messages
  Future<void> loadChat({required String chatId, required String chatTitle}) async {
    final client = _supabase;
    if (client == null) return;

    state = state.copyWith(isLoading: true);

    try {
      // Charger tous les messages du chat
      final messagesData = await client
          .from('ai_chat_messages_flut')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      final messages = (messagesData as List)
          .map((msg) => AiMessage.fromJson(msg as Map<String, dynamic>))
          .toList();

      state = AiChatState(
        currentChatId: chatId,
        currentChatTitle: chatTitle,
        module: 'context',
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Assure qu'une conversation est active, en crée une si besoin (pour backward compatibility)
  Future<void> ensureCurrentChat({required String module}) async {
    if (state.currentChatId != null && state.module == module) return;

    await createNewChat(module: module);
  }

  /// Ajoute un message utilisateur
  Future<void> addUserMessage(String text) async {
    final client = _supabase;
    if (client == null || state.currentChatId == null) return;

    // Ajout optimiste à l'UI
    final tempId = DateTime.now().toIso8601String();
    final tempMessage =
        AiMessage(id: tempId, role: 'user', content: text, createdAt: DateTime.now());
    state = state.copyWith(messages: [...state.messages, tempMessage]);

    try {
      await client.from('ai_chat_messages_flut').insert({
        'chat_id': state.currentChatId,
        'role': 'user',
        'content': text,
      });
    } catch (e) {
      // Gérer l'échec de la sauvegarde
    }
  }

  /// Ajoute un message assistant
  Future<void> addAssistantMessage(String text, {Map<String, dynamic>? meta}) async {
    final client = _supabase;
    if (client == null || state.currentChatId == null) return;

    final tempId = DateTime.now().toIso8601String();
    final tempMessage = AiMessage(
      id: tempId,
      role: 'assistant',
      content: text,
      meta: meta,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, tempMessage]);

    try {
      await client.from('ai_chat_messages_flut').insert({
        'chat_id': state.currentChatId,
        'role': 'assistant',
        'content': text,
        'meta': meta,
      });
    } catch (e) {
      // Gérer l'échec
    }
  }

  /// Vide le chat courant (pour commencer un nouveau)
  void clearCurrentChat() {
    state = AiChatState();
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
