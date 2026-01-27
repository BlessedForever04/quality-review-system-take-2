import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'checklist_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/approval_service.dart';
import '../../services/stage_service.dart';
import '../../services/phase_checklist_service.dart';
import '../../services/project_checklist_service.dart';
import '../../services/template_service.dart';
import '../../services/defect_categorization_service.dart';
// import '../../config/api_config.dart';

enum UploadStatus { pending, uploading, success, failed }

// Special key used to persist reviewer submission summary alongside answers
const String _reviewerSummaryKey = '_meta_reviewer_summary';

class ImageUploadState {
  UploadStatus status;
  double progress;
  Object? cancelToken; // keep flexible to avoid hard dependency
  ImageUploadState({
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.cancelToken,
  });
}

class Question {
  final String mainQuestion;
  // Each sub-question keeps its backend id (if any) and display text.
  // { 'id': '<checkpointId>', 'text': '<question text>', 'categoryId': '<optional>', 'sectionName': '<optional>' }
  final List<Map<String, String>> subQuestions;
  final String? checklistId; // MongoDB ID for backend checklist or group

  Question({
    required this.mainQuestion,
    required this.subQuestions,
    this.checklistId,
  });

  static List<Question> fromChecklist(
    Map<String, dynamic> checklist,
    List<Map<String, dynamic>> checkpoints,
  ) {
    final checklistId = (checklist['_id'] ?? '').toString();
    final checklistName = (checklist['checklist_name'] ?? '').toString();

    final checkpointObjs = checkpoints
        .map(
          (cp) => {
            'id': (cp['_id'] ?? '').toString(),
            'text': (cp['question'] ?? '').toString(),
            'categoryId': (cp['categoryId'] ?? '').toString(),
          },
        )
        .where((m) => (m['text'] ?? '').isNotEmpty)
        .cast<Map<String, String>>()
        .toList();

    return [
      Question(
        mainQuestion: checklistName,
        subQuestions: checkpointObjs,
        checklistId: checklistId,
      ),
    ];
  }

