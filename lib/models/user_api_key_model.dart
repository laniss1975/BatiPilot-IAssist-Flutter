// lib/models/user_api_key_model.dart

class UserApiKey {
  final String id;
  final String userId;
  final String providerKey;
  final String? modelKey; // null = valable pour tous les modèles du provider
  final String keyName;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserApiKey({
    required this.id,
    required this.userId,
    required this.providerKey,
    this.modelKey,
    required this.keyName,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserApiKey.fromJson(Map<String, dynamic> json) {
    return UserApiKey(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      providerKey: json['provider_key'] as String,
      modelKey: json['model_key'] as String?,
      keyName: json['key_name'] as String,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'provider_key': providerKey,
      'model_key': modelKey,
      'key_name': keyName,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserApiKey copyWith({
    String? id,
    String? userId,
    String? providerKey,
    String? modelKey,
    String? keyName,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserApiKey(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerKey: providerKey ?? this.providerKey,
      modelKey: modelKey ?? this.modelKey,
      keyName: keyName ?? this.keyName,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
