/// Project Template Model
/// Represents a complete reusable template with multiple stages and their associated checklists
/// Can be used to quickly set up new projects with pre-defined structure

import 'stage_template.dart';

class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final List<StageTemplate> stages; // Ordered list of stages
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy; // Admin who created this template

  ProjectTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.stages = const [],
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Create from JSON response from backend
  factory ProjectTemplate.fromJson(Map<String, dynamic> json) {
    return ProjectTemplate(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      stages:
          (json['stages'] as List<dynamic>?)
              ?.map((s) => StageTemplate.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
      createdBy: json['createdBy'] as String?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'description': description,
    'stages': stages.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (createdBy != null) 'createdBy': createdBy,
  };

  /// Create a copy with modified fields
  ProjectTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<StageTemplate>? stages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ProjectTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      stages: stages ?? this.stages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Add a stage to this template
  ProjectTemplate addStage(StageTemplate stage) {
    final newStages = List<StageTemplate>.from(stages);
    newStages.add(stage);
    // Re-order stages by their order property
    newStages.sort((a, b) => a.order.compareTo(b.order));
    return copyWith(stages: newStages);
  }

  /// Remove a stage from this template
  ProjectTemplate removeStage(String stageId) {
    final newStages = stages.where((s) => s.id != stageId).toList();
    return copyWith(stages: newStages);
  }

  /// Update a stage in this template
  ProjectTemplate updateStage(StageTemplate updatedStage) {
    final newStages = stages.map((s) {
      if (s.id == updatedStage.id) {
        return updatedStage;
      }
      return s;
    }).toList();
    // Re-order stages by their order property
    newStages.sort((a, b) => a.order.compareTo(b.order));
    return copyWith(stages: newStages);
  }

  /// Get stage by ID
  StageTemplate? getStageById(String stageId) {
    try {
      return stages.firstWhere((s) => s.id == stageId);
    } catch (e) {
      return null;
    }
  }

  /// Get total stage count
  int getStageCount() {
    return stages.length;
  }

  /// Get total checklist count across all stages
  int getTotalChecklistCount() {
    return stages.fold(0, (count, stage) => count + stage.checklistIds.length);
  }
}