  // New: Create from hierarchical ProjectChecklist group structure
  static List<Question> fromProjectChecklistGroups(List<dynamic> groups) {
    final questions = <Question>[];

    for (final group in groups) {
      if (group is! Map<String, dynamic>) continue;

      final groupId = (group['_id'] ?? '').toString();
      final groupName = (group['groupName'] ?? '').toString();
      final subQuestions = <Map<String, String>>[];

      // Add direct questions in group
      final directQuestions = group['questions'] as List<dynamic>? ?? [];
      for (final q in directQuestions) {
        if (q is! Map<String, dynamic>) continue;
        subQuestions.add({
          'id': (q['_id'] ?? '').toString(),
          'text': (q['text'] ?? '').toString(),
          'categoryId': '', // Can be added later if needed
        });
      }

      // Add questions from sections
      final sections = group['sections'] as List<dynamic>? ?? [];
      for (final section in sections) {
        if (section is! Map<String, dynamic>) continue;
        final sectionName = (section['sectionName'] ?? '').toString();
        final sectionQuestions = section['questions'] as List<dynamic>? ?? [];

        for (final q in sectionQuestions) {
          if (q is! Map<String, dynamic>) continue;
          subQuestions.add({
            'id': (q['_id'] ?? '').toString(),
            'text': (q['text'] ?? '').toString(),
            'categoryId': '',
            'sectionName': sectionName, // Tag with section name
          });
        }
      }

      if (subQuestions.isNotEmpty) {
        questions.add(
          Question(
            mainQuestion: groupName,
            subQuestions: subQuestions,
            checklistId: groupId,
          ),
        );
      }
    }

    return questions;
  }
}

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
  String? _currentStageId;
  bool _isLoadingData = true;
  // Phase numbering: 1, 2, 3... directly maps to stage1, stage2, stage3...
  int _selectedPhase = 1; // Currently selected phase (1 = first phase)
  int _activePhase = 1; // Active phase index (enabled for editing)
  int _maxActualPhase = 7; // Max phase number discovered from stages
  List<Map<String, dynamic>> _stages = []; // Store stages with names
  Map<String, dynamic> _stageMap = {}; // Map stageKey to stage data
  Map<String, dynamic>? _approvalStatus;
  Map<String, dynamic>? _compareStatus;
  final ScrollController _executorScroll = ScrollController();
  final ScrollController _reviewerScroll = ScrollController();
  final Set<String> _highlightSubs = {};
  Map<String, int> _defectsByChecklist = {};
  Map<String, int> _checkpointsByChecklist =
      {}; // Track checkpoints per checklist
  int _defectsTotal = 0;
  int _totalCheckpoints = 0; // Total number of checkpoints
  int _loopbackCounter = 0; // Track loopback count for current phase
  Map<String, Map<String, dynamic>> _defectCategories = {};
  final Map<String, String?> _selectedDefectCategory = {};
  final Map<String, String?> _selectedDefectSeverity = {};
  // Cumulative defect tracking
  double _cumulativeDefectRate = 0.0; // Accumulated defect rate percentage
  int _cumulativeDefectCount = 0; // Total defects found so far
  int _maxCheckpointsSeen = 0; // Highest checkpoint count seen
  // Session-level tracking: track highest defects seen, not just current
  int _maxDefectsSeenInSession = 0; // Highest defect count in this session
  // Reviewer submission summaries per phase
  final Map<int, Map<String, dynamic>> _reviewerSubmissionSummaries = {};
  int _totalCheckpointsInSession = 0; // Total checkpoints for this session
  // Revert tracking
  int _revertCount = 0; // Number of times checklist was reverted by SDH

  ApprovalService get _approvalService => Get.find<ApprovalService>();

  late List<Question> checklist;

  @override
  void initState() {
    super.initState();
    print('🔷 QuestionsScreen.initState() for project: ${widget.projectId}');
    checklistCtrl = Get.isRegistered<ChecklistController>()
        ? Get.find<ChecklistController>()
        : Get.put(ChecklistController());

    print('✓ ChecklistController obtained: ${checklistCtrl.runtimeType}');

    if (widget.initialPhase != null &&
        widget.initialPhase! >= 1 &&
        widget.initialPhase! <= 5) {
      _selectedPhase = widget.initialPhase!;
    }

    checklist = [];

    _loadChecklistData();
  }

  Map<String, dynamic>? _getCategoryInfo(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      debugPrint('🔹 _getCategoryInfo: categoryId is null or empty');
      return null;
    }
    final cat = _defectCategories[categoryId];
    if (cat == null) {
      debugPrint(
        '🔹 _getCategoryInfo: Category not found for ID: $categoryId. Available IDs: ${_defectCategories.keys.toList()}',
      );
      return null;
    }
    if ((cat['name'] ?? '').isEmpty) {
      debugPrint(
        '🔹 _getCategoryInfo: Category missing name for ID: $categoryId, cat: $cat',
      );
      return null;
    }
    debugPrint(
      '✓ _getCategoryInfo: Found category for ID: $categoryId, cat: $cat',
    );
    return cat;
  }

  List<Map<String, dynamic>> _getAvailableCategories() {
    return _defectCategories.values.toList();
  }

  Future<void> _assignDefectCategory(
    String checkpointId,
    String? categoryId, {
    String? severity,
  }) async {
    try {
      print(
        '🔄 Assigning defect category: $checkpointId → $categoryId ($severity)',
      );

      // Immediately update local state
      setState(() {
        _selectedDefectCategory[checkpointId] = categoryId;
        if (severity != null) {
          _selectedDefectSeverity[checkpointId] = severity;
        }
      });

      // Save to backend
      if (categoryId != null && categoryId.isNotEmpty) {
        final checklistService = Get.find<PhaseChecklistService>();
        print('📡 Saving to backend...');
        await checklistService.assignDefectCategory(
          checkpointId,
          categoryId,
          severity: severity,
        );
        print('✓ Saved successfully');
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      print(
        '🔍 CHECKLIST PAGE: Loading data for Phase $phase, ProjectID: ${widget.projectId}',
      );

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
              print('  📂 Category loaded: ID="$id", name="${cat['name']}"');
            }
          }
        }
        print('✓ Defect categories loaded: ${_defectCategories.length}');
      } catch (e) {
        print('⚠️ Failed to load defect categories: $e');
      }

      // Step 1: Fetch stages
      final stageService = Get.find<StageService>();

      final stages = await stageService.listStages(widget.projectId);
      print('✓ Stages fetched: ${stages.length} stages found');

      // Build stage map and discover maximum actual phase number
      int discoveredMaxActual = 1;
      final stageMap = <String, dynamic>{};
      for (final s in stages) {
        final name = (s['stage_name'] ?? '').toString();
        final stageKey = (s['stage_key'] ?? '').toString();
        stageMap[stageKey] = {'name': name, ...s};
        print('  📍 Stage: $stageKey => $name');

        // Extract phase number from stage_key (e.g., "stage1" => 1, "stage2" => 2)
        // This is reliable because stage_key is always in format "stageN"
        final match = RegExp(
          r'stage(\d+)',
          caseSensitive: false,
        ).firstMatch(stageKey);
        if (match != null) {
          final p = int.tryParse(match.group(1) ?? '') ?? 0;
          if (p > discoveredMaxActual) discoveredMaxActual = p;
        }
      }

      setState(() {
        _stages = stages;
        _stageMap = stageMap;
        _maxActualPhase = discoveredMaxActual;
      });

      if (stages.isEmpty) {
        print('❌ No stages found');
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
        print(
          '  Checking stage: "$stageKey" for expected key: "$expectedStageKey"',
        );
        return stageKey == expectedStageKey;
      });

      if (stage == null) {
        print('❌ No stage found with stage_key "$expectedStageKey"');
        print(
          '   Available stages: ${stages.map((s) => s['stage_key']).join(", ")}',
        );
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

      // Load loopback counter from the dedicated API endpoint instead of stage data
      // This ensures we always get the latest persisted value from the backend
      try {
        final loopbackCount = await _approvalService.getRevertCount(
          widget.projectId,
          phase,
        );
        setState(() {
          _loopbackCounter = loopbackCount;
        });
        print(
          '✓ Stage found: $stageId, Loopback Count: $loopbackCount (from API)',
        );
      } catch (e) {
        print('⚠️ Error loading loopback counter: $e, defaulting to 0');
        setState(() {
          _loopbackCounter = 0;
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
          print(
            '✓ Loaded ${loadedChecklist.length} groups from ProjectChecklist (hierarchical structure)',
          );
        }
      } catch (e) {
        print(
          '⚠️ ProjectChecklist not available, falling back to old structure: $e',
        );
      }

      // Step 4: Fallback to old checklist structure if needed
      if (loadedChecklist.isEmpty) {
        List<Map<String, dynamic>> checklists = [];
        try {
          final checklistService = Get.find<PhaseChecklistService>();
          final res = await checklistService.listForStage(stageId);
          checklists = List<Map<String, dynamic>>.from(res as List);
          print(
            '✓ Checklists fetched: ${checklists.length} checklists found (old structure)',
          );
        } catch (e) {
          final msg = e.toString();
          print('❌ Error fetching checklists: $msg');
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
          print('❌ No checklists returned for this stage');
          // As a last fallback, mirror admin template for this phase
          try {
            final templateService = Get.find<TemplateService>();
            final template = await templateService.fetchTemplate();
            final stageKey = 'stage$phase';
            final stageData = template[stageKey];
            if (stageData is List && stageData.isNotEmpty) {
              print('↩️ Building checklist from admin template "$stageKey"');
              loadedChecklist = _questionsFromTemplateStage(stageData);
            } else if (stageData is Map && stageData.isNotEmpty) {
              print(
                '↩️ Building checklist from admin template map "$stageKey"',
              );
              loadedChecklist = _questionsFromTemplateStage([stageData]);
            }
          } catch (e) {
            print('⚠️ Template fallback failed: $e');
          }

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
          print('  Processing checklist: $checklistName');

          final checkpoints = await checklistService.getCheckpoints(
            checklistId,
          );
          print('    Checkpoints: ${checkpoints.length}');

          // Debug: Print first checkpoint structure to verify defect data
          if (checkpoints.isNotEmpty) {
            final firstCp = checkpoints.first;
            print('    📋 First checkpoint structure:');
            print('      _id: ${firstCp['_id']}');
            print('      question: ${firstCp['question']}');
            print('      defect: ${firstCp['defect']}');
            if (firstCp['defect'] is Map) {
              print('        - categoryId: ${firstCp['defect']['categoryId']}');
              print('        - severity: ${firstCp['defect']['severity']}');
              print('        - isDetected: ${firstCp['defect']['isDetected']}');
            }
          }

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
                  print(
                    '✓ Loaded defect: $cpId → $defectCatId ($defectSeverity)',
                  );
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

          print('    📝 Created ${cpObjs.length} question objects:');
          cpObjs.forEach((obj) {
            print('       • id=${obj['id']} | text=${obj['text']}');
          });

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
            print(
              '↩️ No questions from project checklists; mirroring admin template $stageKey',
            );
            loadedChecklist = _questionsFromTemplateStage(stageData);
          } else if (stageData is Map && stageData.isNotEmpty) {
            loadedChecklist = _questionsFromTemplateStage([stageData]);
          }
        } catch (e) {
          print('⚠️ Final template fallback failed: $e');
        }
      }

      // Use the loaded checklist (either from ProjectChecklist or old structure)
      if (!mounted) return;
      setState(() {
        checklist = loadedChecklist;
      });
      print(
        '✅ Checklist loaded successfully: ${loadedChecklist.length} questions',
      );
    } catch (e) {
      print('❌ Error loading checklist: $e');
      if (!mounted) return;
      setState(() {
        checklist = [];
        _errorMessage = e.toString();
      });
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
        final revertCountFromDb = await _approvalService.getRevertCount(
          widget.projectId,
          phase,
        );
        if (mounted) {
          setState(() {
            _revertCount = revertCountFromDb;
            debugPrint(
              '✓ Revert count loaded from DB: $_revertCount for phase $phase',
            );
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error loading revert count: $e');
      }

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
      print('🔍 Looking for reviewer summary in phase $phase...');
      print('   Meta summary found: ${metaSummary != null}');
      if (metaSummary != null) {
        print('   Meta summary type: ${metaSummary.runtimeType}');
        print('   Meta summary content: $metaSummary');

        // Extract the actual summary data from the meta answer structure
        if (metaSummary is Map<String, dynamic>) {
          // First check if there's a metadata field (from backend)
          if (metaSummary.containsKey('metadata') &&
              metaSummary['metadata'] is Map<String, dynamic>) {
            final metadata = metaSummary['metadata'] as Map<String, dynamic>;
            if (metadata.containsKey('_summaryData') &&
                metadata['_summaryData'] is Map<String, dynamic>) {
              persistedReviewerSummary = Map<String, dynamic>.from(
                metadata['_summaryData'] as Map<String, dynamic>,
              );
              print(
                '✅ Extracted summary from metadata._summaryData: $persistedReviewerSummary',
              );
            }
          }
          // Fallback: check direct _summaryData field (old structure)
          else if (metaSummary.containsKey('_summaryData') &&
              metaSummary['_summaryData'] is Map<String, dynamic>) {
            persistedReviewerSummary = Map<String, dynamic>.from(
              metaSummary['_summaryData'] as Map<String, dynamic>,
            );
            print(
              '✅ Extracted summary from _summaryData: $persistedReviewerSummary',
            );
          } else {
            // Last fallback: try to use the whole object
            persistedReviewerSummary = Map<String, dynamic>.from(metaSummary);
            print(
              '✅ Using whole meta object as summary: $persistedReviewerSummary',
            );
          }
        }
      }
      // Remove meta entry so it does not interfere with question rendering
      reviewerSheet.remove(_reviewerSummaryKey);

      if (!mounted) return;
      setState(() {
        executorAnswers.clear();
        executorAnswers.addAll(executorSheet);
        reviewerAnswers.clear();
        reviewerAnswers.addAll(reviewerSheet);
        if (persistedReviewerSummary != null) {
          _reviewerSubmissionSummaries[_selectedPhase] =
              persistedReviewerSummary;
          print(
            '✅ Reviewer summary SET for phase $_selectedPhase: $persistedReviewerSummary',
          );
        } else {
          print('⚠️ No reviewer summary to set for phase $_selectedPhase');
        }
        print('📊 Current summaries map: $_reviewerSubmissionSummaries');
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

    // DEBUG: Print current state of defect maps
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('🔍 DEBUG: Defect Category & Severity Maps After Loading');
    print('═══════════════════════════════════════════════════════════════');
    print(
      '📍 Total checkpoints with categories: ${_selectedDefectCategory.length}',
    );
    _selectedDefectCategory.forEach((checkpointId, categoryId) {
      final severity = _selectedDefectSeverity[checkpointId] ?? 'N/A';
      print(
        '   • Checkpoint: $checkpointId | Category: $categoryId | Severity: $severity',
      );
    });
    print('═══════════════════════════════════════════════════════════════');
    print('');

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
        // Try to scroll to approximate position
        await Future.delayed(const Duration(milliseconds: 100));
        final offset = (idx * 140).toDouble();
        if (_executorScroll.hasClients) {
          _executorScroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        if (_reviewerScroll.hasClients) {
          _reviewerScroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
    print('🔍 Starting defect computation...');
    print('📝 Executor answers: ${executorAnswers.length} entries');
    print('📝 Reviewer answers: ${reviewerAnswers.length} entries');
    if (executorAnswers.isNotEmpty) {
      print('   Sample executor key: ${executorAnswers.keys.first}');
    }
    if (reviewerAnswers.isNotEmpty) {
      print('   Sample reviewer key: ${reviewerAnswers.keys.first}');
    }

    final counts = <String, int>{};
    final checkpointCounts = <String, int>{};
    int total = 0;
    int totalCheckpoints = 0;

    for (final q in checklist) {
      final checklistId = q.checklistId ?? '';
      int defectCount = 0;
      final subs = q.subQuestions;
      final checkpointCount = subs.length;

      print('🔍 Checking "${q.mainQuestion}" - ${subs.length} questions');

      for (final sub in subs) {
        final textKey = (sub['text'] ?? '').toString();
        final idKey = (sub['id'] ?? '').toString();

        // Try text key first, then id key
        var execAnswer = executorAnswers[textKey]?['answer'];
        var reviAnswer = reviewerAnswers[textKey]?['answer'];

        String usedKey = textKey;
        if (execAnswer == null && idKey.isNotEmpty) {
          execAnswer = executorAnswers[idKey]?['answer'];
          reviAnswer = reviewerAnswers[idKey]?['answer'];
          usedKey = idKey;
        }

        print(
          '  Q: "${textKey.length > 50 ? '${textKey.substring(0, 50)}...' : textKey}"',
        );
        print(
          '    Key used: "${usedKey.length > 30 ? '${usedKey.substring(0, 30)}...' : usedKey}"',
        );
        print('    Exec=$execAnswer, Revi=$reviAnswer');

        // Count as defect only if both have answered and answers differ
        if (execAnswer != null &&
            reviAnswer != null &&
            execAnswer != reviAnswer) {
          defectCount++;
          print('    🔴 DEFECT!');
        }
      }

      counts[checklistId] = defectCount;
      checkpointCounts[checklistId] = checkpointCount;
      total += defectCount;
      totalCheckpoints += checkpointCount;

      print('  ✓ Defects for this checklist: $defectCount/$checkpointCount');
    }

    if (mounted) {
      setState(() {
        _defectsByChecklist = counts;
        _checkpointsByChecklist = checkpointCounts;
        _defectsTotal = total;
        _totalCheckpoints = totalCheckpoints;
        // Update max checkpoints if needed
        if (totalCheckpoints > _maxCheckpointsSeen) {
          _maxCheckpointsSeen = totalCheckpoints;
        }
        // Track the highest defects seen in this session
        // Even if conflicts are fixed later, we remember the max we saw
        if (total > _maxDefectsSeenInSession) {
          _maxDefectsSeenInSession = total;
        }
        _totalCheckpointsInSession = totalCheckpoints;
        debugPrint(
          '📊 Defects recomputed: current=$total, max_in_session=$_maxDefectsSeenInSession, total_checkpoints=$totalCheckpoints',
        );
      });
    }

    print(
      '📊 TOTAL DEFECTS: $total out of $totalCheckpoints questions = ${totalCheckpoints > 0 ? (total / totalCheckpoints * 100).toStringAsFixed(2) : "0.00"}%',
    );
  }

  /// Accumulate maximum defects from this session into cumulative defect rate
  /// This ensures that even if conflicts are fixed before submission,
  /// the maximum defects encountered are still counted
  void _accumulateDefects() {
    if (_totalCheckpointsInSession > 0 && _maxDefectsSeenInSession > 0) {
      // Calculate rate based on max defects in session
      final sessionDefectRate =
          (_maxDefectsSeenInSession / _totalCheckpointsInSession) * 100.0;
      _cumulativeDefectRate += sessionDefectRate;
      _cumulativeDefectCount += _maxDefectsSeenInSession;

      debugPrint(
        '✅ Defects accumulated from session: max_defects=$_maxDefectsSeenInSession, session_rate=$sessionDefectRate%, total_checkpoints=$_totalCheckpointsInSession, cumulative_rate=${_cumulativeDefectRate.toStringAsFixed(2)}%',
      );

      // Reset session tracking for next submission
      _maxDefectsSeenInSession = 0;
      _totalCheckpointsInSession = 0;
    } else {
      debugPrint(
        '⚠️ No defects to accumulate in this session. max_in_session=$_maxDefectsSeenInSession, total_checkpoints=$_totalCheckpointsInSession',
      );
    }
  }

  Future<void> _computeActivePhase() async {
    int active = 1;
    try {
      final st1 = await _approvalService.getStatus(widget.projectId, 1);
      if (st1 != null && st1['status'] == 'approved') {
        active = 2;
        final st2 = await _approvalService.getStatus(widget.projectId, 2);
        if (st2 != null && st2['status'] == 'approved') {
          active = 3;
          final st3 = await _approvalService.getStatus(widget.projectId, 3);
          if (st3 != null && st3['status'] == 'approved') {
            // Phase 3 approved - project is completed
            active = 4;
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      // active represents the next phase that's now active
      // active = 1 means phase 1 is active, active = 2 means phase 2 is active, etc.
      _activePhase = active;
      // Only clamp selected phase for non-SDH users
      // SDH can view any phase including pending ones
      final currentUserName = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value?.name
          : null;
      final isSDH = currentUserName != null && authRoleIsSDH(currentUserName);
      if (!isSDH) {
        // Non-SDH users: clamp to active phase
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
      if (mounted) setState(() => _approvalStatus = appr);
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
    // SDH role: show approve/revert controls
    final isSDH =
        currentUserName != null && (authRoleIsSDH(currentUserName) == true);
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
    final phaseEditable = _selectedPhase == _activePhase;

    // Check if executor checklist for this phase has been submitted
    final executorSubmitted =
        checklistCtrl.submissionInfo(
          widget.projectId,
          _selectedPhase,
          'executor',
        )?['is_submitted'] ==
        true;

    // Check if reviewer checklist for this phase has been submitted
    final reviewerSubmitted =
        checklistCtrl.submissionInfo(
          widget.projectId,
          _selectedPhase,
          'reviewer',
        )?['is_submitted'] ==
        true;

    // Can edit only if phase is editable AND checklist has not been submitted
    final canEditExecutorPhase =
        canEditExecutor && phaseEditable && !executorSubmitted;
    final canEditReviewerPhase =
        canEditReviewer && phaseEditable && !reviewerSubmitted;

    // Check if current phase is already approved (no more actions allowed)
    final phaseAlreadyApproved = _approvalStatus?['status'] == 'approved';

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
          // Approve and Revert buttons in the middle
          if (isSDH) ...[
            ElevatedButton.icon(
              onPressed: (reviewerSubmitted && !phaseAlreadyApproved)
                  ? () async {
                      try {
                        await _approvalService.approve(
                          widget.projectId,
                          _selectedPhase,
                        );

                        checklistCtrl.clearProjectCache(widget.projectId);
                        await _computeActivePhase();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Phase ${_selectedPhase} approved! Next phase is now active.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }

                        await _loadChecklistData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Approve failed: $e')),
                          );
                        }
                      }
                    }
                  : () {
                      if (phaseAlreadyApproved) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phase already approved!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Waiting for reviewer response...'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve Phase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: (reviewerSubmitted && !phaseAlreadyApproved)
                    ? Colors.green
                    : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: (reviewerSubmitted && !phaseAlreadyApproved)
                  ? () async {
                      try {
                        await _approvalService.revert(
                          widget.projectId,
                          _selectedPhase,
                        );

                        // Increment loopback counter on backend
                        await _approvalService.incrementRevertCount(
                          widget.projectId,
                          _selectedPhase,
                        );

                        checklistCtrl.clearProjectCache(widget.projectId);
                        await _computeActivePhase();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Phase ${_selectedPhase} reverted. Executor and Reviewer can edit again.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }

                        // Reload data - loopback counter will be fetched from API
                        await _loadChecklistData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Revert failed: $e')),
                          );
                        }
                      }
                    }
                  : () {
                      if (phaseAlreadyApproved) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Phase already approved! Cannot revert.',
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Waiting for reviewer response...'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.undo),
              label: const Text('Revert Phase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: (reviewerSubmitted && !phaseAlreadyApproved)
                    ? Colors.orange
                    : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
                      enabled: isSDH ? true : (p <= _activePhase),
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
                          else if (p == _activePhase)
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
                          else if (p > _activePhase && isSDH)
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
                // SDH can navigate to any phase for review
                // Others can only go up to active phase
                if (!isSDH && val > _activePhase) {
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
                    print('🔄 Manual refresh triggered');
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
                  if (isSDH)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Defect Rate on the left
                          _DefectSummaryBar(
                            totalDefects: _defectsTotal,
                            totalCheckpoints: _totalCheckpoints,
                            cumulativeDefectRate: _cumulativeDefectRate,
                            cumulativeDefectCount: _cumulativeDefectCount,
                            maxDefectsInSession: _maxDefectsSeenInSession,
                            totalCheckpointsInSession:
                                _totalCheckpointsInSession,
                          ),
                          const Spacer(),
                          // Loopback Counter on the right
                          _LoopbackCounterBar(loopbackCount: _loopbackCounter),
                        ],
                      ),
                    ),
                  // Show reviewer submission summary for SDH
                  if (isSDH &&
                      _reviewerSubmissionSummaries[_selectedPhase] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: _ReviewerSubmissionSummaryCard(
                        summary: _reviewerSubmissionSummaries[_selectedPhase]!,
                        availableCategories: _getAvailableCategories(),
                      ),
                    ),
                  // Debug: Show if SDH but no summary
                  if (isSDH &&
                      _reviewerSubmissionSummaries[_selectedPhase] == null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No reviewer submission summary available for Phase $_selectedPhase',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
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
                  Expanded(
                    child: Row(
                      children: [
                        _RoleColumn(
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
                          showDefects: isSDH,
                          expanded: executorExpanded,
                          scrollController: _executorScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          onExpand: (idx) => setState(
                            () => executorExpanded.contains(idx)
                                ? executorExpanded.remove(idx)
                                : executorExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => executorAnswers[subQ] = ans);
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                              subQ,
                              ans,
                            );
                            _recomputeDefects();
                          },
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
                                  content: Text('Executor checklist submitted'),
                                ),
                              );
                              await _computeActivePhase();
                            }
                          },
                          editMode: _editMode,
                          onRefresh: _loadChecklistData,
                        ),
                        _RoleColumn(
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
                          showDefects: isSDH,
                          expanded: reviewerExpanded,
                          scrollController: _reviewerScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          onExpand: (idx) => setState(
                            () => reviewerExpanded.contains(idx)
                                ? reviewerExpanded.remove(idx)
                                : reviewerExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => reviewerAnswers[subQ] = ans);
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                              subQ,
                              ans,
                            );
                            _recomputeDefects();
                          },
                          onSubmit: () async {
                            if (!canEditReviewerPhase) return;
                            // Accumulate current defects before submission
                            _accumulateDefects();

                            // Show defect summary dialog
                            final summaryData =
                                await _showReviewerSubmissionDialog(context);
                            if (summaryData == null) return; // User cancelled

                            // Persist reviewer summary as a meta-answer so SDH can view later
                            print('💾 Saving reviewer summary: $summaryData');

                            // First update the local cache
                            setState(() {
                              _reviewerSubmissionSummaries[_selectedPhase] =
                                  summaryData;
                            });

                            // Create a valid answer structure with the summary in the remark field
                            final metaAnswer = {
                              'answer': null, // Valid null answer
                              'remark': summaryData
                                  .toString(), // Serialized summary
                              'images': [],
                              '_isMeta':
                                  true, // Flag to identify this as metadata
                              '_summaryData': summaryData, // Original summary
                            };

                            setState(() {
                              reviewerAnswers[_reviewerSummaryKey] = metaAnswer;
                            });

                            // Force immediate save to backend (no debounce)
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                              _reviewerSummaryKey,
                              metaAnswer,
                            );

                            // Wait for debounced save to complete
                            await Future.delayed(
                              const Duration(milliseconds: 600),
                            );
                            print(
                              '✅ Reviewer summary saved to cache and backend',
                            );

                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                            );
                            if (success && mounted) {
                              print(
                                '✅ Checklist submitted. Summary in map: ${_reviewerSubmissionSummaries[_selectedPhase]}',
                              );
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reviewer checklist submitted'),
                                ),
                              );
                              await _computeActivePhase();
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

  bool authRoleIsSDH(String userName) {
    final u = userName.trim().toLowerCase();
    if (u.contains('sdh')) return true;
    return widget.leaders.map((e) => e.trim().toLowerCase()).contains(u);
  }

  // Show defect summary dialog when reviewer submits checklist
  Future<Map<String, dynamic>?> _showReviewerSubmissionDialog(
    BuildContext context,
  ) async {
    final remarkCtrl = TextEditingController();
    String? selectedCategory;
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
                                    setDialogState(() => selectedCategory = id);
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
                      onChanged: (val) =>
                          setDialogState(() => selectedCategory = val),
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

class _AddCheckpointRow extends StatefulWidget {
  final String? checklistId;
  final Future<void> Function()? onAdded;
  const _AddCheckpointRow({this.checklistId, this.onAdded});

  @override
  State<_AddCheckpointRow> createState() => _AddCheckpointRowState();
}

class _AddCheckpointRowState extends State<_AddCheckpointRow> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'New checkpoint question',
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _add,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || widget.checklistId == null) return;
    setState(() => _loading = true);
    try {
      final svc = Get.find<PhaseChecklistService>();
      await svc.createCheckpoint(widget.checklistId!, question: txt);
      _ctrl.clear();
      if (widget.onAdded != null) await widget.onAdded!();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EditableCheckpointTile extends StatefulWidget {
  final String initialText;
  final String? checkpointId;
  final String? checklistId;
  final Future<void> Function()? onSaved;
  const _EditableCheckpointTile({
    required this.initialText,
    this.checkpointId,
    this.checklistId,
    this.onSaved,
  });

  @override
  State<_EditableCheckpointTile> createState() =>
      _EditableCheckpointTileState();
}

class _EditableCheckpointTileState extends State<_EditableCheckpointTile> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          onPressed: _loading ? null : _save,
        ),
      ),
      onSubmitted: (_) => _save(),
    );
  }

  Future<void> _save() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _loading = true);
    try {
      final svc = Get.find<PhaseChecklistService>();
      if (widget.checkpointId != null && widget.checkpointId!.isNotEmpty) {
        await svc.updateCheckpoint(widget.checkpointId!, {'question': txt});
      } else if (widget.checklistId != null && widget.checklistId!.isNotEmpty) {
        await svc.createCheckpoint(widget.checklistId!, question: txt);
      }
      if (widget.onSaved != null) await widget.onSaved!();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _RoleColumn extends StatelessWidget {
  final String role;
  final Color color;
  final String projectId;
  final int phase;
  final bool canEdit;
  final List<Question> checklist;
  final Map<String, Map<String, dynamic>> answers;
  final Map<String, Map<String, dynamic>> otherAnswers;
  final Set<int> expanded;
  final ScrollController scrollController;
  final Set<String> highlightSubs;
  final ChecklistController checklistCtrl;
  final Map<String, String?> selectedDefectCategory;
  final Map<String, String?> selectedDefectSeverity;
  final bool editMode;
  final Future<void> Function()? onRefresh;
  final Function(int) onExpand;
  final Function(String, Map<String, dynamic>) onAnswer;
  final Future<void> Function() onSubmit;
  final Map<String, int>? defectsByChecklist;
  final Map<String, int>? checkpointsByChecklist;
  final bool showDefects;
  final Map<String, dynamic>? Function(String?)? getCategoryInfo;
  final List<Map<String, dynamic>>
  availableCategories; // Added: for category assignment
  final Function(String checkpointId, String? categoryId, {String? severity})?
  onCategoryAssigned; // Added: callback for category assignment

  const _RoleColumn({
    required this.role,
    required this.color,
    required this.projectId,
    required this.phase,
    required this.canEdit,
    required this.checklist,
    required this.answers,
    required this.otherAnswers,
    required this.expanded,
    required this.scrollController,
    required this.highlightSubs,
    required this.checklistCtrl,
    required this.selectedDefectCategory,
    required this.selectedDefectSeverity,
    required this.onExpand,
    required this.onAnswer,
    required this.onSubmit,
    this.editMode = false,
    this.onRefresh,
    this.defectsByChecklist,
    this.checkpointsByChecklist,
    this.showDefects = false,
    this.getCategoryInfo,
    this.availableCategories = const [],
    this.onCategoryAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final title = role == 'executor' ? 'Executor Section' : 'Reviewer Section';
    final bgColor = role == 'executor'
        ? Colors.blue.shade100
        : Colors.green.shade100;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: bgColor,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                if (!canEdit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View only',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          _SubmitBar(
            role: role,
            projectId: projectId,
            phase: phase,
            onSubmit: onSubmit,
            submissionInfo: checklistCtrl.submissionInfo(
              projectId,
              phase,
              role,
            ),
            canEdit: canEdit,
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: checklist.length,
              itemBuilder: (context, index) {
                final q = checklist[index];
                // sub is Map<String,String>
                String subKey(Map<String, String> s) => (s['id'] ?? s['text'])!;
                String subText(Map<String, String> s) => (s['text'] ?? '');
                final differs = q.subQuestions.any((sub) {
                  final key = subKey(sub);
                  final a =
                      answers[key]?['answer'] ??
                      checklistCtrl.getAnswers(
                        projectId,
                        phase,
                        role,
                        key,
                      )?['answer'];
                  final b =
                      otherAnswers[key]?['answer'] ??
                      checklistCtrl.getAnswers(
                        projectId,
                        phase,
                        role == 'executor' ? 'reviewer' : 'executor',
                        key,
                      )?['answer'];
                  return (a is String ? a.trim().toLowerCase() : a) !=
                      (b is String ? b.trim().toLowerCase() : b);
                });
                final isExpanded = expanded.contains(index);
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: differs ? Colors.redAccent : color),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: differs ? Colors.red.shade50 : null,
                  child: Column(
                    children: [
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (showDefects && role == 'executor')
                              _DefectChip(
                                defectCount:
                                    defectsByChecklist?[q.checklistId ??
                                        q.mainQuestion] ??
                                    0,
                                checkpointCount:
                                    checkpointsByChecklist?[q.checklistId ??
                                        q.mainQuestion] ??
                                    0,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.mainQuestion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (editMode &&
                                (q.checklistId != null &&
                                    q.checklistId!.isNotEmpty))
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Rename checklist',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final ctrl = TextEditingController(
                                        text: q.mainQuestion,
                                      );
                                      final newName = await showDialog<String?>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Rename checklist'),
                                          content: TextField(controller: ctrl),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: null),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Get.back(
                                                result: ctrl.text.trim(),
                                              ),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (newName != null &&
                                          newName.isNotEmpty) {
                                        try {
                                          final svc =
                                              Get.find<PhaseChecklistService>();
                                          await svc.updateChecklist(
                                            q.checklistId!,
                                            {'checklist_name': newName},
                                          );
                                          if (onRefresh != null) {
                                            await onRefresh!();
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Rename failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete checklist',
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final ok = await showDialog<bool?>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Delete checklist?',
                                          ),
                                          content: const Text(
                                            'This will remove the checklist and its checkpoints for this project.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        try {
                                          final svc =
                                              Get.find<PhaseChecklistService>();
                                          await svc.deleteChecklist(
                                            q.checklistId!,
                                          );
                                          if (onRefresh != null) {
                                            await onRefresh!();
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Delete failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                        onTap: () => onExpand(index),
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // When editing allow adding a checkpoint
                              if (editMode)
                                _AddCheckpointRow(
                                  checklistId: q.checklistId,
                                  onAdded: onRefresh,
                                ),
                              // Track last section for section header display
                              ...() {
                                String? lastSection;
                                return q.subQuestions.map((sub) {
                                  final key = subKey(sub);
                                  final text = subText(sub);
                                  final sectionName = sub['sectionName'];

                                  // DEBUG: Log the key and category lookup
                                  final catFromMap =
                                      selectedDefectCategory[key];
                                  final sevFromMap =
                                      selectedDefectSeverity[key];
                                  if (catFromMap != null ||
                                      sevFromMap != null) {
                                    print(
                                      '🎯 Building SubQuestionCard: key=$key | category=$catFromMap | severity=$sevFromMap | role=$role',
                                    );
                                  }

                                  final widgets = <Widget>[];

                                  // Add section header if section changed
                                  if (sectionName != null &&
                                      sectionName != lastSection) {
                                    widgets.add(
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.folder,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              sectionName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    lastSection = sectionName;
                                  }

                                  // Add the question card
                                  widgets.add(
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (editMode)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      _EditableCheckpointTile(
                                                        initialText: text,
                                                        checkpointId: sub['id'],
                                                        checklistId:
                                                            q.checklistId,
                                                        onSaved: onRefresh,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      sub['id'] != null &&
                                                          sub['id']!.isNotEmpty
                                                      ? () async {
                                                          final confirm = await showDialog<bool?>(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              title: const Text(
                                                                'Delete checkpoint?',
                                                              ),
                                                              content: const Text(
                                                                'This will delete the checkpoint for this checklist.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Get.back(
                                                                        result:
                                                                            false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Get.back(
                                                                        result:
                                                                            true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Delete',
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          if (confirm == true) {
                                                            try {
                                                              final svc =
                                                                  Get.find<
                                                                    PhaseChecklistService
                                                                  >();
                                                              await svc
                                                                  .deleteCheckpoint(
                                                                    sub['id']!,
                                                                  );
                                                              if (onRefresh !=
                                                                  null) {
                                                                await onRefresh!();
                                                              }
                                                            } catch (e) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Delete failed: $e',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          SubQuestionCard(
                                            key: ValueKey("${role}_$key"),
                                            subQuestion: text,
                                            editable: canEdit,
                                            role: role,
                                            initialData:
                                                answers[key] ??
                                                checklistCtrl.getAnswers(
                                                  projectId,
                                                  phase,
                                                  role,
                                                  key,
                                                ),
                                            onAnswer: (ans) => canEdit
                                                ? onAnswer(key, ans)
                                                : null,
                                            highlight: highlightSubs.contains(
                                              key,
                                            ),
                                            categoryInfo: getCategoryInfo?.call(
                                              sub['categoryId'],
                                            ),
                                            checkpointId: key,
                                            selectedCategoryId:
                                                selectedDefectCategory[key],
                                            selectedSeverity:
                                                selectedDefectSeverity[key],
                                            availableCategories:
                                                availableCategories,
                                            onCategoryAssigned: canEdit
                                                ? onCategoryAssigned
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: widgets,
                                  );
                                }).toList();
                              }(),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DefectChip extends StatelessWidget {
  final int defectCount;
  final int checkpointCount;
  const _DefectChip({required this.defectCount, required this.checkpointCount});

  @override
  Widget build(BuildContext context) {
    final percentage = checkpointCount > 0
        ? ((defectCount / checkpointCount) * 100).toStringAsFixed(1)
        : '0.0';
    final has = defectCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: has ? Colors.redAccent : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percentage%',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DefectSummaryBar extends StatelessWidget {
  final int totalDefects;
  final int totalCheckpoints;
  final double cumulativeDefectRate;
  final int cumulativeDefectCount;
  final int maxDefectsInSession;
  final int totalCheckpointsInSession;
  const _DefectSummaryBar({
    required this.totalDefects,
    required this.totalCheckpoints,
    required this.cumulativeDefectRate,
    required this.cumulativeDefectCount,
    required this.maxDefectsInSession,
    required this.totalCheckpointsInSession,
  });

  @override
  Widget build(BuildContext context) {
    // Match older version: use current phase defect ratio only
    final hasDefects = totalDefects > 0;
    final rate = totalCheckpoints > 0
        ? ((totalDefects / totalCheckpoints) * 100)
        : 0.0;
    final defectRateDisplay = rate.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasDefects ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasDefects ? Colors.redAccent : Colors.green,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDefects ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: hasDefects ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          const Text(
            'Defect Rate',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasDefects ? Colors.redAccent : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$defectRateDisplay%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '(${totalDefects}/${totalCheckpoints})',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopbackCounterBar extends StatelessWidget {
  final int loopbackCount;
  const _LoopbackCounterBar({required this.loopbackCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 22, color: Colors.purple.shade700),
          const SizedBox(width: 10),
          const Text(
            'Loopback Counter',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$loopbackCount',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewerSubmissionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> availableCategories;

  const _ReviewerSubmissionSummaryCard({
    required this.summary,
    required this.availableCategories,
  });

  String _getCategoryName(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return 'None';
    try {
      final cat = availableCategories.firstWhere(
        (c) => (c['_id'] ?? '').toString() == categoryId,
        orElse: () => {},
      );
      return (cat['name'] ?? 'Unknown').toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remark = summary['remark']?.toString() ?? '';
    final category = summary['category']?.toString();
    final severity = summary['severity']?.toString();
    final categoryName = _getCategoryName(category);

    return Card(
      elevation: 3,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.orange.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reviewer Submission Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (remark.isNotEmpty) ...[
              const Text(
                'Remark:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(remark, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Defect Category:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Severity:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: severity == 'Critical'
                              ? Colors.red.shade100
                              : Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity ?? 'None',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: severity == 'Critical'
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ApprovalBanner extends StatelessWidget {
  final Map<String, dynamic>? approvalStatus;
  final Map<String, dynamic>? compareStatus;
  const ApprovalBanner({super.key, this.approvalStatus, this.compareStatus});

  @override
  Widget build(BuildContext context) {
    final status = approvalStatus?['status']?.toString() ?? 'none';
    final match = compareStatus?['match'] == true;
    String text = 'Approval: $status';
    Color bg = Colors.grey.shade200;
    if (status == 'pending') bg = Colors.amber.shade100;
    if (status == 'approved') bg = Colors.green.shade100;
    if (status == 'reverted') bg = Colors.red.shade100;
    final cmp = match ? 'Answers match' : 'Answers differ';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$text • $cmp')),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final String role;
  final String projectId;
  final int phase;
  final Future<void> Function() onSubmit;
  final Map<String, dynamic>? submissionInfo;
  final bool canEdit;

  const _SubmitBar({
    required this.role,
    required this.projectId,
    required this.phase,
    required this.onSubmit,
    required this.submissionInfo,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = submissionInfo?['is_submitted'] == true;
    final submittedAt = submissionInfo?['submitted_at'];
    final when = submittedAt != null
        ? (submittedAt is DateTime
              ? submittedAt.toString().split('.')[0]
              : submittedAt.toString())
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          if (submitted)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Submitted${when != null ? ' • $when' : ''}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: canEdit ? onSubmit : null,
              icon: const Icon(Icons.send),
              label: Text(
                'Submit ${role[0].toUpperCase()}${role.substring(1)} Checklist',
              ),
            ),
          const Spacer(),
          Text(role.toUpperCase(), style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class SubQuestionCard extends StatefulWidget {
  final String subQuestion;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onAnswer;
  final bool editable;
  final bool highlight;
  final Map<String, dynamic>? categoryInfo;
  final String? checkpointId; // Added: checkpoint ID for category assignment
  final String?
  selectedCategoryId; // New: controlled selected category from parent
  final String?
  selectedSeverity; // New: controlled selected severity from parent
  final List<Map<String, dynamic>>
  availableCategories; // Added: list of categories from template
  final Function(String checkpointId, String? categoryId, {String? severity})?
  onCategoryAssigned; // Added: callback for category assignment
  final String role; // Added: to restrict category UI to reviewer only

  const SubQuestionCard({
    super.key,
    required this.subQuestion,
    this.initialData,
    required this.onAnswer,
    this.editable = true,
    this.highlight = false,
    this.categoryInfo,
    this.checkpointId,
    this.selectedCategoryId,
    this.selectedSeverity,
    this.availableCategories = const [],
    this.onCategoryAssigned,
    this.role = 'reviewer', // Default to reviewer for backward compatibility
  });

  @override
  State<SubQuestionCard> createState() => _SubQuestionCardState();
}

class _SubQuestionCardState extends State<SubQuestionCard> {
  String? selectedOption;
  String? selectedCategory; // Added: for category assignment
  String? selectedSeverity; // Added: for severity assignment
  final TextEditingController remarkController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  Map<String, dynamic>? _categorySuggestion;
  bool _showSuggestion = false;
  bool _loadingSuggestion = false;
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _localSuggestions = [];

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Initialize category and severity from parent or initialData
    selectedCategory = widget.selectedCategoryId;
    selectedSeverity = widget.selectedSeverity;
  }

  void _initializeData() {
    if (widget.initialData != null) {
      selectedOption = widget.initialData!['answer'];
      final newRemark = widget.initialData!['remark'] ?? '';
      if (remarkController.text != newRemark) remarkController.text = newRemark;
      final imgs = widget.initialData!['images'];
      if (imgs is List) _images = List<Map<String, dynamic>>.from(imgs);
    }
  }

  // Check if a defect is detected for this checkpoint
  bool _isDefectDetected() => true;

  // Get category name by ID
  String? _getCategoryName(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    try {
      final cat = widget.availableCategories.firstWhere(
        (c) => (c['_id'] ?? '').toString() == categoryId,
        orElse: () => {},
      );
      return (cat['name'] ?? '').toString();
    } catch (e) {
      return null;
    }
  }

  // Current selected category
  String? _currentSelectedCategory() =>
      selectedCategory ?? widget.selectedCategoryId;

  // Current selected severity
  String? _currentSelectedSeverity() =>
      selectedSeverity ?? widget.selectedSeverity;

  @override
  void dispose() {
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _updateAnswer() => widget.onAnswer({
    "answer": selectedOption,
    "remark": remarkController.text,
    "images": _images,
  });

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(
          () => _images = result.files
              .where((f) => f.bytes != null)
              .map((f) => {'bytes': f.bytes!, 'name': f.name})
              .toList(),
        );
        await _updateAnswer();
      }
    } catch (e) {
      debugPrint('pick images error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCat = _currentSelectedCategory();
    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.subQuestion,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (widget.categoryInfo != null) ...[],
          ],
        ),
        RadioListTile<String>(
          title: const Text("Yes"),
          value: "Yes",
          groupValue: selectedOption,
          onChanged: widget.editable
              ? (val) async {
                  setState(() => selectedOption = val);
                  await _updateAnswer();
                }
              : null,
        ),
        RadioListTile<String>(
          title: const Text("No"),
          value: "No",
          groupValue: selectedOption,
          onChanged: widget.editable
              ? (val) async {
                  setState(() => selectedOption = val);
                  await _updateAnswer();
                }
              : null,
        ),
        // Allow clearing an existing answer when editable
        if (widget.editable && selectedOption != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                setState(() {
                  selectedOption = null;
                });
                await _updateAnswer();
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear answer'),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: remarkController,
                onChanged: widget.editable ? _onRemarkChanged : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  hintText: "Remark",
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                enabled: widget.editable,
                maxLines: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: widget.editable ? _pickImages : null,
            ),
          ],
        ),
        if (_images.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, i) {
                final img = _images[i];
                final bytes = img['bytes'] is Uint8List
                    ? img['bytes'] as Uint8List
                    : null;
                final name = img['name'] is String
                    ? img['name'] as String
                    : null;
                if (bytes == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          bytes,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () async {
                            setState(() => _images.removeAt(i));
                            await _updateAnswer();
                          },
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                      if (name != null)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            color: Colors.black45,
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
    return widget.highlight
        ? Container(
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Padding(padding: const EdgeInsets.all(6.0), child: base),
          )
        : base;
  }

  // Debounced remark handler
  void _onRemarkChanged(String newRemark) {
    _debounceTimer?.cancel();
    // Only compute suggestions for reviewer role
    if (widget.role == 'reviewer') {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _computeLocalSuggestions(newRemark);
        _fetchCategorySuggestion(newRemark);
      });
    }
    _updateAnswer();
  }

  Future<void> _fetchCategorySuggestion(String remark) async {
    if (remark.trim().length < 2) {
      setState(() {
        _showSuggestion = false;
        _categorySuggestion = null;
        _loadingSuggestion = false;
      });
      return;
    }
    setState(() {
      _loadingSuggestion = true;
    });
    try {
      final svc = Get.find<DefectCategorizationService>();
      final checkpointId = widget.checkpointId ?? 'dummy';
      final suggestion = await svc.suggestCategory(checkpointId, remark.trim());
      setState(() {
        _categorySuggestion = suggestion;
        _showSuggestion = (suggestion['suggestedCategoryId'] ?? '') != '';
        _loadingSuggestion = false;
      });
    } catch (e) {
      setState(() {
        _loadingSuggestion = false;
        _showSuggestion = false;
        _categorySuggestion = null;
      });
    }
  }

  void _acceptSuggestion() {
    final s = _categorySuggestion;
    if (s == null) return;
    final categoryId = (s['suggestedCategoryId'] ?? '').toString();
    if (categoryId.isEmpty) return;
    setState(() {
      selectedCategory = categoryId;
      _showSuggestion = false;
    });
    // Immediately assign category to backend and update answer
    if (widget.checkpointId != null && widget.onCategoryAssigned != null) {
      widget.onCategoryAssigned!(
        widget.checkpointId!,
        categoryId,
        severity: _currentSelectedSeverity(),
      );
    }
    // Update answer with category - this persists to local cache
    _updateAnswer();
  }

  void _acceptLocalSuggestion(Map<String, dynamic> suggestion) {
    final categoryId = (suggestion['suggestedCategoryId'] ?? '').toString();
    if (categoryId.isEmpty) return;
    setState(() => selectedCategory = categoryId);
    // Immediately assign category to backend
    if (widget.checkpointId != null && widget.onCategoryAssigned != null) {
      widget.onCategoryAssigned!(
        widget.checkpointId!,
        categoryId,
        severity: _currentSelectedSeverity(),
      );
    }
    _updateAnswer();
  }

  void _computeLocalSuggestions(String remark) {
    final text = remark.trim();
    if (text.length < 2 || widget.availableCategories.isEmpty) {
      setState(() => _localSuggestions = []);
      return;
    }
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      setState(() => _localSuggestions = []);
      return;
    }
    final suggestions = <Map<String, dynamic>>[];
    for (final cat in widget.availableCategories) {
      final name = (cat['name'] ?? '').toString();
      final id = (cat['_id'] ?? '').toString();
      // Gather keywords with graceful fallbacks: keywords[] → aliases[] → name tokens
      final kwFromArray = (cat['keywords'] as List<dynamic>? ?? [])
          .map((k) => k.toString().toLowerCase())
          .where((k) => k.trim().isNotEmpty)
          .toList();
      final aliasArray = (cat['aliases'] as List<dynamic>? ?? [])
          .map((k) => k.toString().toLowerCase())
          .where((k) => k.trim().isNotEmpty)
          .toList();
      final nameTokens = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      final kws = [
        ...kwFromArray,
        ...aliasArray,
        ...nameTokens,
      ].toSet().toList();
      if (id.isEmpty || kws.isEmpty) continue;
      double matchCount = 0;
      for (final token in normalized) {
        for (final kw in kws) {
          if (token == kw) {
            matchCount += 1;
          } else if (kw.contains(token) || token.contains(kw)) {
            matchCount += 0.5;
          }
        }
      }
      if (matchCount > 0) {
        suggestions.add({'suggestedCategoryId': id, 'categoryName': name});
      }
    }
    // Sort by name for consistent ordering
    suggestions.sort(
      (a, b) =>
          (a['categoryName'] as String).compareTo(b['categoryName'] as String),
    );
    setState(() {
      _localSuggestions = suggestions.take(5).toList();
    });
  }
}
