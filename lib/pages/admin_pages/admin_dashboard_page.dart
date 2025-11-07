import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../controllers/projects_controller.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final ProjectsController _ctrl;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProjectsController());

    if (_ctrl.projects.isEmpty) {
      _ctrl.loadInitial([
        Project(id: 'p1', title: 'Implement New CRM System', started: DateTime(2024, 6, 1), priority: 'High', status: 'In Progress', executor: 'Emily Carter'),
        Project(id: 'p2', title: 'Develop Marketing Strategy', started: DateTime(2024, 5, 20), priority: 'Medium', status: 'Completed', executor: 'David Lee'),
        Project(id: 'p3', title: 'Conduct Market Research', started: DateTime(2024, 6, 10), priority: 'Low', status: 'Not Started', executor: null),
        Project(id: 'p4', title: 'Build Analytics Dashboard', started: DateTime(2024, 5, 5), priority: 'High', status: 'In Progress', executor: 'Sophia Clark'),
      ]);
    }
  }

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
                  decoration: const InputDecoration(labelText: 'Project Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                  onSaved: (v) => title = v!.trim(),
                ),
                // Date picker field
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(text: '${started.year}-${started.month.toString().padLeft(2,'0')}-${started.day.toString().padLeft(2,'0')}'),
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
                      // trigger a rebuild of the dialog content
                      (context as Element).markNeedsBuild();
                    }
                  },
                  validator: null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => priority = v ?? priority,
                  decoration: const InputDecoration(labelText: 'Priority *'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['In Progress', 'Completed', 'Not Started'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                ),
                // Executor dropdown populated from team members
                DropdownButtonFormField<String>(
                  initialValue: executor,
                  items: _teamNames().map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => executor = v,
                  decoration: const InputDecoration(labelText: 'Executor (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
                    executor: (executor == null || executor?.isEmpty == true) ? null : executor,
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
      'Isabella King'
    ];
  }

  Widget _priorityChip(String p) {
    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(label: Text(p, style: const TextStyle(fontSize: 12)), backgroundColor: bg);
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
                  Text('Welcome Back!', style: Theme.of(context).textTheme.headlineMedium),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Project'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(() {
                      final projects = _ctrl.projects;
                      return DataTable(
                        sortAscending: _sortAscending,
                        sortColumnIndex: _sortColumnIndex,
                        columnSpacing: 90,
                        columns: [
                          DataColumn(
                            label: const Text('Project Title'),
                            onSort: (colIndex, asc) {
                              setState(() {
                                _sortColumnIndex = colIndex;
                                _sortAscending = asc;
                                _ctrl.projects.sort((a, b) => asc ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
                              });
                            },
                          ),
                          DataColumn(
                            label: const Text('Started Date'),
                            onSort: (colIndex, asc) {
                              setState(() {
                                _sortColumnIndex = colIndex;
                                _sortAscending = asc;
                                _ctrl.projects.sort((a, b) => asc ? a.started.compareTo(b.started) : b.started.compareTo(a.started));
                              });
                            },
                          ),
                          const DataColumn(label: Text('Priority')),
                          const DataColumn(label: Text('Status')),
                          const DataColumn(label: Text('Executor')),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: projects.map((proj) {
                          final executor = (proj.status == 'In Progress' || proj.status == 'Completed') ? (proj.executor ?? '--') : '--';
                          return DataRow(cells: [
                            DataCell(Container(constraints: const BoxConstraints(maxWidth: 300), child: Text(proj.title))),
                            DataCell(Text('${proj.started.year}-${proj.started.month.toString().padLeft(2, '0')}-${proj.started.day.toString().padLeft(2, '0')}')),
                            DataCell(_priorityChip(proj.priority)),
                            DataCell(Text(proj.status)),
                            DataCell(Text(executor)),
                            DataCell(Row(children: [
                              IconButton(onPressed: () => _showEditDialog(proj), icon: const Icon(Icons.edit, size: 20)),
                              IconButton(onPressed: () => _confirmDelete(proj), icon: const Icon(Icons.delete_outline, size: 20)),
                            ])),
                          ]);
                        }).toList(),
                      );
                    }),
                  ),
                ),
              ),
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
        return  Container(
              width: 400,
              height: 400,
              color: Colors.black12,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: title,
                    decoration: const InputDecoration(labelText: 'Project Title *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                    onSaved: (v) => title = v!.trim(),
                  ),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(text: '${started.year}-${started.month.toString().padLeft(2,'0')}-${started.day.toString().padLeft(2,'0')}'),
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
                    items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => priority = v ?? priority,
                    decoration: const InputDecoration(labelText: 'Priority *'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: ['In Progress', 'Completed', 'Not Started'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => status = v ?? status,
                    decoration: const InputDecoration(labelText: 'Status *'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: executor,
                    items: _teamNames().map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                    onChanged: (v) => executor = v,
                    decoration: const InputDecoration(labelText: 'Executor (optional)'),
                  ),
                
             
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    formKey.currentState?.save();
                    final updated = project.copyWith(
                      title: title,
                      started: started,
                      priority: priority,
                      status: status,
                      executor: (executor == null || executor?.isEmpty == true) ? null : executor,
                    );
                    _ctrl.updateProject(project.id, updated);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
                ]
        )
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      _ctrl.deleteProject(project.id);
    }
  }
}