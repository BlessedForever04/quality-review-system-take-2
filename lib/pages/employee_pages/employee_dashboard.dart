import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/employee_project_detail_page.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/export_controller.dart';
import '../../components/project_statistics_card.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<EmployeeDashboard> {
  late final ProjectsController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'started';
  bool _ascending = false; // default: newest first
  final Set<String> _selectedStatuses = {}; // Start with no filters selected

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ProjectsController>();
    // Projects are automatically loaded via real-time stream in ProjectsController
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Project> get _visibleProjects {
    List<Project> list = _ctrl.projects.toList();

    // Apply status filter (empty means show all)
    if (_selectedStatuses.isNotEmpty) {
      list = list.where((p) => _selectedStatuses.contains(p.status)).toList();
    } // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final exec = p.executor ?? '';
        return p.title.toLowerCase().contains(q) ||
            p.status.toLowerCase().contains(q) ||
            p.priority.toLowerCase().contains(q) ||
            exec.toLowerCase().contains(q);
      }).toList();
    }
    int cmp(Project a, Project b) {
      int res = 0;
      switch (_sortKey) {
        case 'title':
          res = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'started':
          res = a.started.compareTo(b.started);
          break;
        case 'priority':
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          res = (order[a.priority] ?? 9).compareTo(order[b.priority] ?? 9);
          break;
        case 'status':
          res = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'executor':
          res = (a.executor ?? '').toLowerCase().compareTo(
            (b.executor ?? '').toLowerCase(),
          );
          break;
      }
      return _ascending ? res : -res;
    }

    list.sort(cmp);
    return list;
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = true;
      }
    });
  }

  Widget _buildFilterChip(String status) {
    final isSelected = _selectedStatuses.contains(status);
    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedStatuses.add(status);
          } else {
            _selectedStatuses.remove(status);
          }
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[800],
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[900] : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
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
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Project Statistics
              const ProjectStatisticsCard(),
              const SizedBox(height: 16),
              // Search bar
              Container(
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
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText:
                        'Search by title, status, priority, created by...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 16),
              // Status filter chips and Export button
              Row(
                children: [
                  const Text(
                    'Filter by Status:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip('Not Started'),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed'),
                  const Spacer(),
                  // Export Master Excel Button
                  Obx(() {
                    final exportCtrl = Get.find<ExportController>();
                    return ElevatedButton.icon(
                      onPressed: exportCtrl.isExporting.value
                          ? null
                          : () async {
                              await exportCtrl.exportMasterExcel();
                            },
                      icon: exportCtrl.isExporting.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        exportCtrl.isExporting.value
                            ? 'Exporting...'
                            : 'Export Master Excel',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  if (_selectedStatuses.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedStatuses.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Tabular layout using ListView + Rows
              Obx(() {
                final projects = _visibleProjects;
                return Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: const Text(
                              'Project No.',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _HeaderCell(
                              label: 'Project Title',
                              active: _sortKey == 'title',
                              ascending: _ascending,
                              onTap: () => _toggleSort('title'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Started',
                              active: _sortKey == 'started',
                              ascending: _ascending,
                              onTap: () => _toggleSort('started'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Priority',
                              active: _sortKey == 'priority',
                              ascending: _ascending,
                              onTap: () => _toggleSort('priority'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Status',
                              active: _sortKey == 'status',
                              ascending: _ascending,
                              onTap: () => _toggleSort('status'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Created By',
                              active: _sortKey == 'executor',
                              ascending: _ascending,
                              onTap: () => _toggleSort('executor'),
                            ),
                          ),
                          // Actions column removed (moved to details page)
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final proj = projects[index];
                        return _EmployeeProjectCard(project: proj);
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Description now lives on Project model; no temp store needed.
}

class _EmployeeProjectCard extends StatefulWidget {
  final Project project;

  const _EmployeeProjectCard({required this.project});

  @override
  State<_EmployeeProjectCard> createState() => _EmployeeProjectCardState();
}

class _EmployeeProjectCardState extends State<_EmployeeProjectCard> {
  bool _isHovered = false;

  Widget _priorityChip(String p) {
    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(p, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final executor =
        (widget.project.status == 'In Progress' ||
            widget.project.status == 'Completed')
        ? ((widget.project.executor?.trim().isNotEmpty ?? false)
              ? widget.project.executor!.trim()
              : '--')
        : '--';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => Get.to(
          () => EmployeeProjectDetailPage(
            project: widget.project,
            description: widget.project.description,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF7F9FC) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? Colors.blue.shade300 : Colors.grey.shade300,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.blue.shade100.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -2.0))
              : Matrix4.identity(),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  (widget.project.projectNo?.trim().isNotEmpty ?? false)
                      ? widget.project.projectNo!.trim()
                      : '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  widget.project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${widget.project.started.year}-${widget.project.started.month.toString().padLeft(2, '0')}-${widget.project.started.day.toString().padLeft(2, '0')}',
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _priorityChip(widget.project.priority),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text((widget.project.status).toString()),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(executor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectFormData {
  String title;
  DateTime started;
  String priority;
  String status;
  String? executor;
  String description;
  ProjectFormData({
    required this.title,
    required this.started,
    required this.priority,
    required this.status,
    required this.executor,
    required this.description,
  });
}

class _ProjectFormDialog extends StatefulWidget {
  final String title;
  final void Function(ProjectFormData data) onSubmit;

  const _ProjectFormDialog({required this.title, required this.onSubmit});

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ProjectFormData data;

  @override
  void initState() {
    super.initState();
    data = ProjectFormData(
      title: '',
      started: DateTime.now(),
      priority: 'Medium',
      status: 'Not Started',
      executor: '',
      description: '',
    );
  }

  String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 520,
        height: 600,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Always single column layout. Place Description at the top.
                    final List<Widget> fields = [
                      // Large description area at top
                      // Description

                      // Title
                      TextFormField(
                        initialValue: data.title,
                        decoration: const InputDecoration(
                          labelText: 'Project Title *',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter title';
                          }
                          return null;
                        },
                        onSaved: (v) => data.title = v!.trim(),
                      ),
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: data.started,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => data.started = picked);
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Started Date *',
                            ),
                            controller: TextEditingController(
                              text: _dateString(data.started),
                            ),
                          ),
                        ),
                      ),
                      // Priority
                      DropdownButtonFormField<String>(
                        initialValue: data.priority,
                        items: ['High', 'Medium', 'Low']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => data.priority = v ?? data.priority),
                        decoration: const InputDecoration(
                          labelText: 'Priority *',
                        ),
                      ),
                    ];
                    fields.add(
                      DropdownButtonFormField<String>(
                        initialValue: data.status,
                        items: ['In Progress', 'Completed', 'Not Started']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => data.status = v ?? data.status),
                        decoration: const InputDecoration(
                          labelText: 'Status *',
                        ),
                      ),
                    );
                    fields.add(
                      DropdownButtonFormField<String>(
                        initialValue: (data.executor?.isEmpty ?? true)
                            ? null
                            : data.executor,
                        items:
                            (Get.isRegistered<TeamController>()
                                    ? Get.find<TeamController>().members
                                          .map((m) => m.name.trim())
                                          .where((n) => n.isNotEmpty)
                                          .toSet()
                                          .toList()
                                    : const <String>[])
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text(n),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) =>
                            setState(() => data.executor = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Executor (optional)',
                        ),
                      ),
                    );

                    return Column(
                      children: [
                        for (int i = 0; i < fields.length; i++) ...[
                          fields[i],
                          if (i != fields.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
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
                  initialValue: data.description,
                  minLines: 10,
                  maxLines: 16,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Enter description...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter description'
                      : null,
                  onSaved: (v) => data.description = v!.trim(),
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
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          _formKey.currentState?.save();
                          widget.onSubmit(data);
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  const _HeaderCell({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active
        ? (ascending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded)
        : Icons.unfold_more_rounded;
    final color = active ? Colors.blueGrey[800] : Colors.blueGrey[600];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }
}
