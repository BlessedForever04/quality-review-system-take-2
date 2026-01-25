/// Checklist Template Model
/// Represents a reusable checklist/group that can be assigned to multiple stages
/// Can contain sections and questions

class ChecklistQuestion {
  final String id;
  final String text;

  ChecklistQuestion({required this.id, required this.text});

  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) {
    return ChecklistQuestion(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'_id': id, 'text': text};

  ChecklistQuestion copyWith({String? id, String? text}) {
    return ChecklistQuestion(id: id ?? this.id, text: text ?? this.text);
  }
}

class ChecklistSection {
  final String id;
  final String name;
  final List<ChecklistQuestion> questions;

  ChecklistSection({
    required this.id,
    required this.name,
    this.questions = const [],
  });

  factory ChecklistSection.fromJson(Map<String, dynamic> json) {
    return ChecklistSection(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map(
                (q) => ChecklistQuestion.fromJson(q as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  ChecklistSection copyWith({
    String? id,
    String? name,
    List<ChecklistQuestion>? questions,
  }) {
    return ChecklistSection(
      id: id ?? this.id,
      name: name ?? this.name,
      questions: questions ?? this.questions,
    );
  }

  ChecklistSection addQuestion(ChecklistQuestion question) {
    final newQuestions = List<ChecklistQuestion>.from(questions);
    newQuestions.add(question);
    return copyWith(questions: newQuestions);
  }

  ChecklistSection removeQuestion(String questionId) {
    final newQuestions = questions.where((q) => q.id != questionId).toList();
    return copyWith(questions: newQuestions);
  }

  ChecklistSection updateQuestion(ChecklistQuestion updatedQuestion) {
    final newQuestions = questions.map((q) {
      if (q.id == updatedQuestion.id) {
        return updatedQuestion;
      }
      return q;
    }).toList();
    return copyWith(questions: newQuestions);
  }
}

class ChecklistTemplate {
  final String id;
  final String name; // e.g., "Code Review", "Security Audit", "QA Testing"
  final String description;
  final List<ChecklistSection> sections;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChecklistTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.sections = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON response from backend
  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplate(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((s) => ChecklistSection.fromJson(s as Map<String, dynamic>))
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
    'description': description,
    'sections': sections.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  /// Create a copy with modified fields
  ChecklistTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<ChecklistSection>? sections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sections: sections ?? this.sections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add a section to this checklist
  ChecklistTemplate addSection(ChecklistSection section) {
    final newSections = List<ChecklistSection>.from(sections);
    newSections.add(section);
    return copyWith(sections: newSections);
  }

  /// Remove a section from this checklist
  ChecklistTemplate removeSection(String sectionId) {
    final newSections = sections.where((s) => s.id != sectionId).toList();
    return copyWith(sections: newSections);
  }

  /// Update a section in this checklist
  ChecklistTemplate updateSection(ChecklistSection updatedSection) {
    final newSections = sections.map((s) {
      if (s.id == updatedSection.id) {
        return updatedSection;
      }
      return s;
    }).toList();
    return copyWith(sections: newSections);
  }

  /// Get total question count
  int getQuestionCount() {
    return sections.fold(
      0,
      (count, section) => count + section.questions.length,
    );
  }
}
