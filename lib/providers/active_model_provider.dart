import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// --- Modèle de Données ---
class ActiveModelConfig {
  final String providerName;
  final String modelName;

  ActiveModelConfig({
    required this.providerName,
    required this.modelName,
  });
}

// --- Notifier et Provider ---
class ActiveModelNotifier extends AsyncNotifier<ActiveModelConfig?> {
  static const _moduleName = 'global';

  @override
  Future<ActiveModelConfig?> build() async {
    final supabase = ref.watch(supabaseConnectionProvider).client;
    final user = ref.watch(authStateProvider).value?.session?.user;
    if (supabase == null || user == null) return null;

    final data = await supabase
        .from('ai_provider_configs')
        .select('provider_name, model_name')
        .eq('user_id', user.id)
        .eq('module_name', _moduleName)
        .eq('is_active', true)
        .maybeSingle();

    if (data == null) return null;
    return ActiveModelConfig(
      providerName: data['provider_name'] as String,
      modelName: data['model_name'] as String,
    );
  }

  /// Active un modèle global via la fonction SQL RPC ai_activate_global_model
  /// - providerKey: ex 'openai'
  /// - modelKey: ex 'gpt-4o-mini'
  /// - systemPrompt: snapshot optionnel (sinon null)
  Future<void> setActiveModel(
      String providerKey,
      String modelKey, {
        String? systemPrompt,
      }) async {
    final supabase = ref.read(supabaseConnectionProvider).client;
    final user = ref.read(authStateProvider).value?.session?.user;
    if (supabase == null || user == null) {
      state = AsyncValue.error(Exception('Non connecté'), StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();

    try {
      // Appel atomique à la RPC (désactive l’ancien + upsert/active le nouveau)
      await supabase.rpc('ai_activate_global_model', params: {
        'p_provider_name': providerKey,
        'p_model_name': modelKey,
        'p_system_prompt': systemPrompt, // peut rester null
        'p_module': _moduleName,        // explicite, même si 'global' par défaut côté SQL
      });

      // Rafraîchit l’état depuis la BDD (évite l’optimisme si jamais la RPC évolue)
      final fresh = await supabase
          .from('ai_provider_configs')
          .select('provider_name, model_name')
          .eq('user_id', user.id)
          .eq('module_name', _moduleName)
          .eq('is_active', true)
          .maybeSingle();

      if (fresh == null) {
        // Si aucune config active n’est trouvée (ne devrait pas arriver si RPC OK)
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(ActiveModelConfig(
        providerName: fresh['provider_name'] as String,
        modelName: fresh['model_name'] as String,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final activeModelProvider =
AsyncNotifierProvider<ActiveModelNotifier, ActiveModelConfig?>(
    ActiveModelNotifier.new);