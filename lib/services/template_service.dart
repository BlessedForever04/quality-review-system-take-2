import 'package:get/get.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import 'http_client.dart';

/// Service for Template Management API operations
/// Handles admin template CRUD operations with backend integration
class TemplateService {
  final SimpleHttp http;

  TemplateService(this.http);

  static const String _baseUrl = '${ApiConfig.baseUrl}/templates';

  /// Ensure token is set from current user
  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.currentUser.value != null &&
          auth.currentUser.value!.token.isNotEmpty) {
        http.accessToken = auth.currentUser.value!.token;
      }
    }
  }

  /// Fetch the complete template with all stages
  /// Optional [stage] parameter to filter by specific stage (stage1, stage2, stage3)
  Future<Map<String, dynamic>> fetchTemplate({String? stage}) async {
    try {
      _ensureToken();
      String urlString = _baseUrl;
      if (stage != null && ['stage1', 'stage2', 'stage3'].contains(stage)) {
        urlString = '$urlString?stage=$stage';
      }

      final response = await http.getJson(Uri.parse(urlString));
      // API responses are wrapped in { statusCode, data, message }
      // Return only the payload to callers
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error fetching template: $e');
    }
  }

  /// Create or update the template
  /// Uses POST to create initial template or update existing template name
  Future<Map<String, dynamic>> createOrUpdateTemplate({String? name}) async {
    try {
      _ensureToken();
      final body = <String, dynamic>{};
      if (name != null) {
        body['name'] = name;
      }

      final response = await http.postJson(Uri.parse(_baseUrl), body);
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error creating/updating template: $e');
    }
  }

  /// Add a checklist to a specific stage
  /// [stage] must be one of: stage1, stage2, stage3
  /// [checklistName] is the checklist group name
  Future<Map<String, dynamic>> addChecklist({
    required String stage,
    required String checklistName,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage. Must be stage1, stage2, or stage3');
      }

      final response = await http.postJson(Uri.parse('$_baseUrl/checklists'), {
        'stage': stage,
        'text': checklistName,
      });
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding checklist: $e');
    }
  }

  /// Update a checklist's name
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  /// [newName] is the updated checklist name
  Future<Map<String, dynamic>> updateChecklist({
    required String checklistId,
    required String stage,
    required String newName,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage');
      }

      final response = await http.patchJson(
        Uri.parse('$_baseUrl/checklists/$checklistId'),
        {'stage': stage, 'text': newName},
      );
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating checklist: $e');
    }
  }

  /// Delete a checklist from the template
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  Future<void> deleteChecklist({
    required String checklistId,
    required String stage,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage');
      }

      await http.deleteJson(Uri.parse('$_baseUrl/checklists/$checklistId'), {
        'stage': stage,
      });
    } catch (e) {
      throw Exception('Error deleting checklist: $e');
    }
  }

  /// Add a checkpoint (question) to a checklist
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  /// [questionText] is the checkpoint text
  /// [categoryId] optional defect category ID
  Future<Map<String, dynamic>> addCheckpoint({
    required String checklistId,
    required String stage,
    required String questionText,
    String? categoryId,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage');
      }

      final body = {
        'stage': stage,
        'text': questionText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.postJson(
        Uri.parse('$_baseUrl/checklists/$checklistId/checkpoints'),
        body,
      );
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding checkpoint: $e');
    }
  }

  /// Update a checkpoint (question) text
  /// [checkpointId] is the MongoDB _id of the checkpoint
  /// [checklistId] is the MongoDB _id of the parent checklist
  /// [stage] indicates which stage the checkpoint belongs to
  /// [newText] is the updated checkpoint text
  /// [categoryId] optional defect category ID
  Future<Map<String, dynamic>> updateCheckpoint({
    required String checkpointId,
    required String checklistId,
    required String stage,
    required String newText,
    String? categoryId,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage');
      }

      final body = {
        'checklistId': checklistId,
        'stage': stage,
        'text': newText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.patchJson(
        Uri.parse('$_baseUrl/checkpoints/$checkpointId'),
        body,
      );
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating checkpoint: $e');
    }
  }

  /// Delete a checkpoint (question) from a checklist
  /// [checkpointId] is the MongoDB _id of the checkpoint
  /// [checklistId] is the MongoDB _id of the parent checklist
  /// [stage] indicates which stage the checkpoint belongs to
  Future<void> deleteCheckpoint({
    required String checkpointId,
    required String checklistId,
    required String stage,
  }) async {
    try {
      _ensureToken();
      if (!['stage1', 'stage2', 'stage3'].contains(stage)) {
        throw Exception('Invalid stage');
      }

      await http.deleteJson(Uri.parse('$_baseUrl/checkpoints/$checkpointId'), {
        'checklistId': checklistId,
        'stage': stage,
      });
    } catch (e) {
      throw Exception('Error deleting checkpoint: $e');
    }
  }

  /// Update defect categories in template
  Future<void> updateDefectCategories(List<dynamic> categories) async {
    try {
      _ensureToken();

      await http.patchJson(Uri.parse('$_baseUrl/defect-categories'), {
        'defectCategories': categories.map((c) => c.toJson()).toList(),
      });
    } catch (e) {
      throw Exception('Error updating defect categories: $e');
    }
  }
}
