import 'package:get/get.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import 'http_client.dart';

class ProjectChecklistService {
  final SimpleHttp http;
  ProjectChecklistService(this.http);

  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      final user = auth.currentUser.value;
      if (user != null && user.token.isNotEmpty) {
        http.accessToken = user.token;
      }
    }
  }

  Future<Map<String, dynamic>> fetchChecklist(
    String projectId,
    String stageId,
  ) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/project-checklist',
    );
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> updateExecutor(
    String projectId,
    String stageId,
    String groupId,
    String questionId, {
    required String? answer,
    String? remark,
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/checklist/groups/$groupId/questions/$questionId/executor',
    );
    final payload = {'answer': answer, if (remark != null) 'remark': remark};
    final json = await http.patchJson(uri, payload);
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> updateReviewer(
    String projectId,
    String stageId,
    String groupId,
    String questionId, {
    required String? status,
    String? remark,
    String? categoryId,
    String? severity,
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/checklist/groups/$groupId/questions/$questionId/reviewer',
    );
    final payload = {
      'status': status,
      if (remark != null) 'remark': remark,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
    };
    final json = await http.patchJson(uri, payload);
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> getDefectRatesPerIteration(
    String projectId,
    int phase,
  ) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/defect-rates?phase=$phase',
    );
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> getOverallDefectRate(String projectId) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/overall-defect-rate',
    );
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>? ?? {});
  }
}
