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
  /// Optional [stage] parameter to filter by specific stage (stage1, stage2, stage3, stage4, etc.)
  Future<Map<String, dynamic>> fetchTemplate({String? stage}) async {
    try {
      _ensureToken();
      String urlString = _baseUrl;
      if (stage != null && _isValidStage(stage)) {
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

  /// Validate if stage name is in correct format (stage1, stage2, stage3, stage4, etc.)
  bool _isValidStage(String stage) {
    // Match stage1, stage2, stage3, ..., stage99
    return RegExp(r'^stage[1-9]\d*$').hasMatch(stage);
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
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  /// [checklistName] is the checklist group name
  Future<Map<String, dynamic>> addChecklist({
    required String stage,
    required String checklistName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
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
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
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
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
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
  /// [sectionId] optional - if provided, adds to section; otherwise adds to group directly
  Future<Map<String, dynamic>> addCheckpoint({
    required String checklistId,
    required String stage,
    required String questionText,
    String? categoryId,
    String? sectionId,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      // Build endpoint based on whether sectionId is provided
      final String endpoint = sectionId != null
          ? '$_baseUrl/checklists/$checklistId/sections/$sectionId/checkpoints'
          : '$_baseUrl/checklists/$checklistId/checkpoints';

      final body = {
        'stage': stage,
        'text': questionText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.postJson(Uri.parse(endpoint), body);
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
    String? sectionId,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      // Choose endpoint based on section presence
      final String endpoint = sectionId != null
          ? '$_baseUrl/checklists/$checklistId/sections/$sectionId/checkpoints/$checkpointId'
          : '$_baseUrl/checkpoints/$checkpointId';

      final body = {
        'checklistId': checklistId,
        'stage': stage,
        'text': newText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.patchJson(Uri.parse(endpoint), body);
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating checkpoint: $e');
    }
  }

  /// Delete a checkpoint (question) from a checklist or section
  /// [checkpointId] is the MongoDB _id of the checkpoint
  /// [checklistId] is the MongoDB _id of the parent checklist
  /// [stage] indicates which stage the checkpoint belongs to
  /// [sectionId] optional - if provided, deletes from section; otherwise deletes from group directly
  Future<Map<String, dynamic>> deleteCheckpoint({
    required String checkpointId,
    required String checklistId,
    required String stage,
    String? sectionId,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      // Build endpoint based on whether sectionId is provided
      final String endpoint = sectionId != null
          ? '$_baseUrl/checklists/$checklistId/sections/$sectionId/checkpoints/$checkpointId'
          : '$_baseUrl/checkpoints/$checkpointId';

      final response = await http.deleteJson(Uri.parse(endpoint), {
        'checklistId': checklistId,
        'stage': stage,
      });
      return response['data'] as Map<String, dynamic>? ?? response;
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

  /// Add a section to a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [stage] indicates which stage the checklist belongs to
  /// [sectionName] is the name of the new section
  Future<Map<String, dynamic>> addSection({
    required String checklistId,
    required String stage,
    required String sectionName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final response = await http.postJson(
        Uri.parse('$_baseUrl/checklists/$checklistId/sections'),
        {'stage': stage, 'text': sectionName},
      );
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding section: $e');
    }
  }

  /// Update a section in a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [sectionId] is the MongoDB _id of the section
  /// [stage] indicates which stage the checklist belongs to
  /// [newName] is the updated section name
  Future<Map<String, dynamic>> updateSection({
    required String checklistId,
    required String sectionId,
    required String stage,
    required String newName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final response = await http.putJson(
        Uri.parse('$_baseUrl/checklists/$checklistId/sections/$sectionId'),
        {'stage': stage, 'text': newName},
      );
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating section: $e');
    }
  }

  /// Delete a section from a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [sectionId] is the MongoDB _id of the section
  /// [stage] indicates which stage the checklist belongs to
  Future<void> deleteSection({
    required String checklistId,
    required String sectionId,
    required String stage,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      await http.deleteJson(
        Uri.parse('$_baseUrl/checklists/$checklistId/sections/$sectionId'),
        {'stage': stage},
      );
    } catch (e) {
      throw Exception('Error deleting section: $e');
    }
  }

  /// Add a new stage to the template
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  /// Add a new stage to the template with optional custom name
  /// [stage] must be in format: stage1, stage2, stage3, etc.
  /// [stageName] is optional custom display name for the stage
  Future<Map<String, dynamic>> addStage({
    required String stage,
    String? stageName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
      }

      final body = {'stage': stage};
      if (stageName != null && stageName.trim().isNotEmpty) {
        body['stageName'] = stageName.trim();
      }

      print('🔵 POST /templates/stages - Body: $body');
      final response = await http.postJson(Uri.parse('$_baseUrl/stages'), body);
      print('🟢 POST /templates/stages - Response: $response');
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      print('🔴 POST /templates/stages - Error: $e');
      throw Exception('Error adding stage: $e');
    }
  }

  /// Delete a stage from the template
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  Future<void> deleteStage({required String stage}) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
      }

      await http.deleteJson(Uri.parse('$_baseUrl/stages/$stage'), {});
    } catch (e) {
      throw Exception('Error deleting stage: $e');
    }
  }

  /// Get all stages with their names from the template
  Future<Map<String, String>> getStages() async {
    try {
      _ensureToken();
      final response = await http.getJson(Uri.parse('$_baseUrl/stages'));
      final stagesData = response['data'] as Map<String, dynamic>? ?? {};

      return stagesData.map((key, value) {
        return MapEntry(key.toString(), value.toString());
      });
    } catch (e) {
      throw Exception('Error fetching stages: $e');
    }
  }
}
