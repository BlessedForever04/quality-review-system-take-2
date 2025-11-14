import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/team_controller.dart';
import '../../components/admin_dialog.dart';
import '../../controllers/project_details_controller.dart';

class AdminProjectDetailsPage extends StatelessWidget {
  final Project project;
  final String? descriptionOverride;

  AdminProjectDetailsPage({super.key, required this.project, this.descriptionOverride}) {
    final details = Get.put(ProjectDetailsController(), tag: project.id, permanent: false);
    details.seed(project);
  }

  ProjectsController get _projectsCtrl => Get.find<ProjectsController>();
  TeamController get _teamCtrl => Get.find<TeamController>();
  ProjectDetailsController _details() => Get.find<ProjectDetailsController>(tag: project.id);

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final details = _details();
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(details.project.title)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => _row('Title', details.project.title)),
                    Obx(() => _row('Started', _formatDate(details.project.started))),
                    Obx(() => _row('Priority', details.project.priority)),
                    Obx(() => _row('Status', details.project.status)),
                    Obx(() => _row('Executor', (details.project.executor?.trim().isNotEmpty ?? false) ? details.project.executor!.trim() : '--')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Obx(() {
                  final desc = (descriptionOverride ?? details.project.description)?.trim() ?? '';
                  return Text(desc.isNotEmpty ? desc : 'No description provided.', style: const TextStyle(height: 1.4));
                }),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assign Employees', style: Theme.of(context).textTheme.titleMedium),
                Obx(() => Text('${details.selectedMemberIds.length} selected', style: const TextStyle(color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Obx(() {
                  final members = _teamCtrl.members;
                  if (members.isEmpty) return const Text('No employees found.');
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final checked = details.selectedMemberIds.contains(m.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) => details.toggleMember(m.id, v == true),
                        title: Text(m.name),
                        subtitle: Text(m.email),
                        secondary: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0] : '?')),
                      );
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final updated = details.project.copyWith(
                      assignedEmployees: details.selectedMemberIds.toList(),
                    );
                    _projectsCtrl.updateProject(updated.id, updated);
                    details.updateMeta();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignments saved')));
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Assignments'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => details.selectedMemberIds.clear(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Obx(() => details.selectedMemberIds.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Currently Assigned', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: details.selectedMemberIds
                            .map((id) {
                              final idx = _teamCtrl.members.indexWhere((e) => e.id == id);
                              final name = idx != -1 ? _teamCtrl.members[idx].name : id;
                              return Chip(label: Text(name));
                            })
                            .toList(),
                      ),
                    ],
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  List<String> _executorNames() {
    final names = _teamCtrl.members.map((m) => m.name).where((e) => e.trim().isNotEmpty).toSet().toList();
    names.sort();
    if (names.isEmpty) {
      return const ['Emma Carter','Liam Walker','Olivia Harris','Noah Clark','Ava Lewis','William Hall','Sophia Young','James Wright','Isabella King'];
    }
    return names;
  }

  Future<void> _showEditDialog(BuildContext context, ProjectDetailsController detailsCtrl) async {
    final formKey = GlobalKey<FormState>();
    final current = detailsCtrl.project;
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
    executor = (executor != null && executor.trim().isNotEmpty) ? executor.trim() : null;
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
              initialValue: title,
              decoration: const InputDecoration(labelText: 'Project Title *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
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
                  decoration: const InputDecoration(labelText: 'Started Date *'),
                  controller: TextEditingController(
                    text: _formatDate(started),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priority,
              items: const ['High', 'Medium', 'Low']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => priority = v ?? priority,
              decoration: const InputDecoration(labelText: 'Priority *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: status,
              items: const ['In Progress', 'Completed', 'Not Started']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => status = v ?? status,
              decoration: const InputDecoration(labelText: 'Status *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: executor,
              items: executorNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => executor = v,
              decoration: const InputDecoration(labelText: 'Executor (optional)'),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Description *', style: TextStyle(fontWeight: FontWeight.w600)),
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter description' : null,
              onSaved: (v) => description = v!.trim(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final updated = current.copyWith(
                        title: title,
                        started: started,
                        priority: priority,
                        status: status,
                        executor: (executor == null || executor!.isEmpty) ? null : executor,
                        description: description,
                      );
                      _projectsCtrl.saveProjectRemote(updated);
                      detailsCtrl.updateMeta(
                        title: updated.title,
                        started: updated.started,
                        priority: updated.priority,
                        status: updated.status,
                        executor: updated.executor,
                        description: updated.description,
                      );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project updated')));
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

  Future<void> _showDeleteDialog(BuildContext context, ProjectDetailsController detailsCtrl) async {
    await showAdminDialog(
      context,
      title: 'Delete Project',
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => Text('Are you sure you want to delete "${detailsCtrl.project.title}"? This action cannot be undone.')),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  await _projectsCtrl.removeProjectRemote(detailsCtrl.project.id);
                  Navigator.of(context).pop();
                  Get.back();
                  Get.snackbar('Deleted', 'Project has been deleted', snackPosition: SnackPosition.BOTTOM);
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
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}