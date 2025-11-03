// Model: AiPrompt
// Description: Représente un prompt système pour l'assistant IA
// Table: ai_prompts

class AiPrompt {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String key;
  final String title;
  final String content;
  final String userId;

  AiPrompt({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.key,
    required this.title,
    required this.content,
    required this.userId,
  });

  /// Créer un AiPrompt depuis JSON (depuis Supabase)
  factory AiPrompt.fromJson(Map<String, dynamic> json) {
    return AiPrompt(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      key: json['key'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      userId: json['user_id'] as String,
    );
  }

  /// Convertir en JSON (pour Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'key': key,
      'title': title,
      'content': content,
      'user_id': userId,
    };
  }

  /// Copier avec modifications
  AiPrompt copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? key,
    String? title,
    String? content,
    String? userId,
  }) {
    return AiPrompt(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      key: key ?? this.key,
      title: title ?? this.title,
      content: content ?? this.content,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'AiPrompt(id: $id, key: $key, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AiPrompt &&
        other.id == id &&
        other.key == key &&
        other.title == title &&
        other.content == content &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        key.hashCode ^
        title.hashCode ^
        content.hashCode ^
        userId.hashCode;
  }
}
