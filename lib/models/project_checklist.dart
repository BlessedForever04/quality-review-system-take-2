/// Models for hierarchical ProjectChecklist structure used in execution mode.
/// These models mirror the backend schema and represent the project-specific
/// checklist hierarchy: Group → Sections (optional) → Questions

/// Represents a single question in the project checklist
class ProjectQuestion {
  final String id;
  final String text;
  final String? executorAnswer; // "Yes", "No", "NA", or null
  final String? executorRemark;
  final String?
  reviewerAnswer; // "Yes", "No", "NA", or null - the actual reviewer answer
  final String? reviewerStatus; // "Approved", "Rejected", or null
  final String? reviewerRemark;

  ProjectQuestion({
    required this.id,
    required this.text,
    this.executorAnswer,
    this.executorRemark,
    this.reviewerAnswer,
    this.reviewerStatus,
    this.reviewerRemark,
  });

  /// Create from JSON response from backend
  factory ProjectQuestion.fromJson(Map<String, dynamic> json) {
    return ProjectQuestion(
      id: json['_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      executorAnswer: json['executorAnswer'] as String?,
      executorRemark: json['executorRemark'] as String?,
      reviewerAnswer: json['reviewerAnswer'] as String?,
      reviewerStatus: json['reviewerStatus'] as String?,
      reviewerRemark: json['reviewerRemark'] as String?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    '_id': id,
    'text': text,
    'executorAnswer': executorAnswer,
    'executorRemark': executorRemark,
    'reviewerAnswer': reviewerAnswer,
    'reviewerStatus': reviewerStatus,
    'reviewerRemark': reviewerRemark,
  };

  /// Create a copy with modified fields
  ProjectQuestion copyWith({
    String? id,
    String? text,
    String? executorAnswer,
    String? executorRemark,
    String? reviewerAnswer,
    String? reviewerStatus,
    String? reviewerRemark,
  }) {
    return ProjectQuestion(
      id: id ?? this.id,
      text: text ?? this.text,
      executorAnswer: executorAnswer ?? this.executorAnswer,
      executorRemark: executorRemark ?? this.executorRemark,
      reviewerAnswer: reviewerAnswer ?? this.reviewerAnswer,
      reviewerStatus: reviewerStatus ?? this.reviewerStatus,
      reviewerRemark: reviewerRemark ?? this.reviewerRemark,
    );
  }
}

/// Represents a section within a group (optional hierarchical level)
class ProjectSection {
  final String sectionName;
  final List<ProjectQuestion> questions;

  ProjectSection({required this.sectionName, required this.questions});

  /// Create from JSON response from backend
  factory ProjectSection.fromJson(Map<String, dynamic> json) {
    final questionsList =
        (json['questions'] as List<dynamic>?)
            ?.map((q) => ProjectQuestion.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];
    return ProjectSection(
      sectionName: json['sectionName'] as String? ?? '',
      questions: questionsList,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    'sectionName': sectionName,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  /// Create a copy with modified fields
  ProjectSection copyWith({
    String? sectionName,
    List<ProjectQuestion>? questions,
  }) {
    return ProjectSection(
      sectionName: sectionName ?? this.sectionName,
      questions: questions ?? this.questions,
    );
  }
}

/// Represents a group in the project checklist
class ProjectChecklistGroup {
  final String id;
  final String groupName;
  final List<ProjectQuestion>
  questions; // Direct questions in group (not in sections)
  final List<ProjectSection> sections; // Optional subsections
  final int defectCount; // Number of defects in this group

  ProjectChecklistGroup({
    required this.id,
    required this.groupName,
    required this.questions,
    required this.sections,
    this.defectCount = 0,
  });

  /// Create from JSON response from backend
  factory ProjectChecklistGroup.fromJson(Map<String, dynamic> json) {
    final questionsList =
        (json['questions'] as List<dynamic>?)
            ?.map((q) => ProjectQuestion.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];
    final sectionsList =
        (json['sections'] as List<dynamic>?)
            ?.map((s) => ProjectSection.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];
    return ProjectChecklistGroup(
      id: json['_id'] as String? ?? '',
      groupName: json['groupName'] as String? ?? '',
      questions: questionsList,
      sections: sectionsList,
      defectCount: json['defectCount'] as int? ?? 0,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    '_id': id,
    'groupName': groupName,
    'questions': questions.map((q) => q.toJson()).toList(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'defectCount': defectCount,
  };

  /// Create a copy with modified fields
  ProjectChecklistGroup copyWith({
    String? id,
    String? groupName,
    List<ProjectQuestion>? questions,
    List<ProjectSection>? sections,
    int? defectCount,
  }) {
    return ProjectChecklistGroup(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      questions: questions ?? this.questions,
      sections: sections ?? this.sections,
      defectCount: defectCount ?? this.defectCount,
    );
  }

  /// Get all questions (both direct and from sections)
  List<ProjectQuestion> getAllQuestions() {
    final directQuestions = [...questions];
    for (final section in sections) {
      directQuestions.addAll(section.questions);
    }
    return directQuestions;
  }

  /// Find a question by ID (searches direct questions and sections)
  ProjectQuestion? findQuestion(String questionId) {
    // Search direct questions
    try {
      return questions.firstWhere((q) => q.id == questionId);
    } catch (_) {}

    // Search in sections
    for (final section in sections) {
      try {
        return section.questions.firstWhere((q) => q.id == questionId);
      } catch (_) {}
    }
    return null;
  }

  /// Update a question by ID (returns new group with updated question)
  ProjectChecklistGroup updateQuestion(
    String questionId,
    ProjectQuestion updatedQuestion,
  ) {
    // Try updating direct questions
    final updatedDirectQuestions = questions.map((q) {
      if (q.id == questionId) {
        return updatedQuestion;
      }
      return q;
    }).toList();

    if (updatedDirectQuestions.any((q) => q.id == questionId)) {
      return copyWith(questions: updatedDirectQuestions);
    }

    // Try updating in sections
    final updatedSections = sections.map((section) {
      final updatedSectionQuestions = section.questions.map((q) {
        if (q.id == questionId) {
          return updatedQuestion;
        }
        return q;
      }).toList();

      if (updatedSectionQuestions.any((q) => q.id == questionId)) {
        return section.copyWith(questions: updatedSectionQuestions);
      }
      return section;
    }).toList();

    return copyWith(sections: updatedSections);
  }
}

/// Represents the complete project checklist for a stage
class ProjectChecklist {
  final String id;
  final String projectId;
  final String stageId;
  final String stage;
  final List<ProjectChecklistGroup> groups;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectChecklist({
    required this.id,
    required this.projectId,
    required this.stageId,
    required this.stage,
    required this.groups,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON response from backend
  factory ProjectChecklist.fromJson(Map<String, dynamic> json) {
    final groupsList =
        (json['groups'] as List<dynamic>?)
            ?.map(
              (g) => ProjectChecklistGroup.fromJson(g as Map<String, dynamic>),
            )
            .toList() ??
        [];
    return ProjectChecklist(
      id: json['_id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      stageId: json['stageId'] as String? ?? '',
      stage: json['stage'] as String? ?? '',
      groups: groupsList,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    '_id': id,
    'projectId': projectId,
    'stageId': stageId,
    'stage': stage,
    'groups': groups.map((g) => g.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Create a copy with modified fields
  ProjectChecklist copyWith({
    String? id,
    String? projectId,
    String? stageId,
    String? stage,
    List<ProjectChecklistGroup>? groups,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectChecklist(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      stageId: stageId ?? this.stageId,
      stage: stage ?? this.stage,
      groups: groups ?? this.groups,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Find a group by ID
  ProjectChecklistGroup? findGroup(String groupId) {
    try {
      return groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  /// Update a group (returns new checklist with updated group)
  ProjectChecklist updateGroup(ProjectChecklistGroup updatedGroup) {
    final updatedGroups = groups.map((g) {
      if (g.id == updatedGroup.id) {
        return updatedGroup;
      }
      return g;
    }).toList();
    return copyWith(groups: updatedGroups);
  }

  /// Get all questions across all groups
  List<ProjectQuestion> getAllQuestions() {
    final allQuestions = <ProjectQuestion>[];
    for (final group in groups) {
      allQuestions.addAll(group.getAllQuestions());
    }
    return allQuestions;
  }

  /// Get completion statistics
  Map<String, int> getCompletionStats() {
    int totalQuestions = 0;
    int answeredByExecutor = 0;
    int approvedByReviewer = 0;

    for (final question in getAllQuestions()) {
      totalQuestions++;
      if (question.executorAnswer != null) {
        answeredByExecutor++;
      }
      if (question.reviewerStatus != null) {
        approvedByReviewer++;
      }
    }

    return {
      'total': totalQuestions,
      'executorAnswered': answeredByExecutor,
      'reviewerApproved': approvedByReviewer,
    };
  }
}
