import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/projects_controller.dart';

class ProjectStatisticsCard extends StatelessWidget {
  const ProjectStatisticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final projCtrl = Get.find<ProjectsController>();

    return Obx(() {
      final allProjects = projCtrl.projects;

      final notStartedCount = allProjects
          .where((p) => p.status == 'Not Started')
          .length;
      final inProgressCount = allProjects
          .where((p) => p.status == 'In Progress')
          .length;
      final completedCount = allProjects
          .where((p) => p.status == 'Completed')
          .length;

      return Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.pending_outlined,
              label: 'Not Started',
              count: notStartedCount,
              color: Colors.orange,
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.autorenew,
              label: 'In Progress',
              count: inProgressCount,
              color: Colors.blue,
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              count: completedCount,
              color: Colors.green,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
