import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/questions_screen.dart';

import '../../models/project.dart';
import '../../models/project_membership.dart';
import '../../components/project_detail_info.dart';
import '../../controllers/my_project_detail_controller.dart';
import '../../services/template_service.dart';
import '../../services/project_service.dart';

class MyProjectDetailPage extends GetView<MyProjectDetailController> {
  final Project project;
  final String? description;
  const MyProjectDetailPage({
    super.key,
    required this.project,
    this.description,
  });

  // Refresh project data from server to get accurate status
  Future<void> _refreshProjectData(MyProjectDetailController controller) async {
    try {
      if (Get.isRegistered<ProjectService>()) {
        final projectService = Get.find<ProjectService>();
        final latestProject = await projectService.getById(project.id);
        controller.project.value = latestProject;
      }
    } catch (e) {
      debugPrint('Failed to refresh project data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controller
    if (!Get.isRegistered<MyProjectDetailController>()) {
      Get.lazyPut<MyProjectDetailController>(
        () => MyProjectDetailController(
          project: project,
          description: description,
        ),
        fenix: true,
      );
    }
    final c = Get.find<MyProjectDetailController>();

    // Always fetch latest project data to ensure status is accurate
    _refreshProjectData(c);

    // If the controller was already registered (navigated from another project),
    // make sure we update its state to reflect the newly selected project.
    // This prevents showing details from a previously opened project.
    if (c.project.value.id != project.id ||
        c.project.value.title != project.title) {
      c.project.value = project;
      c.description.value = description;
      // Reload assigned members for the new project context
      c.loadAssignments();
    }

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(c.project.value.title)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project info with action buttons on the right
            Obx(() {
              final p = c.project.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: ProjectDetailInfo(
                      project: p,
                      descriptionOverride: c.description.value ?? p.description,
                      showAssignedEmployees: false,
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Action buttons column on the right
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48), // Align with card content
                        // Start button (only for assigned members when project not started)
                        if (c.showStartButton) ...[
                          _StartButton(),
                          const SizedBox(height: 16),
                        ],
                        // Checklist button or info message
                        Obx(() {
                          final status = c.project.value.status.toLowerCase();
                          // Only show checklist after project is started (In Progress or Completed)
                          final isAccessible =
                              status == 'in progress' || status == 'completed';

                          if (isAccessible) {
                            return _ChecklistButton();
                          } else {
                            return Card(
                              color: Colors.blue.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.blue.shade600,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Checklists will be available when project is in progress',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            Text(
              'Assigned Team Members',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            // Loading state vs assigned members section
            Obx(
              () => c.isLoadingAssignments.value
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _AssignedEmployeesSection(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AssignedEmployeesSection extends GetView<MyProjectDetailController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Establish reactive dependencies on RxLists
      final leadersCount = controller.teamLeaders.length;
      final executorsCount = controller.executors.length;
      final reviewersCount = controller.reviewers.length;
      // Snapshot current lists for rendering
      final leaders = controller.teamLeaders.toList();
      final executors = controller.executors.toList();
      final reviewers = controller.reviewers.toList();
      // Use counts to satisfy dependencies and avoid unused warnings
      assert(leadersCount == leaders.length);
      assert(executorsCount == executors.length);
      assert(reviewersCount == reviewers.length);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _RoleCard(
              title: 'TeamLeader',
              members: leaders,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _RoleCard(
              title: 'Executors',
              members: executors,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _RoleCard(
              title: 'Reviewers',
              members: reviewers,
              color: Colors.orange,
            ),
          ),
        ],
      );
    });
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final List<ProjectMembership> members;
  final Color color;
  const _RoleCard({
    required this.title,
    required this.members,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${members.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No ${title.toLowerCase()} assigned',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withOpacity(0.2),
                              child: Text(
                                (member.userName ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                member.userName ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends GetView<MyProjectDetailController> {
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: controller.starting.value
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: const [
                          Icon(
                            Icons.play_circle_fill,
                            color: Colors.green,
                            size: 28,
                          ),
                          SizedBox(width: 8),
                          Text('Start Project'),
                        ],
                      ),
                      content: const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Do you want to start this project now?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  'Starting signals that work has begun. You can no longer use the start button afterward.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actionsPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            controller.startProject();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        ),
                      ],
                    ),
                  );
                },
          icon: controller.starting.value
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.play_circle_fill, size: 24),
          label: Text(
            controller.starting.value ? 'Starting...' : 'Start Project',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _ChecklistButton extends GetView<MyProjectDetailController> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          // Preflight: ensure template/checklists exist before navigating
          if (Get.isRegistered<TemplateService>()) {
            final tmplSvc = Get.find<TemplateService>();
            try {
              final tmpl = await tmplSvc.fetchTemplate();
              final stageKeys =
                  tmpl.keys
                      .where((k) => k.toString().startsWith('stage'))
                      .map((e) => e.toString())
                      .toList()
                    ..sort((a, b) {
                      final numA = int.tryParse(a.replaceAll('stage', '')) ?? 0;
                      final numB = int.tryParse(b.replaceAll('stage', '')) ?? 0;
                      return numA.compareTo(numB);
                    });

              var hasAnyChecklist = false;
              for (var k in stageKeys) {
                final v = tmpl[k];
                if (v is List && v.isNotEmpty) {
                  hasAnyChecklist = true;
                  break;
                }
                if (v is Map && v.isNotEmpty) {
                  hasAnyChecklist = true;
                  break;
                }
              }

              if (!hasAnyChecklist) {
                Get.snackbar(
                  'No checklist',
                  'No checklists found in the templates. Ask admin to create a template.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
            } catch (e) {
              Get.snackbar(
                'Error',
                'Failed to load templates: $e',
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
          } else {
            Get.snackbar(
              'Service unavailable',
              'TemplateService not available. Cannot open checklist.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }

          final leaders = controller.teamLeaders
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          final executors = controller.executors
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          final reviewers = controller.reviewers
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          Get.to(
            () => QuestionsScreen(
              projectId: controller.project.value.id,
              projectTitle: controller.project.value.title,
              leaders: leaders,
              reviewers: reviewers,
              executors: executors,
              initialPhase: 1,
            ),
          );
        },
        icon: const Icon(Icons.checklist_rtl, size: 26),
        label: const Text(
          'Open Checklist',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
