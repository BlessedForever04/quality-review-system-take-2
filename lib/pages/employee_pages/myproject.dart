import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/auth_controller.dart';
import 'my_project_detail_page.dart';

class Myproject extends StatefulWidget {
  const Myproject({super.key});

  @override
  State<Myproject> createState() => _MyprojectState();
}

class _MyprojectState extends State<Myproject> {
  late final ProjectsController _ctrl;
  // Sorting & hover state (dashboard parity)
  String _sortKey = 'started';
  bool _ascending = false; // newest first
  int? _hoverIndex;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  // Cached visible projects to avoid flicker/disappear on hover state changes
  List<Project> _currentProjects = [];
  StreamSubscription? _projectsSub;
  // Stable snapshot to avoid transient empty flicker during hydration
  List<Project> _stableProjects = [];
  Timer? _debounceTimer;

  // Removed legacy caching fields (_cachedMyProjects, _lastUserId) no longer needed.

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<ProjectsController>()
        ? Get.find<ProjectsController>()
        : Get.put(ProjectsController());
    // Ensure search starts empty
    _searchQuery = '';
    _searchCtrl.text = '';

    // Refresh projects with assignments when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ctrl.refreshProjects();
      // Rebuild once after hydration
      if (mounted) {
        setState(() {
          _currentProjects = _visibleProjects();
        });
      }
      // Listen for project list changes (including assignment hydration) and recompute
      _projectsSub = _ctrl.projects.listen((_) {
        if (!mounted) return;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          final loading = _ctrl.isLoading.value;
          final next = _visibleProjects();
          final sourceHasData = _ctrl.projects.isNotEmpty;
          final transientEmpty =
              loading &&
              sourceHasData &&
              _stableProjects.isNotEmpty &&
              next.isEmpty;
          setState(() {
            if (transientEmpty) {
              _currentProjects = _stableProjects;
            } else {
              _currentProjects = next;
              _stableProjects = next;
            }
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _projectsSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _openProjectDetails(Project project) {
    Get.to(
      () => MyProjectDetailPage(
        project: project,
        description: project.description,
      ),
    );
  }

  // Active / assigned projects for authenticated user only
  List<Project> _myProjects() {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final userId = auth?.currentUser.value?.id?.trim();
    if (userId == null || userId.isEmpty) return const [];

    final matched = _ctrl.projects.where((p) {
      final assigned = p.assignedEmployees ?? const [];
      return assigned.any((e) => e.trim() == userId);
    }).toList();
    return matched;
  }

  Widget _debugBanner() {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final userId = auth?.currentUser.value?.id ?? 'null';
    final userName = auth?.currentUser.value?.name ?? 'null';
    final userEmail = auth?.currentUser.value?.email ?? 'null';
    final total = _ctrl.projects.length;
    final matched = _myProjects().length;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            'UserId: ' + userId,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          Text(
            'Name: ' + userName,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          Text(
            'Email: ' + userEmail,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          Text(
            'Projects: ' + matched.toString() + ' / ' + total.toString(),
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  List<Project> _visibleProjects() {
    List<Project> list = _myProjects();
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
      // Recompute projects only when sort changes, not on hover
      _currentProjects = _visibleProjects();
    });
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
                    'My Projects',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh projects',
                    onPressed: () => _ctrl.refreshProjects(),
                  ),
                ],
              ),
              // Lightweight debug banner to surface matching context
              _debugBanner(),
              const SizedBox(height: 12),
              // Search bar (same style as dashboard)
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
                    hintText: 'Search by title, status, priority, executor...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    final next = _visibleProjects();
                    _currentProjects = next;
                    _stableProjects =
                        next; // search defines a new stable subset
                  }),
                ),
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
                  child: Builder(
                    builder: (context) {
                      final projects = _stableProjects.isNotEmpty
                          ? _stableProjects
                          : (_currentProjects.isNotEmpty
                                ? _currentProjects
                                : _visibleProjects());
                      final auth = Get.isRegistered<AuthController>()
                          ? Get.find<AuthController>()
                          : null;
                      final userId = auth?.currentUser.value?.id?.trim();
                      if (projects.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No projects assigned to you',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[500]),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          // Debug: show per-project assignment contents and match status
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.blueGrey.shade100,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assignments Debug',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: Colors.blueGrey[700]),
                                ),
                                const SizedBox(height: 6),
                                ...projects.map((p) {
                                  final assigned =
                                      p.assignedEmployees ?? const [];
                                  final matches =
                                      userId != null &&
                                      assigned.any((e) => e.trim() == userId);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '[${matches ? '✓' : '×'}] ${p.title}: ' +
                                          assigned.join(', '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: matches
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          // Header row (sortable)
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
                                  flex: 1,
                                  child: _HeaderCell(
                                    label: 'Priority',
                                    active: _sortKey == 'priority',
                                    ascending: _ascending,
                                    onTap: () => _toggleSort('priority'),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
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
                                    label: 'Executor',
                                    active: _sortKey == 'executor',
                                    ascending: _ascending,
                                    onTap: () => _toggleSort('executor'),
                                  ),
                                ),
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
                              final hovered = _hoverIndex == index;
                              return MouseRegion(
                                onEnter: (_) {
                                  if (_hoverIndex != index) {
                                    setState(() => _hoverIndex = index);
                                  }
                                },
                                onExit: (_) {
                                  if (_hoverIndex != null) {
                                    setState(() => _hoverIndex = null);
                                  }
                                },
                                child: GestureDetector(
                                  onTap: () => _openProjectDetails(proj),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    curve: Curves.easeOut,
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
                                          flex: 3,
                                          child: Text(
                                            proj.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            // Keep title default color (remove blue styling)
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${proj.started.year}-${proj.started.month.toString().padLeft(2, '0')}-${proj.started.day.toString().padLeft(2, '0')}',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: _priorityChip(proj.priority),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(proj.status),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(proj.executor ?? '--'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
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
