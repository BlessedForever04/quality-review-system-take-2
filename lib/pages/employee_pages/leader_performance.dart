import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/auth_controller.dart';
import 'my_project_detail_page.dart';

class LeaderPerformance extends StatefulWidget {
  const LeaderPerformance({super.key});

  @override
  State<LeaderPerformance> createState() => _LeaderPerformanceState();
}

class _LeaderPerformanceState extends State<LeaderPerformance> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'defectRate';
  bool _ascending = false;
  List<Project> _cachedProjects = [];
  bool _isInitialLoad = true;
  final Set<String> _selectedStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      final ctrl = Get.find<ProjectsController>();
      final authCtrl = Get.find<AuthController>();
      final userId = authCtrl.currentUser.value?.id;

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _cachedProjects = [];
            _isInitialLoad = false;
          });
        }
        return;
      }

      // Load projects if needed
      if (_isInitialLoad || forceRefresh) {
        print('[LeaderPerformance] Loading projects for team leader $userId');
        await ctrl.loadUserProjects(userId);
      }

      if (!mounted) return;

      // Debug: Log all projects and their userRole
      print(
        '[LeaderPerformance] Total projects loaded: ${ctrl.projects.length}',
      );
      for (final p in ctrl.projects) {
        print('[LeaderPerformance]   - ${p.title} (userRole: ${p.userRole})');
      }

      // Filter projects where this user is the team leader
      final leaderProjects = ctrl.byTeamLeaderId(userId);

      print(
        '[LeaderPerformance] Found ${leaderProjects.length} projects where user is team leader',
      );
      for (final p in leaderProjects) {
        print('[LeaderPerformance]   - ${p.title} (userRole: ${p.userRole})');
      }

      if (mounted) {
        setState(() {
          _cachedProjects = leaderProjects;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      print('[LeaderPerformance] Error loading projects: $e');
      if (mounted) {
        setState(() {
          _cachedProjects = [];
          _isInitialLoad = false;
        });

        Get.snackbar(
          'Error',
          'Failed to load projects: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _calculateOverallPerformance() {
    if (_cachedProjects.isEmpty) return 0.0;

    double totalDefectRate = 0.0;
    int projectsWithDefectRate = 0;

    for (final project in _cachedProjects) {
      if (project.overallDefectRate != null) {
        totalDefectRate += project.overallDefectRate!;
        projectsWithDefectRate++;
      }
    }

    if (projectsWithDefectRate == 0) return 0.0;
    return totalDefectRate / projectsWithDefectRate;
  }

  List<Project> _getFilteredProjects() {
    List<Project> list = _cachedProjects;

    // Apply status filter
    if (_selectedStatuses.isNotEmpty) {
      list = list.where((p) => _selectedStatuses.contains(p.status)).toList();
    }

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.status.toLowerCase().contains(query) ||
            (p.projectNo ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting by defect rate
    list.sort((a, b) {
      final aRate = a.overallDefectRate ?? 0.0;
      final bRate = b.overallDefectRate ?? 0.0;
      final result = aRate.compareTo(bRate);
      return _ascending ? result : -result;
    });

    return list;
  }

  void _toggleSort() {
    setState(() {
      _ascending = !_ascending;
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
    final overallPerformance = _calculateOverallPerformance();
    final performanceColor = _getPerformanceColor(overallPerformance);
    final performanceLabel = _getPerformanceLabel(overallPerformance);

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
                    'Leader Performance',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh projects',
                    onPressed: () => _loadProjects(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Overall Performance Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      performanceColor.withOpacity(0.1),
                      performanceColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: performanceColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: performanceColor.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_graph,
                          color: performanceColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Overall Performance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${overallPerformance.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: performanceColor,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            performanceLabel,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: performanceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Average Defect Rate across ${_cachedProjects.length} project${_cachedProjects.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search Bar
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
                    hintText: 'Search by title, status, project no...',
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

              // Status Filter Chips
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

              // Projects Table
              _isInitialLoad
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final projects = _getFilteredProjects();

                        if (_cachedProjects.isEmpty) {
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
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No projects where you are team leader',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

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
                                'No projects match your filters',
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
                                // Table Header
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
                                        child: const Text(
                                          'Project Title',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blueGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: const Text(
                                          'Started',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blueGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: const Text(
                                          'Status',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blueGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: InkWell(
                                          onTap: _toggleSort,
                                          child: Row(
                                            children: [
                                              const Flexible(
                                                child: Text(
                                                  'Defect Rate',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF135BEC),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                _ascending
                                                    ? Icons.arrow_upward
                                                    : Icons.arrow_downward,
                                                size: 14,
                                                color: const Color(0xFF135BEC),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Project List
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: projects.length,
                                  itemBuilder: (context, index) {
                                    final project = projects[index];
                                    return _ProjectCard(project: project);
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

// Project Card Widget
class _ProjectCard extends StatefulWidget {
  final Project project;

  const _ProjectCard({required this.project});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _isHovered = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'not started':
        return const Color(0xFFFFF9E6);
      case 'in progress':
        return const Color(0xFFE3F2FD);
      case 'completed':
        return const Color(0xFFE8F5E9);
      default:
        return Colors.white;
    }
  }

  Color _getHoverColor(String status) {
    switch (status.toLowerCase()) {
      case 'not started':
        return const Color(0xFFFFF3CD);
      case 'in progress':
        return const Color(0xFFBBDEFB);
      case 'completed':
        return const Color(0xFFC8E6C9);
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getDefectRateColor(double? defectRate) {
    if (defectRate == null) return Colors.grey.shade700;
    if (defectRate <= 5.0) return Colors.green.shade700;
    if (defectRate <= 20.0) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final defectRateColor = _getDefectRateColor(project.overallDefectRate);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          Get.to(() => MyProjectDetailPage(project: project));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? _getHoverColor(project.status)
                : _getStatusColor(project.status),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? Colors.blue[300]! : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  project.projectNo ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  project.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${project.started.year}-${project.started.month.toString().padLeft(2, '0')}-${project.started.day.toString().padLeft(2, '0')}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  project.status,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: defectRateColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: defectRateColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    project.overallDefectRate != null
                        ? '${project.overallDefectRate!.toStringAsFixed(2)}%'
                        : 'N/A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: defectRateColor,
                    ),
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
