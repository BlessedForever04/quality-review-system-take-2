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
    'Is Review Applicable',
    'Overall Defect Rate (%)',
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

    DateTime? date(dynamic v) {
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

    double? num(dynamic v) {
      if (v == null) return null;
      try {
        return double.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    String? cell(List<Data?> row, String name) {
      final idx = colIndex[name.toLowerCase()];
      if (idx == null || idx >= row.length) return null;
      final val = row[idx]?.value;
      final s = val?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    // Helper to parse "Is Review Applicable" column
    String? parseReviewApplicable(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim().toLowerCase();
      if (s.isEmpty) return null;
      if (s == 'yes' || s == 'y') return 'yes';
      if (s == 'no' || s == 'n') return 'no';
      return null; // Default to null if not recognized
    }

    final projects = <Project>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      final title = cell(row, 'Project Name') ?? 'Untitled';
      final status = cell(row, 'Project Status') ?? 'Not Started';

      final p = Project(
        id: '',
        projectNo: cell(row, 'Project No.'),
        internalOrderNo: cell(row, 'Project / Internal Order No.'),
        title: title,
        description: cell(row, 'Action Required'),
        started: date(cell(row, 'Creation On')) ?? DateTime.now(),
        priority: 'Medium',
        status: status,
        executor: null,
        groupOrCostCentre: cell(row, 'Group/Cost Centre'),
        actionRequired: cell(row, 'Action Required'),
        sponsor: cell(row, 'Sponsor'),
        competence: cell(row, 'Competence'),
        competenceManager: cell(row, 'Competence Manager'),
        projectLeader: cell(row, 'Project Leader'),
        projectTeam: cell(row, 'Project Team'),
        createdBy: cell(row, 'Created By'),
        creationOn: date(cell(row, 'Creation On')),
        requiredDeliveryDate: date(cell(row, 'Required Delivery Date')),
        plannedEndDate: date(cell(row, 'Planned End Date')),
        actualDeliveryDate: date(cell(row, 'Actual Delivery Date')),
        plannedEfforts: num(cell(row, 'Planned Efforts')),
        actualEfforts: num(cell(row, 'Actual Efforts')),
        isReviewApplicable: parseReviewApplicable(
          cell(row, 'Is Review Applicable'),
        ),
        overallDefectRate: num(cell(row, 'Overall Defect Rate (%)')),
      );
      projects.add(p);
    }
    return projects;
  }
}
