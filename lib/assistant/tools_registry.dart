import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/assistant_models.dart';

// --- Définition d'un Tool ---
// Utiliser Ref (générique) plutôt que WidgetRef
typedef ToolHandler = Future<void> Function({
required Map<String, dynamic> payload,
required Ref ref,
required BuildContext context,
});

// --- Le Registre de Tools ---
class ToolsRegistry {
  final Map<String, ToolHandler> _handlers = {};

  // Enregistre un nouveau tool
  void register(String type, ToolHandler handler) {
    _handlers[type] = handler;
  }

  // Exécute le tool correspondant au type du ContextUpdate
  Future<void> dispatch(ContextUpdate update, Ref ref, BuildContext context) async {
    final handler = _handlers[update.type];
    if (handler == null) {
      debugPrint('Aucun tool enregistré pour le type: ${update.type}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action non supportée: ${update.type}')),
      );
      return;
    }

    await handler(payload: update.payload, ref: ref, context: context);
  }
}

// --- Exemples de Tools (stubs) ---
// À brancher plus tard sur la logique métier (navigation, écriture DB, etc.)

Future<void> navigateTool({
  required Map<String, dynamic> payload,
  required Ref ref,
  required BuildContext context,
}) async {
  final path = (payload['path'] ?? '/').toString();
  debugPrint('Action NAVIGATE: Redirection vers $path');

  // TODO: branche ta navigation:
  // - Avec GoRouter: context.go(path);
  // - Avec Navigator: Navigator.of(context).pushNamed(path);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Navigation demandée vers: $path')),
  );
}

Future<void> addWorkTool({
  required Map<String, dynamic> payload,
  required Ref ref,
  required BuildContext context,
}) async {
  debugPrint('Action ADD_TRAVAIL: Données -> $payload');

  // Exemple si tu veux lire le client Supabase:
  // final client = ref.read(supabaseConnectionProvider).client;
  // await client?.from('...').insert({...});

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Une nouvelle prestation a été ajoutée.')),
  );
}