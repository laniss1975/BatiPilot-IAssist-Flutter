import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test1/models/ai_chat_model.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

class AiChatsHistoryNotifier extends StateNotifier<AsyncValue<List<AiChat>>> {
  final Ref _ref;

  AiChatsHistoryNotifier(this._ref) : super(const AsyncValue.loading());

  SupabaseClient? get _supabase => _ref.read(supabaseConnectionProvider).client;
  String? get _userId => _ref.read(authStateProvider).value?.session?.user.id;

  Future<void> loadChats() async {
    final client = _supabase;
    final userId = _userId;

    if (client == null || userId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final response = await client
          .from('ai_chats_flut')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .withConverter((data) => (data as List)
              .map((chat) => AiChat.fromJson(chat as Map<String, dynamic>))
              .toList());

      state = AsyncValue.data(response);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<AiChat?> createNewChat({required String title, required String moduleName}) async {
    final client = _supabase;
    final userId = _userId;

    if (client == null || userId == null) return null;

    try {
      final now = DateTime.now();
      final response = await client.from('ai_chats_flut').insert({
        'user_id': userId,
        'title': title,
        'module_name': moduleName,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).select().single();

      final newChat = AiChat.fromJson(response as Map<String, dynamic>);

      state.whenData((chats) {
        state = AsyncValue.data([newChat, ...chats]);
      });

      return newChat;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  Future<bool> deleteChat(String chatId) async {
    final client = _supabase;

    if (client == null) return false;

    try {
      await client.from('ai_chats_flut').delete().eq('id', chatId);

      state.whenData((chats) {
        state = AsyncValue.data(chats.where((c) => c.id != chatId).toList());
      });

      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> renameChat(String chatId, String newTitle) async {
    final client = _supabase;

    if (client == null) return false;

    try {
      await client
          .from('ai_chats_flut')
          .update({'title': newTitle, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      state.whenData((chats) {
        final updatedChats = chats.map((c) {
          if (c.id == chatId) {
            return c.copyWith(title: newTitle, updatedAt: DateTime.now());
          }
          return c;
        }).toList();
        state = AsyncValue.data(updatedChats);
      });

      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final aiChatsHistoryProvider =
    StateNotifierProvider<AiChatsHistoryNotifier, AsyncValue<List<AiChat>>>((ref) {
  return AiChatsHistoryNotifier(ref);
});
