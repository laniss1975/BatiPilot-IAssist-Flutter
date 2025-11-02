// lib/models/designation_model.dart
import 'travail_model.dart';

class Designation {
  final String id;
  final String name;
  final double? longueur;
  final double? largeur;
  final double? hauteur;
  final List<Travail> travaux;

  Designation({
    required this.id,
    required this.name,
    this.longueur,
    this.largeur,
    this.hauteur,
    this.travaux = const [],
  });

  // Méthode pour convertir un objet Designation en JSON (Map)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'longueur': longueur,
        'largeur': largeur,
        'hauteur': hauteur,
        'travaux': travaux.map((t) => t.toJson()).toList(), // Convertit chaque Travail en JSON
      };

  // Constructeur factory pour créer un objet Designation à partir d'un JSON (Map)
  factory Designation.fromJson(Map<String, dynamic> json) {
    var travauxListJson = json['travaux'] as List<dynamic>?; // Peut être null
    List<Travail> travaux = [];
    if (travauxListJson != null) {
      travaux = travauxListJson
          .map((tJson) => Travail.fromJson(tJson as Map<String, dynamic>))
          .toList();
    }

    return Designation(
      id: json['id'] as String,
      name: json['name'] as String,
      longueur: (json['longueur'] as num?)?.toDouble(), // Gère les nullables et num
      largeur: (json['largeur'] as num?)?.toDouble(),
      hauteur: (json['hauteur'] as num?)?.toDouble(),
      travaux: travaux,
    );
  }

  Designation copyWith({
    String? id,
    String? name,
    double? longueur,
    double? largeur,
    double? hauteur,
    List<Travail>? travaux,
  }) {
    return Designation(
      id: id ?? this.id,
      name: name ?? this.name,
      longueur: longueur ?? this.longueur,
      largeur: largeur ?? this.largeur,
      hauteur: hauteur ?? this.hauteur,
      travaux: travaux ?? this.travaux,
    );
  }
}
