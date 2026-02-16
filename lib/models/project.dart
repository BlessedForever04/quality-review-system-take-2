class Project {
  String id;
  // Existing fields
  String? projectNo;
  String? internalOrderNo;
  String title;
  String? description;
  DateTime started;
  String priority; // Low, Medium, High
  String status; // Pending, In Progress, Completed, Not Started
  String? executor;
  List<String>? assignedEmployees;
  bool?
  isReviewApplicable; // Toggle: null = not set, true = Yes (normal workflow), false = No (mark as Completed)

  // New attributes from Excel import
  String? groupOrCostCentre;
  String? actionRequired;
  String? sponsor;
  String? competence;
  String? competenceManager;
  String? projectLeader;
  String? projectTeam; // comma-separated names
  String? createdBy;
  DateTime? creationOn;
  DateTime? requiredDeliveryDate;
  DateTime? plannedEndDate;
  DateTime? actualDeliveryDate;
  double? plannedEfforts; // hours
  double? actualEfforts; // hours

  Project({
    required this.id,
    this.projectNo,
    this.internalOrderNo,
    required this.title,
    this.description,
    required this.started,
    required this.priority,
    required this.status,
    this.executor,
    this.assignedEmployees,
    this.isReviewApplicable,
    this.groupOrCostCentre,
    this.actionRequired,
    this.sponsor,
    this.competence,
    this.competenceManager,
    this.projectLeader,
    this.projectTeam,
    this.createdBy,
    this.creationOn,
    this.requiredDeliveryDate,
    this.plannedEndDate,
    this.actualDeliveryDate,
    this.plannedEfforts,
    this.actualEfforts,
  });

  Project copyWith({
    String? id,
    String? projectNo,
    String? internalOrderNo,
    String? title,
    String? description,
    DateTime? started,
    String? priority,
    String? status,
    String? executor,
    List<String>? assignedEmployees,
    bool? isReviewApplicable,
    String? groupOrCostCentre,
    String? actionRequired,
    String? sponsor,
    String? competence,
    String? competenceManager,
    String? projectLeader,
    String? projectTeam,
    String? createdBy,
    DateTime? creationOn,
    DateTime? requiredDeliveryDate,
    DateTime? plannedEndDate,
    DateTime? actualDeliveryDate,
    double? plannedEfforts,
    double? actualEfforts,
  }) {
    return Project(
      id: id ?? this.id,
      projectNo: projectNo ?? this.projectNo,
      internalOrderNo: internalOrderNo ?? this.internalOrderNo,
      title: title ?? this.title,
      description: description ?? this.description,
      started: started ?? this.started,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      executor: executor ?? this.executor,
      assignedEmployees: assignedEmployees ?? this.assignedEmployees,
      isReviewApplicable: isReviewApplicable ?? this.isReviewApplicable,
      groupOrCostCentre: groupOrCostCentre ?? this.groupOrCostCentre,
      actionRequired: actionRequired ?? this.actionRequired,
      sponsor: sponsor ?? this.sponsor,
      competence: competence ?? this.competence,
      competenceManager: competenceManager ?? this.competenceManager,
      projectLeader: projectLeader ?? this.projectLeader,
      projectTeam: projectTeam ?? this.projectTeam,
      createdBy: createdBy ?? this.createdBy,
      creationOn: creationOn ?? this.creationOn,
      requiredDeliveryDate: requiredDeliveryDate ?? this.requiredDeliveryDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      plannedEfforts: plannedEfforts ?? this.plannedEfforts,
      actualEfforts: actualEfforts ?? this.actualEfforts,
    );
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    double? parseNum(dynamic v) {
      if (v == null) return null;
      try {
        return double.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return Project(
      id: map['id'] ?? '',
      projectNo: map['projectNo'],
      internalOrderNo: map['internalOrderNo'],
      title: map['title'] ?? 'Untitled',
      description: map['description'],
      started: parseDate(map['started']) ?? DateTime.now(),
      priority: map['priority'] ?? 'Medium',
      status: map['status'] ?? 'Not Started',
      executor: map['executor'],
      assignedEmployees: (map['assignedEmployees'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isReviewApplicable: map['isReviewApplicable'],
      groupOrCostCentre: map['groupOrCostCentre'],
      actionRequired: map['actionRequired'],
      sponsor: map['sponsor'],
      competence: map['competence'],
      competenceManager: map['competenceManager'],
      projectLeader: map['projectLeader'],
      projectTeam: map['projectTeam'],
      createdBy: map['createdBy'],
      creationOn: parseDate(map['creationOn']),
      requiredDeliveryDate: parseDate(map['requiredDeliveryDate']),
      plannedEndDate: parseDate(map['plannedEndDate']),
      actualDeliveryDate: parseDate(map['actualDeliveryDate']),
      plannedEfforts: parseNum(map['plannedEfforts']),
      actualEfforts: parseNum(map['actualEfforts']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'projectNo': projectNo,
    'internalOrderNo': internalOrderNo,
    'title': title,
    'description': description,
    'started': started.toIso8601String(),
    'priority': priority,
    'status': status,
    'executor': executor,
    'assignedEmployees': assignedEmployees,
    'isReviewApplicable': isReviewApplicable,
    'groupOrCostCentre': groupOrCostCentre,
    'actionRequired': actionRequired,
    'sponsor': sponsor,
    'competence': competence,
    'competenceManager': competenceManager,
    'projectLeader': projectLeader,
    'projectTeam': projectTeam,
    'createdBy': createdBy,
    'creationOn': creationOn?.toIso8601String(),
    'requiredDeliveryDate': requiredDeliveryDate?.toIso8601String(),
    'plannedEndDate': plannedEndDate?.toIso8601String(),
    'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
    'plannedEfforts': plannedEfforts,
    'actualEfforts': actualEfforts,
  };
}
