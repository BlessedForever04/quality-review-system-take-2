import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/team_controller.dart';
import 'employee_projects_page.dart';
import '../../models/team_member.dart';
import '../../components/admin_dialog.dart';

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

  // Status no longer used in admin view; password added instead.

  Future<void> _showAddDialog(BuildContext context, TeamController ctrl) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String email = '';
    String role = 'Executor/Reviewer';
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
                if (v.trim().length < 2) return 'Name too short';
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
                final pattern = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
                if (!pattern.hasMatch(value)) return 'Invalid email format';
                final exists = ctrl.members.any((m) => m.email.toLowerCase() == value.toLowerCase());
                if (exists) return 'Email already in use';
                return null;
              },
              onSaved: (v) => email = v!.trim(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              items: const ['Team Leader', 'Executor/Reviewer']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role *'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (context, setInner) {
              return TextFormField(
                decoration: InputDecoration(
                  labelText: 'Password *',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setInner(() => obscure = !obscure),
                    tooltip: obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter password';
                  if (v.length < 6) return 'Min 6 chars';
                  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Include letter & number';
                  return null;
                },
                onSaved: (v) => password = v!.trim(),
              );
            }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final newMember = TeamMember(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        email: email,
                        role: role,
                        status: 'Active',
                        dateAdded: DateTime.now().toIso8601String().split('T').first,
                        lastActive: 'Never',
                        password: password,
                      );
                      ctrl.createMember(newMember);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
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

  Future<void> _showEditDialog(BuildContext context, TeamController ctrl, TeamMember m) async {
    final formKey = GlobalKey<FormState>();
    String name = m.name;
    String email = m.email;
    String role = (m.role == 'Team Leader')
        ? 'Team Leader'
        : 'Executor/Reviewer';
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
                final pattern = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
                if (!pattern.hasMatch(value)) return 'Invalid email format';
                final exists = ctrl.members.any((mm) => mm.id != m.id && mm.email.toLowerCase() == value.toLowerCase());
                if (exists) return 'Email already in use';
                return null;
              },
              onSaved: (v) => email = v!.trim(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              items: const ['Team Leader', 'Executor/Reviewer']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role *'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (context, setInner) {
              return TextFormField(
                initialValue: password,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setInner(() => obscure = !obscure),
                    tooltip: obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter password';
                  if (v.length < 6) return 'Min 6 chars';
                  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Include letter & number';
                  return null;
                },
                onSaved: (v) => password = v!.trim(),
              );
            }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final updated = m.copyWith(name: name, email: email, role: role, password: password);
                      ctrl.saveMember(updated);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated')));
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

  Future<void> _confirmDelete(BuildContext context, TeamController ctrl, TeamMember m) async {
    final confirmed = await showAdminDialog<bool>(
      context,
      title: 'Delete Member',
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${m.name}"?'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.removeMember(m.id);
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
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(() {
                          final list = ctrl.filtered;
                          return DataTable(
                            columnSpacing: 24,
                            sortAscending: true,
                            sortColumnIndex: 0,
                            columns: [
                              DataColumn(
                                label: const Text('User'),
                                onSort: (colIndex, asc) {
                                  final sorted = ctrl.members.toList()
                                    ..sort((a, b) => asc ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
                                  ctrl.members.assignAll(sorted);
                                },
                              ),
                              const DataColumn(label: Text('Email')),
                              const DataColumn(label: Text('Role')),
                              const DataColumn(label: Text('Password')),
                              DataColumn(
                                label: const Text('Date Added'),
                                onSort: (colIndex, asc) {
                                  final sorted = ctrl.members.toList()
                                    ..sort((a, b) => asc ? a.dateAdded.compareTo(b.dateAdded) : b.dateAdded.compareTo(a.dateAdded));
                                  ctrl.members.assignAll(sorted);
                                },
                              ),
                              const DataColumn(label: Text('Last Active')),
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
            onTap: () => Get.to(() => EmployeeProjectsPage(member: e)),
                                  ),
                                  DataCell(Text(e.email)),
                                  DataCell(
                                    _roleChip(
                                      e.role == 'Team Leader'
                                          ? 'Team Leader'
                                          : 'Executor/Reviewer',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      e.password != null &&
                                              e.password!.isNotEmpty
                                          ? '••••••'
                                          : 'Not Set',
                                    ),
                                  ),
                                  DataCell(Text(e.dateAdded)),
                                  DataCell(Text(e.lastActive)),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
              onPressed: () => _showEditDialog(context, ctrl, e),
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                        ),
                                        IconButton(
              onPressed: () => _confirmDelete(context, ctrl, e),
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
                          );
                        }),
                      ),
                    ),
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
                                value: ctrl.selectedRoles.contains(
                                  'Team Leader',
                                ),
                                onChanged: (v) => v == true
                                    ? ctrl.selectedRoles.add('Team Leader')
                                    : ctrl.selectedRoles.remove('Team Leader'),
                                title: const Text('Team Leader'),
                              ),
                              CheckboxListTile(
                                value: ctrl.selectedRoles.contains(
                                  'Executor/Reviewer',
                                ),
                                onChanged: (v) => v == true
                                    ? ctrl.selectedRoles.add(
                                        'Executor/Reviewer',
                                      )
                                    : ctrl.selectedRoles.remove(
                                        'Executor/Reviewer',
                                      ),
                                title: const Text('Executor/Reviewer'),
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
