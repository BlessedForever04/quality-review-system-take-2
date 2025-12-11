import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'checklist_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/approval_service.dart';
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
  final List<String> subQuestions;
  Question({required this.mainQuestion, required this.subQuestions});
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
  late final ChecklistController checklistCtrl;
  bool _isLoadingData = true;
  int _selectedPhase = 1; // currently viewed phase
  int _activePhase = 1; // max editable phase (older are view-only)
  Map<String, dynamic>? _approvalStatus; // pending/approved/reverted
  Map<String, dynamic>? _compareStatus; // match + stats
  final ScrollController _executorScroll = ScrollController();
  final ScrollController _reviewerScroll = ScrollController();
  final Set<String> _highlightSubs = {};

  ApprovalService get _approvalService => Get.find<ApprovalService>();

  final List<Question> checklist = [
    Question(
      mainQuestion: "Verification",
      subQuestions: [
        "Original BDF available?",
        "Revised input file checked?",
        "Description correct?",
      ],
    ),
    Question(
      mainQuestion: "Geometry Preparation",
      subQuestions: [
        "Is imported geometry correct (units/required data)?",
        "Required splits for pre- and post-processing?",
        "Required splits for bolted joint procedure?",
        "Geometry correctly defeatured?",
      ],
    ),
    Question(
      mainQuestion: "Coordinate Systems",
      subQuestions: ["Is correct coordinate system created and assigned?"],
    ),
    Question(
      mainQuestion: "FE Mesh",
      subQuestions: [
        "Is BDF exported with comments?",
        "Are Components, Properties, LBC, Materials renamed appropriately?",
        "Visual check of FE model (critical locations, transitions)?",
        "Nastran Model Checker run?",
        "Element quality report available?",
      ],
    ),
    Question(
      mainQuestion: "Solid Mesh",
      subQuestions: [
        "Correct element type and properties?",
        "Face of solid elements checked (for internal crack)?",
      ],
    ),
    Question(
      mainQuestion: "Shell Mesh",
      subQuestions: [
        "Free edges handled?",
        "Correct element type and properties?",
        "Shell normals correct?",
        "Shell thickness defined?",
        "Weld thickness/material correctly assigned?",
      ],
    ),
    Question(
      mainQuestion: "Beam Elements",
      subQuestions: [
        "Is the orientation and cross-section correct?",
        "Are correct nodes used to create beam elements?",
        "Number of beam elements appropriate?",
      ],
    ),
    Question(
      mainQuestion: "Rigids (RBE2/RBE3)",
      subQuestions: ["Rigid elements defined correctly?"],
    ),
    Question(
      mainQuestion: "Joints",
      subQuestions: [
        "Bolted joints defined?",
        "Welds defined?",
        "Shrink fit applied?",
        "Merged regions correct?",
      ],
    ),
    Question(
      mainQuestion: "Mass & Weight",
      subQuestions: [
        "Total weight cross-checked with model units?",
        "Point masses defined?",
        "COG location correct?",
        "Connection to model verified?",
      ],
    ),
    Question(
      mainQuestion: "Material Properties",
      subQuestions: [
        "E modulus verified?",
        "Poisson coefficient verified?",
        "Shear modulus verified?",
        "Density verified?",
      ],
    ),
    Question(
      mainQuestion: "Boundary Conditions",
      subQuestions: [
        "Correct DOFs assigned?",
        "Correct coordinate system assigned?",
      ],
    ),
    Question(
      mainQuestion: "Loading",
      subQuestions: [
        "Pressure load applied correctly?",
        "End loads/Total load defined?",
        "Gravity load applied?",
        "Force (point load) applied?",
        "Temperature load applied?",
        "Subcases defined (operating, lifting, wind, seismic, etc.)?",
      ],
    ),
    Question(
      mainQuestion: "Subcases",
      subQuestions: [
        "Subcase I: Definition, load, SPC ID, output request?",
        "Subcase II: Definition, load, SPC ID, output request?",
        "Subcase III: Definition, load, SPC ID, output request?",
        "Subcase IV: Definition, load, SPC ID, output request?",
      ],
    ),
    Question(
      mainQuestion: "Parameters",
      subQuestions: [
        "Param,post,-1 (op2 output)?",
        "Param,prgpst,no?",
        "Param,Ogeom,no?",
        "NASTRAN BUFFSIZE set for large models?",
        "Nastran system(151)=1 for large models?",
      ],
    ),
    Question(
      mainQuestion: "Oloads",
      subQuestions: [
        "Oload verification for Subcase I?",
        "Oload verification for Subcase II?",
        "Oload verification for Subcase III?",
        "Oload verification for Subcase IV?",
      ],
    ),
    Question(
      mainQuestion: "SPC",
      subQuestions: [
        "SPC resultant verified for Subcase I?",
        "SPC resultant verified for Subcase II?",
        "SPC resultant verified for Subcase III?",
      ],
    ),
  ];

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

    // Load existing answers from backend for both executor and reviewer
    _loadChecklistData();
  }

  Future<void> _loadChecklistData() async {
    setState(() {
      _isLoadingData = true;
      // Clear any prior phase status to avoid showing messages from other phases
      _approvalStatus = null;
      _compareStatus = null;
    });
    final phase = _selectedPhase;
    print(
      '🔄 Loading checklist data for project: ${widget.projectId} phase=$phase',
    );

    // Clear cache to force fresh load from backend
    checklistCtrl.clearProjectCache(widget.projectId);

    await Future.wait([
      checklistCtrl.loadAnswers(widget.projectId, phase, 'executor'),
      checklistCtrl.loadAnswers(widget.projectId, phase, 'reviewer'),
    ]);

    // Load approval and compare status
    try {
      final status = await _approvalService.compare(widget.projectId, phase);
      _compareStatus = status;
    } catch (_) {}
    try {
      _approvalStatus = await _approvalService.getStatus(
        widget.projectId,
        phase,
      );
    } catch (_) {}

    // Populate UI with loaded answers
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

    print('✓ Loaded ${executorSheet.length} executor answers');
    print('✓ Loaded ${reviewerSheet.length} reviewer answers');

    setState(() {
      executorAnswers.clear();
      executorAnswers.addAll(executorSheet);

      reviewerAnswers.clear();
      reviewerAnswers.addAll(reviewerSheet);

      _isLoadingData = false;
    });

    // Compute active phase (approved phases advance)
    await _computeActivePhase();

    // If an initial sub-question was provided, expand and scroll to it
    if (widget.initialSubQuestion != null) {
      final target = widget.initialSubQuestion!;
      final idx = checklist.indexWhere((q) => q.subQuestions.contains(target));
      if (idx != -1) {
        setState(() {
          executorExpanded.add(idx);
          reviewerExpanded.add(idx);
          _highlightSubs.add(target);
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
            setState(() => _highlightSubs.remove(target));
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
      setState(() => _compareStatus = status);
    } catch (_) {}
    try {
      final appr = await _approvalService.getStatus(
        widget.projectId,
        _selectedPhase,
      );
      setState(() => _approvalStatus = appr);
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
              child: Row(
                children: [
                  // Left status rail
                  SizedBox(width: 8),
                  // Executor Column
                  Expanded(
                    child: Column(
                      children: [
                        if (_approvalStatus != null || _compareStatus != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ApprovalBanner(
                              approvalStatus: _approvalStatus,
                              compareStatus: _compareStatus,
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          color: Colors.blue.shade100,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Executor Section",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!canEditExecutorPhase)
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
                          role: 'executor',
                          projectId: widget.projectId,
                          phase: _selectedPhase,
                          onSubmit: () async {
                            if (!canEditExecutorPhase) return;
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                            );
                            if (success) {
                              setState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Executor checklist submitted successfully',
                                    ),
                                  ),
                                );
                              }
                              // Recompute active phase after submit (may have triggered approval)
                              await _computeActivePhase();
                            }
                          },
                          submissionInfo: checklistCtrl.submissionInfo(
                            widget.projectId,
                            _selectedPhase,
                            'executor',
                          ),
                          canEdit: canEditExecutorPhase,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _executorScroll,
                            padding: const EdgeInsets.all(8),
                            itemCount: checklist.length,
                            itemBuilder: (context, index) {
                              final question = checklist[index];
                              final differsForQuestion = question.subQuestions.any((subQ) {
                                final exRaw = (executorAnswers[subQ]?['answer']) ??
                                    (checklistCtrl.getAnswers(
                                      widget.projectId,
                                      _selectedPhase,
                                      'executor',
                                      subQ,
                                    )?['answer']);
                                final rvRaw = (reviewerAnswers[subQ]?['answer']) ??
                                    (checklistCtrl.getAnswers(
                                      widget.projectId,
                                      _selectedPhase,
                                      'reviewer',
                                      subQ,
                                    )?['answer']);
                                final ex = exRaw is String ? exRaw.trim().toLowerCase() : exRaw;
                                final rv = rvRaw is String ? rvRaw.trim().toLowerCase() : rvRaw;
                                return ex != rv;
                              });
                              final isExpanded = executorExpanded.contains(
                                index,
                              );
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: differsForQuestion
                                        ? Colors.redAccent
                                        : Colors.blue,
                                  ),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: differsForQuestion
                                    ? Colors.red.shade50
                                    : null,
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(
                                        question.mainQuestion,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            executorExpanded.remove(index);
                                          } else {
                                            executorExpanded.add(index);
                                          }
                                        });
                                      },
                                    ),
                                    if (isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: question.subQuestions.map((
                                            subQ,
                                          ) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: SubQuestionCard(
                                                key: ValueKey("executor_$subQ"),
                                                subQuestion: subQ,
                                                editable: canEditExecutorPhase,
                                                initialData:
                                                    executorAnswers[subQ] ??
                                                    checklistCtrl.getAnswers(
                                                      widget.projectId,
                                                      _selectedPhase,
                                                      'executor',
                                                      subQ,
                                                    ),
                                                onAnswer: (ans) {
                                                  if (!canEditExecutorPhase)
                                                    return;
                                                  setState(() {
                                                    executorAnswers[subQ] = ans;
                                                  });
                                                  checklistCtrl.setAnswer(
                                                    widget.projectId,
                                                    _selectedPhase,
                                                    'executor',
                                                    subQ,
                                                    ans,
                                                  );
                                                },
                                                highlight: _highlightSubs
                                                    .contains(subQ),
                                              ),
                                            );
                                          }).toList(),
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
                  ),

                  // Reviewer Column
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.green.shade100,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Reviewer Section",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!canEditReviewerPhase)
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
                          role: 'reviewer',
                          projectId: widget.projectId,
                          phase: _selectedPhase,
                          onSubmit: () async {
                            if (!canEditReviewerPhase) return;
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                            );
                            if (success) {
                              setState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Reviewer checklist submitted successfully',
                                    ),
                                  ),
                                );
                              }
                              await _computeActivePhase();
                            }
                          },
                          submissionInfo: checklistCtrl.submissionInfo(
                            widget.projectId,
                            _selectedPhase,
                            'reviewer',
                          ),
                          canEdit: canEditReviewerPhase,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _reviewerScroll,
                            padding: const EdgeInsets.all(8),
                            itemCount: checklist.length,
                            itemBuilder: (context, index) {
                              final question = checklist[index];
                              final differsForQuestion = question.subQuestions.any((subQ) {
                                final exRaw = (executorAnswers[subQ]?['answer']) ??
                                    (checklistCtrl.getAnswers(
                                      widget.projectId,
                                      _selectedPhase,
                                      'executor',
                                      subQ,
                                    )?['answer']);
                                final rvRaw = (reviewerAnswers[subQ]?['answer']) ??
                                    (checklistCtrl.getAnswers(
                                      widget.projectId,
                                      _selectedPhase,
                                      'reviewer',
                                      subQ,
                                    )?['answer']);
                                final ex = exRaw is String ? exRaw.trim().toLowerCase() : exRaw;
                                final rv = rvRaw is String ? rvRaw.trim().toLowerCase() : rvRaw;
                                return ex != rv;
                              });
                              final isExpanded = reviewerExpanded.contains(
                                index,
                              );
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: differsForQuestion
                                        ? Colors.redAccent
                                        : Colors.green,
                                  ),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: differsForQuestion
                                    ? Colors.red.shade50
                                    : null,
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(
                                        question.mainQuestion,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            reviewerExpanded.remove(index);
                                          } else {
                                            reviewerExpanded.add(index);
                                          }
                                        });
                                      },
                                    ),
                                    if (isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: question.subQuestions.map((
                                            subQ,
                                          ) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: SubQuestionCard(
                                                key: ValueKey("reviewer_$subQ"),
                                                subQuestion: subQ,
                                                editable: canEditReviewerPhase,
                                                initialData:
                                                    reviewerAnswers[subQ] ??
                                                    checklistCtrl.getAnswers(
                                                      widget.projectId,
                                                      _selectedPhase,
                                                      'reviewer',
                                                      subQ,
                                                    ),
                                                onAnswer: (ans) {
                                                  if (!canEditReviewerPhase)
                                                    return;
                                                  setState(() {
                                                    reviewerAnswers[subQ] = ans;
                                                  });
                                                  checklistCtrl.setAnswer(
                                                    widget.projectId,
                                                    _selectedPhase,
                                                    'reviewer',
                                                    subQ,
                                                    ans,
                                                  );
                                                },
                                                highlight: _highlightSubs
                                                    .contains(subQ),
                                              ),
                                            );
                                          }).toList(),
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
                  ),
                ],
              ),
            ),
    );
  }

  // Simple helper to decide if current user is SDH
  bool authRoleIsSDH(String userName) {
    // TODO: Replace with real role check from AuthController when available
    // For now, consider leaders list as SDH or explicit "sdh" name match
    final u = userName.trim().toLowerCase();
    if (u.contains('sdh')) return true;
    return widget.leaders.map((e) => e.trim().toLowerCase()).contains(u);
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

// Simple submit bar widget
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

// --- SubQuestionCard ---
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
      // Only update controller text if it has actually changed to avoid cursor issues
      if (remarkController.text != newRemark) {
        remarkController.text = newRemark;
      }
      final imgs = widget.initialData!['images'];
      if (imgs is List) {
        _images = List<Map<String, dynamic>>.from(imgs);
      }
    }
  }

  @override
  void didUpdateWidget(SubQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If initialData changed, update the state
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

  void _updateAnswer() {
    widget.onAnswer({
      "answer": selectedOption,
      "remark": remarkController.text,
      "images": _images,
    });
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _images = result.files
              .where((f) => f.bytes != null)
              .map((f) => {'bytes': f.bytes!, 'name': f.name})
              .toList();
        });
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
                onChanged: widget.editable
                    ? (val) {
                        // Update answer as user types
                        _updateAnswer();
                      }
                    : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  hintText: "Remark",
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                enabled: widget.editable,
                maxLines: null,
                keyboardType: TextInputType.multiline,
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
                final rawBytes = img['bytes'];
                final bytes = rawBytes is Uint8List ? rawBytes : null;
                final name = img['name'] is String
                    ? img['name'] as String
                    : null;
                if (bytes == null) {
                  return const SizedBox(width: 0, height: 0);
                }
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
    if (widget.highlight) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.yellow.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Padding(padding: const EdgeInsets.all(6.0), child: base),
      );
    }
    return base;
  }
}
