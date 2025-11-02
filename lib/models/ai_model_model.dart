// lib/models/ai_model_model.dart

class AiModel {
  final String id;
  final String modelKey;
  final String modelName;
  final bool isActive;
  final String providerKey; // Clé du provider, ex: 'openai'

  AiModel({
    required this.id,
    required this.modelKey,
    required this.modelName,
    required this.isActive,
    required this.providerKey,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    // Utiliser directement provider_key de la table ai_models
    final providerKey = json['provider_key'] as String? ?? 'unknown';

    return AiModel(
      id: json['id'] as String,
      modelKey: json['model_key'] as String,
      modelName: json['model_name'] as String,
      isActive: json['is_active'] as bool,
      providerKey: providerKey,
    );
  }
}
