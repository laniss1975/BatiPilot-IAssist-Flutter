// lib/models/client_type_model.dart

class ClientType {
  final String id;
  final DateTime createdAt;
  final String name;
  final String userId;

  ClientType({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.userId,
  });

  factory ClientType.fromJson(Map<String, dynamic> json) {
    return ClientType(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      name: json['name'] as String,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'name': name,
        'user_id': userId,
      };
}
