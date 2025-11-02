// lib/models/client_model.dart

class Client {
  final String id;
  final DateTime createdAt;
  final String nom;
  final String? prenom;
  final String? adresse;
  final String? codePostal;
  final String? ville;
  final String? tel1;
  final String? tel2;
  final String? email;
  final String? clientTypeId;
  final String? autreInfo;
  final String? infosComplementaires;
  final String userId;

  Client({
    required this.id,
    required this.createdAt,
    required this.nom,
    this.prenom,
    this.adresse,
    this.codePostal,
    this.ville,
    this.tel1,
    this.tel2,
    this.email,
    this.clientTypeId,
    this.autreInfo,
    this.infosComplementaires,
    required this.userId,
  });

  String get fullName => '$nom ${prenom ?? ''}'.trim();

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      nom: json['nom'] as String,
      prenom: json['prenom'] as String?,
      adresse: json['adresse'] as String?,
      codePostal: json['code_postal'] as String?,
      ville: json['ville'] as String?,
      tel1: json['tel1'] as String?,
      tel2: json['tel2'] as String?,
      email: json['email'] as String?,
      clientTypeId: json['client_type_id'] as String?,
      autreInfo: json['autre_info'] as String?,
      infosComplementaires: json['infos_complementaires'] as String?,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'nom': nom,
        'prenom': prenom,
        'adresse': adresse,
        'code_postal': codePostal,
        'ville': ville,
        'tel1': tel1,
        'tel2': tel2,
        'email': email,
        'client_type_id': clientTypeId,
        'autre_info': autreInfo,
        'infos_complementaires': infosComplementaires,
        'user_id': userId,
      };
}
