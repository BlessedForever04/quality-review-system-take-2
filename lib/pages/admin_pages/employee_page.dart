import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/team_controller.dart';
import '../../controllers/projects_controller.dart';
import 'employee_projects_page.dart';
import '../../models/team_member.dart';
import '../../components/admin_dialog.dart';
import '../../services/project_membership_service.dart';

class EmployeePage extends StatelessWidget {
  const EmployeePage({super.key});

  void _ensureSeed(TeamController ctrl) {}

  Widget _roleChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFEFF3F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final date =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Status no longer used in admin view; password added instead.

  Future<void> _showAddDialog(BuildContext context, TeamController ctrl) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String email = '';
    String role = 'User';
    String password = '';
    bool obscure = true;
    await showAdminDialog(
      context,
      title: 'Add Team Member',
      width: 520,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Full name *'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter name';
                if (v.trim().isEmpty) return 'Name can\'t be empty';
                return null;
              },
              onSaved: (v) => name = v!.trim(),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Email *'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter email';
                final value = v.trim();
                final pattern = RegExp(
                  r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                );
                if (!pattern.hasMatch(value)) return 'Invalid email format';
                final exists = ctrl.members.any(
                  (m) => m.email.toLowerCase() == value.toLowerCase(),
                );
                if (exists) return 'Email already in use';
                return null;
              },
              onSaved: (v) => email = v!.trim(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                'Admin',
                'User',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role *'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setInner) {
                return TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setInner(() => obscure = !obscure),
                      tooltip: obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter password';
                    if (v.length < 6) return 'Min 6 chars';
                    if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
                      return 'Include letter & number';
                    }
                    return null;
                  },
                  onSaved: (v) => password = v!.trim(),
                );
              },
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
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final newMember = TeamMember(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        email: email,
                        role: role,
                        status: 'Active',
                        dateAdded: DateTime.now()
                            .toIso8601String()
                            .split('T')
                            .first,
                        lastActive: 'Never',
                        password: password,
                      );
                      Navigator.of(context).pop();
                      try {
                        await ctrl.createMember(newMember);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member created successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Add Member'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    TeamController ctrl,
    TeamMember m,
  ) async {
    final formKey = GlobalKey<FormState>();
    String name = m.name;
    String email = m.email;
    String role = (m.role == 'Admin') ? 'Admin' : 'User';
    String password = m.password ?? '';
    bool obscure = true;
    await showAdminDialog(
      context,
      title: 'Edit Member',
      width: 520,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: 'Full name *'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter name';
                if (v.trim().length < 2) return 'Name too short';
                return null;
              },
              onSaved: (v) => name = v!.trim(),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: email,
              decoration: const InputDecoration(labelText: 'Email *'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter email';
                final value = v.trim();
                final pattern = RegExp(
                  r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                );
                if (!pattern.hasMatch(value)) return 'Invalid email format';
                final exists = ctrl.members.any(
                  (mm) =>
                      mm.id != m.id &&
                      mm.email.toLowerCase() == value.toLowerCase(),
                );
                if (exists) return 'Email already in use';
                return null;
              },
              onSaved: (v) => email = v!.trim(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                'Admin',
                'User',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role *'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setInner) {
                return TextFormField(
                  initialValue: password,
                  decoration: InputDecoration(
                    labelText: 'Password (optional)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setInner(() => obscure = !obscure),
                      tooltip: obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    // Password is optional during edit; validate only if provided
                    if (v == null || v.isEmpty) return null;
                    if (v.length < 6) return 'Min 6 chars';
                    if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
                      return 'Include letter';
                    }
                    return null;
                  },
                  onSaved: (v) => password = (v ?? '').trim(),
                );
              },
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
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final updated = m.copyWith(
                        name: name,
                        email: email,
                        role: role,
                        password: password,
                      );
                      Navigator.of(context).pop();
                      try {
                        await ctrl.saveMember(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${updated.name} has been updated successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to update member: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TeamController ctrl,
    TeamMember m,
  ) async {
    // Check if employee has projects in progress
    bool hasActiveProjects = false;
    Map<String, List<String>> projectRoles =
        {}; // projectTitle -> list of roles

    try {
      final projectsCtrl = Get.find<ProjectsController>();
      final membershipService = Get.find<ProjectMembershipService>();

      // Refresh projects first
      await projectsCtrl.refreshProjects();

      // Get all projects assigned to this employee
      final employeeProjects = projectsCtrl.byAssigneeId(m.id);

      // Check each project to see if employee has any role in an in-progress project
      for (final project in employeeProjects) {
        if (project.status.toLowerCase() != 'completed') {
          // Get memberships for this project
          try {
            final memberships = await membershipService.getProjectMembers(
              project.id,
            );

            // Get all roles for this employee in this project
            final employeeRoles = memberships
                .where((membership) => membership.userId == m.id)
                .map((membership) => membership.roleName ?? 'Unknown')
                .toList();

            if (employeeRoles.isNotEmpty) {
              hasActiveProjects = true;
              projectRoles[project.title] = employeeRoles;
            }
          } catch (e) {
            print('[EmployeePage] Error checking project ${project.id}: $e');
          }
        }
      }
    } catch (e) {
      print('[EmployeePage] Error checking active projects: $e');
    }

    final String warningMessage = hasActiveProjects
        ? 'Warning: "${m.name}" is currently assigned to ${projectRoles.length} in-progress project(s):\n\n${projectRoles.entries.map((e) => '• ${e.key} (${e.value.join(', ')})').join('\n')}\n\nDeleting this employee may affect these projects. Are you sure you want to proceed?'
        : 'Are you sure you want to delete "${m.name}"? This action cannot be undone.';

    final String deleteButtonText = hasActiveProjects
        ? 'Acknowledge and Delete'
        : 'Delete Member';

    final confirmed = await showAdminDialog<bool>(
      context,
      title: 'Delete Member',
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasActiveProjects)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      warningMessage,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(warningMessage),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(deleteButtonText),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ctrl.removeMember(m.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${m.name} has been deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete member: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<TeamController>();
    _ensureSeed(ctrl);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Management',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context, ctrl),
                        icon: const Icon(Icons.add),
                        label: const Text('Add New User'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar styled similar to admin dashboard (reactive clear button)
                  Obx(
                    () => Container(
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
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: ctrl.searchQuery.value.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Clear search',
                                  onPressed: () => ctrl.searchQuery.value = '',
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (v) => ctrl.searchQuery.value = v,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Full-width card with DataTable; constrain minimum width of table to available width
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Obx(() {
                              final list = ctrl.filtered;
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        constraints.maxWidth -
                                        32, // account for padding
                                  ),
                                  child: DataTable(
                                    columnSpacing: 24,
                                    sortAscending: true,
                                    sortColumnIndex: 0,
                                    columns: [
                                      DataColumn(
                                        label: const Text('User'),
                                        onSort: (colIndex, asc) {
                                          final sorted = ctrl.members.toList()
                                            ..sort(
                                              (a, b) => asc
                                                  ? a.name.compareTo(b.name)
                                                  : b.name.compareTo(a.name),
                                            );
                                          ctrl.members.assignAll(sorted);
                                        },
                                      ),
                                      const DataColumn(label: Text('Email')),
                                      const DataColumn(label: Text('Role')),
                                      DataColumn(
                                        label: const Text('Added on Date/Time'),
                                        onSort: (colIndex, asc) {
                                          final sorted = ctrl.members.toList()
                                            ..sort(
                                              (a, b) => asc
                                                  ? a.dateAdded.compareTo(
                                                      b.dateAdded,
                                                    )
                                                  : b.dateAdded.compareTo(
                                                      a.dateAdded,
                                                    ),
                                            );
                                          ctrl.members.assignAll(sorted);
                                        },
                                      ),
                                      const DataColumn(label: Text('Actions')),
                                    ],
                                    rows: list.map((e) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  child: Text(e.name[0]),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(e.name),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(e.email)),
                                          DataCell(_roleChip(e.role)),
                                          DataCell(
                                            Text(_formatDateTime(e.dateAdded)),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () =>
                                                      _showEditDialog(
                                                        context,
                                                        ctrl,
                                                        e,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 20,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      _confirmDelete(
                                                        context,
                                                        ctrl,
                                                        e,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter by Role',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                          () => Column(
                            children: [
                              CheckboxListTile(
                                value: ctrl.selectedRoles.contains('Admin'),
                                onChanged: (v) => v == true
                                    ? ctrl.selectedRoles.add('Admin')
                                    : ctrl.selectedRoles.remove('Admin'),
                                title: const Text('Admin'),
                              ),
                              CheckboxListTile(
                                value: ctrl.selectedRoles.contains('User'),
                                onChanged: (v) => v == true
                                    ? ctrl.selectedRoles.add('User')
                                    : ctrl.selectedRoles.remove('User'),
                                title: const Text('User'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Status filters removed.
                        ElevatedButton(
                          onPressed: () => ctrl.clearFilters(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F5F8),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
