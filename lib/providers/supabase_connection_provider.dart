import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- 1. Définition des états ---

enum ConnectionStatus { disconnected, connected, error, connecting }

class SupabaseConnectionState {
  final ConnectionStatus status;
  final SupabaseClient? client;
  final String? url;
  final String? errorMessage;

  SupabaseConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.client,
    this.url,
    this.errorMessage,
  });
}

// --- 2. Le StateNotifier ---

class SupabaseConnectionNotifier extends StateNotifier<SupabaseConnectionState> {
  SupabaseConnectionNotifier() : super(SupabaseConnectionState());

  final _secureStorage = const FlutterSecureStorage();
  static const _supabaseUrlKey = 'supabaseUrl';
  static const _supabaseAnonKey = 'supabaseAnonKey';

  Future<void> connect(String url, String anonKey, {bool persist = true}) async {
    state = SupabaseConnectionState(status: ConnectionStatus.connecting, url: url);
    try {
      final client = SupabaseClient(url, anonKey);

      // Test optionnel (peut échouer si RLS bloque l'anon)
      await client.from('companies').select('name').limit(1);

      if (persist) {
        await _saveCredentials(url, anonKey);
      }
      state = SupabaseConnectionState(
        status: ConnectionStatus.connected,
        client: client,
        url: url,
      );
    } catch (e) {
      state = SupabaseConnectionState(
        status: ConnectionStatus.error,
        url: url,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // Devient async pour pouvoir être "await"
  Future<void> disconnect({bool clearStorage = true}) async {
    try {
      if (state.client != null) {
        await state.client!.auth.signOut();
      }
    } catch (_) {
      // ignore
    }
    if (clearStorage) {
      await _deleteCredentials();
    }
    state = SupabaseConnectionState(); // reset → disconnected
  }

  Future<void> autoConnect() async {
    final credentials = await _loadCredentials();
    if (credentials != null) {
      await connect(credentials['url']!, credentials['key']!);
    }
  }

  Future<Map<String, String>?> getCredentials() async {
    return _loadCredentials();
  }

  // --- Helpers pour le stockage sécurisé ---

  Future<void> _saveCredentials(String url, String anonKey) async {
    await _secureStorage.write(key: _supabaseUrlKey, value: url);
    await _secureStorage.write(key: _supabaseAnonKey, value: anonKey);
  }

  Future<Map<String, String>?> _loadCredentials() async {
    final url = await _secureStorage.read(key: _supabaseUrlKey);
    final key = await _secureStorage.read(key: _supabaseAnonKey);
    if (url != null && key != null) {
      return {'url': url, 'key': key};
    }
    return null;
  }

  Future<void> _deleteCredentials() async {
    await _secureStorage.delete(key: _supabaseUrlKey);
    await _secureStorage.delete(key: _supabaseAnonKey);
  }
}

// --- 3. Le Provider ---

final supabaseConnectionProvider = StateNotifierProvider<SupabaseConnectionNotifier, SupabaseConnectionState>((ref) {
  return SupabaseConnectionNotifier();
});