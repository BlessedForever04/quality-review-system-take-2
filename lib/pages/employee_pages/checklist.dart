import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:url_launcher/url_launcher.dart';
import 'checklist_controller.dart';
import '../../services/phase_checklist_service.dart';

// import '../../config/api_config.dart';
// Simple backend base URL for uploads; adjust if needed
const String _backendBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

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

class RoleColumn extends StatelessWidget {
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
  final Future<void> Function()? onRevert; // New: revert callback for reviewer
  final bool isCurrentUserReviewer; // Check if logged-in user is a reviewer
  final Map<String, int>? defectsByChecklist;
  final Map<String, int>? checkpointsByChecklist;
  final bool showDefects;
  final Map<String, dynamic>? Function(String?)? getCategoryInfo;
  final List<Map<String, dynamic>>
  availableCategories; // Added: for category assignment
  final Function(String checkpointId, String? categoryId, {String? severity})?
  onCategoryAssigned; // Added: callback for category assignment

  const RoleColumn({
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
    this.onRevert,
    this.isCurrentUserReviewer = false,
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
            onRevert: onRevert,
            isCurrentUserReviewer: isCurrentUserReviewer,
            submissionInfo: checklistCtrl.submissionInfo(
              projectId,
              phase,
              role,
            ),
            executorSubmissionInfo: role == 'reviewer'
                ? checklistCtrl.submissionInfo(projectId, phase, 'executor')
                : null,
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

                  // Only show as different if BOTH have provided answers AND they differ
                  // If either side hasn't answered (null), don't consider it as differing
                  if (a == null || b == null) return false;

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

class ConflictCountBar extends StatelessWidget {
  final int conflictCount;
  const ConflictCountBar({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    final hasConflicts = conflictCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasConflicts ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflicts ? Colors.orange : Colors.green,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasConflicts ? Icons.sync_problem : Icons.check_circle_outline,
            size: 22,
            color: hasConflicts ? Colors.orange.shade700 : Colors.green,
          ),
          const SizedBox(width: 10),
          const Text(
            'Conflict Count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasConflicts ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$conflictCount',
              style: const TextStyle(
                fontSize: 16,
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

class ConflictCounterBar extends StatelessWidget {
  final int conflictCount;
  const ConflictCounterBar({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows, size: 22, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          const Text(
            'Conflict Counter',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$conflictCount',
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

class ReviewerSubmissionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> availableCategories;

  const ReviewerSubmissionSummaryCard({
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
    if (status == 'reverted_to_executor') {
      bg = Colors.orange.shade100;
      text = 'Reverted to Executor - Waiting for executor to resubmit';
    }

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
  final Future<void> Function()? onRevert; // New: revert callback for reviewer
  final bool isCurrentUserReviewer; // Check if logged-in user is a reviewer
  final Map<String, dynamic>? submissionInfo;
  final Map<String, dynamic>?
  executorSubmissionInfo; // New: to check if executor submitted
  final bool canEdit;

  const _SubmitBar({
    required this.role,
    required this.projectId,
    required this.phase,
    required this.onSubmit,
    this.onRevert,
    this.isCurrentUserReviewer = false,
    required this.submissionInfo,
    this.executorSubmissionInfo,
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

    // Check if executor has submitted (for reviewer to enable revert)
    final executorSubmitted = executorSubmissionInfo?['is_submitted'] == true;
    // Reviewer can revert to executor when executor submitted but reviewer hasn't
    final showRevertButton =
        role == 'reviewer' &&
        isCurrentUserReviewer &&
        !submitted &&
        executorSubmitted &&
        onRevert != null;

    // Reviewer can only submit/revert when executor has submitted
    final canReviewerSubmit = role == 'reviewer'
        ? (canEdit && executorSubmitted)
        : canEdit;

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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: canReviewerSubmit ? onSubmit : null,
                  icon: const Icon(Icons.send),
                  label: Text(
                    'Submit ${role[0].toUpperCase()}${role.substring(1)} Checklist',
                  ),
                ),
                if (showRevertButton) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onRevert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.undo),
                    label: const Text('Revert to Executor'),
                  ),
                ],
              ],
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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Initialize category and severity from parent or initialData
    selectedCategory = widget.selectedCategoryId;
    selectedSeverity = widget.selectedSeverity;

    // Fetch existing images for this checkpoint/subquestion
    _fetchExistingImages();
  }

  @override
  void didUpdateWidget(SubQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync category and severity from parent when they change
    if (widget.selectedCategoryId != oldWidget.selectedCategoryId) {
      setState(() => selectedCategory = widget.selectedCategoryId);
    }
    if (widget.selectedSeverity != oldWidget.selectedSeverity) {
      setState(() => selectedSeverity = widget.selectedSeverity);
    }
    // Re-initialize if initialData changed
    if (widget.initialData != oldWidget.initialData) {
      _initializeData();
    }
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
        // Upload each selected image to backend GridFS, associated by questionId
        final uploaded = <Map<String, dynamic>>[];
        for (final f in result.files) {
          if (f.bytes == null) continue;
          try {
            final req = await http.MultipartRequest(
              'POST',
              Uri.parse(
                '$_backendBaseUrl/api/v1/images/${widget.checkpointId ?? widget.subQuestion}',
              ),
            );
            req.files.add(
              http.MultipartFile.fromBytes('image', f.bytes!, filename: f.name),
            );
            final streamed = await req.send();
            final resp = await http.Response.fromStream(streamed);
            if (resp.statusCode == 201) {
              final data = jsonDecode(resp.body) as Map<String, dynamic>;
              uploaded.add({
                'fileId': data['fileId'],
                'filename': data['filename'],
              });
            }
          } catch (_) {}
        }
        setState(() => _images = uploaded);
        await _updateAnswer();
      }
    } catch (e) {
      // Silently handle image picker errors
    }
  }

  Future<void> _fetchExistingImages() async {
    final qid = widget.checkpointId ?? widget.subQuestion;
    if (qid.isEmpty) return;
    try {
      final resp = await http.get(
        Uri.parse('$_backendBaseUrl/api/v1/images/$qid'),
      );
      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List?) ?? [];
        final imgs = list
            .whereType<Map>()
            .map(
              (m) => {
                'fileId': (m['_id'] ?? '').toString(),
                'filename': (m['filename'] ?? '').toString(),
              },
            )
            .where((m) => (m['fileId'] ?? '').toString().isNotEmpty)
            .toList();
        if (mounted) setState(() => _images = imgs);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // final currentCat = _currentSelectedCategory();
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
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
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
            ),
            Expanded(
              child: RadioListTile<String>(
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
            ),
          ],
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
            // IconButton(
            //   icon: const Icon(Icons.add_a_photo_outlined),
            //   onPressed: widget.editable ? _pickImages : null,
            // ),
          ],
        ),
        // Add defect category and severity for reviewer role
        if (widget.role == 'reviewer') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    labelText: 'Defect Category',
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...widget.availableCategories.map((cat) {
                      final id = (cat['_id'] ?? '').toString();
                      final name = (cat['name'] ?? 'Unknown').toString();
                      return DropdownMenuItem(value: id, child: Text(name));
                    }),
                  ],
                  onChanged: widget.editable
                      ? (val) {
                          setState(() => selectedCategory = val);
                          if (widget.checkpointId != null &&
                              widget.onCategoryAssigned != null) {
                            widget.onCategoryAssigned!(
                              widget.checkpointId!,
                              val,
                              severity: selectedSeverity,
                            );
                          }
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedSeverity,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    labelText: 'Severity',
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                  onChanged: widget.editable
                      ? (val) {
                          setState(() => selectedSeverity = val);
                          if (widget.checkpointId != null &&
                              widget.onCategoryAssigned != null) {
                            widget.onCategoryAssigned!(
                              widget.checkpointId!,
                              selectedCategory,
                              severity: val,
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
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
                // If we have local bytes (just picked), show memory; else try server fileId
                final fileId = img['fileId'] is String
                    ? img['fileId'] as String
                    : '';
                if (bytes == null && fileId.isEmpty)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openImageViewer(
                          fileId: fileId,
                          bytes: bytes,
                          name: name,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: bytes != null
                              ? Image.memory(
                                  bytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  '$_backendBaseUrl/api/v1/images/file/$fileId',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                        ),
                      ),
                      if (widget.editable)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () async {
                              if (!widget.editable) return;
                              final fileId = (img['fileId'] ?? '').toString();
                              // If this image exists on server, request deletion
                              if (fileId.isNotEmpty) {
                                try {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete image?'),
                                      content: const Text(
                                        'Are you sure you want to delete this image?',
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
                                  if (confirmed == true) {
                                    await http.delete(
                                      Uri.parse(
                                        '$_backendBaseUrl/api/v1/images/file/$fileId',
                                      ),
                                    );
                                  }
                                  // Proceed to remove locally regardless of response
                                } catch (_) {}
                              }
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

  void _openImageViewer({String? fileId, Uint8List? bytes, String? name}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx).size;
        final width = media.width;
        final height = media.height;
        Widget image;
        if (bytes != null) {
          image = Image.memory(bytes, fit: BoxFit.contain);
        } else if (fileId != null && fileId.isNotEmpty) {
          image = Image.network(
            '$_backendBaseUrl/api/v1/images/file/$fileId',
            fit: BoxFit.contain,
          );
        } else {
          image = const SizedBox.shrink();
        }
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(child: image),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                if (name != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Debounced remark handler
  void _onRemarkChanged(String newRemark) {
    _debounceTimer?.cancel();
    // Only compute suggestions for reviewer role
    if (widget.role == 'reviewer') {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _computeLocalSuggestions(newRemark);
      });
    }
    _updateAnswer();
  }

  void _computeLocalSuggestions(String remark) {
    final text = remark.trim();
    if (text.length < 2 || widget.availableCategories.isEmpty) {
      return;
    }
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
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
    setState(() {});
  }
}
