import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/team_controller.dart';
import '../../models/team_member.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _TeamPageState();
}

class _TeamPageState extends State<EmployeePage> {
  late final TeamController _ctrl;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(TeamController());

    if (_ctrl.members.isEmpty) {
      _ctrl.loadInitial([
        TeamMember(id: 't1', name: 'Emma Carter', email: 'emma.carter@example.com', role: 'Team Leader', status: 'Active', dateAdded: '2023-08-15', lastActive: '2024-05-20'),
        TeamMember(id: 't2', name: 'Liam Walker', email: 'liam.walker@example.com', role: 'Member', status: 'Active', dateAdded: '2023-09-22', lastActive: '2024-05-21'),
        TeamMember(id: 't3', name: 'Olivia Harris', email: 'olivia.harris@example.com', role: 'Reviewer', status: 'Inactive', dateAdded: '2023-10-10', lastActive: '2024-04-30'),
        TeamMember(id: 't4', name: 'Noah Clark', email: 'noah.clark@example.com', role: 'Member', status: 'Active', dateAdded: '2023-11-05', lastActive: '2024-05-19'),
        TeamMember(id: 't5', name: 'Ava Lewis', email: 'ava.lewis@example.com', role: 'Team Leader', status: 'Pending', dateAdded: '2023-12-18', lastActive: 'Never'),
      ]);
    }
  }

  Widget _roleChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFEFF3F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _statusChip(String text) {
    Color bg = const Color(0xFFEFF3F7);
    if (text == 'Active') bg = const Color(0xFFDFF7E6);
    if (text == 'Inactive') bg = const Color(0xFFF5F7FA);
    if (text == 'Pending') bg = const Color(0xFFFFF4E5);
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String email = '';
    String role = 'Member';
    String status = 'Active';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Team Member'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Full name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  onSaved: (v) => name = v!.trim(),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                  onSaved: (v) => email = v!.trim(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: ['Team Leader', 'Member', 'Reviewer'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => role = v ?? role,
                  decoration: const InputDecoration(labelText: 'Role *'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['Active', 'Inactive', 'Pending'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  final newMember = TeamMember(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    email: email,
                    role: role,
                    status: status,
                    dateAdded: DateTime.now().toIso8601String().split('T').first,
                    lastActive: 'Never',
                  );
                  _ctrl.addMember(newMember);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(TeamMember m) async {
    final formKey = GlobalKey<FormState>();
    String name = m.name;
    String email = m.email;
    String role = m.role;
    String status = m.status;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Member'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Full name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  onSaved: (v) => name = v!.trim(),
                ),
                TextFormField(
                  initialValue: email,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                  onSaved: (v) => email = v!.trim(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: ['Team Leader', 'Member', 'Reviewer'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => role = v ?? role,
                  decoration: const InputDecoration(labelText: 'Role *'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['Active', 'Inactive', 'Pending'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  final updated = m.copyWith(name: name, email: email, role: role, status: status);
                  _ctrl.updateMember(m.id, updated);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(TeamMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Delete "${m.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) _ctrl.deleteMember(m.id);
  }

  @override
  Widget build(BuildContext context) {
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
                      Text('User Management', style: Theme.of(context).textTheme.headlineMedium),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New User'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(() {
                          final list = _ctrl.filtered;
                          return DataTable(
                            columnSpacing: 24,
                            sortAscending: _sortAscending,
                            sortColumnIndex: _sortColumnIndex,
                            columns: [
                              DataColumn(
                                label: const Text('User'),
                                onSort: (colIndex, asc) {
                                  setState(() {
                                    _sortColumnIndex = colIndex;
                                    _sortAscending = asc;
                                    _ctrl.members.sort((a, b) => asc ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Email')),
                              const DataColumn(label: Text('Role')),
                              const DataColumn(label: Text('Status')),
                              DataColumn(
                                label: const Text('Date Added'),
                                onSort: (colIndex, asc) {
                                  setState(() {
                                    _sortColumnIndex = colIndex;
                                    _sortAscending = asc;
                                    _ctrl.members.sort((a, b) => asc ? a.dateAdded.compareTo(b.dateAdded) : b.dateAdded.compareTo(a.dateAdded));
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Last Active')),
                              const DataColumn(label: Text('Actions')),
                            ],
                            rows: list.map((e) {
                              return DataRow(cells: [
                                DataCell(Row(children: [CircleAvatar(radius: 18, child: Text(e.name[0])), const SizedBox(width: 12), Text(e.name)])),
                                DataCell(Text(e.email)),
                                DataCell(_roleChip(e.role)),
                                DataCell(_statusChip(e.status)),
                                DataCell(Text(e.dateAdded)),
                                DataCell(Text(e.lastActive)),
                                DataCell(Row(children: [IconButton(onPressed: () => _showEditDialog(e), icon: const Icon(Icons.edit, size: 20)), IconButton(onPressed: () => _confirmDelete(e), icon: const Icon(Icons.delete_outline, size: 20))])),
                              ]);
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
                const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Filter by Role', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Obx(() => Column(children: [
                          CheckboxListTile(value: _ctrl.selectedRoles.contains('Team Leader'), onChanged: (v) => v == true ? _ctrl.selectedRoles.add('Team Leader') : _ctrl.selectedRoles.remove('Team Leader'), title: const Text('Team Leader')),
                          CheckboxListTile(value: _ctrl.selectedRoles.contains('Member'), onChanged: (v) => v == true ? _ctrl.selectedRoles.add('Member') : _ctrl.selectedRoles.remove('Member'), title: const Text('Member')),
                          CheckboxListTile(value: _ctrl.selectedRoles.contains('Reviewer'), onChanged: (v) => v == true ? _ctrl.selectedRoles.add('Reviewer') : _ctrl.selectedRoles.remove('Reviewer'), title: const Text('Reviewer')),
                        ])),
                        const SizedBox(height: 12),
                        const Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Obx(() => Column(children: [
                          CheckboxListTile(value: _ctrl.selectedStatuses.contains('Active'), onChanged: (v) => v == true ? _ctrl.selectedStatuses.add('Active') : _ctrl.selectedStatuses.remove('Active'), title: const Text('Active')),
                          CheckboxListTile(value: _ctrl.selectedStatuses.contains('Inactive'), onChanged: (v) => v == true ? _ctrl.selectedStatuses.add('Inactive') : _ctrl.selectedStatuses.remove('Inactive'), title: const Text('Inactive')),
                          CheckboxListTile(value: _ctrl.selectedStatuses.contains('Pending'), onChanged: (v) => v == true ? _ctrl.selectedStatuses.add('Pending') : _ctrl.selectedStatuses.remove('Pending'), title: const Text('Pending')),
                        ])),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _ctrl.clearFilters(),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2F5F8), foregroundColor: Colors.black),
                          child: const Text('Clear Filters'),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
