import 'dart:async';
import '../config/api_config.dart';
import '../models/project.dart';
import 'http_client.dart';

class ProjectService {
  final SimpleHttp http;
  Timer? _pollTimer;
  final _projectsController = StreamController<List<Project>>.broadcast();

  ProjectService(this.http);

  Project _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
    final projectNo = j['project_no']?.toString();
    final internalOrderNo = j['internal_order_no']?.toString();
    final title = (j['project_name'] ?? '').toString();
    final statusRaw = (j['status'] ?? '').toString();
    final status = switch (statusRaw) {
      'pending' => 'Not Started',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      _ => 'Not Started',
    };
    final startedStr = (j['start_date'] ?? j['started']).toString();
    final started = DateTime.tryParse(startedStr) ?? DateTime.now();

    // Get description from backend
    final description = j['description']?.toString();

    // Get priority from backend and map to frontend format
    final priorityRaw = (j['priority'] ?? 'medium').toString().toLowerCase();
    final priority = switch (priorityRaw) {
      'high' => 'High',
      'low' => 'Low',
      _ => 'Medium',
    };

    // Handle populated created_by field
    String? creatorId;
    String? creatorName;
    final createdBy = j['created_by'];
    if (createdBy is Map<String, dynamic>) {
      creatorId = (createdBy['_id'] ?? createdBy['id']).toString();
      creatorName = createdBy['name']?.toString();
    } else if (createdBy != null) {
      creatorId = createdBy.toString();
    }

    // Handle assignedEmployees if present (from optimized endpoint)
    List<String>? assignedEmployees;
    if (j.containsKey('assignedEmployees') && j['assignedEmployees'] is List) {
      assignedEmployees = (j['assignedEmployees'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Handle isReviewApplicable field
    String? isReviewApplicable;
    if (j.containsKey('isReviewApplicable')) {
      final value = j['isReviewApplicable'];
      if (value is String) {
        isReviewApplicable = value;
      } else if (value is bool) {
        // Handle legacy boolean values
        isReviewApplicable = value ? 'yes' : 'no';
      }
    }

    // Handle reviewApplicableRemark field
    String? reviewApplicableRemark;
    if (j.containsKey('reviewApplicableRemark')) {
      reviewApplicableRemark = j['reviewApplicableRemark']?.toString();
    }

    // Handle overallDefectRate field
    double? overallDefectRate;
    if (j.containsKey('overallDefectRate')) {
      final value = j['overallDefectRate'];
      if (value is num) {
        overallDefectRate = value.toDouble();
      }
    }

    return Project(
      id: id,
      projectNo: projectNo,
      internalOrderNo: internalOrderNo,
      title: title.isEmpty ? 'Untitled' : title,
      description: description,
      started: started,
      priority: priority,
      status: status,
      executor: creatorName ?? creatorId, // Use creator name or ID
      assignedEmployees: assignedEmployees, // From backend or null
      isReviewApplicable: isReviewApplicable,
      reviewApplicableRemark: reviewApplicableRemark,
      overallDefectRate: overallDefectRate,
    );
  }

  Map<String, dynamic> _toApi(Project p, {String? userId}) {
    String status = switch (p.status) {
      'In Progress' => 'in_progress',
      'Completed' => 'completed',
      _ => 'pending',
    };
    String priority = switch (p.priority) {
      'High' => 'high',
      'Low' => 'low',
      _ => 'medium',
    };
    return {
      if (p.projectNo != null) 'project_no': p.projectNo,
      if (p.internalOrderNo != null) 'internal_order_no': p.internalOrderNo,
      'project_name': p.title,
      if (p.description != null) 'description': p.description,
      'status': status,
      'priority': priority,
      'start_date': p.started.toIso8601String(),
      if (userId != null) 'created_by': userId,
      if (p.isReviewApplicable != null)
        'isReviewApplicable': p.isReviewApplicable,
      if (p.reviewApplicableRemark != null)
        'reviewApplicableRemark': p.reviewApplicableRemark,
    };
  }

  Future<List<Project>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  /// Get projects for a specific user (optimized - includes memberships)
  Future<List<Project>> getForUser(String userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/user/$userId');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<Project> getById(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/$id');
    final json = await http.getJson(uri);
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Project> create(Project p, {required String userId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.postJson(uri, _toApi(p, userId: userId));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Project> update(Project p) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/${p.id}');
    final json = await http.putJson(uri, _toApi(p));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/$id');
    await http.delete(uri);
  }

  Stream<List<Project>> getProjectsStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final projects = await getAll();
        if (!_projectsController.isClosed) {
          _projectsController.add(projects);
        }
      } catch (e) {
        if (!_projectsController.isClosed) {
          _projectsController.addError(e);
        }
      }
    });
    // Immediately fetch initial data
    getAll()
        .then((projects) {
          if (!_projectsController.isClosed) {
            _projectsController.add(projects);
          }
        })
        .catchError((e) {
          if (!_projectsController.isClosed) {
            _projectsController.addError(e);
          }
        });
    return _projectsController.stream;
  }

  void dispose() {
    _pollTimer?.cancel();
    _projectsController.close();
  }
}
