/// Hierarchical checklist execution widget for ProjectChecklist structure.
/// This widget handles role-based editing (Executor, Reviewer, TeamLeader) and renders
/// the hierarchical structure: Group → Sections (optional) → Questions.
///
/// This is distinct from the template editor (checklist.dart) and is used
/// when displaying a project's execution-mode checklist.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../models/project_checklist.dart';
import '../../services/project_checklist_service.dart';

class ProjectChecklistExecutionWidget extends StatefulWidget {
  final String projectId;
  final String stageId;
  final String stageName;
  final List<String> executors;
  final List<String> reviewers;
  final List<String> leaders; // TeamLeader users
  final bool readOnly; // If true, all controls disabled

  const ProjectChecklistExecutionWidget({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.stageName,
    required this.executors,
    required this.reviewers,
    required this.leaders,
    this.readOnly = false,
  });

  @override
  State<ProjectChecklistExecutionWidget> createState() =>
      _ProjectChecklistExecutionWidgetState();
}

class _ProjectChecklistExecutionWidgetState
    extends State<ProjectChecklistExecutionWidget> {
  late final ProjectChecklistService _checklistService;
  ProjectChecklist? _checklist;
  String? _errorMessage;
  bool _isLoading = true;
  final Set<String> _expandedGroups = {};

  // Role permissions for current user
  late final bool _canEditExecutor;
  late final bool _canEditReviewer;
  late final bool _isTeamLeader;

  @override
  void initState() {
    super.initState();
    _checklistService = Get.find<ProjectChecklistService>();
    _determineRolePermissions();
    _loadChecklist();
  }

  void _determineRolePermissions() {
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }

    _canEditExecutor =
        currentUserName != null &&
        widget.executors
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    _canEditReviewer =
        currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    _isTeamLeader =
        currentUserName != null &&
        widget.leaders
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());
  }

  Future<void> _loadChecklist() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final checklistData = await _checklistService.fetchChecklist(
        widget.projectId,
        widget.stageId,
      );

      if (mounted) {
        setState(() {
          _checklist = ProjectChecklist.fromJson(checklistData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load checklist: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateExecutorAnswer(
    String groupId,
    String questionId,
    String? answer,
    String? remark,
  ) async {
    try {
      // Update group state from API response
      final updatedGroupJson = await _checklistService.updateExecutor(
        widget.projectId,
        widget.stageId,
        groupId,
        questionId,
        answer: answer,
        remark: remark,
      );

      final updatedGroup = ProjectChecklistGroup.fromJson(updatedGroupJson);

      if (mounted && _checklist != null) {
        setState(() {
          _checklist = _checklist!.updateGroup(updatedGroup);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Executor answer updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateReviewerStatus(
    String groupId,
    String questionId,
    String? status,
    String? remark,
  ) async {
    try {
      // Update group state from API response
      final updatedGroupJson = await _checklistService.updateReviewer(
        widget.projectId,
        widget.stageId,
        groupId,
        questionId,
        status: status,
        remark: remark,
      );

      final updatedGroup = ProjectChecklistGroup.fromJson(updatedGroupJson);

      if (mounted && _checklist != null) {
        setState(() {
          _checklist = _checklist!.updateGroup(updatedGroup);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reviewer status updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChecklist,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_checklist == null || _checklist!.groups.isEmpty) {
      return const Center(child: Text('No checklist items found'));
    }

    return ListView.builder(
      itemCount: _checklist!.groups.length,
      itemBuilder: (context, index) {
        final group = _checklist!.groups[index];
        final isExpanded = _expandedGroups.contains(group.id);

        // Calculate defect count and rate for the group
        int totalItems = group.questions.length;
        for (final section in group.sections) {
          totalItems += section.questions.length;
        }

        int defectCount = 0;
        // Count rejections in direct questions
        for (final q in group.questions) {
          if (q.reviewerStatus == 'Rejected') {
            defectCount++;
          }
        }
        // Count rejections in section questions
        for (final section in group.sections) {
          for (final q in section.questions) {
            if (q.reviewerStatus == 'Rejected') {
              defectCount++;
            }
          }
        }

        double defectRate = totalItems > 0
            ? (defectCount / totalItems) * 100
            : 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    group.groupName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Group defect stats badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: defectCount > 0
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: defectCount > 0
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                  ),
                  child: Text(
                    '${defectRate.toStringAsFixed(1)}% (${defectCount}/${totalItems})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: defectCount > 0
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedGroups.add(group.id);
                } else {
                  _expandedGroups.remove(group.id);
                }
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Direct questions in group
                    ...group.questions.map((question) {
                      return _QuestionTile(
                        question: question,
                        groupId: group.id,
                        onExecutorUpdate: (answer, remark) =>
                            _updateExecutorAnswer(
                              group.id,
                              question.id,
                              answer,
                              remark,
                            ),
                        onReviewerUpdate: (status, remark) =>
                            _updateReviewerStatus(
                              group.id,
                              question.id,
                              status,
                              remark,
                            ),
                        canEditExecutor: !widget.readOnly && _canEditExecutor,
                        canEditReviewer: !widget.readOnly && _canEditReviewer,
                        isTeamLeader: _isTeamLeader,
                      );
                    }).toList(),

                    // Sections with their questions
                    ...group.sections.map((section) {
                      return _SectionTile(
                        section: section,
                        groupId: group.id,
                        onExecutorUpdate: (questionId, answer, remark) =>
                            _updateExecutorAnswer(
                              group.id,
                              questionId,
                              answer,
                              remark,
                            ),
                        onReviewerUpdate: (questionId, status, remark) =>
                            _updateReviewerStatus(
                              group.id,
                              questionId,
                              status,
                              remark,
                            ),
                        canEditExecutor: !widget.readOnly && _canEditExecutor,
                        canEditReviewer: !widget.readOnly && _canEditReviewer,
                        isTeamLeader: _isTeamLeader,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Displays a single question with executor and reviewer controls
class _QuestionTile extends StatefulWidget {
  final ProjectQuestion question;
  final String groupId;
  final Function(String?, String?) onExecutorUpdate;
  final Function(String?, String?) onReviewerUpdate;
  final bool canEditExecutor;
  final bool canEditReviewer;
  final bool isTeamLeader;

  const _QuestionTile({
    required this.question,
    required this.groupId,
    required this.onExecutorUpdate,
    required this.onReviewerUpdate,
    required this.canEditExecutor,
    required this.canEditReviewer,
    required this.isTeamLeader,
  });

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile> {
  late TextEditingController _executorRemarkCtrl;
  late TextEditingController _reviewerRemarkCtrl;
  bool _showExecutorForm = false;
  bool _showReviewerForm = false;

  @override
  void initState() {
    super.initState();
    _executorRemarkCtrl = TextEditingController(
      text: widget.question.executorRemark ?? '',
    );
    _reviewerRemarkCtrl = TextEditingController(
      text: widget.question.reviewerRemark ?? '',
    );
  }

  @override
  void dispose() {
    _executorRemarkCtrl.dispose();
    _reviewerRemarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate defect metrics
    bool isDefect = widget.question.reviewerStatus == 'Rejected';
    String defectRate = isDefect ? '100%' : '0%';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDefect ? Colors.red.shade300 : Colors.grey.shade300,
          width: isDefect ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDefect ? Colors.red.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with question text and defect badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.question.text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Defect rate badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDefect ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDefect
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDefect ? Icons.error : Icons.check_circle,
                      size: 14,
                      color: isDefect
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      defectRate,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDefect
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Executor section
          if (widget.canEditExecutor || widget.question.executorAnswer != null)
            _buildExecutorSection(),
          if ((widget.canEditExecutor ||
                  widget.question.executorAnswer != null) &&
              (widget.canEditReviewer ||
                  widget.question.reviewerStatus != null))
            const Divider(),

          // Reviewer section
          if (widget.canEditReviewer || widget.question.reviewerStatus != null)
            _buildReviewerSection(),
        ],
      ),
    );
  }

  Widget _buildExecutorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Executor Answer:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.canEditExecutor)
          Column(
            children: [
              // Answer dropdown
              DropdownButton<String?>(
                value: widget.question.executorAnswer,
                items: [null, 'Yes', 'No', 'NA']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value ?? 'Not Answered'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  _executorRemarkCtrl.clear();
                  _showExecutorForm = false;
                  await widget.onExecutorUpdate(value, null);
                },
              ),
              const SizedBox(height: 8),
              // Remark text field
              if (_showExecutorForm || widget.question.executorRemark != null)
                TextField(
                  controller: _executorRemarkCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add remark...',
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  maxLines: 2,
                  onChanged: (remark) {
                    // Debounce updates or use a save button
                  },
                ),
              if (!_showExecutorForm && widget.question.executorAnswer != null)
                TextButton(
                  onPressed: () {
                    setState(() => _showExecutorForm = true);
                  },
                  child: const Text('Add/Edit Remark'),
                ),
              if (_showExecutorForm)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await widget.onExecutorUpdate(
                          widget.question.executorAnswer,
                          _executorRemarkCtrl.text,
                        );
                        setState(() => _showExecutorForm = false);
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _executorRemarkCtrl.text =
                            widget.question.executorRemark ?? '';
                        setState(() => _showExecutorForm = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          )
        else
          // Read-only display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.executorAnswer ?? 'Not Answered',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (widget.question.executorRemark != null &&
                  widget.question.executorRemark!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remark: ${widget.question.executorRemark}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildReviewerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviewer Status:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.canEditReviewer)
          Column(
            children: [
              // Status dropdown
              DropdownButton<String?>(
                value: widget.question.reviewerStatus,
                items: [null, 'Approved', 'Rejected']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value ?? 'Not Reviewed'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  _reviewerRemarkCtrl.clear();
                  _showReviewerForm = false;
                  await widget.onReviewerUpdate(value, null);
                },
              ),
              const SizedBox(height: 8),
              // Remark text field
              if (_showReviewerForm || widget.question.reviewerRemark != null)
                TextField(
                  controller: _reviewerRemarkCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add review remark...',
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  maxLines: 2,
                  onChanged: (remark) {
                    // Debounce updates or use a save button
                  },
                ),
              if (!_showReviewerForm && widget.question.reviewerStatus != null)
                TextButton(
                  onPressed: () {
                    setState(() => _showReviewerForm = true);
                  },
                  child: const Text('Add/Edit Remark'),
                ),
              if (_showReviewerForm)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await widget.onReviewerUpdate(
                          widget.question.reviewerStatus,
                          _reviewerRemarkCtrl.text,
                        );
                        setState(() => _showReviewerForm = false);
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _reviewerRemarkCtrl.text =
                            widget.question.reviewerRemark ?? '';
                        setState(() => _showReviewerForm = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          )
        else
          // Read-only display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.reviewerStatus ?? 'Not Reviewed',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (widget.question.reviewerRemark != null &&
                  widget.question.reviewerRemark!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remark: ${widget.question.reviewerRemark}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Displays a section with its questions
class _SectionTile extends StatelessWidget {
  final ProjectSection section;
  final String groupId;
  final Function(String, String?, String?) onExecutorUpdate;
  final Function(String, String?, String?) onReviewerUpdate;
  final bool canEditExecutor;
  final bool canEditReviewer;
  final bool isTeamLeader;

  const _SectionTile({
    required this.section,
    required this.groupId,
    required this.onExecutorUpdate,
    required this.onReviewerUpdate,
    required this.canEditExecutor,
    required this.canEditReviewer,
    required this.isTeamLeader,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate defect metrics for section
    int totalItems = section.questions.length;
    int defectCount = section.questions
        .where((q) => q.reviewerStatus == 'Rejected')
        .length;
    double defectRate = totalItems > 0 ? (defectCount / totalItems) * 100 : 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.sectionName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Section defect stats
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: defectCount > 0
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: defectCount > 0
                          ? Colors.orange.shade300
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    '${defectRate.toStringAsFixed(1)}% (${defectCount}/${totalItems})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: defectCount > 0
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: section.questions
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuestionTile(
                        question: question,
                        groupId: groupId,
                        onExecutorUpdate: (answer, remark) =>
                            onExecutorUpdate(question.id, answer, remark),
                        onReviewerUpdate: (status, remark) =>
                            onReviewerUpdate(question.id, status, remark),
                        canEditExecutor: canEditExecutor,
                        canEditReviewer: canEditReviewer,
                        isTeamLeader: isTeamLeader,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
