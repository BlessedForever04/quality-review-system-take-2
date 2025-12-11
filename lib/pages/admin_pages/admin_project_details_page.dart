import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/team_controller.dart';
import '../../components/admin_dialog.dart';
import '../../controllers/project_details_controller.dart';
import '../../services/project_service.dart';
import '../../services/project_membership_service.dart';
import '../../services/role_service.dart';
import '../../models/role.dart';

class AdminProjectDetailsPage extends StatefulWidget {
  final Project project;
  final String? descriptionOverride;

  const AdminProjectDetailsPage({
    super.key,
    required this.project,
    this.descriptionOverride,
  });

  @override
  State<AdminProjectDetailsPage> createState() =>
      _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> {
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
      // If fetch fails, continue with the passed project data
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
        actions: [
          IconButton(
            tooltip: 'Edit project',
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, details),
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, details),
          ),
        ],
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

  List<String> _executorNames() {
    final names = _teamCtrl.members
        .map((m) => m.name)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  Future<void> _showEditDialog(
    BuildContext context,
    ProjectDetailsController detailsCtrl,
  ) async {
    final formKey = GlobalKey<FormState>();
    final current = detailsCtrl.project;
    String? projectNo = current.projectNo;
    String? internalOrderNo = current.internalOrderNo;
    String title = current.title;
    DateTime started = current.started;
    String priority = current.priority;
    String status = current.status;
    String? executor = current.executor;
    String description = current.description ?? '';

    const allowedPriorities = ['High', 'Medium', 'Low'];
    const allowedStatuses = ['In Progress', 'Completed', 'Not Started'];
    if (!allowedPriorities.contains(priority)) priority = 'Medium';
    if (!allowedStatuses.contains(status)) status = 'Not Started';
    executor = (executor != null && executor.trim().isNotEmpty)
        ? executor.trim()
        : null;
    final executorNames = _executorNames();
    if (executor != null && !executorNames.contains(executor)) executor = null;

    await showAdminDialog(
      context,
      title: 'Edit Project',
      width: 900,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: projectNo,
              decoration: const InputDecoration(labelText: 'Project No.'),
              onSaved: (v) => projectNo = v?.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: internalOrderNo,
              decoration: const InputDecoration(
                labelText: 'Project / Internal Order No.',
              ),
              onSaved: (v) => internalOrderNo = v?.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: title,
              decoration: const InputDecoration(labelText: 'Project Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter title' : null,
              onSaved: (v) => title = v!.trim(),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: started,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) started = picked;
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Started Date *',
                  ),
                  controller: TextEditingController(text: _formatDate(started)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              items: const [
                'High',
                'Medium',
                'Low',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => priority = v ?? priority,
              decoration: const InputDecoration(labelText: 'Priority *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                'In Progress',
                'Completed',
                'Not Started',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => status = v ?? status,
              decoration: const InputDecoration(labelText: 'Status *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: executor,
              items: executorNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => executor = v,
              decoration: const InputDecoration(
                labelText: 'Executor (optional)',
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Description *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            TextFormField(
              initialValue: description,
              minLines: 10,
              maxLines: 16,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Enter description...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter description' : null,
              onSaved: (v) => description = v!.trim(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final updated = current.copyWith(
                        projectNo: projectNo,
                        internalOrderNo: internalOrderNo,
                        title: title,
                        started: started,
                        priority: priority,
                        status: status,
                        executor: (executor == null || executor!.isEmpty)
                            ? null
                            : executor,
                        description: description,
                      );
                      Navigator.of(context).pop();
                      try {
                        await _projectsCtrl.saveProjectRemote(updated);
                        // Fetch latest data from backend
                        final projectService = Get.find<ProjectService>();
                        final latestProject = await projectService.getById(
                          updated.id,
                        );
                        detailsCtrl.seed(latestProject);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Project updated')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ProjectDetailsController detailsCtrl,
  ) async {
    await showAdminDialog(
      context,
      title: 'Delete Project',
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to delete "${detailsCtrl.project.title}"? This action cannot be undone.',
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  try {
                    Navigator.of(context).pop(); // Close dialog first
                    await _projectsCtrl.removeProjectRemoteAndRefresh(
                      detailsCtrl.project.id,
                    );
                    Get.back(); // Go back to project list
                    Get.snackbar(
                      'Deleted',
                      'Project has been deleted successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to delete project: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text('Delete Project'),
              ),
            ],
          ),
        ],
      ),
    );
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
      // Find existing roles by name (case-insensitive)
      Role? leaderRole = roles.firstWhereOrNull(
        (r) => r.roleName.toLowerCase() == 'sdh',
      );
      leaderRole ??= roles.firstWhereOrNull(
        (r) => r.roleName.toLowerCase() == 'team leader',
      );
      // Mutable so we can assign if role needs to be created
      String? leaderRoleId = leaderRole?.id;
      final String? executorRoleId = roles
          .firstWhereOrNull((r) => r.roleName.toLowerCase() == 'executor')
          ?.id;
      final String? reviewerRoleId = roles
          .firstWhereOrNull((r) => r.roleName.toLowerCase() == 'reviewer')
          ?.id;
      // Create SDH role if missing
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
    // Responsive: if width is small (< 900), fall back to vertical layout
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
          // Use fixed height based on parent Row children's intrinsic height, so just build many dashes.
          final dashHeight = 6.0;
          final dashWidth = 1.0;
          // Approximate available height by using 400 if unconstrained.
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
