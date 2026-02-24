import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/projects_controller.dart';
import '../../models/team_member.dart';
import 'employee_performance_detail_page.dart';

class EmployeePerformancePage extends StatefulWidget {
  const EmployeePerformancePage({super.key});

  @override
  State<EmployeePerformancePage> createState() =>
      _EmployeePerformancePageState();
}

class _EmployeePerformancePageState extends State<EmployeePerformancePage> {
  bool _isLoading = true;
  Map<String, Map<String, int>> _employeeStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final projectsCtrl = Get.find<ProjectsController>();
      await projectsCtrl.refreshProjects();

      // Calculate and store employee stats
      final teamCtrl = Get.find<TeamController>();
      final stats = <String, Map<String, int>>{};

      for (final employee in teamCtrl.members) {
        final allProjects = projectsCtrl.byAssigneeId(employee.id);
        final completed = allProjects
            .where((p) => p.status.toLowerCase() == 'completed')
            .length;
        final inProgress = allProjects
            .where((p) => p.status.toLowerCase() == 'in progress')
            .length;

        stats[employee.id] = {
          'total': allProjects.length,
          'completed': completed,
          'inProgress': inProgress,
        };
      }

      if (mounted) {
        setState(() {
          _employeeStats = stats;
        });
      }

      print(
        '[EmployeePerformance] Stats calculated for ${stats.length} employees',
      );
    } catch (e) {
      print('[EmployeePerformance] Error loading projects: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamCtrl = Get.find<TeamController>();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              if (teamCtrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final employees = teamCtrl.members
                  .where((m) => m.role.toLowerCase() != 'admin')
                  .toList();

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text(
                          'Employee Performance',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadData,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track all employees\' project assignments and completion status',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),

                    // Data Table
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: employees.isEmpty
                            ? const Center(child: Text('No employees found'))
                            : SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: MaterialStateProperty.all(
                                      Colors.grey[100],
                                    ),
                                    dataRowMinHeight: 60,
                                    dataRowMaxHeight: 60,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'User',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Email',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Total Projects',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'In Progress',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: employees.map((employee) {
                                      // Get stored stats
                                      final stats =
                                          _employeeStats[employee.id] ??
                                          {
                                            'total': 0,
                                            'completed': 0,
                                            'inProgress': 0,
                                          };
                                      final total = stats['total'] ?? 0;
                                      final completed = stats['completed'] ?? 0;
                                      final inProgress =
                                          stats['inProgress'] ?? 0;

                                      return DataRow(
                                        onSelectChanged: (_) {
                                          Get.to(
                                            () => EmployeePerformanceDetailPage(
                                              member: employee,
                                            ),
                                          );
                                        },
                                        cells: [
                                          DataCell(
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: const Color(
                                                    0xFF1976D2,
                                                  ),
                                                  child: Text(
                                                    employee.name
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  employee.name,
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee.email,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              total.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              completed.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              inProgress.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }),
    );
  }
}
