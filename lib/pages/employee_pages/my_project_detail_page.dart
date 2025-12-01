import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../models/project_membership.dart';
import '../../components/project_detail_info.dart';
import '../../services/project_membership_service.dart';
import '../../controllers/team_controller.dart';

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

  @override
  void initState() {
    super.initState();
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
                .where((m) => m.roleName?.toLowerCase() == 'sdh')
                .toList();
            _executors = memberships
                .where((m) => m.roleName?.toLowerCase() == 'executor')
                .toList();
            _reviewers = memberships
                .where((m) => m.roleName?.toLowerCase() == 'reviewer')
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
        title: Text(widget.project.title),
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
              project: widget.project,
              descriptionOverride:
                  widget.description ?? widget.project.description,
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
}
