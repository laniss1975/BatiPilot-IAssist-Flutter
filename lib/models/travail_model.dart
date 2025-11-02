// lib/models/travail_model.dart

class Travail {
  final String id;
  final String designationId; // Pour lier à une Designation
  final String name;
  final double quantite;
  final String unit; // "M²", "Ml", "Unité", etc.
  final double prixUnitaireHT;

  Travail({
    required this.id,
    required this.designationId,
    required this.name,
    required this.quantite,
    required this.unit,
    required this.prixUnitaireHT,
  });

  // Méthode pour convertir un objet Travail en JSON (Map)
  Map<String, dynamic> toJson() => {
        'id': id,
        'designationId': designationId,
        'name': name,
        'quantite': quantite,
        'unit': unit,
        'prixUnitaireHT': prixUnitaireHT,
      };

  // Constructeur factory pour créer un objet Travail à partir d'un JSON (Map)
  factory Travail.fromJson(Map<String, dynamic> json) {
    return Travail(
      id: json['id'] as String,
      designationId: json['designationId'] as String,
      name: json['name'] as String,
      quantite: (json['quantite'] as num).toDouble(), // num pour gérer int ou double
      unit: json['unit'] as String,
      prixUnitaireHT: (json['prixUnitaireHT'] as num).toDouble(),
    );
  }

  Travail copyWith({
    String? id,
    String? designationId,
    String? name,
    double? quantite,
    String? unit,
    double? prixUnitaireHT,
  }) {
    return Travail(
      id: id ?? this.id,
      designationId: designationId ?? this.designationId,
      name: name ?? this.name,
      quantite: quantite ?? this.quantite,
      unit: unit ?? this.unit,
      prixUnitaireHT: prixUnitaireHT ?? this.prixUnitaireHT,
    );
  }
}
