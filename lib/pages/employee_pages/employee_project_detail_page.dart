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
import 'phase1_checklist.dart';
import '../../services/approval_service.dart';

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
                    _PhaseCards(
                      project: details.project,
                      onOpenChecklist: (phase) {
                        final proj = details.project;
                        // Derive names from IDs using TeamController
                        List<String> _namesFrom(Set<String> ids) {
                          return ids
                              .map(
                                (id) => _teamCtrl.members
                                    .firstWhereOrNull((m) => m.id == id)
                                    ?.name,
                              )
                              .whereType<String>()
                              .toList();
                        }

                        final leaders = _namesFrom(details.teamLeaderIds);
                        final reviewers = _namesFrom(details.reviewerIds);
                        final executors = _namesFrom(details.executorIds);
                        Get.to(() => QuestionsScreen(
                              projectId: proj.id,
                              projectTitle: proj.title,
                              leaders: leaders,
                              reviewers: reviewers,
                              executors: executors,
                              initialPhase: phase,
                              // Optionally deep-link to specific sub-question: pass via initialSubQuestion
                            ));
                      },
                    ),
                    const SizedBox(height: 24),
                    _RoleAssignmentSections(
                      teamCtrl: _teamCtrl,
                      details: details,
                      projectId: details.project.id,
                      projectsCtrl: _projectsCtrl,
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
  final void Function(int phase) onOpenChecklist;
  const _PhaseCards({required this.project, required this.onOpenChecklist});

  @override
  State<_PhaseCards> createState() => _PhaseCardsState();
}

class _PhaseCardsState extends State<_PhaseCards> {
  int _activePhase = 1;
  final Map<int, bool> _answersDiffer = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  Future<void> _prefetch() async {
    setState(() => _loading = true);
    try {
      final ApprovalService svc = Get.find<ApprovalService>();
      // Compute active phase from approvals
      int ap = 1;
      final st1 = await svc.getStatus(widget.project.id, 1);
      if (st1 != null && st1['status'] == 'approved') {
        ap = 2;
        final st2 = await svc.getStatus(widget.project.id, 2);
        if (st2 != null && st2['status'] == 'approved') {
          ap = 3;
        }
      }
      _activePhase = ap;
      // Compare for phases
      for (final p in [1, 2, 3]) {
        try {
          final cmp = await svc.compare(widget.project.id, p);
          _answersDiffer[p] = !(cmp['match'] == true);
        } catch (_) {
          _answersDiffer[p] = false;
        }
      }
    } catch (_) {
      _activePhase = 1;
    }
    if (mounted) setState(() => _loading = false);
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [1, 2, 3].map((p) {
            final isActive = p == activePhase;
            final isOld = p < activePhase;
            final canOpen = p <= activePhase;
            final differs = _answersDiffer[p] == true;
            final cardColor = differs ? Colors.red.shade50 : Colors.white;
            final borderColor = differs
                ? Colors.redAccent
                : (isActive ? Colors.green : Colors.blueGrey);
            return GestureDetector(
              onTap: canOpen
                  ? () => widget.onOpenChecklist(p)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Phase $p is locked. Complete Phase ${p - 1} first.',
                          ),
                        ),
                      );
                    },
              child: Card(
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
                        backgroundColor: isActive
                            ? Colors.green
                            : (canOpen
                                  ? Colors.blueGrey
                                  : Colors.grey.shade300),
                        child: Text(
                          '$p',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phase $p',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (differs) _Badge(label: 'Answers differ'),
                                if (isOld) _Badge(label: 'View only'),
                                if (!canOpen) _Badge(label: 'Locked'),
                                if (isActive) _Badge(label: 'Active'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
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
  const _Badge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _RoleAssignmentSections extends StatefulWidget {
  final TeamController teamCtrl;
  final ProjectDetailsController details;
  final String projectId;
  final ProjectsController projectsCtrl;
  const _RoleAssignmentSections({
    required this.teamCtrl,
    required this.details,
    required this.projectId,
    required this.projectsCtrl,
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

  List<TeamMemberFiltered> _filter(String q) {
    final members = widget.teamCtrl.members;
    if (q.trim().isEmpty) {
      return members
          .map((m) => TeamMemberFiltered(m.id, m.name, m.email))
          .toList();
    }
    final lower = q.toLowerCase();
    return members
        .where(
          (m) =>
              m.name.toLowerCase().contains(lower) ||
              m.email.toLowerCase().contains(lower),
        )
        .map((m) => TeamMemberFiltered(m.id, m.name, m.email))
        .toList();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Role assignments saved')));
      }
      await _hydrateMemberships();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
  }) {
    final filtered = _filter(ctrl.text);
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
                          onChanged: (v) =>
                              setState(() => toggle(m.id, v == true)),
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
          ),
          const _DashedDivider(),
          _section(
            title: 'Assign Executor(s)',
            ctrl: _searchExecutor,
            selected: d.executorIds,
            toggle: d.toggleExecutor,
          ),
          const _DashedDivider(),
          _section(
            title: 'Assign Reviewer(s)',
            ctrl: _searchReviewer,
            selected: d.reviewerIds,
            toggle: d.toggleReviewer,
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
              ),
            ),
            const _VerticalDashedDivider(),
            Expanded(
              child: _section(
                title: 'Assign Executor(s)',
                ctrl: _searchExecutor,
                selected: d.executorIds,
                toggle: d.toggleExecutor,
              ),
            ),
            const _VerticalDashedDivider(),
            Expanded(
              child: _section(
                title: 'Assign Reviewer(s)',
                ctrl: _searchReviewer,
                selected: d.reviewerIds,
                toggle: d.toggleReviewer,
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
