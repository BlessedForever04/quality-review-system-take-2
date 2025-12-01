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
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'started';
  bool _ascending = false;
  int? _hoverIndex;
  List<Project> _cachedProjects = [];
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final ctrl = Get.find<ProjectsController>();
    await ctrl.refreshProjects();
    if (mounted) {
      setState(() {
        _cachedProjects = _computeMyProjects();
        _isInitialLoad = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Project> _computeMyProjects() {
    final projectsCtrl = Get.find<ProjectsController>();
    final authCtrl = Get.find<AuthController>();
    final userId = authCtrl.currentUser.value?.id;

    if (userId == null || userId.isEmpty) {
      return [];
    }

    final myProjects = projectsCtrl.projects.where((project) {
      final assigned = project.assignedEmployees ?? [];
      return assigned.contains(userId);
    }).toList();

    return myProjects;
  }

  List<Project> _getMyProjects() {
    List<Project> list = _cachedProjects;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.status.toLowerCase().contains(query) ||
            p.priority.toLowerCase().contains(query) ||
            (p.executor ?? '').toLowerCase().contains(query);
      }).toList();
    }

    list.sort((a, b) {
      int result = 0;
      switch (_sortKey) {
        case 'title':
          result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'started':
          result = a.started.compareTo(b.started);
          break;
        case 'priority':
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          result = (order[a.priority] ?? 9).compareTo(order[b.priority] ?? 9);
          break;
        case 'status':
          result = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'executor':
          result = (a.executor ?? '').toLowerCase().compareTo(
            (b.executor ?? '').toLowerCase(),
          );
          break;
      }
      return _ascending ? result : -result;
    });

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

  Widget _priorityChip(String priority) {
    Color bg = const Color(0xFFEFF3F7);
    if (priority == 'High') bg = const Color(0xFFFBEFEF);
    if (priority == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(priority, style: const TextStyle(fontSize: 12)),
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
                    onPressed: _loadProjects,
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              _isInitialLoad
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final projects = _getMyProjects();

                        if (projects.isEmpty) {
                          return Container(
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

                        return Container(
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
                            child: Column(
                              children: [
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
                                    final project = projects[index];
                                    final hovered = _hoverIndex == index;

                                    return MouseRegion(
                                      onEnter: (_) =>
                                          setState(() => _hoverIndex = index),
                                      onExit: (_) =>
                                          setState(() => _hoverIndex = null),
                                      child: GestureDetector(
                                        onTap: () => Get.to(
                                          () => MyProjectDetailPage(
                                            project: project,
                                          ),
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          curve: Curves.easeOut,
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hovered
                                                ? const Color(0xFFF7F9FC)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                                  project.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${project.started.year}-${project.started.month.toString().padLeft(2, '0')}-${project.started.day.toString().padLeft(2, '0')}',
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: _priorityChip(
                                                  project.priority,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(project.status),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  project.executor ?? '--',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
