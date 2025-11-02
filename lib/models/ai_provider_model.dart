// lib/models/ai_provider_model.dart

class AiProvider {
  final String id;
  final String providerKey;
  final String providerName;
  final bool isActive;
  final String? apiEndpoint;
  final Map<String, dynamic>? apiHeaders;
  final String? authMethod;

  AiProvider({
    required this.id,
    required this.providerKey,
    required this.providerName,
    required this.isActive,
    this.apiEndpoint,
    this.apiHeaders,
    this.authMethod,
  });

  factory AiProvider.fromJson(Map<String, dynamic> json) {
    return AiProvider(
      id: json['id'] as String,
      providerKey: json['provider_key'] as String,
      providerName: json['provider_name'] as String,
      isActive: json['is_active'] as bool,
      apiEndpoint: json['api_endpoint'] as String?,
      apiHeaders: (json['api_headers'] as Map?)?.cast<String, dynamic>(),
      authMethod: json['api_auth_method'] as String?,
    );
  }
}
