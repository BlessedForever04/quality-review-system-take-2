import '../config/api_config.dart';
import '../models/team_member.dart';
import 'http_client.dart';

class UserService {
  final SimpleHttp http;
  UserService(this.http);

  TeamMember _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
    final name = (j['name'] ?? j['fullName'] ?? '').toString();
    final email = (j['email'] ?? '').toString();
    // Map backend role fields to two canonical roles
    final roleRaw = (j['role'] ?? j['userRole'] ?? '').toString().toLowerCase();
    final role = roleRaw.contains('leader') ? 'Team Leader' : 'Executor/Reviewer';
    final status = ((j['status'] ?? 'Active').toString().toLowerCase() == 'inactive') ? 'Inactive' : 'Active';
    final createdAt = (j['createdAt'] ?? j['dateAdded'] ?? '').toString();
    final lastActive = (j['lastActive'] ?? '').toString();
    return TeamMember(
      id: id,
      name: name.isEmpty ? 'Unnamed' : name,
      email: email,
      role: role,
      status: status,
      dateAdded: createdAt,
      lastActive: lastActive.isEmpty ? createdAt : lastActive,
    );
  }

  Map<String, dynamic> _toApi(TeamMember m) {
    return {
      'name': m.name,
      'email': m.email,
      'role': m.role == 'Team Leader' ? 'team_leader' : 'executor',
      if (m.password != null && m.password!.isNotEmpty) 'password': m.password,
      'status': m.status.toLowerCase(),
    };
  }

  Future<List<TeamMember>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMember> create(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users');
    final json = await http.postJson(uri, _toApi(m));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<TeamMember> update(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/${m.id}');
    final json = await http.putJson(uri, _toApi(m));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$id');
    await http.delete(uri);
  }
}
