import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';

class Myproject extends StatefulWidget {
  const Myproject({super.key});

  @override
  State<Myproject> createState() => _MyprojectState();
}

class _MyprojectState extends State<Myproject> {
  late final ProjectsController _ctrl;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Mock data: Current logged-in user
  final String currentUser = 'Emily Carter';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProjectsController());

    // Load all company projects (mock data)
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
        Project(
          id: 'p5',
          title: 'Mobile App Development',
          description:
              'Develop a cross-platform mobile application for iOS and Android to enhance customer engagement.',
          started: DateTime(2024, 6, 15),
          priority: 'High',
          status: 'In Progress',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'William Hall', 'Isabella King'],
        ),
        Project(
          id: 'p6',
          title: 'Website Redesign',
          description:
              'Complete redesign of the company website with modern UI/UX, improved performance, and better SEO.',
          started: DateTime(2024, 5, 10),
          priority: 'Medium',
          status: 'Completed',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'Ava Lewis'],
        ),
      ]);
    }
  }

  // Filter projects to show only those where current user is the executor
  List<Project> get _myProjects {
    return _ctrl.projects
        .where((project) => project.executor == currentUser)
        .toList();
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
              Text(
                'My Projects',
                style: Theme.of(context).textTheme.headlineMedium,
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
                      final projects = _myProjects;

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
                                _ctrl.projects.sort(
                                  (a, b) => asc
                                      ? a.title.compareTo(b.title)
                                      : b.title.compareTo(a.title),
                                );
                              });
                            },
                          ),
                          DataColumn(
                            label: const Text('Started Date'),
                            onSort: (colIndex, asc) {
                              setState(() {
                                _sortColumnIndex = colIndex;
                                _sortAscending = asc;
                                _ctrl.projects.sort(
                                  (a, b) => asc
                                      ? a.started.compareTo(b.started)
                                      : b.started.compareTo(a.started),
                                );
                              });
                            },
                          ),
                          const DataColumn(label: Text('Priority')),
                          const DataColumn(label: Text('Status')),
                        ],
                        rows: projects.map((proj) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: Text(proj.title),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${proj.started.year}-${proj.started.month.toString().padLeft(2, '0')}-${proj.started.day.toString().padLeft(2, '0')}',
                                ),
                              ),
                              DataCell(_priorityChip(proj.priority)),
                              DataCell(Text(proj.status)),
                            ],
                          );
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
}
