import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/projects_controller.dart';
import '../../models/team_member.dart';
import '../../models/project.dart';

class EmployeeProjectsPage extends StatefulWidget {
  final TeamMember member;
  const EmployeeProjectsPage({super.key, required this.member});

  @override
  State<EmployeeProjectsPage> createState() => _EmployeeProjectsPageState();
}

class _EmployeeProjectsPageState extends State<EmployeeProjectsPage> {
  bool _isLoading = true;
  List<Project> _current = [];
  List<Project> _completed = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final projectsCtrl = Get.find<ProjectsController>();

      // Refresh projects to ensure we have latest data with assigned employees
      await projectsCtrl.refreshProjects();

      // Small delay to ensure hydration completes (race condition fix)
      // Removed delay for faster loading

      if (!mounted) return;

      // Use the controller's byAssigneeId method for more reliable filtering
      final allProjects = projectsCtrl.byAssigneeId(widget.member.id);

      // Debug logging
      print(
        '[EmployeeProjectsPage] Loaded projects for ${widget.member.name} (${widget.member.id}):',
      );
      print(
        '[EmployeeProjectsPage] Total projects found: ${allProjects.length}',
      );
      for (final p in allProjects) {
        print(
          '[EmployeeProjectsPage]   - ${p.title} (assignedEmployees: ${p.assignedEmployees})',
        );
      }

      // Separate into current and completed
      bool isCompleted(Project p) => p.status.toLowerCase() == 'completed';

      if (mounted) {
        setState(() {
          _current = allProjects.where((p) => !isCompleted(p)).toList();
          _completed = allProjects.where(isCompleted).toList();
          _isLoading = false;
        });

        print(
          '[EmployeeProjectsPage] Current: ${_current.length}, Completed: ${_completed.length}',
        );
      }
    } catch (e) {
      print('[EmployeeProjectsPage] Error loading projects: $e');
      if (mounted) {
        setState(() {
          _current = [];
          _completed = [];
          _isLoading = false;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load projects: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadProjects,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadProjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ProjectListSection(
                              title: 'Current Projects',
                              projects: _current,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _ProjectListSection(
                              title: 'Completed Projects',
                              projects: _completed,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProjectListSection(
                            title: 'Current Projects',
                            projects: _current,
                          ),
                          const SizedBox(height: 24),
                          _ProjectListSection(
                            title: 'Completed Projects',
                            projects: _completed,
                          ),
                        ],
                      );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projects for ${widget.member.name}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${_current.length + _completed.length} projects',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      content,
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ProjectListSection extends StatelessWidget {
  final String title;
  final List<Project> projects;
  const _ProjectListSection({required this.title, required this.projects});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${projects.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (projects.isEmpty)
              const Text('None')
            else
              Column(
                children: [for (final p in projects) _ProjectTile(project: p)],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  project.status,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}
