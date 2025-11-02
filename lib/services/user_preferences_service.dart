import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Le service lui-même
class UserPreferencesService {
  final SharedPreferences _prefs;

  UserPreferencesService(this._prefs);

  static const _selectedCompanyIdKey = 'selectedCompanyId';

  // Méthode pour sauvegarder l'ID
  Future<void> saveSelectedCompanyId(String id) async {
    await _prefs.setString(_selectedCompanyIdKey, id);
  }

  // Méthode pour lire l'ID
  String? getSelectedCompanyId() {
    return _prefs.getString(_selectedCompanyIdKey);
  }
}

// 2. Un FutureProvider pour initialiser SharedPreferences une seule fois
final _prefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// 3. Le Provider de notre service, qui dépend du FutureProvider précédent
final userPreferencesServiceProvider = Provider<UserPreferencesService?>((ref) {
  // Il écoute le FutureProvider et ne retournera le service que lorsque
  // SharedPreferences sera prêt.
  return ref.watch(_prefsProvider).when(
        data: (prefs) => UserPreferencesService(prefs),
        loading: () => null,
        error: (_, __) => null,
      );
});
