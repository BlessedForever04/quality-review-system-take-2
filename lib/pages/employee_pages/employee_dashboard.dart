import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../controllers/projects_controller.dart';

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  late final ProjectsController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProjectsController());

    if (_ctrl.projects.isEmpty) {
      _ctrl.loadInitial([
        Project(
          id: 'p1',
          title: 'Implement New CRM System',
          description:
              'Develop and implement a comprehensive Customer Relationship Management system to streamline sales and customer support processes.',
          started: DateTime(2024, 6, 1),
          priority: 'High',
          status: 'In Progress',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'David Lee', 'Sophia Clark'],
        ),
        Project(
          id: 'p2',
          title: 'Develop Marketing Strategy',
          description:
              'Create a comprehensive marketing strategy for Q3 2024 including social media, content marketing, and paid advertising campaigns.',
          started: DateTime(2024, 5, 20),
          priority: 'Medium',
          status: 'Completed',
          executor: 'David Lee',
          assignedEmployees: ['David Lee', 'Liam Walker', 'Noah Clark'],
        ),
        Project(
          id: 'p3',
          title: 'Conduct Market Research',
          description:
              'Perform detailed market research to identify new opportunities and understand customer needs in emerging markets.',
          started: DateTime(2024, 6, 10),
          priority: 'Low',
          status: 'Not Started',
          assignedEmployees: ['Emily Carter', 'Olivia Harris'],
        ),
        Project(
          id: 'p4',
          title: 'Build Analytics Dashboard',
          description:
              'Design and develop a real-time analytics dashboard for tracking key business metrics and KPIs.',
          started: DateTime(2024, 5, 5),
          priority: 'High',
          status: 'In Progress',
          executor: 'Sophia Clark',
          assignedEmployees: ['Sophia Clark', 'James Wright'],
        ),
      ]);
    }
  }

  // Mock data: Current logged-in user
  final String currentUser = 'Emily Carter';

  Future<void> _showCreateDialog() async {
    final formKey = GlobalKey<FormState>();
    String title = '';
    DateTime started = DateTime.now();
    String priority = 'Medium';
    String status = 'Not Started';
    String? executor;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Project'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Project Title *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                  onSaved: (v) => title = v!.trim(),
                ),
                // Date picker field
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text:
                        '${started.year}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')}',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Started Date *',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: started,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      started = picked;
                      // trigger a rebuild of the dialog content
                      (context as Element).markNeedsBuild();
                    }
                  },
                  validator: null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: ['High', 'Medium', 'Low']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => priority = v ?? priority,
                  decoration: const InputDecoration(labelText: 'Priority *'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['In Progress', 'Completed', 'Not Started']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                ),
                // Executor dropdown populated from team members
                DropdownButtonFormField<String>(
                  initialValue: executor,
                  items: _teamNames()
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => executor = v,
                  decoration: const InputDecoration(
                    labelText: 'Executor (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  final newProject = Project(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    started: started,
                    priority: priority,
                    status: status,
                    executor: (executor == null || executor?.isEmpty == true)
                        ? null
                        : executor,
                  );
                  _ctrl.addProject(newProject);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Helper: read team names from team page initial data (light coupling)
  List<String> _teamNames() {
    return const [
      'Emma Carter',
      'Liam Walker',
      'Olivia Harris',
      'Noah Clark',
      'Ava Lewis',
      'William Hall',
      'Sophia Young',
      'James Wright',
      'Isabella King',
    ];
  }

  Widget _priorityChip(String p) {
    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(p, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
    );
  }

  Widget _statusChip(String status) {
    Color bg = const Color(0xFFEFF3F7);
    Color textColor = Colors.black87;

    if (status == 'In Progress') {
      bg = const Color(0xFFE3F2FD);
      textColor = Colors.blue[900]!;
    } else if (status == 'Completed') {
      bg = const Color(0xFFE8F5E9);
      textColor = Colors.green[900]!;
    } else if (status == 'Not Started') {
      bg = const Color(0xFFFFF3E0);
      textColor = Colors.orange[900]!;
    }

    return Chip(
      label: Text(status, style: TextStyle(fontSize: 12, color: textColor)),
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Obx(() {
                final projects = _ctrl.projects;

                if (projects.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'No projects available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final proj = projects[index];
                    final executor =
                        (proj.status == 'In Progress' ||
                            proj.status == 'Completed')
                        ? (proj.executor ?? 'Unassigned')
                        : 'Not assigned';
                    final isNotStarted = proj.status == 'Not Started';
                    final isAssignedToUser =
                        proj.assignedEmployees?.contains(currentUser) ?? false;
                    final canStart = isNotStarted && isAssignedToUser;

                    return GestureDetector(
                      onTap: () => _showProjectDetails(proj, canStart),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      proj.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  _priorityChip(proj.priority),
                                  const SizedBox(width: 8),
                                  _statusChip(proj.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Started: ${proj.started.day}/${proj.started.month}/${proj.started.year}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Executor: $executor',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                canStart
                                    ? 'Click to view details and start project'
                                    : 'Click to view project details',
                                style: TextStyle(
                                  color: canStart
                                      ? Colors.blue[700]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showEditDialog(proj),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _confirmDelete(proj),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Project project) async {
    final formKey = GlobalKey<FormState>();
    String title = project.title;
    DateTime started = project.started;
    String priority = project.priority;
    String status = project.status;
    String? executor = project.executor;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Container(
          width: 400,
          height: 400,
          child: Column(
            children: [
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(labelText: 'Project Title *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                onSaved: (v) => title = v!.trim(),
              ),
              TextFormField(
                readOnly: true,
                controller: TextEditingController(
                  text:
                      '${started.year}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')}',
                ),
                decoration: const InputDecoration(labelText: 'Started Date *'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: started,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    started = picked;
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: priority,
                items: ['High', 'Medium', 'Low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => priority = v ?? priority,
                decoration: const InputDecoration(labelText: 'Priority *'),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: ['In Progress', 'Completed', 'Not Started']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => status = v ?? status,
                decoration: const InputDecoration(labelText: 'Status *'),
              ),
              DropdownButtonFormField<String>(
                initialValue: executor,
                items: _teamNames()
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => executor = v,
                decoration: const InputDecoration(
                  labelText: 'Executor (optional)',
                ),
              ),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    formKey.currentState?.save();
                    final updated = project.copyWith(
                      title: title,
                      started: started,
                      priority: priority,
                      status: status,
                      executor: (executor == null || executor?.isEmpty == true)
                          ? null
                          : executor,
                    );
                    _ctrl.updateProject(project.id, updated);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _ctrl.deleteProject(project.id);
    }
  }

  void _showProjectDetails(Project project, bool canStart) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _priorityChip(project.priority),
                    const SizedBox(width: 8),
                    _statusChip(project.status),
                  ],
                ),
                const SizedBox(height: 24),

                // Description Section
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  project.description ?? 'No description available',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),

                // Start Date Section
                Text(
                  'Scheduled Start Date',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${project.started.day}/${project.started.month}/${project.started.year}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Executor Section (if exists)
                if (project.executor != null) ...[
                  Text(
                    'Current Executor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        project.executor!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Assigned Employees Section
                Text(
                  'Assigned Team Members',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (project.assignedEmployees?.isEmpty ?? true)
                  Text(
                    'No team members assigned',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: project.assignedEmployees!.map((employee) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            employee[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        label: Text(employee),
                        backgroundColor: Colors.grey[100],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 32),

                // Start Project Button (only if canStart is true)
                if (canStart)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startProject(project),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Project'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startProject(Project project) {
    // Update project status to "In Progress" and set executor to current user
    final updatedProject = project.copyWith(
      status: 'In Progress',
      executor: currentUser,
    );

    _ctrl.updateProject(project.id, updatedProject);

    // Close the dialog
    Navigator.of(context).pop();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project "${project.title}" has been started!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
