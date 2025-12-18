import '../config/api_config.dart';
import 'http_client.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class PhaseChecklistService {
  final SimpleHttp http;
  PhaseChecklistService(this.http);

  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.currentUser.value != null &&
          auth.currentUser.value!.token.isNotEmpty) {
        http.accessToken = auth.currentUser.value!.token;
      }
    }
  }

  // List checklists for a stage
  Future<List<Map<String, dynamic>>> listForStage(String stageId) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/stages/$stageId/checklists',
    );
    print('📍 API Call: GET $uri');
    final json = await http.getJson(uri);
    print('📦 Response: $json');
    final data = (json['data'] as List?) ?? [];
    print('✓ Checklists parsed: ${data.length} items');
    return data.cast<Map<String, dynamic>>();
  }

  // Create checklist for a stage
  Future<Map<String, dynamic>> createForStage(
    String stageId, {
    required String name,
    String? description,
    String status = 'draft',
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/stages/$stageId/checklists',
    );
    final body = {
      'checklist_name': name,
      if (description != null) 'description': description,
      'status': status,
    };
    final json = await http.postJson(uri, body);
    return (json['data'] as Map<String, dynamic>);
  }

  // Get checklist by id
  Future<Map<String, dynamic>> getById(String id) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.checklistBaseUrl}/checklists/$id');
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>);
  }

  // Update checklist (supports updating answers JSON)
  Future<Map<String, dynamic>> updateChecklist(
    String id,
    Map<String, dynamic> update,
  ) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.checklistBaseUrl}/checklists/$id');
    final json = await http.putJson(uri, update);
    return (json['data'] as Map<String, dynamic>);
  }

  // Delete checklist
  Future<void> deleteChecklist(String id) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.checklistBaseUrl}/checklists/$id');
    await http.delete(uri);
  }

  // Fetch checkpoints for a checklist
  Future<List<Map<String, dynamic>>> getCheckpoints(String checklistId) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/checklists/$checklistId/checkpoints',
    );
    print('📍 API Call: GET $uri');
    final json = await http.getJson(uri);
    print('📦 Response: $json');
    final data = (json['data'] as List?) ?? [];
    print('✓ Checkpoints parsed: ${data.length} items');
    return data.cast<Map<String, dynamic>>();
  }

  // Create a checkpoint (question) under a checklist
  Future<Map<String, dynamic>> createCheckpoint(
    String checklistId, {
    required String question,
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/checklists/$checklistId/checkpoints',
    );
    final json = await http.postJson(uri, {'question': question});
    return (json['data'] as Map<String, dynamic>);
  }

  // Update a checkpoint (e.g., rename question text)
  Future<Map<String, dynamic>> updateCheckpoint(
    String checkpointId,
    Map<String, dynamic> patch,
  ) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/checkpoints/$checkpointId');
    final json = await http.patchJson(uri, patch);
    return (json['data'] as Map<String, dynamic>);
  }

  // Delete a checkpoint
  Future<void> deleteCheckpoint(String checkpointId) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/checkpoints/$checkpointId');
    await http.delete(uri);
  }

  // Submit/approve/request-changes
  Future<void> submit(String id) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/checklists/$id/submit',
    );
    await http.postJson(uri, {
      'user_id': 'self',
    }); // user is taken from token if backend uses it
  }

  Future<void> approve(String id) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/checklists/$id/approve',
    );
    await http.postJson(uri, {'user_id': 'self'});
  }

  Future<void> requestChanges(String id, String message) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/checklists/$id/request-changes',
    );
    await http.postJson(uri, {'user_id': 'self', 'message': message});
  }
}
