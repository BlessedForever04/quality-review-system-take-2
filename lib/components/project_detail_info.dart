import 'package:flutter/material.dart';
import '../models/project.dart';

/// Reusable widget to display project core details, description and optional assigned employees.
class ProjectDetailInfo extends StatelessWidget {
  final Project project;
  final String? descriptionOverride;
  final bool showAssignedEmployees;
  final EdgeInsetsGeometry? cardPadding;

  const ProjectDetailInfo({
    super.key,
    required this.project,
    this.descriptionOverride,
    this.showAssignedEmployees = true,
    this.cardPadding,
  });

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final description = (descriptionOverride ?? project.description ?? '')
        .trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project Details',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: cardPadding ?? const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.projectNo != null && project.projectNo!.isNotEmpty)
                  DetailRow(label: 'Project No.', value: project.projectNo!),
                if (project.internalOrderNo != null &&
                    project.internalOrderNo!.isNotEmpty)
                  DetailRow(
                    label: 'Project / Internal Order No.',
                    value: project.internalOrderNo!,
                  ),
                DetailRow(label: 'Title', value: project.title),
                DetailRow(
                  label: 'Started',
                  value: _formatDate(project.started),
                ),
                DetailRow(label: 'Priority', value: project.priority),
                DetailRow(label: 'Status', value: project.status),
                DetailRow(
                  label: 'Executor',
                  value: (project.executor?.trim().isNotEmpty ?? false)
                      ? project.executor!.trim()
                      : '--',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Description', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: cardPadding ?? const EdgeInsets.all(16.0),
            child: Text(
              description.isNotEmpty ? description : 'No description provided.',
            ),
          ),
        ),
        if (showAssignedEmployees &&
            (project.assignedEmployees?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          Text(
            'Assigned Employees',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: project.assignedEmployees!
                .map((name) => Chip(label: Text(name)))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
