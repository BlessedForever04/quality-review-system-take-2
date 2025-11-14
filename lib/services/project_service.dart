// No additional imports required

import '../config/api_config.dart';
import '../models/project.dart';
import 'http_client.dart';

class ProjectService {
  final SimpleHttp http;
  ProjectService(this.http);

  Project _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
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
    return Project(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
      description: null,
      started: started,
      priority: 'Medium', // not in backend model; default
      status: status,
      executor: null, // not in backend model
      assignedEmployees: null,
    );
  }

  Map<String, dynamic> _toApi(Project p) {
    String status = switch (p.status) {
      'In Progress' => 'in_progress',
      'Completed' => 'completed',
      _ => 'pending',
    };
    return {
      'project_name': p.title,
      'status': status,
      'start_date': p.started.toIso8601String(),
      if (p.executor != null) 'created_by': p.executor, // executor mapping placeholder
    };
  }

  Future<List<Project>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<Project> create(Project p) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.postJson(uri, _toApi(p));
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
}
