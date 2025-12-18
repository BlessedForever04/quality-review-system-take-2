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
// import '../../config/api_config.dart';

enum UploadStatus { pending, uploading, success, failed }

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
  // { 'id': '<checkpointId>', 'text': '<question text>' }
  final List<Map<String, String>> subQuestions;
  final String? checklistId; // MongoDB ID for backend checklist

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
  int _selectedPhase = 1; // currently viewed phase
  int _activePhase = 1; // max editable phase (older are view-only)
  Map<String, dynamic>? _approvalStatus; // pending/approved/reverted
  Map<String, dynamic>? _compareStatus; // match + stats
  final ScrollController _executorScroll = ScrollController();
  final ScrollController _reviewerScroll = ScrollController();
  final Set<String> _highlightSubs = {};

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

    // If caller provided an initial phase, honor it
    if (widget.initialPhase != null &&
        widget.initialPhase! >= 1 &&
        widget.initialPhase! <= 3) {
      _selectedPhase = widget.initialPhase!;
    }

    // Initialize with empty checklist; load from backend
    checklist = [];

    // Load existing answers from backend for both executor and reviewer
    _loadChecklistData();
  }

  Future<void> _loadChecklistData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
      _approvalStatus = null;
      _compareStatus = null;
      _errorMessage = null;
    });

    final phase = _selectedPhase;

    try {
      print(
        '🔍 CHECKLIST PAGE: Loading data for Phase $phase, ProjectID: ${widget.projectId}',
      );

      // Step 1: Fetch stages
      final stageService = Get.find<StageService>();
      final checklistService = Get.find<PhaseChecklistService>();

      final stages = await stageService.listStages(widget.projectId);
      print('✓ Stages fetched: ${stages.length} stages found');

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

      // Step 2: Find stage for current phase
      final stage = stages.firstWhereOrNull((s) {
        final stageName = (s['stage_name'] ?? '').toString().toLowerCase();
        print('  Checking stage: "$stageName" for phase $phase');
        return stageName.contains('phase $phase');
      });

      if (stage == null) {
        print('❌ No stage found matching "Phase $phase"');
        if (!mounted) return;
        setState(() {
          checklist = [];
          _isLoadingData = false;
          _errorMessage =
              'No stage found for Phase $phase. Make sure the template has Phase $phase and the project has stages.';
        });
        return;
      }

      final stageId = (stage['_id'] ?? '').toString();
      _currentStageId = stageId;
      print('✓ Stage found: $stageId');

      // Step 3: Fetch checklists for this stage
      List<Map<String, dynamic>> checklists = [];
      try {
        final res = await checklistService.listForStage(stageId);
        // ensure we have a List<Map<String,dynamic>>
        checklists = (res is List)
            ? List<Map<String, dynamic>>.from(res)
            : <Map<String, dynamic>>[];
        print('✓ Checklists fetched: ${checklists.length} checklists found');
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
        if (!mounted) return;
        setState(() {
          checklist = [];
          _isLoadingData = false;
          _errorMessage =
              'No checklists available for this stage. Ensure templates/checkpoints exist.';
        });
        return;
      }

      // Step 4: Build question list
      final questions = <Question>[];
      for (final cl in checklists) {
        final checklistId = (cl['_id'] ?? '').toString();
        final checklistName = (cl['checklist_name'] ?? '').toString();
        print('  Processing checklist: $checklistName');

        final checkpoints = await checklistService.getCheckpoints(checklistId);
        print('    Checkpoints: ${checkpoints.length}');

        final cpObjs = checkpoints
            .map(
              (cp) => {
                'id': (cp['_id'] ?? '').toString(),
                'text': (cp['question'] ?? '').toString(),
              },
            )
            .where((m) => (m['text'] ?? '').isNotEmpty)
            .cast<Map<String, String>>()
            .toList();

        if (cpObjs.isNotEmpty) {
          questions.add(
            Question(
              mainQuestion: checklistName,
              subQuestions: cpObjs,
              checklistId: checklistId,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        checklist = questions;
      });
      print('✅ Checklist loaded successfully: ${questions.length} questions');
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

      if (!mounted) return;
      setState(() {
        executorAnswers.clear();
        executorAnswers.addAll(executorSheet);
        reviewerAnswers.clear();
        reviewerAnswers.addAll(reviewerSheet);
      });
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

  Future<void> _computeActivePhase() async {
    int active = 1;
    try {
      final st1 = await _approvalService.getStatus(widget.projectId, 1);
      if (st1 != null && st1['status'] == 'approved') {
        active = 2;
        final st2 = await _approvalService.getStatus(widget.projectId, 2);
        if (st2 != null && st2['status'] == 'approved') {
          active = 3;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _activePhase = active;
      // If selected phase exceeds known phases cap at active
      if (_selectedPhase > _activePhase) _selectedPhase = _activePhase;
    });
    // Refresh approval/compare for the currently selected phase
    try {
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
    final phaseEditable = _selectedPhase >= _activePhase;
    final canEditExecutorPhase = canEditExecutor && phaseEditable;
    final canEditReviewerPhase = canEditReviewer && phaseEditable;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Checklist - ${widget.projectTitle}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        actions: [
          // Phase selector
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedPhase,
              alignment: Alignment.center,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.expand_more, color: Colors.white),
              items: [1, 2, 3]
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      enabled: p <= _activePhase,
                      child: Row(
                        children: [
                          Text('Phase $p'),
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
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) async {
                if (val == null) return;
                // Restrict jumping ahead of active phase
                if (val > _activePhase) {
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
          IconButton(
            icon: Icon(
              _editMode ? Icons.check : Icons.edit,
              color: Colors.white,
            ),
            tooltip: _editMode ? 'Exit edit mode' : 'Enter edit mode',
            onPressed: () {
              setState(() => _editMode = !_editMode);
            },
          ),
          if (isSDH)
            PopupMenuButton<String>(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              onSelected: (value) async {
                if (value == 'approve') {
                  try {
                    await _approvalService.approve(
                      widget.projectId,
                      _selectedPhase,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Approved. Next phase created.'),
                      ),
                    );
                    _loadChecklistData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Approve failed: $e')),
                    );
                  }
                } else if (value == 'revert') {
                  try {
                    await _approvalService.revert(
                      widget.projectId,
                      _selectedPhase,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reverted to current stage.'),
                      ),
                    );
                    _loadChecklistData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Revert failed: $e')),
                    );
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'approve',
                  child: Text('Approve SDH'),
                ),
                const PopupMenuItem(value: 'revert', child: Text('Revert SDH')),
              ],
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
                          expanded: executorExpanded,
                          scrollController: _executorScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          onExpand: (idx) => setState(
                            () => executorExpanded.contains(idx)
                                ? executorExpanded.remove(idx)
                                : executorExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) {
                            setState(() => executorAnswers[subQ] = ans);
                            checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                              subQ,
                              ans,
                            );
                          },
                          onSubmit: () async {
                            if (!canEditExecutorPhase) return;
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
                          expanded: reviewerExpanded,
                          scrollController: _reviewerScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          onExpand: (idx) => setState(
                            () => reviewerExpanded.contains(idx)
                                ? reviewerExpanded.remove(idx)
                                : reviewerExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) {
                            setState(() => reviewerAnswers[subQ] = ans);
                            checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                              subQ,
                              ans,
                            );
                          },
                          onSubmit: () async {
                            if (!canEditReviewerPhase) return;
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                            );
                            if (success && mounted) {
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
}

class _AddCheckpointRow extends StatefulWidget {
  final String? checklistId;
  final Future<void> Function()? onAdded;
  const _AddCheckpointRow({super.key, this.checklistId, this.onAdded});

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
    super.key,
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
  final bool editMode;
  final Future<void> Function()? onRefresh;
  final Function(int) onExpand;
  final Function(String, Map<String, dynamic>) onAnswer;
  final Future<void> Function() onSubmit;

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
    required this.onExpand,
    required this.onAnswer,
    required this.onSubmit,
    this.editMode = false,
    this.onRefresh,
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
                String _subKey(Map<String, String> s) =>
                    (s['id'] ?? s['text'])!;
                String _subText(Map<String, String> s) => (s['text'] ?? '');
                final differs = q.subQuestions.any((sub) {
                  final key = _subKey(sub);
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
                          children: [
                            Expanded(
                              child: Text(
                                q.mainQuestion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                                  Navigator.of(ctx).pop(null),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                ctx,
                                              ).pop(ctrl.text.trim()),
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
                                          if (onRefresh != null)
                                            await onRefresh!();
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
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
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
                                          if (onRefresh != null)
                                            await onRefresh!();
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
                              ...q.subQuestions.map((sub) {
                                final key = _subKey(sub);
                                final text = _subText(sub);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (editMode)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _EditableCheckpointTile(
                                                initialText: text,
                                                checkpointId: sub['id'],
                                                checklistId: q.checklistId,
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
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(true),
                                                              child: const Text(
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
                                                          if (onRefresh != null)
                                                            await onRefresh!();
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
                                        initialData:
                                            answers[key] ??
                                            checklistCtrl.getAnswers(
                                              projectId,
                                              phase,
                                              role,
                                              key,
                                            ),
                                        onAnswer: (ans) =>
                                            canEdit ? onAnswer(key, ans) : null,
                                        highlight: highlightSubs.contains(key),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
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

  const SubQuestionCard({
    super.key,
    required this.subQuestion,
    this.initialData,
    required this.onAnswer,
    this.editable = true,
    this.highlight = false,
  });

  @override
  State<SubQuestionCard> createState() => _SubQuestionCardState();
}

class _SubQuestionCardState extends State<SubQuestionCard> {
  String? selectedOption;
  final TextEditingController remarkController = TextEditingController();
  List<Map<String, dynamic>> _images = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
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

  @override
  void didUpdateWidget(SubQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      _initializeData();
      setState(() {});
    }
  }

  @override
  void dispose() {
    remarkController.dispose();
    super.dispose();
  }

  void _updateAnswer() => widget.onAnswer({
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
        _updateAnswer();
      }
    } catch (e) {
      debugPrint('pick images error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.subQuestion,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        RadioListTile<String>(
          title: const Text("Yes"),
          value: "Yes",
          groupValue: selectedOption,
          onChanged: widget.editable
              ? (val) {
                  setState(() => selectedOption = val);
                  _updateAnswer();
                }
              : null,
        ),
        RadioListTile<String>(
          title: const Text("No"),
          value: "No",
          groupValue: selectedOption,
          onChanged: widget.editable
              ? (val) {
                  setState(() => selectedOption = val);
                  _updateAnswer();
                }
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: remarkController,
                onChanged: widget.editable ? (val) => _updateAnswer() : null,
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
                          onTap: () {
                            setState(() => _images.removeAt(i));
                            _updateAnswer();
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
}
