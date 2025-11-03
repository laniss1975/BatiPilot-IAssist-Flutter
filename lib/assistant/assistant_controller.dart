import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/assistant_models.dart';
import 'package:test1/providers/ai_chat_provider.dart';
import 'package:test1/providers/project_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/providers/ai_prompts_provider.dart';
import 'tools_registry.dart';

class AssistantController {
  final Ref _ref;
  final ToolsRegistry _tools = ToolsRegistry();

  AssistantController(this._ref) {
    _tools.register('NAVIGATE', navigateTool);
    _tools.register('ADD_TRAVAIL', addWorkTool);
  }

  Future<void> handleUserMessage({required String text, required String module, required BuildContext context}) async {
    final chatNotifier = _ref.read(aiChatProvider.notifier);
    
    await chatNotifier.ensureCurrentChat(module: module);
    await chatNotifier.addUserMessage(text);

    // On remplace l'appel simulé par l'appel réel
    final assistantResponse = await _callRealModel(userMessage: text, module: module);

    if (assistantResponse.contextUpdate != null) {
      await _tools.dispatch(assistantResponse.contextUpdate!, _ref, context);
    }
    if (assistantResponse.navigationSignal != null) {
      await _tools.dispatch(
        ContextUpdate(type: 'NAVIGATE', payload: {'path': assistantResponse.navigationSignal!.path}),
        _ref,
        context,
      );
    }
    
    await chatNotifier.addAssistantMessage(assistantResponse.answer, meta: assistantResponse.toMeta());
  }

  // --- Véritable appel à la Edge Function ---
  Future<AssistantResponse> _callRealModel({required String userMessage, required String module}) async {
    final supabase = _ref.read(supabaseConnectionProvider).client;
    if (supabase == null) throw Exception("Client Supabase non initialisé.");

    // 1. On récupère l'état actuel du projet et on le convertit en JSON
    final projectState = _ref.read(projectProvider).toJson();

    // 2. Charger le prompt système depuis la BDD
    String systemPrompt = _getMinimalPrompt();

    try {
      // Tenter de charger le prompt_system depuis la BDD
      final promptSystem = await _ref.read(aiPromptsProvider.notifier).getPromptByKey('prompt_system');

      if (promptSystem != null) {
        systemPrompt = promptSystem.content;
        debugPrint('✅ Prompt système chargé depuis la BDD (${promptSystem.content.length} caractères)');
      } else {
        debugPrint('⚠️ Prompt système non trouvé en BDD, utilisation du prompt minimal');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement du prompt système: $e');
      // On continue avec le prompt minimal
    }

    try {
      // 3. On invoque la fonction avec le prompt système
      final response = await supabase.functions.invoke(
        'assist_flut',
        body: {
          'module': module,
          'userMessage': userMessage,
          'projectState': projectState,
          'systemPrompt': systemPrompt,  // 🆕 Ajout du prompt système
        },
      );

      // 4. On parse la réponse et on la retourne
      if (response.data is Map<String, dynamic>) {
        return AssistantResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception("La réponse de la fonction n'est pas un JSON valide.");
      }
    } catch (e) {
      debugPrint("Erreur lors de l'appel à la Edge Function: $e");
      // En cas d'erreur, on retourne une réponse par défaut pour ne pas crasher l'UI
      return AssistantResponse(answer: "Désolé, une erreur technique est survenue.");
    }
  }

  // Prompt minimal en dur (utilisé uniquement si la BDD est inaccessible)
  String _getMinimalPrompt() {
    return '''Tu es BatiPilot Assistant, l'IA de l'application BatiPilot IAssist.

Pour connaître ton rôle complet et tes capacités:
1. Charge le prompt avec key='prompt_system' depuis la table ai_prompts
2. Ce prompt contient la liste de tous les autres prompts disponibles
3. Charge les prompts spécifiques selon tes besoins

Si tu ne peux pas accéder à la base de données, réponds de manière générale et indique que tu as besoin d'accéder aux prompts système.''';
  }
}

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController(ref);
});
