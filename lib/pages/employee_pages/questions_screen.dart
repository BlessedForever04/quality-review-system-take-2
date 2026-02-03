import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:quality_review/controllers/auth_controller.dart';
import 'package:quality_review/pages/employee_pages/checklist.dart';
import 'package:quality_review/pages/employee_pages/checklist_controller.dart';
import 'package:quality_review/services/approval_service.dart';
import 'package:quality_review/services/phase_checklist_service.dart';
import 'package:quality_review/services/template_service.dart';
import 'package:quality_review/services/stage_service.dart';
import 'package:quality_review/services/project_checklist_service.dart';

class QuestionsScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final List<String> leaders;
  final List<String> reviewers;
  final List<String> executors;
  final int? initialPhase;
  final String? initialSubQuestion;

  const QuestionsScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.leaders,
    required this.reviewers,
    required this.executors,
    this.initialPhase,
    this.initialSubQuestion,
  });

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final Map<String, Map<String, dynamic>> executorAnswers = {};
  final Map<String, Map<String, dynamic>> reviewerAnswers = {};
  final Set<int> executorExpanded = {};
  final Set<int> reviewerExpanded = {};
  String? _errorMessage;
  bool _editMode = false;
  late final ChecklistController checklistCtrl;
  late final ApprovalService _approvalService;
  String? _currentStageId;
  bool _isLoadingData = true;
  // Phase numbering: 1, 2, 3... directly maps to stage1, stage2, stage3...
  int _selectedPhase = 1; // Currently selected phase (1 = first phase)
  int _activePhase = 1; // Active phase index (enabled for editing)
  int _maxActualPhase = 7; // Max phase number discovered from stages
  bool _isProjectCompleted = false; // Track if all phases are completed
  Map<String, dynamic> _stageMap = {}; // Map stageKey to stage data
  Map<String, dynamic>? _approvalStatus;
  Map<String, dynamic>? _compareStatus;
  final ScrollController _executorScroll = ScrollController();
  final ScrollController _reviewerScroll = ScrollController();
  final Set<String> _highlightSubs = {};
  List<Question> checklist = []; // Checklist questions for current phase

  // Defect tracking and category state
  Map<String, int> _defectsByChecklist = {};
  Map<String, int> _checkpointsByChecklist =
      {}; // Track checkpoints per checklist
  final Map<String, String?> _selectedDefectCategory = {};
  final Map<String, String?> _selectedDefectSeverity = {};
  Map<String, Map<String, dynamic>> _defectCategories = {};
  String _reviewerSummaryKey = '_meta_reviewer_summary';

  // Counters and metrics
  // Store conflict counter per phase (key: phase number, value: conflict count)
  final Map<int, int> _conflictCounters = {};
  int _maxDefectsSeenInSession = 0;
  int _totalCheckpointsInSession = 0;
  // Track loopback count per phase (key: phase number, value: loopback count)
  final Map<int, int> _loopbackCounters = {};

  // Persisted reviewer submission summary per phase
  final Map<int, Map<String, dynamic>> _reviewerSubmissionSummaries = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers/services
    checklistCtrl = Get.find<ChecklistController>();
    _approvalService = Get.find<ApprovalService>();

    // Clear cache to ensure fresh data when opening this screen
    // This prevents stale submission status from previous session
    checklistCtrl.clearProjectCache(widget.projectId);

    // Initial load
    _loadChecklistData();
  }

  List<Map<String, dynamic>> _getAvailableCategories() {
    return _defectCategories.values.toList();
  }

  Map<String, dynamic>? _getCategoryInfo(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    return _defectCategories[categoryId];
  }

  Future<void> _assignDefectCategory(
    String checkpointId,
    String? categoryId, {
    String? severity,
  }) async {
    // Only update local state - actual save happens through updateCheckpointResponse
    setState(() {
      _selectedDefectCategory[checkpointId] = categoryId;
      if (severity != null) {
        _selectedDefectSeverity[checkpointId] = severity;
      }
    });
  }

  /// Handle reviewer reverting the phase back to executor
  /// This allows the executor to re-fill the checklist if the reviewer is not satisfied
  /// The cycle continues until the reviewer is satisfied and approves
  Future<void> _handleReviewerRevert() async {
    // Check if current user is a reviewer
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }
    final canEditReviewer =
        currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    if (!canEditReviewer) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert to Executor'),
        content: const Text(
          'Are you sure you want to send this phase back to the executor? '
          'The executor will need to review and resubmit their work. '
          'This cycle can continue until you are satisfied with the results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _approvalService.revertToExecutor(widget.projectId, _selectedPhase);

      // Clear cache to ensure fresh data is loaded
      checklistCtrl.clearProjectCache(widget.projectId);

      // Reload checklist data to reflect the revert
      await _loadChecklistData();

      if (mounted) {
        // Force UI rebuild to show updated submission status
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase reverted to executor successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revert: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadChecklistData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
      _approvalStatus = null;
      _compareStatus = null;
      _errorMessage = null;
      // Clear previous category/severity data before loading fresh data
      _selectedDefectCategory.clear();
      _selectedDefectSeverity.clear();
    });

    // Get actual phase number from UI selection
    // UI phases are 1, 2, 3 and these directly map to stage1, stage2, stage3
    final phase = _selectedPhase;

    try {
      // Step 0: Load defect categories from template
      try {
        final templateService = Get.find<TemplateService>();
        final template = await templateService.fetchTemplate();
        final cats = template['defectCategories'] as List<dynamic>? ?? [];
        _defectCategories = {};
        for (final cat in cats) {
          if (cat is Map<String, dynamic>) {
            final id = (cat['_id'] ?? '').toString();
            if (id.isNotEmpty) {
              _defectCategories[id] = cat;
            }
          }
        }
      } catch (e) {
        // Silently handle defect category loading errors
      }

      // Step 1: Fetch stages
      final stageService = Get.find<StageService>();

      final stages = await stageService.listStages(widget.projectId);

      // Build stage map and discover maximum actual phase number
      // Also load conflict counters for all phases
      int discoveredMaxActual = 1;
      final stageMap = <String, dynamic>{};
      final conflictCountersMap = <int, int>{};

      for (final s in stages) {
        final name = (s['stage_name'] ?? '').toString();
        final stageKey = (s['stage_key'] ?? '').toString();
        stageMap[stageKey] = {'name': name, ...s};

        print('\n🔍 Processing stage: $stageKey');
        print('   Full stage data: $s');

        // Extract phase number from stage_key (e.g., "stage1" => 1, "stage2" => 2)
        // This is reliable because stage_key is always in format "stageN"
        final match = RegExp(
          r'stage(\d+)',
          caseSensitive: false,
        ).firstMatch(stageKey);
        if (match != null) {
          final p = int.tryParse(match.group(1) ?? '') ?? 0;
          if (p > discoveredMaxActual) discoveredMaxActual = p;

          // Load conflict counter for this phase - handle both int and double
          final conflictValue = s['conflict_count'];
          print(
            '   🔢 Phase $p - conflictValue from stage: $conflictValue (type: ${conflictValue.runtimeType})',
          );
          final conflictCount = conflictValue is int
              ? conflictValue
              : (conflictValue is double ? conflictValue.toInt() : 0);
          conflictCountersMap[p] = conflictCount;
          debugPrint(
            '✓ Phase $p: Loaded conflict counter = $conflictCount (from: $conflictValue, type: ${conflictValue.runtimeType})',
          );
        }
      }

      setState(() {
        _stageMap = stageMap;
        _maxActualPhase = discoveredMaxActual;
        // Clear and update conflict counters for all phases
        _conflictCounters.clear();
        _conflictCounters.addAll(conflictCountersMap);
        debugPrint('✓ Conflict counters updated: $_conflictCounters');

        // Loopback counter is the same as conflict counter (tracks reviewer reverts)
        _loopbackCounters.clear();
        _loopbackCounters.addAll(conflictCountersMap);
        debugPrint('✓ Loopback counters updated: $_loopbackCounters');
      });

      if (stages.isEmpty) {
        if (!mounted) return;
        setState(() {
          checklist = [];
          _isLoadingData = false;
          _errorMessage =
              'No stages/checklists found. Ensure the template exists and the project is started.';
        });
        return;
      }

      // Step 2: Find stage for current phase using stage_key
      // _selectedPhase directly corresponds to actual phase number (1, 2, 3...)
      // stage_key is in format "stage1", "stage2", etc. matching the actual phase numbers
      final expectedStageKey = 'stage$phase';
      final stage = stages.firstWhereOrNull((s) {
        final stageKey = (s['stage_key'] ?? '').toString().toLowerCase();
        return stageKey == expectedStageKey;
      });

      if (stage == null) {
        if (!mounted) return;
        setState(() {
          checklist = [];
          _isLoadingData = false;
          _errorMessage =
              'No stage found for Phase $phase (looking for $expectedStageKey). Available stages: ${stages.map((s) => s['stage_key']).join(", ")}';
        });
        return;
      }

      final stageId = (stage['_id'] ?? '').toString();
      _currentStageId = stageId;

      // Debug: Log the complete stage object to verify fields
      debugPrint('📦 Current stage object: $stage');
      debugPrint(
        '📊 Stage fields - conflict_count: ${stage['conflict_count']}',
      );

      // Ensure conflict counter exists for this phase
      if (!_conflictCounters.containsKey(phase)) {
        setState(() {
          _conflictCounters[phase] = 0;
        });
      }

      // Step 3: Try to fetch from new ProjectChecklist API first
      List<Question> loadedChecklist = [];
      try {
        final projectChecklistService = Get.find<ProjectChecklistService>();
        final projectChecklistData = await projectChecklistService
            .fetchChecklist(widget.projectId, stageId);

        final groups = projectChecklistData['groups'] as List<dynamic>? ?? [];
        if (groups.isNotEmpty) {
          loadedChecklist = Question.fromProjectChecklistGroups(groups);

          // Extract defect category and severity from questions
          for (final group in groups) {
            if (group is! Map<String, dynamic>) continue;

            // Process direct questions in group
            final directQuestions = group['questions'] as List<dynamic>? ?? [];
            for (final q in directQuestions) {
              if (q is! Map<String, dynamic>) continue;
              final questionId = (q['_id'] ?? '').toString();
              if (questionId.isEmpty) continue;

              // Extract defect info from reviewer response
              final reviewerResp =
                  q['reviewerResponse'] as Map<String, dynamic>? ?? {};
              final defectCatId = (reviewerResp['categoryId'] ?? '').toString();
              final defectSeverity = (reviewerResp['severity'] ?? '')
                  .toString();

              if (defectCatId.isNotEmpty) {
                _selectedDefectCategory[questionId] = defectCatId;
                _selectedDefectSeverity[questionId] = defectSeverity.isNotEmpty
                    ? defectSeverity
                    : null;
              }
            }

            // Process questions from sections
            final sections = group['sections'] as List<dynamic>? ?? [];
            for (final section in sections) {
              if (section is! Map<String, dynamic>) continue;
              final sectionQuestions =
                  section['questions'] as List<dynamic>? ?? [];

              for (final q in sectionQuestions) {
                if (q is! Map<String, dynamic>) continue;
                final questionId = (q['_id'] ?? '').toString();
                if (questionId.isEmpty) continue;

                // Extract defect info from reviewer response
                final reviewerResp =
                    q['reviewerResponse'] as Map<String, dynamic>? ?? {};
                final defectCatId = (reviewerResp['categoryId'] ?? '')
                    .toString();
                final defectSeverity = (reviewerResp['severity'] ?? '')
                    .toString();

                if (defectCatId.isNotEmpty) {
                  _selectedDefectCategory[questionId] = defectCatId;
                  _selectedDefectSeverity[questionId] =
                      defectSeverity.isNotEmpty ? defectSeverity : null;
                }
              }
            }
          }
        }
      } catch (e) {}

      // Step 4: Fallback to old checklist structure if needed
      if (loadedChecklist.isEmpty) {
        List<Map<String, dynamic>> checklists = [];
        try {
          final checklistService = Get.find<PhaseChecklistService>();
          final res = await checklistService.listForStage(stageId);
          checklists = List<Map<String, dynamic>>.from(res as List);
        } catch (e) {
          final msg = e.toString();
          if (!mounted) return;
          setState(() {
            checklist = [];
            _isLoadingData = false;
            if (msg.contains('status=404')) {
              _errorMessage =
                  'No checklists found for this stage (404). Ensure the template was cloned or backend routes exist.';
            } else if (msg.toLowerCase().contains('non-json') ||
                msg.toLowerCase().contains('html')) {
              _errorMessage =
                  'Backend returned a non-JSON response when fetching checklists. Check the backend service.';
            } else {
              _errorMessage = 'Failed to fetch checklists: $msg';
            }
          });
          return;
        }

        if (checklists.isEmpty) {
          // As a last fallback, mirror admin template for this phase
          try {
            final templateService = Get.find<TemplateService>();
            final template = await templateService.fetchTemplate();
            final stageKey = 'stage$phase';
            final stageData = template[stageKey];
            if (stageData is List && stageData.isNotEmpty) {
              loadedChecklist = _questionsFromTemplateStage(stageData);
            } else if (stageData is Map && stageData.isNotEmpty) {
              loadedChecklist = _questionsFromTemplateStage([stageData]);
            }
          } catch (e) {}

          if (loadedChecklist.isEmpty) {
            if (!mounted) return;
            setState(() {
              checklist = [];
              _isLoadingData = false;
              _errorMessage =
                  'No checklists available for this stage. Ensure templates/checkpoints exist.';
            });
            return;
          }
        }

        // Step 4b: Build question list from old structure
        final checklistService = Get.find<PhaseChecklistService>();
        for (final cl in checklists) {
          final checklistId = (cl['_id'] ?? '').toString();
          final checklistName = (cl['checklist_name'] ?? '').toString();

          final checkpoints = await checklistService.getCheckpoints(
            checklistId,
          );

          final cpObjs = checkpoints
              .map((cp) {
                final cpId = (cp['_id'] ?? '').toString();

                // Extract defect category and severity from checkpoint.defect
                final defect = cp['defect'] as Map? ?? {};
                final defectCatId = (defect['categoryId'] ?? '').toString();
                final defectSeverity = (defect['severity'] ?? '').toString();

                // Store in local maps for UI
                if (defectCatId.isNotEmpty) {
                  _selectedDefectCategory[cpId] = defectCatId;
                  _selectedDefectSeverity[cpId] = defectSeverity.isNotEmpty
                      ? defectSeverity
                      : null;
                }

                return {
                  'id': cpId,
                  'text': (cp['question'] ?? '').toString(),
                  'categoryId': defectCatId,
                };
              })
              .where((m) => (m['text'] ?? '').isNotEmpty)
              .cast<Map<String, String>>()
              .toList();

          if (cpObjs.isNotEmpty) {
            loadedChecklist.add(
              Question(
                mainQuestion: checklistName,
                subQuestions: cpObjs,
                checklistId: checklistId,
              ),
            );
          }
        }
      } // Close the if (loadedChecklist.isEmpty) block

      // If old structure produced no questions (e.g., 0 checkpoints), mirror template
      if (loadedChecklist.isEmpty) {
        try {
          final templateService = Get.find<TemplateService>();
          final template = await templateService.fetchTemplate();
          final stageKey = 'stage$phase';
          final stageData = template[stageKey];
          if (stageData is List && stageData.isNotEmpty) {
            loadedChecklist = _questionsFromTemplateStage(stageData);
          } else if (stageData is Map && stageData.isNotEmpty) {
            loadedChecklist = _questionsFromTemplateStage([stageData]);
          }
        } catch (e) {}
      }

      // Use the loaded checklist (either from ProjectChecklist or old structure)
      if (!mounted) return;
      setState(() {
        checklist = loadedChecklist;
      });
    } catch (e) {
      if (!mounted) return;
      // Don't show checkpoint-related errors to users
      final errorMsg = e.toString();
      if (!errorMsg.toLowerCase().contains('checkpoint')) {
        setState(() {
          checklist = [];
          _errorMessage = errorMsg;
        });
      } else {
        // Silently ignore checkpoint errors
        setState(() {
          checklist = [];
        });
      }
    }

    // Step 5: Load answers
    try {
      checklistCtrl.clearProjectCache(widget.projectId);

      await Future.wait([
        checklistCtrl.loadAnswers(widget.projectId, phase, 'executor'),
        checklistCtrl.loadAnswers(widget.projectId, phase, 'reviewer'),
      ]);

      try {
        final status = await _approvalService.compare(widget.projectId, phase);
        if (mounted) _compareStatus = status;
      } catch (_) {}

      try {
        final appr = await _approvalService.getStatus(widget.projectId, phase);
        if (mounted) _approvalStatus = appr;
      } catch (_) {}

      // Step 5b: Fetch revert count for this phase from DB
      try {
        await _approvalService.getRevertCount(widget.projectId, phase);
      } catch (e) {}

      // Force refresh submission status to ensure it's up to date
      // This is critical for proper UI state when logging back in
      debugPrint('🔄 Force refreshing submission status for phase $phase');
      await checklistCtrl.loadAnswers(widget.projectId, phase, 'executor');
      await checklistCtrl.loadAnswers(widget.projectId, phase, 'reviewer');

      final executorSheet = checklistCtrl.getRoleSheet(
        widget.projectId,
        phase,
        'executor',
      );
      final reviewerSheet = checklistCtrl.getRoleSheet(
        widget.projectId,
        phase,
        'reviewer',
      );
      // Extract persisted reviewer summary (if any) from the answers map
      Map<String, dynamic>? persistedReviewerSummary;
      final metaSummary = reviewerSheet[_reviewerSummaryKey];
      if (metaSummary != null) {
        // Extract the actual summary data from the meta answer structure
        // First check if there's a metadata field (from backend)
        if (metaSummary.containsKey('metadata') &&
            metaSummary['metadata'] is Map<String, dynamic>) {
          final metadata = metaSummary['metadata'] as Map<String, dynamic>;
          if (metadata.containsKey('_summaryData') &&
              metadata['_summaryData'] is Map<String, dynamic>) {
            persistedReviewerSummary = Map<String, dynamic>.from(
              metadata['_summaryData'] as Map<String, dynamic>,
            );
          }
        }
        // Fallback: check direct _summaryData field (old structure)
        else if (metaSummary.containsKey('_summaryData') &&
            metaSummary['_summaryData'] is Map<String, dynamic>) {
          persistedReviewerSummary = Map<String, dynamic>.from(
            metaSummary['_summaryData'] as Map<String, dynamic>,
          );
        } else {
          // Last fallback: try to use the whole object
          persistedReviewerSummary = Map<String, dynamic>.from(metaSummary);
        }
      }
      // Remove meta entry so it does not interfere with question rendering
      reviewerSheet.remove(_reviewerSummaryKey);

      // Extract category and severity from reviewer answers and populate the maps
      debugPrint(
        '🔍 Extracting category/severity from ${checklist.length} checklists...',
      );
      for (final question in checklist) {
        for (final subQuestion in question.subQuestions) {
          final questionId = (subQuestion['id'] ?? '').toString();
          final questionText = (subQuestion['text'] ?? '').toString();

          // The key used by RoleColumn is (id ?? text)
          final key = questionId.isNotEmpty ? questionId : questionText;

          if (key.isEmpty) continue;

          // Try to find the answer by question ID or text
          var answer = reviewerSheet[questionId];
          if (answer == null && questionText.isNotEmpty) {
            answer = reviewerSheet[questionText];
          }
          if (answer == null && key.isNotEmpty) {
            answer = reviewerSheet[key];
          }

          if (answer != null && answer is Map<String, dynamic>) {
            final categoryId = (answer['categoryId'] ?? '').toString();
            final severity = (answer['severity'] ?? '').toString();

            // Store using the same key that RoleColumn uses (id ?? text)
            if (categoryId.isNotEmpty) {
              _selectedDefectCategory[key] = categoryId;
            }
            if (severity.isNotEmpty) {
              _selectedDefectSeverity[key] = severity;
            }

            debugPrint('📥 Loaded category/severity:');
            debugPrint('   Key: $key');
            debugPrint('   QuestionId: $questionId');
            debugPrint('   QuestionText: $questionText');
            debugPrint('   CategoryId: $categoryId');
            debugPrint('   Severity: $severity');
          } else {
            debugPrint(
              '⚠️  No answer found for key: $key (id: $questionId, text: $questionText)',
            );
          }
        }
      }
      debugPrint(
        '📊 Total categories loaded: ${_selectedDefectCategory.length}',
      );
      debugPrint(
        '📊 Total severities loaded: ${_selectedDefectSeverity.length}',
      );

      if (!mounted) return;
      setState(() {
        executorAnswers.clear();
        executorAnswers.addAll(executorSheet);
        reviewerAnswers.clear();
        reviewerAnswers.addAll(reviewerSheet);
        if (persistedReviewerSummary != null) {
          _reviewerSubmissionSummaries[_selectedPhase] =
              persistedReviewerSummary;
        }
      });
      // Recompute defect counts after loading answers
      _recomputeDefects();
    } catch (e) {
      // Silently fail on answer loading
    }

    if (!mounted) return;
    setState(() {
      _isLoadingData = false;
    });

    // Compute active phase
    await _computeActivePhase();

    // If an initial sub-question was provided, expand and scroll to it
    if (widget.initialSubQuestion != null) {
      final target = widget.initialSubQuestion!;
      final idx = checklist.indexWhere(
        (q) => q.subQuestions.any(
          (s) => (s['text'] ?? '') == target || (s['id'] ?? '') == target,
        ),
      );
      if (idx != -1) {
        // compute stable key for highlight
        final matched = checklist[idx].subQuestions.firstWhere(
          (s) => (s['text'] ?? '') == target || (s['id'] ?? '') == target,
        );
        final key = (matched['id'] ?? matched['text'])!;
        setState(() {
          executorExpanded.add(idx);
          reviewerExpanded.add(idx);
          _highlightSubs.add(key);
        });
        // Scroll to position instantly
        final offset = (idx * 140).toDouble();
        if (_executorScroll.hasClients) {
          _executorScroll.jumpTo(
            offset.clamp(0, _executorScroll.position.maxScrollExtent),
          );
        }
        if (_reviewerScroll.hasClients) {
          _reviewerScroll.jumpTo(
            offset.clamp(0, _reviewerScroll.position.maxScrollExtent),
          );
        }
        // Clear highlight after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _highlightSubs.remove(key));
          }
        });
      }
    }
  }

  // Convert admin template stage data to our Questions structure
  List<Question> _questionsFromTemplateStage(List<dynamic> stageData) {
    final questions = <Question>[];
    for (final group in stageData) {
      if (group is! Map<String, dynamic>) continue;
      final groupId = (group['_id'] ?? '').toString();
      final groupName = (group['text'] ?? group['groupName'] ?? '').toString();
      if (groupName.isEmpty) continue;

      final subs = <Map<String, String>>[];

      // Direct checkpoints/questions under group
      final checkpoints = (group['checkpoints'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final cp in checkpoints) {
        subs.add({
          'id': (cp['_id'] ?? '').toString(),
          'text': (cp['text'] ?? cp['question'] ?? '').toString(),
          'categoryId': (cp['categoryId'] ?? '').toString(),
        });
      }

      // Section-based checkpoints/questions
      final sections = (group['sections'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final section in sections) {
        final sectionName = (section['text'] ?? section['sectionName'] ?? '')
            .toString();
        final sectionCps = (section['checkpoints'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final sectionQs = (section['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        for (final cp in sectionCps) {
          subs.add({
            'id': (cp['_id'] ?? '').toString(),
            'text': (cp['text'] ?? cp['question'] ?? '').toString(),
            'categoryId': (cp['categoryId'] ?? '').toString(),
            'sectionName': sectionName,
          });
        }
        for (final q in sectionQs) {
          subs.add({
            'id': (q['_id'] ?? '').toString(),
            'text': (q['text'] ?? '').toString(),
            'categoryId': (q['categoryId'] ?? '').toString(),
            'sectionName': sectionName,
          });
        }
      }

      if (subs.isNotEmpty) {
        questions.add(
          Question(
            mainQuestion: groupName,
            subQuestions: subs
                .where((m) => (m['text'] ?? '').isNotEmpty)
                .toList(),
            checklistId: groupId,
          ),
        );
      }
    }
    return questions;
  }

  void _recomputeDefects() {
    // Compute defects locally from current answers - much simpler and more reliable
    final counts = <String, int>{};
    final checkpointCounts = <String, int>{};
    int total = 0;
    int totalCheckpoints = 0;

    for (final q in checklist) {
      final checklistId = q.checklistId ?? '';
      int defectCount = 0;
      final subs = q.subQuestions;
      final checkpointCount = subs.length;

      for (final sub in subs) {
        final textKey = (sub['text'] ?? '').toString();
        final idKey = (sub['id'] ?? '').toString();

        // Try text key first, then id key
        var execAnswer = executorAnswers[textKey]?['answer'];
        var reviAnswer = reviewerAnswers[textKey]?['answer'];

        if (execAnswer == null && idKey.isNotEmpty) {
          execAnswer = executorAnswers[idKey]?['answer'];
          reviAnswer = reviewerAnswers[idKey]?['answer'];
        }

        // Count as defect only if both have answered and answers differ
        if (execAnswer != null &&
            reviAnswer != null &&
            execAnswer != reviAnswer) {
          defectCount++;
        }
      }

      counts[checklistId] = defectCount;
      checkpointCounts[checklistId] = checkpointCount;
      total += defectCount;
      totalCheckpoints += checkpointCount;
    }

    if (mounted) {
      setState(() {
        _defectsByChecklist = counts;
        _checkpointsByChecklist = checkpointCounts;
        // Track the highest defects seen in this session
        // Even if conflicts are fixed later, we remember the max we saw
        if (total > _maxDefectsSeenInSession) {
          _maxDefectsSeenInSession = total;
        }
        _totalCheckpointsInSession = totalCheckpoints;
      });
    }
  }

  /// Accumulate maximum defects from this session
  /// This ensures that even if conflicts are fixed before submission,
  /// the maximum defects encountered are still counted
  void _accumulateDefects() {
    if (_totalCheckpointsInSession > 0 && _maxDefectsSeenInSession > 0) {
      // Reset session tracking for next submission
      _maxDefectsSeenInSession = 0;
      _totalCheckpointsInSession = 0;
    }
  }

  Future<void> _computeActivePhase() async {
    int active = 1;
    bool allPhasesCompleted = false;
    try {
      // Dynamically check all phases based on _maxActualPhase
      for (int phase = 1; phase <= _maxActualPhase; phase++) {
        final status = await _approvalService.getStatus(
          widget.projectId,
          phase,
        );

        if (status != null && status['status'] == 'approved') {
          // If this phase is approved, the next phase becomes active
          active = phase + 1;
        } else {
          // If this phase is not approved, stop checking
          break;
        }
      }

      // If active phase exceeds max phase, all phases are completed
      if (active > _maxActualPhase) {
        allPhasesCompleted = true;
        active = _maxActualPhase; // Stay on last phase
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isProjectCompleted = allPhasesCompleted;
      // active represents the next phase that's now active
      // active = 1 means phase 1 is active, active = 2 means phase 2 is active, etc.
      _activePhase = active;
      // Only clamp selected phase for non-TeamLeader users
      // TeamLeader can view any phase including pending ones
      final currentUserName = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value?.name
          : null;
      final isTeamLeader =
          currentUserName != null && authRoleIsTeamLeader(currentUserName);
      if (!isTeamLeader) {
        // Non-TeamLeader users: clamp to active phase
        if (_selectedPhase > _activePhase) _selectedPhase = _activePhase;
      }
      // Always ensure phase is at least 1
      if (_selectedPhase < 1) _selectedPhase = 1;
    });
    // Refresh approval/compare for the currently selected phase
    try {
      // Use phase number when comparing approval status
      final status = await _approvalService.compare(
        widget.projectId,
        _selectedPhase,
      );
      if (mounted) setState(() => _compareStatus = status);
    } catch (_) {}
    try {
      final appr = await _approvalService.getStatus(
        widget.projectId,
        _selectedPhase,
      );
      if (mounted) {
        setState(() {
          _approvalStatus = appr;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Determine current user role permissions from provided lists
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }
    // TeamLeader role: show approve/revert controls
    final isTeamLeader =
        currentUserName != null &&
        (authRoleIsTeamLeader(currentUserName) == true);
    final canEditExecutor =
        currentUserName != null &&
        widget.executors
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());
    final canEditReviewer =
        currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    // Editing only allowed on active phase; older phases view-only for all
    // If project is completed, all phases are view-only
    // Special case: if phase is reverted, it becomes editable again
    final approvalStatus = _approvalStatus?['status'] as String?;
    final isReverted =
        approvalStatus == 'reverted' ||
        approvalStatus == 'reverted_to_executor';
    final phaseEditable =
        (_selectedPhase == _activePhase || isReverted) && !_isProjectCompleted;

    // Check if executor checklist for this phase has been submitted
    final executorSubmissionInfo = checklistCtrl.submissionInfo(
      widget.projectId,
      _selectedPhase,
      'executor',
    );
    final executorSubmitted = executorSubmissionInfo?['is_submitted'] == true;

    // Check if reviewer checklist for this phase has been submitted
    final reviewerSubmissionInfo = checklistCtrl.submissionInfo(
      widget.projectId,
      _selectedPhase,
      'reviewer',
    );
    final reviewerSubmitted = reviewerSubmissionInfo?['is_submitted'] == true;

    // Debug logging for submission status
    debugPrint('📊 Phase $_selectedPhase submission status:');
    debugPrint(
      '   Executor submitted: $executorSubmitted (info: $executorSubmissionInfo)',
    );
    debugPrint(
      '   Reviewer submitted: $reviewerSubmitted (info: $reviewerSubmissionInfo)',
    );
    debugPrint('   Approval status: $approvalStatus');
    debugPrint('   Is reverted: $isReverted');
    debugPrint('   Phase editable: $phaseEditable');

    // Can edit only if phase is editable AND checklist has not been submitted
    // Special case: when reverted to executor, only executor can edit (reviewer stays submitted)
    final canEditExecutorPhase =
        canEditExecutor && phaseEditable && !executorSubmitted;
    final canEditReviewerPhase =
        canEditReviewer &&
        phaseEditable &&
        !reviewerSubmitted &&
        executorSubmitted && // Reviewer can only edit after executor submits
        approvalStatus !=
            'reverted_to_executor'; // Reviewer cannot edit when reverted to executor

    debugPrint(
      '   Can edit executor: $canEditExecutorPhase (canEditExecutor: $canEditExecutor, phaseEditable: $phaseEditable, !executorSubmitted: ${!executorSubmitted})',
    );
    debugPrint(
      '   Can edit reviewer: $canEditReviewerPhase (canEditReviewer: $canEditReviewer, phaseEditable: $phaseEditable, !reviewerSubmitted: ${!reviewerSubmitted}, executorSubmitted: $executorSubmitted)',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Checklist - ${widget.projectTitle}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        actions: [
          // Spacer to push all content to the right side
          const Spacer(),
          // TeamLeader can only view - no approve/revert buttons needed anymore
          // Reviewer submission now auto-approves the phase

          // Spacer to create gap before right-aligned items
          const Spacer(),
          // Phase selector on the right
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedPhase,
              alignment: Alignment.center,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.expand_more, color: Colors.white),
              // Build UI phase list dynamically from actual phases [1.._maxActualPhase]
              items:
                  List<int>.generate(
                    _maxActualPhase.clamp(1, 10),
                    (i) => i + 1, // UI phases: 1, 2, 3, ...
                  ).map((p) {
                    // Get stage name from stageMap
                    final stageKey = 'stage$p';
                    final stageData =
                        _stageMap[stageKey] as Map<String, dynamic>?;
                    final stageName = stageData?['name'] ?? 'Phase $p';

                    return DropdownMenuItem(
                      value: p,
                      enabled: isTeamLeader ? true : (p <= _activePhase),
                      child: Row(
                        children: [
                          // Show actual stage name from template
                          Text(stageName),
                          const SizedBox(width: 8),
                          if (p < _activePhase)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'View only',
                                style: TextStyle(fontSize: 10),
                              ),
                            )
                          else if (p == _activePhase && !_isProjectCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(fontSize: 10),
                              ),
                            )
                          else if (_isProjectCompleted && p <= _maxActualPhase)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(fontSize: 10),
                              ),
                            )
                          else if (p > _activePhase && isTeamLeader)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                // TeamLeader can navigate to any phase for review
                // Others can only go up to active phase
                if (!isTeamLeader && val > _activePhase) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You can only proceed to the next phase after approval.',
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedPhase = val;
                });
                await _loadChecklistData();
              },
            ),
          ),
          // Refresh button on far right
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload checklist data',
            onPressed: _isLoadingData
                ? null
                : () {
                    // Clear cache and reload
                    checklistCtrl.clearProjectCache(widget.projectId);
                    _loadChecklistData();
                  },
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading checklist data...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Material(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage ?? '',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_approvalStatus != null || _compareStatus != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ApprovalBanner(
                        approvalStatus: _approvalStatus,
                        compareStatus: _compareStatus,
                      ),
                    ),
                  if (_isProjectCompleted)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Material(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🎉 Project Completed! All phases have been reviewed and approved. All phases are now in view-only mode.',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Show reviewer submission summary for TeamLeader
                  if (isTeamLeader &&
                      _reviewerSubmissionSummaries[_selectedPhase] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ReviewerSubmissionSummaryCard(
                              summary:
                                  _reviewerSubmissionSummaries[_selectedPhase]!,
                              availableCategories: _getAvailableCategories(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_editMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _currentStageId == null
                                ? null
                                : () async {
                                    final nameCtrl = TextEditingController();
                                    final resp = await showDialog<String?>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('New checklist name'),
                                        content: TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Checklist name',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              ctx,
                                            ).pop(nameCtrl.text.trim()),
                                            child: const Text('Create'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (resp != null && resp.isNotEmpty) {
                                      try {
                                        final svc =
                                            Get.find<PhaseChecklistService>();
                                        await svc.createForStage(
                                          _currentStageId!,
                                          name: resp,
                                        );
                                        await _loadChecklistData();
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Create failed: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Add checklist'),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit mode: changes apply immediately to this project',
                          ),
                        ],
                      ),
                    ),
                  // Show defect rate and loopback counter for reviewers and team leaders
                  if (canEditReviewer || isTeamLeader)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Defect Rate
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Defect Rate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Builder(
                                  builder: (context) {
                                    // Calculate total defects and checkpoints
                                    int totalDefects = 0;
                                    int totalCheckpoints = 0;
                                    _defectsByChecklist.values.forEach(
                                      (count) => totalDefects += count,
                                    );
                                    _checkpointsByChecklist.values.forEach(
                                      (count) => totalCheckpoints += count,
                                    );
                                    final percentage = totalCheckpoints > 0
                                        ? (totalDefects /
                                              totalCheckpoints *
                                              100)
                                        : 0.0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${percentage.toStringAsFixed(2)}%\n($totalDefects/$totalCheckpoints)',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Loopback Counter (only for team leaders)
                          if (isTeamLeader)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.loop,
                                    color: Colors.purple.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Loopback Counter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_loopbackCounters[_selectedPhase] ?? 0}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        RoleColumn(
                          role: 'executor',
                          color: Colors.blue,
                          projectId: widget.projectId,
                          phase: _selectedPhase,
                          canEdit: canEditExecutorPhase,
                          checklist: checklist,
                          answers: executorAnswers,
                          otherAnswers: reviewerAnswers,
                          selectedDefectCategory: _selectedDefectCategory,
                          selectedDefectSeverity: _selectedDefectSeverity,
                          defectsByChecklist: _defectsByChecklist,
                          checkpointsByChecklist: _checkpointsByChecklist,
                          showDefects: isTeamLeader,
                          expanded: executorExpanded,
                          scrollController: _executorScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          isCurrentUserReviewer:
                              false, // Never show revert button in executor column
                          onExpand: (idx) => setState(
                            () => executorExpanded.contains(idx)
                                ? executorExpanded.remove(idx)
                                : executorExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => executorAnswers[subQ] = ans);

                            // Save to checklist answers
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                              subQ,
                              ans,
                            );

                            // Also update the checkpoint with category and severity if available
                            // Find checkpoint ID from the checklist Questions structure
                            String? checkpointId;
                            for (final q in checklist) {
                              final sub = q.subQuestions.firstWhereOrNull(
                                (s) =>
                                    (s['text'] ?? '') == subQ ||
                                    (s['id'] ?? '') == subQ,
                              );
                              if (sub != null) {
                                checkpointId = (sub['id'] ?? '').toString();
                                break;
                              }
                            }

                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              final categoryId =
                                  _selectedDefectCategory[checkpointId];
                              final severity =
                                  _selectedDefectSeverity[checkpointId];

                              try {
                                final checklistService =
                                    Get.find<PhaseChecklistService>();
                                await checklistService.updateCheckpointResponse(
                                  checkpointId,
                                  executorResponse: {
                                    'answer': ans['answer'],
                                    'remark': ans['remark'] ?? '',
                                  },
                                  categoryId: categoryId,
                                  severity: severity,
                                );
                              } catch (e) {
                                // Silently ignore checkpoint update errors
                              }
                            }

                            _recomputeDefects();
                          },
                          onRevert:
                              null, // Executor should never see the revert button
                          onSubmit: () async {
                            if (!canEditExecutorPhase) return;
                            // Accumulate current defects before submission
                            _accumulateDefects();
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                            );
                            if (success && mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Executor checklist submitted. Waiting for Reviewer to submit for phase approval.',
                                  ),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              await _computeActivePhase();
                            }
                          },
                          editMode: _editMode,
                          onRefresh: _loadChecklistData,
                        ),
                        RoleColumn(
                          role: 'reviewer',
                          color: Colors.green,
                          projectId: widget.projectId,
                          phase: _selectedPhase,
                          canEdit: canEditReviewerPhase,
                          checklist: checklist,
                          answers: reviewerAnswers,
                          otherAnswers: executorAnswers,
                          selectedDefectCategory: _selectedDefectCategory,
                          selectedDefectSeverity: _selectedDefectSeverity,
                          defectsByChecklist: _defectsByChecklist,
                          checkpointsByChecklist: _checkpointsByChecklist,
                          showDefects: isTeamLeader || canEditReviewer,
                          expanded: reviewerExpanded,
                          scrollController: _reviewerScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          isCurrentUserReviewer:
                              canEditReviewer &&
                              !canEditExecutor, // Only reviewers who are NOT executors
                          onExpand: (idx) => setState(
                            () => reviewerExpanded.contains(idx)
                                ? reviewerExpanded.remove(idx)
                                : reviewerExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => reviewerAnswers[subQ] = ans);

                            // Find checkpoint ID from the checklist Questions structure
                            String? checkpointId;
                            for (final q in checklist) {
                              final sub = q.subQuestions.firstWhereOrNull(
                                (s) =>
                                    (s['text'] ?? '') == subQ ||
                                    (s['id'] ?? '') == subQ,
                              );
                              if (sub != null) {
                                checkpointId = (sub['id'] ?? '').toString();
                                break;
                              }
                            }

                            // Get category and severity from answer if provided, otherwise from maps
                            String? categoryId = (ans['categoryId'] ?? '')
                                .toString();
                            if (categoryId.isEmpty &&
                                checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              categoryId =
                                  _selectedDefectCategory[checkpointId];
                            }

                            String? severity = (ans['severity'] ?? '')
                                .toString();
                            if (severity.isEmpty &&
                                checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              severity = _selectedDefectSeverity[checkpointId];
                            }

                            debugPrint('💾 Saving reviewer answer:');
                            debugPrint('   Question: $subQ');
                            debugPrint('   CheckpointId: $checkpointId');
                            debugPrint('   CategoryId: $categoryId');
                            debugPrint('   Severity: $severity');

                            // Update the maps with the current values
                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              if (categoryId != null && categoryId.isNotEmpty) {
                                _selectedDefectCategory[checkpointId] =
                                    categoryId;
                              }
                              if (severity != null && severity.isNotEmpty) {
                                _selectedDefectSeverity[checkpointId] =
                                    severity;
                              }
                            }

                            // Include category and severity in the answer for saving
                            final answerWithDefectInfo =
                                Map<String, dynamic>.from(ans);
                            if (categoryId != null && categoryId.isNotEmpty) {
                              answerWithDefectInfo['categoryId'] = categoryId;
                            }
                            if (severity != null && severity.isNotEmpty) {
                              answerWithDefectInfo['severity'] = severity;
                            }

                            // Save to checklist answers with category and severity
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                              subQ,
                              answerWithDefectInfo,
                            );

                            // Also update the checkpoint with category and severity if available
                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              try {
                                final checklistService =
                                    Get.find<PhaseChecklistService>();
                                await checklistService.updateCheckpointResponse(
                                  checkpointId,
                                  reviewerResponse: {
                                    'answer': ans['answer'],
                                    'remark': ans['remark'] ?? '',
                                  },
                                  categoryId: categoryId,
                                  severity: severity,
                                );
                              } catch (e) {
                                debugPrint(
                                  '⚠️ Checkpoint update error (non-critical): $e',
                                );
                              }
                            }

                            _recomputeDefects();
                          },
                          // Only show revert button to actual reviewers
                          onRevert: canEditReviewer
                              ? _handleReviewerRevert
                              : null,
                          onSubmit: () async {
                            // Submit reviewer checklist without showing dialog
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                            );
                            if (success && mounted) {
                              setState(() {});

                              // Wait a moment for auto-approval to process
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    '✅ Review submitted! Phase approved automatically. Next phase is now active.',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              await _computeActivePhase();

                              // Auto-switch to next phase if available
                              if (!_isProjectCompleted &&
                                  _activePhase <= _maxActualPhase) {
                                setState(() {
                                  _selectedPhase = _activePhase;
                                });
                                await _loadChecklistData();
                              }
                            }
                          },
                          editMode: _editMode,
                          onRefresh: _loadChecklistData,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool authRoleIsTeamLeader(String userName) {
    final u = userName.trim().toLowerCase();
    if (u.contains('teamleader')) return true;
    return widget.leaders.map((e) => e.trim().toLowerCase()).contains(u);
  }

  // Show defect summary dialog when reviewer submits checklist
  Future<Map<String, dynamic>?> _showReviewerSubmissionDialog(
    BuildContext context,
  ) async {
    final remarkCtrl = TextEditingController();
    String? selectedCategory;
    String? selectedCategoryName; // Store the category name too
    String? selectedSeverity;
    final categories = _getAvailableCategories();
    List<Map<String, dynamic>> suggestedCategories = [];
    bool isLoadingSuggestions = false;
    Timer? debounceTimer;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Auto-suggest on remark change
          void onRemarkChanged(String text) {
            debounceTimer?.cancel();
            if (text.trim().length < 3) {
              setDialogState(() {
                suggestedCategories = [];
                isLoadingSuggestions = false;
              });
              return;
            }
            setDialogState(() => isLoadingSuggestions = true);
            debounceTimer = Timer(const Duration(milliseconds: 500), () async {
              try {
                final matched = categories
                    .where((cat) {
                      final name = (cat['name'] ?? '').toString().toLowerCase();
                      final keywords =
                          (cat['keywords'] as List<dynamic>?)
                              ?.map((k) => k.toString().toLowerCase())
                              .toList() ??
                          [];
                      final searchText = text.toLowerCase();
                      return name.contains(searchText) ||
                          keywords.any((k) => k.contains(searchText));
                    })
                    .take(5)
                    .toList();
                setDialogState(() {
                  suggestedCategories = matched;
                  isLoadingSuggestions = false;
                });
              } catch (e) {
                setDialogState(() => isLoadingSuggestions = false);
              }
            });
          }

          return AlertDialog(
            title: const Text('Reviewer Checklist Submission Summary'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: remarkCtrl,
                      onChanged: onRemarkChanged,
                      decoration: const InputDecoration(
                        labelText: 'Remark (type to auto-suggest category)',
                        hintText: 'Enter defect remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    if (isLoadingSuggestions)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Fetching suggestions...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (suggestedCategories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Suggested Categories:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: suggestedCategories.map((cat) {
                                final id = (cat['_id'] ?? '').toString();
                                final name = (cat['name'] ?? '').toString();
                                final isSelected = selectedCategory == id;
                                return FilterChip(
                                  label: Text(name),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setDialogState(() {
                                      selectedCategory = id;
                                      selectedCategoryName = name;
                                    });
                                  },
                                  backgroundColor: Colors.blue.shade50,
                                  selectedColor: Colors.blue.shade200,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Assigned Defect Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select category',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...categories.map((cat) {
                          final id = (cat['_id'] ?? '').toString();
                          final name = (cat['name'] ?? 'Unknown').toString();
                          return DropdownMenuItem(value: id, child: Text(name));
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCategory = val;
                          // Find and store the category name
                          if (val != null) {
                            final cat = categories.firstWhere(
                              (c) => (c['_id'] ?? '').toString() == val,
                              orElse: () => {},
                            );
                            selectedCategoryName = (cat['name'] ?? '')
                                .toString();
                          } else {
                            selectedCategoryName = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSeverity,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select severity',
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('None')),
                        DropdownMenuItem(
                          value: 'Critical',
                          child: Text('Critical'),
                        ),
                        DropdownMenuItem(
                          value: 'Non-Critical',
                          child: Text('Non-Critical'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedSeverity = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop({
                    'remark': remarkCtrl.text.trim(),
                    'category': selectedCategory,
                    'categoryName': selectedCategoryName, // Save the name too
                    'severity': selectedSeverity,
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }
}
