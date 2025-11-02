// lib/models/project_model.dart
import 'designation_model.dart';

// --- Énumérations ---

// Utilisation d'un enum pour le statut du devis pour plus de sécurité de type
enum DevisStatus { brouillon, accepte, refuse, enAttente }

// --- Classe principale du Projet ---

class Project {
  // --- Champs principaux (correspondent aux colonnes de la BDD) ---
  final String id;
  final String? companyId;
  final String? clientId;
  final String projectName;
  final String devisNumber;
  final DateTime devisDate;
  final DevisStatus status;
  final String? referenceBonCommande;
  final DateTime? dateAcceptation;
  final double totalHt; // Sera calculé plus tard
  final DateTime createdAt;
  final DateTime updatedAt;

  // --- Données imbriquées (correspondent au JSON 'project_data') ---
  final ProjectMetadata metadata;
  final List<Designation> designations; // Remplacera 'property', 'travaux', etc. à terme

  Project({
    required this.id,
    this.companyId,
    this.clientId,
    required this.projectName,
    required this.devisNumber,
    required this.devisDate,
    this.status = DevisStatus.brouillon,
    this.referenceBonCommande,
    this.dateAcceptation,
    this.totalHt = 0.0,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
    this.designations = const [],
  });
  
  // --- Méthodes de sérialisation ---
  
  factory Project.fromJson(Map<String, dynamic> json) {
    var designationsListJson = json['designations'] as List<dynamic>? ?? [];
    List<Designation> designations = designationsListJson
        .map((dJson) => Designation.fromJson(dJson as Map<String, dynamic>))
        .toList();

    return Project(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      clientId: json['client_id'] as String?,
      projectName: json['project_name'] as String,
      devisNumber: json['devis_number'] as String,
      devisDate: DateTime.parse(json['devis_date'] as String),
      status: DevisStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => DevisStatus.brouillon),
      referenceBonCommande: json['reference_bon_commande'] as String?,
      dateAcceptation: json['date_acceptation'] != null ? DateTime.parse(json['date_acceptation'] as String) : null,
      totalHt: (json['total_ht'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      metadata: ProjectMetadata.fromJson(json['project_data']['metadata'] as Map<String, dynamic>),
      designations: designations,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'client_id': clientId,
    'project_name': projectName,
    'devis_number': devisNumber,
    'devis_date': devisDate.toIso8601String(),
    'status': status.name,
    'reference_bon_commande': referenceBonCommande,
    'date_acceptation': dateAcceptation?.toIso8601String(),
    'total_ht': totalHt,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'project_data': {
      'metadata': metadata.toJson(),
    },
    'designations': designations.map((d) => d.toJson()).toList(),
  };

  // --- Méthode copyWith pour la gestion d'état ---
  
  Project copyWith({
    String? id,
    String? companyId,
    String? clientId,
    String? projectName,
    String? devisNumber,
    DateTime? devisDate,
    DevisStatus? status,
    String? referenceBonCommande,
    DateTime? dateAcceptation,
    double? totalHt,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectMetadata? metadata,
    List<Designation>? designations,
  }) {
    return Project(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      clientId: clientId ?? this.clientId,
      projectName: projectName ?? this.projectName,
      devisNumber: devisNumber ?? this.devisNumber,
      devisDate: devisDate ?? this.devisDate,
      status: status ?? this.status,
      referenceBonCommande: referenceBonCommande ?? this.referenceBonCommande,
      dateAcceptation: dateAcceptation ?? this.dateAcceptation,
      totalHt: totalHt ?? this.totalHt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      designations: designations ?? this.designations,
    );
  }
}

// --- Classe pour les Métadonnées (le contenu de 'project_data.metadata') ---

class ProjectMetadata {
  final String descriptionProjet;
  final String clientsData;
  final String adresseChantier;
  final String occupant;
  final String infoComplementaire;

  ProjectMetadata({
    this.descriptionProjet = '',
    this.clientsData = '',
    this.adresseChantier = '',
    this.occupant = '',
    this.infoComplementaire = '',
  });

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) {
    return ProjectMetadata(
      descriptionProjet: json['descriptionProjet'] as String? ?? '',
      clientsData: json['clientsData'] as String? ?? '',
      adresseChantier: json['adresseChantier'] as String? ?? '',
      occupant: json['occupant'] as String? ?? '',
      infoComplementaire: json['infoComplementaire'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'descriptionProjet': descriptionProjet,
    'clientsData': clientsData,
    'adresseChantier': adresseChantier,
    'occupant': occupant,
    'infoComplementaire': infoComplementaire,
  };

  ProjectMetadata copyWith({
    String? descriptionProjet,
    String? clientsData,
    String? adresseChantier,
    String? occupant,
    String? infoComplementaire,
  }) {
    return ProjectMetadata(
      descriptionProjet: descriptionProjet ?? this.descriptionProjet,
      clientsData: clientsData ?? this.clientsData,
      adresseChantier: adresseChantier ?? this.adresseChantier,
      occupant: occupant ?? this.occupant,
      infoComplementaire: infoComplementaire ?? this.infoComplementaire,
    );
  }
}
