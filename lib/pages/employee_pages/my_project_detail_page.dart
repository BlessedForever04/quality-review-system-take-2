import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../models/project_membership.dart';
import '../../components/project_detail_info.dart';
import '../../services/project_membership_service.dart';
import '../../services/excel_export_service.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/export_controller.dart';
import 'checklist.dart';

class MyProjectDetailPage extends StatefulWidget {
  final Project project;
  final String? description;
  const MyProjectDetailPage({
    super.key,
    required this.project,
    this.description,
  });

  @override
  State<MyProjectDetailPage> createState() => _MyProjectDetailPageState();
}

class _MyProjectDetailPageState extends State<MyProjectDetailPage> {
  bool _isLoadingAssignments = true;
  List<ProjectMembership> _teamLeaders = [];
  List<ProjectMembership> _executors = [];
  List<ProjectMembership> _reviewers = [];
  late Project _project; // local mutable copy
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project; // initialize local copy
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    if (!mounted) return;

    setState(() => _isLoadingAssignments = true);

    try {
      if (Get.isRegistered<ProjectMembershipService>()) {
        final membershipService = Get.find<ProjectMembershipService>();
        final memberships = await membershipService.getProjectMembers(
          widget.project.id,
        );

        if (mounted) {
          setState(() {
            _teamLeaders = memberships
                .where((m) => (m.roleName?.toLowerCase() ?? '') == 'sdh')
                .toList();
            _executors = memberships
                .where((m) => (m.roleName?.toLowerCase() ?? '') == 'executor')
                .toList();
            _reviewers = memberships
                .where((m) => (m.roleName?.toLowerCase() ?? '') == 'reviewer')
                .toList();
            _isLoadingAssignments = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingAssignments = false);
        }
      }
    } catch (e) {
      print('[MyProjectDetailPage] Error loading assignments: $e');
      if (mounted) {
        setState(() => _isLoadingAssignments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProjectDetailInfo(
              project: _project,
              descriptionOverride: widget.description ?? _project.description,
              showAssignedEmployees: false,
            ),
            const SizedBox(height: 24),
            Text(
              'Assigned Team Members',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _isLoadingAssignments
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildAssignedEmployeesSection(),
            const SizedBox(height: 32),
            if (_showStartButton()) _buildStartButton(),
            const SizedBox(height: 16),
<<<<<<< HEAD
            _buildChecklistButton(),
            const SizedBox(height: 16),
            _buildExportButton(),
=======
            if (_project.status.toLowerCase() == 'in progress')
              _buildChecklistButton()
            else
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Checklists will be available after you start the project.',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
>>>>>>> b148bfe8082fa54cc5d530e06db92bd4452b6154
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedEmployeesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildRoleCard('SDH', _teamLeaders, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildRoleCard('Executors', _executors, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildRoleCard('Reviewers', _reviewers, Colors.orange)),
      ],
    );
  }

  Widget _buildRoleCard(
    String title,
    List<ProjectMembership> members,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${members.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No ${title.toLowerCase()} assigned',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withOpacity(0.2),
                              child: Text(
                                (member.userName ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                member.userName ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _showStartButton() {
    // Hide if assignments still loading
    if (_isLoadingAssignments) return false;
    // Must not already be in progress or completed
    final statusLower = _project.status.toLowerCase();
    if (statusLower == 'in progress' || statusLower == 'completed')
      return false;
    // Current user must be an executor or reviewer
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    final userId = auth.currentUser.value?.id;
    if (userId == null) return false;
    final isExecutor = _executors.any((m) => m.userId == userId);
    final isReviewer = _reviewers.any((m) => m.userId == userId);
    // Fallback: if executors/reviewers list empty (membership not hydrated yet) but user is in assignedEmployees
    final assignedContainsUser = (_project.assignedEmployees ?? []).contains(
      userId,
    );
    final fallback =
        assignedContainsUser && _executors.isEmpty && _reviewers.isEmpty;
    // Debug trace
    // ignore: avoid_print
    print(
      '[MyProjectDetailPage] _showStartButton status=${_project.status} executors=${_executors.length} reviewers=${_reviewers.length} userId=$userId isExecutor=$isExecutor isReviewer=$isReviewer assignedContainsUser=$assignedContainsUser fallback=$fallback',
    );
    return isExecutor || isReviewer || fallback;
  }

  Widget _buildStartButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: _starting ? null : _confirmStart,
        icon: _starting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_starting ? 'Starting...' : 'Start Project'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildChecklistButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () {
          final leaders = _teamLeaders
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          final executors = _executors
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          final reviewers = _reviewers
              .map((m) => m.userName ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
          Get.to(
            () => QuestionsScreen(
              projectId: _project.id,
              projectTitle: _project.title,
              leaders: leaders,
              reviewers: reviewers,
              executors: executors,
            ),
          );
        },
        icon: const Icon(Icons.checklist),
        label: const Text('Open Checklist'),
      ),
    );
  }

  Widget _buildExportButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _exportToExcel,
        icon: const Icon(Icons.download),
        label: const Text('Export to Excel'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue.shade600,
          side: BorderSide(color: Colors.blue.shade600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  void _exportToExcel() async {
    try {
      // Initialize export controller and service if not already done
      if (!Get.isRegistered<ExcelExportService>()) {
        Get.put(
          ExcelExportService(
            projectService: Get.find(),
            membershipService: Get.find(),
            checklistService: Get.find(),
            answerService: Get.find(),
            stageService: Get.find(),
            templateService: Get.find(),
          ),
        );
      }

      if (!Get.isRegistered<ExportController>()) {
        Get.put(
          ExportController(excelExportService: Get.find<ExcelExportService>()),
        );
      }

      final exportCtrl = Get.find<ExportController>();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Exporting Project'),
            content: const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        },
      );

      // Extract executor and reviewer names BEFORE calling export
      final executors = _executors
          .map((m) => m.userName ?? m.userEmail ?? '')
          .where((n) => n.trim().isNotEmpty)
          .toList();
      final reviewers = _reviewers
          .map((m) => m.userName ?? m.userEmail ?? '')
          .where((n) => n.trim().isNotEmpty)
          .toList();

      print('🚀 Exporting with executors: $executors, reviewers: $reviewers');
      print(
        '🔍 _executors list: ${_executors.map((m) => '${m.userId}|${m.userName}|${m.userEmail}').toList()}',
      );
      print(
        '🔍 _reviewers list: ${_reviewers.map((m) => '${m.userId}|${m.userName}|${m.userEmail}').toList()}',
      );

      // Perform export with proper executor/reviewer names
      final success = await exportCtrl.exportProjectToExcel(
        _project.id,
        _project.title,
        executors: executors,
        reviewers: reviewers,
      );

      // Close loading dialog safely
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export failed: ${exportCtrl.exportError.value ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file downloaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Export error: $e');

      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmStart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.play_circle_fill, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Start Project'),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to start this project now?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Starting signals that work has begun. You can no longer use the start button afterward.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _startProject();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _startProject() async {
    if (!Get.isRegistered<ProjectsController>()) return;
    setState(() => _starting = true);
    final projectsCtrl = Get.find<ProjectsController>();
    final original = _project;
    final updated = _project.copyWith(
      started: DateTime.now(),
      status: 'In Progress',
    );
    try {
      final saved = await projectsCtrl.saveProjectRemote(updated);
      setState(() {
        _project = saved;
        _starting = false;
      });
      // Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project started'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _project = original; // rollback
        _starting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
