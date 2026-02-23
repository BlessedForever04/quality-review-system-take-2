import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/projects_controller.dart';
import '../../models/team_member.dart';
import '../../models/project.dart';
import '../../services/project_membership_service.dart';

class EmployeePerformanceDetailPage extends StatefulWidget {
  final TeamMember member;
  const EmployeePerformanceDetailPage({super.key, required this.member});

  @override
  State<EmployeePerformanceDetailPage> createState() =>
      _EmployeePerformanceDetailPageState();
}

class _EmployeePerformanceDetailPageState
    extends State<EmployeePerformanceDetailPage> {
  bool _isLoading = true;
  List<Project> _current = [];
  List<Project> _completed = [];
  Map<String, List<String>> _projectRoles = {};
  List<Project> _leaderProjects = [];

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

      // Load user's projects
      await projectsCtrl.loadUserProjects(widget.member.id);

      if (!mounted) return;

      // Get all assigned projects
      final allProjects = projectsCtrl.byAssigneeId(widget.member.id);

      // Separate into current and completed
      bool isCompleted(Project p) => p.status.toLowerCase() == 'completed';

      // Fetch roles for each project
      final membershipService = Get.find<ProjectMembershipService>();
      final rolesMap = <String, List<String>>{};
      final leaderProjects = <Project>[];

      for (final project in allProjects) {
        try {
          final memberships = await membershipService.getProjectMembers(
            project.id,
          );
          final userRoles = memberships
              .where((m) => m.userId == widget.member.id)
              .map((m) => m.roleName ?? 'Unknown')
              .toList();
          rolesMap[project.id] = userRoles;

          // Check if user is team leader in this project
          final isTeamLeader = userRoles.any(
            (role) => role.toLowerCase().contains('teamleader'),
          );
          if (isTeamLeader) {
            leaderProjects.add(project);
          }
        } catch (e) {
          print(
            '[EmployeePerformanceDetail] Error fetching roles for project ${project.id}: $e',
          );
          rolesMap[project.id] = [];
        }
      }

      if (mounted) {
        setState(() {
          _current = allProjects.where((p) => !isCompleted(p)).toList();
          _completed = allProjects.where(isCompleted).toList();
          _projectRoles = rolesMap;
          _leaderProjects = leaderProjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[EmployeePerformanceDetail] Error loading projects: $e');
      if (mounted) {
        setState(() {
          _current = [];
          _completed = [];
          _isLoading = false;
        });

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

  double _calculateOverallLeaderPerformance() {
    if (_leaderProjects.isEmpty) return 0.0;

    double totalDefectRate = 0.0;
    int projectsWithDefectRate = 0;

    for (final project in _leaderProjects) {
      if (project.overallDefectRate != null) {
        totalDefectRate += project.overallDefectRate!;
        projectsWithDefectRate++;
      }
    }

    if (projectsWithDefectRate == 0) return 0.0;
    return totalDefectRate / projectsWithDefectRate;
  }

  Color _getPerformanceColor(double performance) {
    if (performance <= 5.0) return Colors.green;
    if (performance <= 20.0) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceLabel(double performance) {
    if (performance <= 5.0) return 'Excellent';
    if (performance <= 20.0) return 'Good';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    final overallLeaderPerformance = _calculateOverallLeaderPerformance();
    final hasLeaderProjects = _leaderProjects.isNotEmpty;

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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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

                  // Leader Performance Card (if applicable)
                  if (hasLeaderProjects) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: _getPerformanceColor(
                                    overallLeaderPerformance,
                                  ),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Team Leader Performance',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Defect Rate',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '${overallLeaderPerformance.toStringAsFixed(2)}%',
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: _getPerformanceColor(
                                                overallLeaderPerformance,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Chip(
                                            label: Text(
                                              _getPerformanceLabel(
                                                overallLeaderPerformance,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor:
                                                _getPerformanceColor(
                                                  overallLeaderPerformance,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.assignment,
                                        size: 28,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_leaderProjects.length}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        'Projects as Leader',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
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
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Projects Section
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _ProjectListSection(
                                    title: 'Current Projects',
                                    projects: _current,
                                    projectRoles: _projectRoles,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _ProjectListSection(
                                    title: 'Completed Projects',
                                    projects: _completed,
                                    projectRoles: _projectRoles,
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
                                  projectRoles: _projectRoles,
                                ),
                                const SizedBox(height: 24),
                                _ProjectListSection(
                                  title: 'Completed Projects',
                                  projects: _completed,
                                  projectRoles: _projectRoles,
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProjectListSection extends StatelessWidget {
  final String title;
  final List<Project> projects;
  final Map<String, List<String>> projectRoles;

  const _ProjectListSection({
    required this.title,
    required this.projects,
    required this.projectRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${projects.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No projects',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ...projects.map(
            (project) => _ProjectCard(
              project: project,
              roles: projectRoles[project.id] ?? [],
            ),
          ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<String> roles;

  const _ProjectCard({required this.project, required this.roles});

  Color _getDefectRateColor(double? rate) {
    if (rate == null) return Colors.grey.shade700;
    if (rate <= 5.0) return Colors.green.shade700;
    if (rate <= 20.0) return Colors.orange.shade700;
    return Colors.red.shade800;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(project.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    project.status,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: roles
                    .map(
                      (role) => Chip(
                        label: Text(role, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFEFF3F7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Started: ${project.started}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (project.overallDefectRate != null) ...[
                  const Icon(Icons.bug_report, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Defect Rate: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${project.overallDefectRate!.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getDefectRateColor(project.overallDefectRate),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'on hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
