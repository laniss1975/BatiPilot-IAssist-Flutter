import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

/// Stream de l’état d’auth Supabase en fonction du client courant.
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final client = ref.watch(supabaseConnectionProvider).client;
  if (client == null) {
    yield const AuthState(AuthChangeEvent.signedOut, null);
    return;
  }
  final current = client.auth.currentSession;
  if (current != null) {
    yield AuthState(AuthChangeEvent.initialSession, current);
  } else {
    yield const AuthState(AuthChangeEvent.signedOut, null);
  }
  yield* client.auth.onAuthStateChange;
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final _secureStorage = const FlutterSecureStorage();
  static const _authEmailKey = 'authEmail';
  static const _authPasswordKey = 'authPassword';

  AuthNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<SupabaseClient> _requireClient() async {
    var client = _ref.read(supabaseConnectionProvider).client;
    if (client != null) return client;

    // Essaie d’auto-connect si des credentials serveur existent.
    await _ref.read(supabaseConnectionProvider.notifier).autoConnect();
    client = _ref.read(supabaseConnectionProvider).client;
    if (client == null) throw Exception('Client Supabase non initialisé.');
    return client;
  }

  /// Sign-in simple (nécessite un client Supabase déjà connecté).
  Future<void> signIn(String email, String password, bool rememberMe) async {
    state = const AsyncValue.loading();
    try {
      final client = await _requireClient();
      await client.auth.signInWithPassword(email: email, password: password);
      if (rememberMe) {
        await _saveCredentials(email, password);
      } else {
        await _deleteCredentials();
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// “Double verrou”: on tente signIn, si ça échoue → déconnexion immédiate du serveur.
  Future<void> signInAndGuard(String email, String password, {bool rememberMe = true}) async {
    try {
      await signIn(email, password, rememberMe);
    } catch (e) {
      // Déconnecte le serveur si l’auth échoue.
      await _ref.read(supabaseConnectionProvider.notifier).disconnect();
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final client = await _requireClient();
      await client.auth.signOut();
      await _deleteCredentials();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Tentative d’auto-connexion utilisateur si email/mdp sont stockés.
  Future<void> autoSignIn() async {
    final creds = await _loadCredentials();
    if (creds != null) {
      try {
        // IMPORTANT: on passe true pour conserver les credentials
        await signIn(creds['email']!, creds['password']!, true);
      } catch (_) {
        // On ignore si ça échoue.
      }
    }
  }

  // Secure storage helpers
  Future<void> _saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _authEmailKey, value: email);
    await _secureStorage.write(key: _authPasswordKey, value: password);
  }

  Future<Map<String, String>?> _loadCredentials() async {
    final email = await _secureStorage.read(key: _authEmailKey);
    final password = await _secureStorage.read(key: _authPasswordKey);
    if (email != null && password != null) return {'email': email, 'password': password};
    return null;
  }

  Future<void> _deleteCredentials() async {
    await _secureStorage.delete(key: _authEmailKey);
    await _secureStorage.delete(key: _authPasswordKey);
  }
}

final authNotifierProvider =
StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref);
});
