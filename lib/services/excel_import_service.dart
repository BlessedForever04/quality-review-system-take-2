import 'dart:typed_data';

import 'package:excel/excel.dart';
import '../models/project.dart';

class ExcelImportService {
  /// Expected column headers (case-insensitive match).
  static const headers = [
    'Project No.',
    'Project / Internal Order No.',
    'Group/Cost Centre',
    'Project Name',
    'Action Required',
    'Sponsor',
    'Competence',
    'Competence Manager',
    'Project Leader',
    'Project Team',
    'Project Status',
    'Created By',
    'Creation On',
    'Required Delivery Date',
    'Planned End Date',
    'Actual Delivery Date',
    'Planned Efforts',
    'Actual Efforts',
  ];

  List<Project> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    // Build column index by header name
    final headerRow = rows.first;
    final colIndex = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final v = headerRow[i]?.value?.toString().trim() ?? '';
      if (v.isEmpty) continue;
      colIndex[v.toLowerCase()] = i;
    }

    DateTime? _date(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      // Try ISO first then dd/MM/yyyy
      try {
        return DateTime.parse(s);
      } catch (_) {
        final parts = s.split(RegExp(r'[\-/]'));
        if (parts.length == 3) {
          try {
            final d = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final y = int.parse(parts[2]);
            return DateTime(y, m, d);
          } catch (_) {}
        }
        return null;
      }
    }

    double? _num(dynamic v) {
      if (v == null) return null;
      try {
        return double.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    String? _cell(List<Data?> row, String name) {
      final idx = colIndex[name.toLowerCase()];
      if (idx == null || idx >= row.length) return null;
      final val = row[idx]?.value;
      final s = val?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final projects = <Project>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      final title = _cell(row, 'Project Name') ?? 'Untitled';
      final status = _cell(row, 'Project Status') ?? 'Not Started';

      final p = Project(
        id: '',
        projectNo: _cell(row, 'Project No.'),
        internalOrderNo: _cell(row, 'Project / Internal Order No.'),
        title: title,
        description: _cell(row, 'Action Required'),
        started: _date(_cell(row, 'Creation On')) ?? DateTime.now(),
        priority: 'Medium',
        status: status,
        executor: null,
        groupOrCostCentre: _cell(row, 'Group/Cost Centre'),
        actionRequired: _cell(row, 'Action Required'),
        sponsor: _cell(row, 'Sponsor'),
        competence: _cell(row, 'Competence'),
        competenceManager: _cell(row, 'Competence Manager'),
        projectLeader: _cell(row, 'Project Leader'),
        projectTeam: _cell(row, 'Project Team'),
        createdBy: _cell(row, 'Created By'),
        creationOn: _date(_cell(row, 'Creation On')),
        requiredDeliveryDate: _date(_cell(row, 'Required Delivery Date')),
        plannedEndDate: _date(_cell(row, 'Planned End Date')),
        actualDeliveryDate: _date(_cell(row, 'Actual Delivery Date')),
        plannedEfforts: _num(_cell(row, 'Planned Efforts')),
        actualEfforts: _num(_cell(row, 'Actual Efforts')),
      );
      projects.add(p);
    }
    return projects;
  }
}