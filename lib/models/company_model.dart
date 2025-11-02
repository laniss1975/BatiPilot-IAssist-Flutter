// lib/models/company_model.dart

class Company {
  final String id;
  final DateTime createdAt;
  final String name;
  final String? prenom;
  final String? email;
  final String? tel1;
  final String? tel2;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? type;
  final String? capitalSocial;
  final String? siret;
  final String? tvaIntracom;
  final String? codeApe;
  final String? slogan;
  final String? notes;
  final String? logoUrl;
  final String? rib;
  final String? bic;
  final String userId;

  Company({
    required this.id,
    required this.createdAt,
    required this.name,
    this.prenom,
    this.email,
    this.tel1,
    this.tel2,
    this.address,
    this.city,
    this.postalCode,
    this.type,
    this.capitalSocial,
    this.siret,
    this.tvaIntracom,
    this.codeApe,
    this.slogan,
    this.notes,
    this.logoUrl,
    this.rib,
    this.bic,
    required this.userId,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      name: json['name'] as String,
      prenom: json['prenom'] as String?,
      email: json['email'] as String?,
      tel1: json['tel1'] as String?,
      tel2: json['tel2'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      postalCode: json['postal_code'] as String?,
      type: json['type'] as String?,
      capitalSocial: json['capital_social'] as String?,
      siret: json['siret'] as String?,
      tvaIntracom: json['tva_intracom'] as String?,
      codeApe: json['code_ape'] as String?,
      slogan: json['slogan'] as String?,
      notes: json['notes'] as String?,
      logoUrl: json['logo_url'] as String?,
      rib: json['rib'] as String?,
      bic: json['bic'] as String?,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'name': name,
        'prenom': prenom,
        'email': email,
        'tel1': tel1,
        'tel2': tel2,
        'address': address,
        'city': city,
        'postal_code': postalCode,
        'type': type,
        'capital_social': capitalSocial,
        'siret': siret,
        'tva_intracom': tvaIntracom,
        'code_ape': codeApe,
        'slogan': slogan,
        'notes': notes,
        'logo_url': logoUrl,
        'rib': rib,
        'bic': bic,
        'user_id': userId,
      };
}
