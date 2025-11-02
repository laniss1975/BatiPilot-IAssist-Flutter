import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/user_api_key_model.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// Provider pour récupérer toutes les clés API de l'utilisateur
final userApiKeysProvider = StreamProvider.autoDispose<List<UserApiKey>>((ref) async* {
  final client = ref.watch(supabaseConnectionProvider).client;
  final userId = ref.watch(authStateProvider).value?.session?.user.id;

  if (client == null || userId == null) {
    yield [];
    return;
  }

  final stream = client
      .from('user_api_keys')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data
          .where((json) => json['user_id'] == userId)
          .map((json) => UserApiKey.fromJson(json))
          .toList());

  await for (final keys in stream) {
    yield keys;
  }
});

// Provider pour récupérer les clés d'un modèle spécifique
final modelApiKeysProvider = StreamProvider.autoDispose.family<List<UserApiKey>, ModelIdentifier>((ref, identifier) async* {
  final client = ref.watch(supabaseConnectionProvider).client;
  final userId = ref.watch(authStateProvider).value?.session?.user.id;

  if (client == null || userId == null) {
    yield [];
    return;
  }

  final stream = client
      .from('user_api_keys')
      .stream(primaryKey: ['id'])
      .order('is_active', ascending: false)
      .order('created_at', ascending: false)
      .map((data) => data
          .where((json) => 
              json['user_id'] == userId &&
              json['provider_key'] == identifier.providerKey &&
              (json['model_key'] == identifier.modelKey || json['model_key'] == null))
          .map((json) => UserApiKey.fromJson(json))
          .toList());

  await for (final keys in stream) {
    yield keys;
  }
});

// Notifier pour gérer les actions CRUD sur les clés API
class ApiKeysNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ApiKeysNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addKey({
    required String providerKey,
    String? modelKey,
    required String keyName,
    required String apiKey,
    String? notes,
    bool setAsActive = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseConnectionProvider).client;
      final userId = _ref.read(authStateProvider).value?.session?.user.id;

      if (client == null || userId == null) {
        throw Exception('Non connecté');
      }

      // Appeler la edge function pour chiffrer et stocker la clé
      final response = await client.functions.invoke('ai-keys-manager', body: {
        'action': 'add-key',
        'provider': providerKey,
        'model': modelKey,
        'keyName': keyName,
        'apiKey': apiKey,
        'notes': notes,
        'setAsActive': setAsActive,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Erreur lors de l\'ajout de la clé');
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateKey({
    required String keyId,
    String? keyName,
    String? newApiKey,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseConnectionProvider).client;
      
      if (client == null) throw Exception('Non connecté');

      final response = await client.functions.invoke('ai-keys-manager', body: {
        'action': 'update-key',
        'keyId': keyId,
        'keyName': keyName,
        'newApiKey': newApiKey,
        'notes': notes,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Erreur lors de la mise à jour');
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setActiveKey(String keyId) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseConnectionProvider).client;
      
      if (client == null) throw Exception('Non connecté');

      await client
          .from('user_api_keys')
          .update({'is_active': true})
          .eq('id', keyId);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteKey(String keyId) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseConnectionProvider).client;
      
      if (client == null) throw Exception('Non connecté');

      final response = await client.functions.invoke('ai-keys-manager', body: {
        'action': 'delete-key',
        'keyId': keyId,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Erreur lors de la suppression');
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final apiKeysNotifierProvider = StateNotifierProvider<ApiKeysNotifier, AsyncValue<void>>((ref) {
  return ApiKeysNotifier(ref);
});

// Classe helper pour identifier un modèle
class ModelIdentifier {
  final String providerKey;
  final String modelKey;

  const ModelIdentifier({required this.providerKey, required this.modelKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelIdentifier &&
          runtimeType == other.runtimeType &&
          providerKey == other.providerKey &&
          modelKey == other.modelKey;

  @override
  int get hashCode => providerKey.hashCode ^ modelKey.hashCode;
}
