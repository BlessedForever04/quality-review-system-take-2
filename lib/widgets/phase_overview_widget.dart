import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/project.dart';
import '../services/stage_service.dart';
import '../services/approval_service.dart';

class PhaseOverviewWidget extends StatefulWidget {
  final Project project;
  final bool compact;
  final bool showTitle;

  const PhaseOverviewWidget({
    super.key,
    required this.project,
    this.compact = false,
    this.showTitle = true,
  });

  @override
  State<PhaseOverviewWidget> createState() => _PhaseOverviewWidgetState();
}

class _PhaseOverviewWidgetState extends State<PhaseOverviewWidget> {
  int _activePhase = 1;
  bool _isProjectCompleted = false;
  final Map<int, bool> _answersDiffer = {};
  final List<Map<String, dynamic>> _stages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhaseData();
  }

  Future<void> _loadPhaseData() async {
    setState(() => _loading = true);
    try {
      final stageService = Get.find<StageService>();
      final stages = await stageService.listStages(widget.project.id);

      if (stages.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final ApprovalService approvalSvc = Get.find<ApprovalService>();
      int activePhaseNum = 1;
      bool allCompleted = false;

      for (int i = 0; i < stages.length; i++) {
        final phaseNum = i + 1;
        try {
          final status = await approvalSvc.getStatus(
            widget.project.id,
            phaseNum,
          );
          if (status != null && status['status'] == 'approved') {
            activePhaseNum = phaseNum + 1;
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }

      if (activePhaseNum > stages.length) {
        allCompleted = true;
        activePhaseNum = stages.length;
      }

      for (int i = 0; i < stages.length; i++) {
        final phaseNum = i + 1;
        try {
          final cmp = await approvalSvc.compare(widget.project.id, phaseNum);
          _answersDiffer[phaseNum] = !(cmp['match'] == true);
        } catch (_) {
          _answersDiffer[phaseNum] = false;
        }
      }

      if (mounted) {
        setState(() {
          _stages.clear();
          _stages.addAll(stages);
          _activePhase = activePhaseNum;
          _isProjectCompleted = allCompleted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activePhase = 1;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          Text(
            'Phase Overview',
            style: widget.compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.headlineSmall,
          ),
        if (widget.showTitle) const SizedBox(height: 8),
        if (_loading)
          Padding(
            padding: EdgeInsets.all(widget.compact ? 4.0 : 8.0),
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        if (!_loading && _stages.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 12.0 : 16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No phases available. Phases will be created when the project is started.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: widget.compact ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_loading && _stages.isNotEmpty) ...[
          if (_isProjectCompleted)
            Padding(
              padding: EdgeInsets.only(bottom: widget.compact ? 8.0 : 12.0),
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: EdgeInsets.all(widget.compact ? 8.0 : 12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue.shade700,
                        size: widget.compact ? 20 : 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🎉 Project Completed! All phases have been reviewed and approved.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: widget.compact ? 12 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: widget.compact ? 8 : 12,
            runSpacing: widget.compact ? 8 : 12,
            children: _stages.asMap().entries.map((entry) {
              final index = entry.key;
              final stage = entry.value;
              final phaseNum = index + 1;
              final stageName = (stage['stage_name'] ?? 'Phase $phaseNum')
                  .toString();
              final differs = _answersDiffer[phaseNum] == true;

              final isDone = phaseNum < _activePhase || _isProjectCompleted;
              final isActive = phaseNum == _activePhase && !_isProjectCompleted;
              final isInactive = phaseNum > _activePhase && !isDone;

              Color cardColor = Colors.white;
              Color borderColor = Colors.blueGrey;
              Color avatarColor = Colors.grey.shade300;

              if (differs && !isDone) {
                cardColor = Colors.red.shade50;
                borderColor = Colors.redAccent;
              } else if (_isProjectCompleted || isDone) {
                borderColor = Colors.blue.shade300;
                avatarColor = Colors.blue.shade300;
              } else if (isActive) {
                borderColor = Colors.green;
                avatarColor = Colors.green;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.compact ? 6 : 8),
                  side: BorderSide(color: borderColor, width: 1),
                ),
                color: cardColor,
                child: Container(
                  width: widget.compact ? 180 : 220,
                  padding: EdgeInsets.all(widget.compact ? 8 : 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: widget.compact ? 12 : 16,
                        backgroundColor: avatarColor,
                        child: Text(
                          '$phaseNum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.compact ? 12 : 14,
                          ),
                        ),
                      ),
                      SizedBox(width: widget.compact ? 8 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.compact ? 12 : 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: widget.compact ? 2 : 4),
                            Row(
                              children: [
                                if (differs)
                                  _Badge(
                                    label: 'Answers differ',
                                    compact: widget.compact,
                                  ),
                                if (isDone)
                                  _Badge(
                                    label: 'Done',
                                    color: Colors.blue.shade100,
                                    compact: widget.compact,
                                  )
                                else if (isActive)
                                  _Badge(
                                    label: 'In progress',
                                    color: Colors.green.shade100,
                                    compact: widget.compact,
                                  )
                                else if (isInactive)
                                  _Badge(
                                    label: 'Inactive',
                                    color: Colors.grey.shade200,
                                    compact: widget.compact,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool compact;

  const _Badge({required this.label, this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color ?? Colors.red.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
