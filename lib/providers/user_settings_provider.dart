import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// --- Modèle de Données ---
class UserSettings {
  final String? selectedCompanyId;

  UserSettings({this.selectedCompanyId});

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      selectedCompanyId: json['selected_company_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'selected_company_id': selectedCompanyId,
  };

  UserSettings copyWith({String? selectedCompanyId}) {
    return UserSettings(
      selectedCompanyId: selectedCompanyId ?? this.selectedCompanyId,
    );
  }
}

// --- Notifier et Provider ---

class UserSettingsNotifier extends AsyncNotifier<UserSettings?> {
  @override
  Future<UserSettings?> build() async {
    final supabase = ref.watch(supabaseConnectionProvider).client;
    final user = ref.watch(authStateProvider).value?.session?.user;

    if (supabase == null || user == null) {
      return null; // Pas de paramètres si pas connecté/authentifié
    }

    final data = await supabase
        .from('user_settings')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (data == null) {
      // Si l'utilisateur n'a pas encore de ligne de paramètres, on en crée une vide
      return UserSettings();
    }

    return UserSettings.fromJson(data);
  }

  // Méthode pour mettre à jour les paramètres
  Future<void> updateSettings({String? selectedCompanyId}) async {
    final supabase = ref.read(supabaseConnectionProvider).client;
    final user = ref.read(authStateProvider).value?.session?.user;

    if (supabase == null || user == null) return;

    final newSettings = (state.value ?? UserSettings()).copyWith(
      selectedCompanyId: selectedCompanyId,
    );
    
    // On met à jour l'état local immédiatement pour la réactivité
    state = AsyncValue.data(newSettings);
    
    // On met à jour la base de données en arrière-plan
    await supabase.from('user_settings').upsert({
      'user_id': user.id,
      'selected_company_id': selectedCompanyId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

final userSettingsProvider = AsyncNotifierProvider<UserSettingsNotifier, UserSettings?>(UserSettingsNotifier.new);
