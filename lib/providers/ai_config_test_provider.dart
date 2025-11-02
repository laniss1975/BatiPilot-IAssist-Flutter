import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/providers/active_model_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// --- Modèle de Données pour le Résultat du Test ---
class AiConfigTestResult {
  final bool apiKeyOk;
  final bool modelAccessible;
  final String details;

  AiConfigTestResult({
    required this.apiKeyOk,
    required this.modelAccessible,
    required this.details,
  });

  factory AiConfigTestResult.fromJson(Map<String, dynamic> json) {
    return AiConfigTestResult(
      apiKeyOk: json['api_key_ok'] as bool? ?? false,
      modelAccessible: json['model_accessible'] as bool? ?? false,
      details: json['details'] as String? ?? 'Aucun détail',
    );
  }
}

// --- FutureProvider pour le Test ---

final aiConfigTestProvider = FutureProvider<AiConfigTestResult?>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  final activeModel = ref.watch(activeModelProvider);

  if (supabase == null || activeModel.value == null) {
    return null;
  }
  
  try {
    final response = await supabase.functions.invoke('ai-config-test');
    if (response.data is Map<String, dynamic>) {
      return AiConfigTestResult.fromJson(response.data);
    } else {
      throw Exception("Réponse invalide de la fonction de test.");
    }
  } catch (e) {
    return AiConfigTestResult(
      apiKeyOk: false,
      modelAccessible: false,
      details: e.toString(),
    );
  }
});

// --- Provider pour le statut des clés API ---

final userApiKeysStatusProvider = FutureProvider<List<String>>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  if (supabase == null) return [];

  final response = await supabase.functions.invoke('ai-keys-manager', body: {
    'action': 'get-status',
  });

  if (response.data is Map<String, dynamic>) {
    final responseData = response.data as Map<String, dynamic>;
    // On vérifie la structure de la réponse de la fonction
    if (responseData['success'] == true && responseData['data'] is Map<String, dynamic>) {
      final keysData = responseData['data'] as Map<String, dynamic>;
      // On retourne la liste des clés où la valeur est `true`
      return keysData.entries.where((entry) => entry.value == true).map((entry) => entry.key).toList();
    }
  }
  
  // En cas d'erreur ou de format inattendu, on retourne une liste vide
  return [];
});
