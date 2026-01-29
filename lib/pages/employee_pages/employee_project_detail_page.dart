import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/project_details_controller.dart';
import '../../services/project_service.dart';
import '../../services/project_membership_service.dart';
import '../../services/role_service.dart';
import '../../models/role.dart';
import '../../models/project_membership.dart';
import '../../services/approval_service.dart';
import '../../services/stage_service.dart';

class EmployeeProjectDetailPage extends StatefulWidget {
  final Project project;
  final String? description;

  const EmployeeProjectDetailPage({
    super.key,
    required this.project,
    this.description,
  });

  @override
  State<EmployeeProjectDetailPage> createState() =>
      _EmployeeProjectDetailsPageState();
}

class _EmployeeProjectDetailsPageState
    extends State<EmployeeProjectDetailPage> {
  late ProjectDetailsController _detailsCtrl;
  bool _isLoading = true;
  bool _loadingAssignments = true;
  List<ProjectMembership> _teamLeaders = [];
  List<ProjectMembership> _executors = [];
  List<ProjectMembership> _reviewers = [];

  @override
  void initState() {
    super.initState();
    _detailsCtrl = Get.put(
      ProjectDetailsController(),
      tag: widget.project.id,
      permanent: false,
    );
    _detailsCtrl.seed(widget.project);
    _fetchLatestProjectData();
    _loadAssignments();
  }

  Future<void> _fetchLatestProjectData() async {
    try {
      final projectService = Get.find<ProjectService>();
      final latestProject = await projectService.getById(widget.project.id);
      _detailsCtrl.seed(latestProject);
    } catch (e) {
      debugPrint('Failed to fetch latest project: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssignments = true);
    try {
      if (Get.isRegistered<ProjectMembershipService>()) {
        final svc = Get.find<ProjectMembershipService>();
        final memberships = await svc.getProjectMembers(widget.project.id);
        final leaders = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'sdh')
            .toList();
        final execs = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'executor')
            .toList();
        final reviewers = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'reviewer')
            .toList();
        if (mounted) {
          setState(() {
            _teamLeaders = leaders;
            _executors = execs;
            _reviewers = reviewers;
          });
        }
      }
    } catch (e) {
      debugPrint('[EmployeeProjectDetail] loadAssignments error: $e');
    } finally {
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  ProjectsController get _projectsCtrl => Get.find<ProjectsController>();
  TeamController get _teamCtrl => Get.find<TeamController>();
  ProjectDetailsController _details() => _detailsCtrl;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final details = _details();
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(details.project.title)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Obx(
              () => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (details.project.projectNo != null &&
                                details.project.projectNo!.isNotEmpty)
                              _row('Project No.', details.project.projectNo!),
                            if (details.project.internalOrderNo != null &&
                                details.project.internalOrderNo!.isNotEmpty)
                              _row(
                                'Project / Internal Order No.',
                                details.project.internalOrderNo!,
                              ),
                            _row('Title', details.project.title),
                            _row(
                              'Started',
                              _formatDate(details.project.started),
                            ),
                            _row('Priority', details.project.priority),
                            _row('Status', details.project.status),
                            _row(
                              'Executor',
                              (details.project.executor?.trim().isNotEmpty ??
                                      false)
                                  ? details.project.executor!.trim()
                                  : '--',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Obx(() {
                          final desc = (details.project.description ?? '')
                              .trim();
                          return Text(
                            desc.isNotEmpty ? desc : 'No description provided.',
                            style: const TextStyle(height: 1.4),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PhaseCards(project: details.project),
                    const SizedBox(height: 24),
                    Text(
                      'Assigned Team Members',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _loadingAssignments
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _AssignedTeamGrid(
                            leaders: _teamLeaders,
                            executors: _executors,
                            reviewers: _reviewers,
                          ),
                    const SizedBox(height: 24),
                    if (details.project.status == 'Not Started')
                      _RoleAssignmentSections(
                        teamCtrl: _teamCtrl,
                        details: details,
                        projectId: details.project.id,
                        projectsCtrl: _projectsCtrl,
                        onAssignmentsChanged: _loadAssignments,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    Get.delete<ProjectDetailsController>(tag: widget.project.id);
    super.dispose();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PhaseCards extends StatefulWidget {
  final Project project;
  const _PhaseCards({required this.project});

  @override
  State<_PhaseCards> createState() => _PhaseCardsState();
}

class _PhaseCardsState extends State<_PhaseCards> {
  int _activePhase = 1;
  final Map<int, bool> _answersDiffer = {};
  final List<Map<String, dynamic>> _stages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  Future<void> _prefetch() async {
    setState(() => _loading = true);
    try {
      // Fetch actual stages from database
      final stageService = Get.find<StageService>();
      final stages = await stageService.listStages(widget.project.id);

      if (stages.isEmpty) {
        // No stages created yet (project not started)
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Find the active stage based on status
      int activePhaseNum = 1;
      bool foundActive = false;

      // First, check if any stage is currently in progress
      for (int i = 0; i < stages.length; i++) {
        final status = (stages[i]['status'] ?? '').toString().toLowerCase();
        if (status == 'in_progress') {
          activePhaseNum = i + 1;
          foundActive = true;
          break;
        }
      }

      // If no stage is in progress, find the first pending stage
      if (!foundActive) {
        for (int i = 0; i < stages.length; i++) {
          final status = (stages[i]['status'] ?? '').toString().toLowerCase();
          if (status == 'pending') {
            activePhaseNum = i + 1;
            break;
          }
        }
      }

      // Check for answer differences
      final ApprovalService approvalSvc = Get.find<ApprovalService>();
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
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stages: $e');
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
    final activePhase = _activePhase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phases', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!_loading && _stages.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No phases available. Phases will be created when the project is started.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_loading && _stages.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _stages.asMap().entries.map((entry) {
              final index = entry.key;
              final stage = entry.value;
              final phaseNum = index + 1;
              final stageName = (stage['stage_name'] ?? 'Phase $phaseNum')
                  .toString();
              final stageStatus = (stage['status'] ?? 'pending')
                  .toString()
                  .toLowerCase();

              // Determine phase state
              final isDone = stageStatus == 'completed';
              final isActive = phaseNum == activePhase && !isDone;
              final isInactive = phaseNum > activePhase;
              final differs = _answersDiffer[phaseNum] == true;

              // Determine colors
              Color cardColor = Colors.white;
              Color borderColor = Colors.blueGrey;
              Color avatarColor = Colors.grey.shade300;

              if (differs) {
                cardColor = Colors.red.shade50;
                borderColor = Colors.redAccent;
              } else if (isDone) {
                borderColor = Colors.blue.shade300;
                avatarColor = Colors.blue.shade300;
              } else if (isActive) {
                borderColor = Colors.green;
                avatarColor = Colors.green;
              } else if (isInactive) {
                avatarColor = Colors.grey.shade300;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor, width: 1),
                ),
                color: cardColor,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: avatarColor,
                        child: Text(
                          '$phaseNum',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (differs) _Badge(label: 'Answers differ'),
                                if (isDone)
                                  _Badge(
                                    label: 'Done',
                                    color: Colors.blue.shade100,
                                  ),
                                if (isActive)
                                  _Badge(
                                    label: 'Active',
                                    color: Colors.green.shade100,
                                  ),
                                if (isInactive)
                                  _Badge(
                                    label: 'Inactive',
                                    color: Colors.grey.shade200,
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
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  const _Badge({required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _AssignedTeamGrid extends StatelessWidget {
  final List<ProjectMembership> leaders;
  final List<ProjectMembership> executors;
  final List<ProjectMembership> reviewers;
  const _AssignedTeamGrid({
    required this.leaders,
    required this.executors,
    required this.reviewers,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RoleCard(title: 'SDH', color: Colors.blue, members: leaders),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _RoleCard(
            title: 'Executors',
            color: Colors.green,
            members: executors,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _RoleCard(
            title: 'Reviewers',
            color: Colors.orange,
            members: reviewers,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<ProjectMembership> members;
  const _RoleCard({
    required this.title,
    required this.color,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${members.length}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (members.isEmpty)
              Text(
                'No members assigned yet',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: members
                    .map(
                      (m) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color.withOpacity(0.14),
                              child: Text(
                                (m.userName ?? 'U')
                                    .trim()
                                    .padRight(1)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(color: color),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m.userName ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleAssignmentSections extends StatefulWidget {
  final TeamController teamCtrl;
  final ProjectDetailsController details;
  final String projectId;
  final ProjectsController projectsCtrl;
  final Future<void> Function()? onAssignmentsChanged;
  const _RoleAssignmentSections({
    required this.teamCtrl,
    required this.details,
    required this.projectId,
    required this.projectsCtrl,
    this.onAssignmentsChanged,
  });

  @override
  State<_RoleAssignmentSections> createState() =>
      _RoleAssignmentSectionsState();
}

class _RoleAssignmentSectionsState extends State<_RoleAssignmentSections> {
  final TextEditingController _searchLeader = TextEditingController();
  final TextEditingController _searchExecutor = TextEditingController();
  final TextEditingController _searchReviewer = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrateMemberships();
  }

  Future<void> _hydrateMemberships() async {
    if (!Get.isRegistered<ProjectMembershipService>()) return;
    final svc = Get.find<ProjectMembershipService>();
    final memberships = await svc.getProjectMembers(widget.projectId);
    widget.details.seedMemberships(memberships);
    setState(() {});
  }

  List<TeamMemberFiltered> _filter(String q, {Set<String> exclude = const {}}) {
    final members = widget.teamCtrl.members;
    // Filter out members who are already assigned to other roles
    // AND filter out admin users - only show users with 'user' role
    final available = members.where(
      (m) => !exclude.contains(m.id) && m.role.toLowerCase() == 'user',
    );

    if (q.trim().isEmpty) {
      return available
          .map((m) => TeamMemberFiltered(m.id, m.name, m.email))
          .toList();
    }
    final lower = q.toLowerCase();
    return available
        .where(
          (m) =>
              m.name.toLowerCase().contains(lower) ||
              m.email.toLowerCase().contains(lower),
        )
        .map((m) => TeamMemberFiltered(m.id, m.name, m.email))
        .toList();
  }

  /// Show warning when trying to select more than 1 SDH
  Future<void> _showSDHLimitWarning() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SDH Selection Limit'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only one SDH (Senior Decision Handler) can be assigned per project.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Please deselect the current SDH before selecting a different one.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final roleService = Get.find<RoleService>();
      final membershipService = Get.find<ProjectMembershipService>();
      final roles = await roleService.getAll();
      Role? leaderRole = roles.firstWhereOrNull(
        (r) => r.roleName.toLowerCase() == 'sdh',
      );
      leaderRole ??= roles.firstWhereOrNull(
        (r) => r.roleName.toLowerCase() == 'team leader',
      );
      String? leaderRoleId = leaderRole?.id;
      final String? executorRoleId = roles
          .firstWhereOrNull((r) => r.roleName.toLowerCase() == 'executor')
          ?.id;
      final String? reviewerRoleId = roles
          .firstWhereOrNull((r) => r.roleName.toLowerCase() == 'reviewer')
          ?.id;
      if (leaderRoleId == null) {
        final created = await roleService.create(
          Role(id: 'new', roleName: 'SDH'),
        );
        leaderRoleId = created.id;
      }
      if (executorRoleId == null || reviewerRoleId == null) {
        throw Exception('Required roles missing (Executor/Reviewer).');
      }
      final existing = await membershipService.getProjectMembers(
        widget.projectId,
      );
      Map<String, Set<String>> existingByRole = {};
      for (final m in existing) {
        final rn = (m.roleName ?? '').toLowerCase();
        existingByRole.putIfAbsent(rn, () => <String>{}).add(m.userId);
      }
      Future<void> apply(
        String roleId,
        String roleKey,
        Set<String> desired,
      ) async {
        final ex = existingByRole[roleKey] ?? <String>{};
        final toAdd = desired.difference(ex);
        final toRemove = ex.difference(desired);
        for (final id in toAdd) {
          await membershipService.addMember(
            projectId: widget.projectId,
            userId: id,
            roleId: roleId,
          );
        }
        for (final id in toRemove) {
          await membershipService.removeMember(
            projectId: widget.projectId,
            userId: id,
          );
        }
      }

      await apply(leaderRoleId, 'sdh', widget.details.teamLeaderIds.toSet());
      await apply(
        executorRoleId,
        'executor',
        widget.details.executorIds.toSet(),
      );
      await apply(
        reviewerRoleId,
        'reviewer',
        widget.details.reviewerIds.toSet(),
      );
      widget.details.updateMeta();
      if (mounted) {
        Get.snackbar(
          'Success',
          'Role assignments saved',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      await _hydrateMemberships();
      if (widget.onAssignmentsChanged != null) {
        await widget.onAssignmentsChanged!();
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section({
    required String title,
    required TextEditingController ctrl,
    required Set<String> selected,
    required Function(String, bool) toggle,
    bool isSDH = false,
    Set<String> excludeIds = const {},
  }) {
    final filtered = _filter(ctrl.text, exclude: excludeIds);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No matches'),
                  )
                : SizedBox(
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final checked = selected.contains(m.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) async {
                            // For SDH role, validate that only 1 is selected
                            if (isSDH && v == true && selected.length >= 1) {
                              await _showSDHLimitWarning();
                              return;
                            }
                            setState(() => toggle(m.id, v == true));
                          },
                          title: Text(m.name),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              'Selected (${selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: selected.map((id) {
                final member = widget.teamCtrl.members.firstWhereOrNull(
                  (e) => e.id == id,
                );
                final label = member?.name ?? id;
                return Chip(label: Text(label));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final width = MediaQuery.of(context).size.width;
    if (width < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(
            title: 'Assign SDH',
            ctrl: _searchLeader,
            selected: d.teamLeaderIds,
            toggle: d.toggleTeamLeader,
            isSDH: true,
            excludeIds: {...d.executorIds, ...d.reviewerIds},
          ),
          const _DashedDivider(),
          _section(
            title: 'Assign Executor(s)',
            ctrl: _searchExecutor,
            selected: d.executorIds,
            toggle: d.toggleExecutor,
            excludeIds: {...d.teamLeaderIds, ...d.reviewerIds},
          ),
          const _DashedDivider(),
          _section(
            title: 'Assign Reviewer(s)',
            ctrl: _searchReviewer,
            selected: d.reviewerIds,
            toggle: d.toggleReviewer,
            excludeIds: {...d.teamLeaderIds, ...d.executorIds},
          ),
          const SizedBox(height: 12),
          _actionsRow(d),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _section(
                title: 'Assign SDH',
                ctrl: _searchLeader,
                selected: d.teamLeaderIds,
                toggle: d.toggleTeamLeader,
                isSDH: true,
                excludeIds: {...d.executorIds, ...d.reviewerIds},
              ),
            ),
            const _VerticalDashedDivider(),
            Expanded(
              child: _section(
                title: 'Assign Executor(s)',
                ctrl: _searchExecutor,
                selected: d.executorIds,
                toggle: d.toggleExecutor,
                excludeIds: {...d.teamLeaderIds, ...d.reviewerIds},
              ),
            ),
            const _VerticalDashedDivider(),
            Expanded(
              child: _section(
                title: 'Assign Reviewer(s)',
                ctrl: _searchReviewer,
                selected: d.reviewerIds,
                toggle: d.toggleReviewer,
                excludeIds: {...d.teamLeaderIds, ...d.executorIds},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _actionsRow(d),
      ],
    );
  }

  Widget _actionsRow(ProjectDetailsController d) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saving ? null : _saveAll,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save changes'),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  setState(() {
                    d.teamLeaderIds.clear();
                    d.executorIds.clear();
                    d.reviewerIds.clear();
                    d.selectedMemberIds.clear();
                  });
                },
          child: const Text('Clear All'),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashWidth = 6.0;
          final dashHeight = 1.0;
          final dashCount = (constraints.maxWidth / (dashWidth * 2)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount,
              (_) => Container(
                width: dashWidth,
                height: dashHeight,
                color: Colors.grey.shade400,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerticalDashedDivider extends StatelessWidget {
  const _VerticalDashedDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashHeight = 6.0;
          final dashWidth = 1.0;
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 400;
          final dashCount = (h / (dashHeight * 2)).floor();
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount > 0 ? dashCount : 40,
              (_) => Container(
                width: dashWidth,
                height: dashHeight,
                color: Colors.grey.shade400,
              ),
            ),
          );
        },
      ),
    );
  }
}

class TeamMemberFiltered {
  final String id;
  final String name;
  final String email;
  TeamMemberFiltered(this.id, this.name, this.email);
}
