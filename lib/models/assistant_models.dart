// lib/models/assistant_models.dart

// Fichier basé sur le contrat JSON défini dans la documentation.

class AssistantResponse {
  final String answer;
  final ContextUpdate? contextUpdate;
  final NavigationSignal? navigationSignal;
  final List<ActionButton> actionButtons;

  AssistantResponse({
    required this.answer,
    this.contextUpdate,
    this.navigationSignal,
    this.actionButtons = const [],
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      answer: (json['answer'] ?? '').toString(),
      contextUpdate: json['contextUpdate'] is Map<String, dynamic>
          ? ContextUpdate.fromJson(json['contextUpdate'] as Map<String, dynamic>)
          : null,
      navigationSignal: json['navigationSignal'] is Map<String, dynamic>
          ? NavigationSignal.fromJson(json['navigationSignal'] as Map<String, dynamic>)
          : null,
      actionButtons: (json['actionButtons'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ActionButton.fromJson)
          .toList(),
    );
  }

  // Convertit l'objet en un format Map pour le stockage dans la colonne 'meta'
  Map<String, dynamic> toMeta() => {
    'contextUpdate': contextUpdate?.toJson(),
    'navigationSignal': navigationSignal?.toJson(),
    'actionButtons': actionButtons.map((e) => e.toJson()).toList(),
  };
}

class ContextUpdate {
  final String type;
  final Map<String, dynamic> payload;

  ContextUpdate({required this.type, required this.payload});

  factory ContextUpdate.fromJson(Map<String, dynamic> json) => ContextUpdate(
    type: (json['type'] ?? '').toString(),
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
  );

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class NavigationSignal {
  final String path;
  final String? message;

  NavigationSignal({required this.path, this.message});

  factory NavigationSignal.fromJson(Map<String, dynamic> json) => NavigationSignal(
    path: (json['path'] ?? '/').toString(),
    message: json['message']?.toString(),
  );

  Map<String, dynamic> toJson() => {'path': path, 'message': message};
}

class ActionButton {
  final String type;
  final String label;
  final Map<String, dynamic>? data;

  ActionButton({required this.type, required this.label, this.data});

  factory ActionButton.fromJson(Map<String, dynamic> json) => ActionButton(
    type: (json['type'] ?? '').toString(),
    label: (json['label'] ?? '').toString(),
    data: (json['data'] as Map?)?.cast<String, dynamic>(),
  );

  Map<String, dynamic> toJson() => {'type': type, 'label': label, 'data': data};
}
