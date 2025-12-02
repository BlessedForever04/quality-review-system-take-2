import 'package:get/get.dart';
import '../../services/http_client.dart';
import '../../services/checklist_answer_service.dart';

class ChecklistController extends GetxService {
  late final ChecklistAnswerService _answerService;

  // Cache for loaded answers: projectId -> phase -> role -> subQuestion -> answer map
  final _cache = <String, Map<int, Map<String, Map<String, dynamic>>>>{}.obs;

  // Submission status cache: projectId -> phase -> role -> metadata
  final _submissionCache = <String, Map<int, Map<String, dynamic>>>{}.obs;

  // Loading state
  final _isLoading = <String, bool>{}.obs;

  // Pending saves (debouncing)
  final Map<String, Future<void>> _pendingSaves = {};

  // Removed stage/checklist caches - using direct checklist answers endpoints

  @override
  void onInit() {
    super.onInit();
    print('🎯 ChecklistController.onInit() called');
    // Initialize service
    try {
      final http = Get.find<SimpleHttp>();
  _answerService = ChecklistAnswerService(http);
      print('✓ ChecklistController initialized successfully');
    } catch (e) {
      print('❌ Error initializing ChecklistController: $e');
      rethrow;
    }
  }

  /// Load answers from backend for a specific project/phase/role
  Future<void> loadAnswers(String projectId, int phase, String role) async {
    print(
      '🔵 loadAnswers CALLED: projectId=$projectId, phase=$phase, role=$role',
    );
    final key = '$projectId-$phase-$role';
    if (_isLoading[key] == true) {
      print('⚠️ Already loading $key, skipping...');
      return; // Already loading
    }

    _isLoading[key] = true;
    print('📥 Loading answers for $role in project $projectId phase $phase...');

    try {
  // Direct load from checklist-answer API
  final answers = await _answerService.getAnswers(projectId, phase, role);
  print('✓ Received ${answers.length} answers from checklist-answer API for $role');

      // Store in cache
      final proj = _cache.putIfAbsent(projectId, () => {});
      final phaseMap = proj.putIfAbsent(phase, () => {});
      phaseMap[role] = answers;
      _cache.refresh();

      // Also load submission status
      await _loadSubmissionStatus(projectId, phase, role);
    } catch (e) {
      print('❌ Error loading checklist answers: $e');
    } finally {
      _isLoading[key] = false;
    }
  }

  // Removed stage/checklist creation logic

  /// Get a specific answer from cache
  Map<String, dynamic>? getAnswers(
    String projectId,
    int phase,
    String role,
    String subQ,
  ) {
    return _cache[projectId]?[phase]?[role]?[subQ];
  }

  /// Get all answers for a role (entire role sheet)
  Map<String, Map<String, dynamic>> getRoleSheet(
    String projectId,
    int phase,
    String role,
  ) {
    return Map<String, Map<String, dynamic>>.from(
      _cache[projectId]?[phase]?[role] ?? {},
    );
  }

  /// Set/update a single answer and save to backend
  Future<void> setAnswer(
    String projectId,
    int phase,
    String role,
    String subQ,
    Map<String, dynamic> ans,
  ) async {
    // Update cache immediately for responsive UI
    final proj = _cache.putIfAbsent(projectId, () => {});
    final phaseMap = proj.putIfAbsent(phase, () => {});
    final roleMap = phaseMap.putIfAbsent(role, () => {});
    roleMap[subQ] = ans;
    _cache.refresh();

    // Debounce save to backend (wait for user to finish typing)
    final saveKey = '$projectId-$phase-$role';
    _pendingSaves[saveKey]?.ignore(); // Cancel pending save if exists

    _pendingSaves[saveKey] = Future.delayed(
      const Duration(milliseconds: 500),
      () => _saveToBackend(projectId, phase, role),
    );
  }

  /// Save all answers for a role to backend
  Future<bool> _saveToBackend(String projectId, int phase, String role) async {
    try {
  final answers = getRoleSheet(projectId, phase, role);
  print('💾 Saving ${answers.length} answers for $role via checklist-answer API...');
      final ok = await _answerService.saveAnswers(projectId, phase, role, answers);
      if (ok) {
        print('✓ Saved checklist answers for $role');
        // Editing clears submission status; update cache so UI enables resubmit
        final proj = _submissionCache.putIfAbsent(projectId, () => {});
        final phaseMap = proj.putIfAbsent(phase, () => {});
        phaseMap[role] = {
          'is_submitted': false,
          'submitted_at': null,
          'answer_count': answers.length,
        };
        _submissionCache.refresh();
      }
      return true;
    } catch (e) {
      print('❌ Error saving checklist answers: $e');
      return false;
    }
  }

  /// Submit checklist (mark as submitted on backend)
  Future<bool> submitChecklist(String projectId, int phase, String role) async {
    try {
      // First ensure all answers are saved
      await _saveToBackend(projectId, phase, role);

  // Submit via checklist-answer API
  final success = await _answerService.submitChecklist(projectId, phase, role);

      if (success) {
        // Update submission cache
        final proj = _submissionCache.putIfAbsent(projectId, () => {});
        final phaseMap = proj.putIfAbsent(phase, () => {});
        phaseMap[role] = {
          'is_submitted': true,
          'submitted_at': DateTime.now(),
          'answer_count': getRoleSheet(projectId, phase, role).length,
        };
        _submissionCache.refresh();
        print('✓ Submitted checklist for $role');
      }

      return success;
    } catch (e) {
      print('Error submitting checklist: $e');
      return false;
    }
  }

  /// Get submission info from cache
  Map<String, dynamic>? submissionInfo(
    String projectId,
    int phase,
    String role,
  ) {
    return _submissionCache[projectId]?[phase]?[role];
  }

  /// Load submission status from backend
  Future<void> _loadSubmissionStatus(
    String projectId,
    int phase,
    String role,
  ) async {
    try {
      // Derive status locally from checklist since dedicated service removed
      final status = await _deriveSubmissionStatus(projectId, phase, role);
      final proj = _submissionCache.putIfAbsent(projectId, () => {});
      final phaseMap = proj.putIfAbsent(phase, () => {});
      phaseMap[role] = status;
      _submissionCache.refresh();
    } catch (e) {
      print('Error loading submission status: $e');
    }
  }

  /// Derive submission status from existing checklist data
  Future<Map<String, dynamic>> _deriveSubmissionStatus(
    String projectId,
    int phase,
    String role,
  ) async {
    try {
      final status = await _answerService.getSubmissionStatus(projectId, phase, role);
      return status;
    } catch (e) {
      print('Error deriving submission status: $e');
      return {
        'is_submitted': false,
        'submitted_at': null,
        'answer_count': 0,
      };
    }
  }

  /// Check if currently loading
  bool isLoading(String projectId, int phase, String role) {
    return _isLoading['$projectId-$phase-$role'] ?? false;
  }

  /// Clear cache for a specific project to force reload from backend
  void clearProjectCache(String projectId) {
    print('🗑️ Clearing cache for project: $projectId');
    _cache.remove(projectId);
    _submissionCache.remove(projectId);
    _cache.refresh();
    _submissionCache.refresh();
  }

  /// Clear all cache
  void clearAllCache() {
    print('🗑️ Clearing all checklist cache');
    _cache.clear();
    _submissionCache.clear();
    _cache.refresh();
    _submissionCache.refresh();
  }
}
