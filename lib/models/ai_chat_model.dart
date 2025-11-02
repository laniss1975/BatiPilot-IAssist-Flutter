import 'package:intl/intl.dart';

class AiChat {
  final String id;
  final String userId;
  final String title;
  final String moduleName;
  final String? providerName;
  final String? modelName;
  final String? systemPromptSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiChat({
    required this.id,
    required this.userId,
    required this.title,
    required this.moduleName,
    this.providerName,
    this.modelName,
    this.systemPromptSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crée un AiChat depuis un JSON (réponse Supabase)
  factory AiChat.fromJson(Map<String, dynamic> json) {
    return AiChat(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Chat sans titre',
      moduleName: json['module_name'] as String? ?? 'context',
      providerName: json['provider_name'] as String?,
      modelName: json['model_name'] as String?,
      systemPromptSnapshot: json['system_prompt_snapshot'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convertit en Map pour envoi à Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'module_name': moduleName,
      'provider_name': providerName,
      'model_name': modelName,
      'system_prompt_snapshot': systemPromptSnapshot,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crée un nouveau chat avec un titre auto-généré
  static String generateDefaultTitle() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM - HH:mm');
    return 'Chat du ${formatter.format(now)}';
  }

  /// Copie l'objet avec des modifications
  AiChat copyWith({
    String? id,
    String? userId,
    String? title,
    String? moduleName,
    String? providerName,
    String? modelName,
    String? systemPromptSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiChat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      moduleName: moduleName ?? this.moduleName,
      providerName: providerName ?? this.providerName,
      modelName: modelName ?? this.modelName,
      systemPromptSnapshot: systemPromptSnapshot ?? this.systemPromptSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
