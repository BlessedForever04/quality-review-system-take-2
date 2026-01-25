/// Stage Template Model
/// Represents a reusable stage/phase that can be used in multiple projects
/// Includes stage name, order, and associated checklists

class StageTemplate {
  final String id;
  final String name; // e.g., "Planning", "Development", "Testing", "Deployment"
  final int order; // Order in which stages appear (1, 2, 3, etc.)
  final List<String> checklistIds; // References to ChecklistTemplate IDs
  final DateTime createdAt;
  final DateTime? updatedAt;

  StageTemplate({
    required this.id,
    required this.name,
    required this.order,
    this.checklistIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON response from backend
  factory StageTemplate.fromJson(Map<String, dynamic> json) {
    return StageTemplate(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      checklistIds:
          (json['checklistIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'order': order,
    'checklistIds': checklistIds,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  /// Create a copy with modified fields
  StageTemplate copyWith({
    String? id,
    String? name,
    int? order,
    List<String>? checklistIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StageTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      checklistIds: checklistIds ?? this.checklistIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add a checklist to this stage
  StageTemplate addChecklist(String checklistId) {
    final newIds = List<String>.from(checklistIds);
    if (!newIds.contains(checklistId)) {
      newIds.add(checklistId);
    }
    return copyWith(checklistIds: newIds);
  }

  /// Remove a checklist from this stage
  StageTemplate removeChecklist(String checklistId) {
    final newIds = checklistIds.where((id) => id != checklistId).toList();
    return copyWith(checklistIds: newIds);
  }
}
