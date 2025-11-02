import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/assistant_models.dart';
import 'package:test1/providers/ai_chat_provider.dart';
import 'package:test1/providers/project_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
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

    try {
      // 2. On invoque la fonction
      final response = await supabase.functions.invoke(
        'assist_flut',
        body: {
          'module': module,
          'userMessage': userMessage,
          'projectState': projectState,
        },
      );

      // 3. On parse la réponse et on la retourne
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
}

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController(ref);
});
