import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';

/// Service for fetching checklist iteration history
class IterationService {
  /// Fetch all iterations for a specific project and stage
  /// Returns: { iterations: [], currentIteration: N, totalIterations: N }
  Future<Map<String, dynamic>> getIterations(
    String projectId,
    String stageId,
  ) async {
    try {
      if (kDebugMode) {
        print('📚 Fetching iterations for project $projectId, stage $stageId');
      }

      // Get auth token from AuthController
      final auth = Get.find<AuthController>();
      final token = auth.currentUser.value?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/projects/$projectId/stages/$stageId/project-checklist/iterations',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('📚 Iterations API response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final result = data['data'];
          if (kDebugMode) {
            print('✅ Fetched ${result['totalIterations'] ?? 0} iterations');
          }
          return result;
        }
      }

      if (kDebugMode) {
        print('⚠️ Failed to fetch iterations: ${response.body}');
      }
      return {'iterations': [], 'currentIteration': 1, 'totalIterations': 0};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching iterations: $e');
      }
      return {'iterations': [], 'currentIteration': 1, 'totalIterations': 0};
    }
  }

  /// Find answer for a specific question in a specific iteration
  /// Returns the full question data including answer, remark, images, etc.
  Map<String, dynamic>? findQuestionInIteration(
    Map<String, dynamic> iteration,
    String questionId,
  ) {
    try {
      final groups = iteration['groups'] as List<dynamic>? ?? [];

      for (final group in groups) {
        if (group is! Map<String, dynamic>) continue;

        // Check direct questions
        final questions = group['questions'] as List<dynamic>? ?? [];
        for (final q in questions) {
          if (q is! Map<String, dynamic>) continue;
          if (q['_id'].toString() == questionId) {
            return q;
          }
        }

        // Check questions in sections
        final sections = group['sections'] as List<dynamic>? ?? [];
        for (final section in sections) {
          if (section is! Map<String, dynamic>) continue;
          final sectionQuestions = section['questions'] as List<dynamic>? ?? [];
          for (final q in sectionQuestions) {
            if (q is! Map<String, dynamic>) continue;
            if (q['_id'].toString() == questionId) {
              return q;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding question in iteration: $e');
      }
    }
    return null;
  }

  /// Extract executor and reviewer answers from a question iteration data
  /// Returns: { executorAnswer: ..., executorRemark: ..., executorImages: ..., reviewerAnswer: ..., etc. }
  Map<String, dynamic> extractAnswersFromQuestion(
    Map<String, dynamic> questionData,
  ) {
    return {
      'executorAnswer': questionData['executorAnswer'],
      'executorRemark': questionData['executorRemark'] ?? '',
      'executorImages': questionData['executorImages'] ?? [],
      'reviewerAnswer': questionData['reviewerAnswer'],
      'reviewerRemark': questionData['reviewerRemark'] ?? '',
      'reviewerImages': questionData['reviewerImages'] ?? [],
      'categoryId': questionData['categoryId'] ?? '',
      'severity': questionData['severity'] ?? '',
      'answeredAt': questionData['answeredAt'],
      'answeredBy': questionData['answeredBy'],
    };
  }
}
