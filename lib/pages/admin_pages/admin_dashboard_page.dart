import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/admin_dashboard_ui_controller.dart';
import '../../controllers/export_controller.dart';
import '../../components/admin_dialog.dart';
import 'admin_project_details_page.dart';
import '../../controllers/team_controller.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/excel_import_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int? _hoverIndex;

  List<Project> _visibleProjects(
    List<Project> source,
    String search,
    String sortKey,
    bool ascending,
    Set<String> statusFilter,
  ) {
    List<Project> list = source.toList();

    // Apply status filter (empty means show all)
    if (statusFilter.isNotEmpty) {
      list = list.where((p) => statusFilter.contains(p.status)).toList();
    }

    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      list = list.where((p) {
        // Removed executor from search filter per requirement
        return p.title.toLowerCase().contains(q) ||
            p.status.toLowerCase().contains(q) ||
            p.priority.toLowerCase().contains(q);
      }).toList();
    }
    int cmp(Project a, Project b) {
      int res = 0;
      switch (sortKey) {
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
        // Executor sort removed
      }
      return ascending ? res : -res;
    }

    list.sort(cmp);
    return list;
  }

  void _ensureSeed(ProjectsController ctrl) {}

  Widget _buildFilterChip(AdminDashboardUIController ui, String status) {
    final isSelected = ui.selectedStatuses.contains(status);
    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        ui.toggleStatus(status);
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

  @override
  Widget build(BuildContext context) {
    final projCtrl = Get.find<ProjectsController>();
    final ui = Get.find<AdminDashboardUIController>();
    _ensureSeed(projCtrl);

    final teamCtrl = Get.isRegistered<TeamController>()
        ? Get.find<TeamController>()
        : null;
    List<String> executors() =>
        teamCtrl == null
              ? const []
              : teamCtrl.members
                    .map((m) => m.name.trim())
                    .where((n) => n.isNotEmpty)
                    .toSet()
                    .toList()
          ..sort();

    Future<void> showCreateDialog() async {
      await showAdminDialog(
        context,
        title: 'Create New Project',
        width: 1000,
        child: _ProjectFormDialog(
          executors: executors(),
          titleValidator: (t) {
            final exists = projCtrl.projects.any(
              (p) => p.title.toLowerCase() == t.toLowerCase(),
            );
            return exists ? 'A project with this title already exists' : null;
          },
          width: 1000,
          showStatus: false,
          showExecutor: false,
          onSubmit: (data) async {
            try {
              final newProject = Project(
                id: '',
                projectNo: data.projectNo,
                internalOrderNo: data.internalOrderNo,
                title: data.title,
                description: data.description,
                started: data.started,
                priority: data.priority,
                status: 'Not Started',
                executor: null,
              );
              await projCtrl.createProjectRemote(newProject);
              if (context.mounted) {
                Get.snackbar(
                  'Success',
                  'Project created successfully',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            } catch (e) {
              if (context.mounted) {
                Get.snackbar(
                  'Error',
                  'Error: ${e.toString()}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            }
          },
        ),
      );
    }

    // ...

    Widget priorityChip(String p) {
      Color bg = const Color(0xFFEFF3F7);
      if (p == 'High') bg = const Color(0xFFFBEFEF);
      if (p == 'Low') bg = const Color(0xFFF5F7FA);
      return Chip(
        label: Text(p, style: const TextStyle(fontSize: 12)),
        backgroundColor: bg,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['xlsx', 'xlsm', 'xls'],
                        withData: true,
                      );
                      if (res == null || res.files.isEmpty) return;
                      final bytes = res.files.first.bytes;
                      if (bytes == null) return;
                      final importer = ExcelImportService();
                      final projects = importer.parse(bytes);

                      // Build existing uniqueness index: projectNo, internalOrderNo, title
                      final existingKeys = <String>{};
                      String norm(String s) => s.trim().toLowerCase();
                      void addKeys(Project p) {
                        final t = norm(p.title);
                        if (t.isNotEmpty) existingKeys.add('title:$t');
                        final pn = (p.projectNo ?? '').trim();
                        if (pn.isNotEmpty) existingKeys.add('no:${norm(pn)}');
                        final io = (p.internalOrderNo ?? '').trim();
                        if (io.isNotEmpty) existingKeys.add('io:${norm(io)}');
                      }

                      for (final p in projCtrl.projects) {
                        addKeys(p);
                      }

                      // Track duplicates within the same import batch as well
                      final seenImportKeys = <String>{};
                      int imported = 0;
                      int skipped = 0;

                      for (final p in projects) {
                        final keys = <String>{};
                        final t = norm(p.title);
                        if (t.isNotEmpty) keys.add('title:$t');
                        final pn = (p.projectNo ?? '').trim();
                        if (pn.isNotEmpty) keys.add('no:${norm(pn)}');
                        final io = (p.internalOrderNo ?? '').trim();
                        if (io.isNotEmpty) keys.add('io:${norm(io)}');

                        final isDup = keys.any(
                          (k) =>
                              existingKeys.contains(k) ||
                              seenImportKeys.contains(k),
                        );
                        if (isDup) {
                          skipped++;
                          continue;
                        }
                        try {
                          await projCtrl.createProjectRemote(p);
                          imported++;
                          seenImportKeys.addAll(keys);
                        } catch (e) {
                          // ignore per-item errors but don't count as imported
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported $imported, skipped $skipped duplicate(s).',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Import from Excel'),
                  ),
                  const SizedBox(width: 12),

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
                ],
              ),
              const SizedBox(height: 12),
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
                  decoration: const InputDecoration(
                    hintText: 'Search by title, status, priority...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: ui.setSearch,
                ),
              ),
              const SizedBox(height: 16),
              // Status filter chips
              Obx(
                () => Row(
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
                    _buildFilterChip(ui, 'Not Started'),
                    const SizedBox(width: 8),
                    _buildFilterChip(ui, 'In Progress'),
                    const SizedBox(width: 8),
                    _buildFilterChip(ui, 'Completed'),
                    const Spacer(),
                    if (ui.selectedStatuses.isNotEmpty)
                      TextButton.icon(
                        onPressed: ui.clearFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Loading / Error states (reactive)
              Obx(() {
                if (projCtrl.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final err = projCtrl.errorMessage.value;
                if (err.isNotEmpty) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F3),
                      border: Border.all(color: const Color(0xFFFFC8C8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              // Tabular layout using ListView + Rows
              Obx(() {
                // Access reactive sources to make this builder reactive
                final rxProjects = projCtrl.projects;
                final search = ui.searchQuery.value;
                final sortKey = ui.sortKey.value;
                final asc = ui.ascending.value;
                final statusFilter = ui.selectedStatuses.toSet();
                final projects = _visibleProjects(
                  rxProjects,
                  search,
                  sortKey,
                  asc,
                  statusFilter,
                );
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
                              active: sortKey == 'title',
                              ascending: asc,
                              onTap: () => ui.toggleSort('title'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Started',
                              active: sortKey == 'started',
                              ascending: asc,
                              onTap: () => ui.toggleSort('started'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Priority',
                              active: sortKey == 'priority',
                              ascending: asc,
                              onTap: () => ui.toggleSort('priority'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Status',
                              active: sortKey == 'status',
                              ascending: asc,
                              onTap: () => ui.toggleSort('status'),
                            ),
                          ),
                          // Executor column removed per requirement
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
                        // Executor value removed per requirement
                        final hovered = _hoverIndex == index;
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoverIndex = index),
                          onExit: (_) => setState(() => _hoverIndex = null),
                          child: GestureDetector(
                            onTap: () => Get.to(
                              () => AdminProjectDetailsPage(
                                project: proj,
                                descriptionOverride: proj.description,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: hovered
                                    ? const Color(0xFFF7F9FC)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hovered
                                      ? Colors.blue.shade200
                                      : Colors.black12,
                                ),
                                boxShadow: hovered
                                    ? const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (proj.projectNo?.trim().isNotEmpty ??
                                              false)
                                          ? proj.projectNo!.trim()
                                          : '--',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      proj.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${proj.started.year}-${proj.started.month.toString().padLeft(2, '0')}-${proj.started.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: priorityChip(proj.priority),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text((proj.status).toString()),
                                    ),
                                  ),
                                  // Executor cell removed
                                  // Edit/Delete removed from dashboard; now only in details page.
                                ],
                              ),
                            ),
                          ),
                        );
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

class ProjectFormData {
  String? projectNo;
  String? internalOrderNo;
  String title;
  DateTime started;
  String priority;
  String status;
  String? executor;
  String description;
  ProjectFormData({
    this.projectNo,
    this.internalOrderNo,
    required this.title,
    required this.started,
    required this.priority,
    required this.status,
    required this.executor,
    required this.description,
  });
}

class _ProjectFormDialog extends StatefulWidget {
  final void Function(ProjectFormData data) onSubmit;
  final List<String>? executors;
  final String? Function(String)? titleValidator;
  final double? width;
  final bool showStatus;
  final bool showExecutor;
  const _ProjectFormDialog({
    required this.onSubmit,
    this.executors,
    this.titleValidator,
    this.width,
    this.showStatus = true,
    this.showExecutor = true,
  });

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
      projectNo: '',
      internalOrderNo: '',
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
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Always single column layout. Place Description at the top.
                final List<Widget> fields = [
                  // Large description area at top
                  // Description

                  // Project No.
                  TextFormField(
                    initialValue: data.projectNo,
                    decoration: const InputDecoration(labelText: 'Project No.'),
                    onSaved: (v) => data.projectNo = v?.trim(),
                  ),
                  // Internal Order No.
                  TextFormField(
                    initialValue: data.internalOrderNo,
                    decoration: const InputDecoration(
                      labelText: 'Project / Internal Order No.',
                    ),
                    onSaved: (v) => data.internalOrderNo = v?.trim(),
                  ),
                  // Title
                  TextFormField(
                    initialValue: data.title,
                    decoration: const InputDecoration(
                      labelText: 'Project Title *',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter title';
                      if (widget.titleValidator != null) {
                        return widget.titleValidator!(v.trim());
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
                      if (picked != null) setState(() => data.started = picked);
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
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => data.priority = v ?? data.priority),
                    decoration: const InputDecoration(labelText: 'Priority *'),
                  ),
                ];
                if (widget.showStatus) {
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
                      decoration: const InputDecoration(labelText: 'Status *'),
                    ),
                  );
                }
                if (widget.showExecutor) {
                  fields.add(
                    DropdownButtonFormField<String>(
                      initialValue: (data.executor?.isEmpty ?? true)
                          ? null
                          : data.executor,
                      items: (widget.executors ?? const [])
                          .map(
                            (n) => DropdownMenuItem(value: n, child: Text(n)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => data.executor = v ?? ''),
                      decoration: const InputDecoration(
                        labelText: 'Executor (optional)',
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1) const SizedBox(height: 12),
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter description' : null,
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
