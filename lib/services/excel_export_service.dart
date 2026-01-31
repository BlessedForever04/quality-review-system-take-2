import 'package:excel/excel.dart';
import 'package:get/get.dart';
import '../models/project.dart';
import '../models/project_membership.dart';
import 'project_service.dart';
import 'project_membership_service.dart';
import 'phase_checklist_service.dart';
import 'checklist_answer_service.dart';
import 'stage_service.dart';
import 'template_service.dart';

class ExcelExportService {
  final ProjectService projectService;
  final ProjectMembershipService membershipService;
  final PhaseChecklistService checklistService;
  final ChecklistAnswerService answerService;
  final StageService stageService;
  final TemplateService templateService;

  ExcelExportService({
    required this.projectService,
    required this.membershipService,
    required this.checklistService,
    required this.answerService,
    required this.stageService,
    required this.templateService,
  });

  /// Export project to Excel with Project Details and Checkpoint Reviews sheets
  Future<List<int>> exportProjectToExcel(
    String projectId, {
    List<String> executors = const [],
    List<String> reviewers = const [],
  }) async {
    try {
      print('🚀 Starting Excel export for project: $projectId');
      print('📥 Received executors: $executors');
      print('📥 Received reviewers: $reviewers');

      // Fetch project data
      final project = await projectService.getById(projectId);
      print('✓ Fetched project: ${project.title}');

      // Fetch team members
      final memberships = await membershipService.getProjectMembers(projectId);
      print('✓ Fetched ${memberships.length} team members');

      // Debug: Print all membership data
      for (final m in memberships) {
        print(
          '   Membership: userId=${m.userId}, userName=${m.userName}, userEmail=${m.userEmail}, roleName=${m.roleName}',
        );
      }

      // Use the passed executors/reviewers lists (already extracted from frontend)
      var finalExecutors = List<String>.from(executors);
      var finalReviewers = List<String>.from(reviewers);

      print('✅ Using executors: $finalExecutors');
      print('✅ Using reviewers: $finalReviewers');

      // Fetch stages
      final stages = await stageService.listStages(projectId);
      print('✓ Fetched ${stages.length} stages');

      // Create Excel workbook
      final excel = Excel.createExcel();

      // Create sheets
      await _createProjectDetailsSheet(
        excel,
        project,
        memberships,
        executors: finalExecutors,
        reviewers: finalReviewers,
      );
      await _createCheckpointReviewsSheet(
        excel,
        projectId,
        stages,
        memberships,
      );

      // Remove Sheet1 AFTER creating other sheets
      try {
        if (excel.sheets.containsKey('Sheet1')) {
          excel.delete('Sheet1');
          print(
            '✓ Deleted Sheet1 (final sheets: ${excel.sheets.keys.toList()})',
          );
        }
      } catch (e) {
        print('⚠️ Could not delete Sheet1: $e');
      }

      // Convert to bytes
      final bytes = excel.encode();
      print('✓ Excel file generated successfully');

      return bytes ?? [];
    } catch (e, stackTrace) {
      print('❌ Error exporting project: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Create Project Details sheet
  Future<void> _createProjectDetailsSheet(
    Excel excel,
    Project project,
    List<ProjectMembership> memberships, {
    List<String> executors = const [],
    List<String> reviewers = const [],
  }) async {
    print('📝 Creating Project Details sheet...');

    final sheet = excel['Project Details'];

    // Define styles
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final fieldStyle = CellStyle(
      bold: true,
      fontSize: 11,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    final valueStyle = CellStyle(
      fontSize: 11,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Headers - Vertical format
    final headerCell0 = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    headerCell0.value = TextCellValue('Field');
    headerCell0.cellStyle = headerStyle;

    final headerCell1 = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
    );
    headerCell1.value = TextCellValue('Value');
    headerCell1.cellStyle = headerStyle;

    int rowIndex = 1;

    // Helper function to add a row with styling
    void addRow(String field, dynamic value) {
      final fieldCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      fieldCell.value = TextCellValue(field);
      fieldCell.cellStyle = fieldStyle;

      final valueCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      valueCell.value = _toCellValue(value);
      valueCell.cellStyle = valueStyle;

      rowIndex++;
    }

    // Use the executors and reviewers extracted in the main export function
    print('✅ Using executors: $executors');
    print('✅ Using reviewers: $reviewers');

    final projectLeader = memberships
        .firstWhereOrNull(
          (m) => (m.roleName?.toLowerCase() ?? '') == 'teamleader',
        )
        ?.userName;

    // Add all fields in vertical format
    addRow('Project No', project.projectNo ?? '');
    addRow('Internal Order No', project.internalOrderNo ?? '');
    addRow('Project Name', project.title);
    addRow('Description', project.description ?? '');
    addRow('Status', project.status);
    addRow('Priority', project.priority);
    addRow('Start Date', _formatDate(project.started));
    addRow(
      'End Date',
      _formatDate(project.actualDeliveryDate ?? project.plannedEndDate),
    );
    addRow('Project Leader', projectLeader ?? '');
    addRow('Executors', executors.isNotEmpty ? executors.join(', ') : '');
    addRow('Reviewers', reviewers.isNotEmpty ? reviewers.join(', ') : '');

    // Set column widths for better readability
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 50);

    print('✓ Project Details sheet created with styling');
  }

  /// Create Checkpoint Reviews sheets (one per phase - supports any number of phases)
  Future<void> _createCheckpointReviewsSheet(
    Excel excel,
    String projectId,
    List<Map<String, dynamic>> stages,
    List<ProjectMembership> memberships,
  ) async {
    print('📝 Creating Checkpoint Reviews sheets...');

    // Include all stages that contain 'phase' in their name (supports unlimited phases)
    final phaseStages = stages.where((s) {
      final stageName = (s['stage_name'] ?? s['name'] ?? '')
          .toString()
          .toLowerCase();
      return stageName.contains('phase');
    }).toList();

    // Process each phase
    for (int phaseIndex = 0; phaseIndex < phaseStages.length; phaseIndex++) {
      final stage = phaseStages[phaseIndex];
      final stageData = stage;
      final stageId = stageData['_id'] ?? stageData['id'];
      final sheetName = 'Phase ${phaseIndex + 1} Reviews';

      try {
        print('  📝 Creating sheet: $sheetName');

        // Create sheet for this phase
        final sheet = excel[sheetName];

        int rowIndex = 0;

        // Extract loopback_count and conflict_count from stage data
        final loopbackCount = stageData['loopback_count'] ?? 0;
        final conflictCount = stageData['conflict_count'] ?? 0;
        print(
          '  ℹ️ Phase ${phaseIndex + 1}: loopback_count=$loopbackCount, conflict_count=$conflictCount',
        );

        // Get checklists for this phase
        final checklists = await checklistService.listForStage(
          stageId.toString(),
        );

        // Collect all checkpoints grouped by checklist
        int totalCheckpoints = 0;
        int totalDefects = 0;
        final List<Map<String, dynamic>> checklistData = [];

        // Fetch executor and reviewer responses for this phase once
        final phaseNum = phaseIndex + 1;
        final executorAnswers = await answerService.getAnswers(
          projectId,
          phaseNum,
          'executor',
        );
        final reviewerAnswers = await answerService.getAnswers(
          projectId,
          phaseNum,
          'reviewer',
        );

        // Get executor and reviewer names
        final executor = memberships.firstWhereOrNull(
          (m) => m.roleName?.toLowerCase() == 'executor',
        );
        final reviewer = memberships.firstWhereOrNull(
          (m) => m.roleName?.toLowerCase() == 'reviewer',
        );

        for (final checklist in checklists) {
          final checklistId = checklist['_id'] ?? checklist['id'];
          final checklistName =
              checklist['checklist_name'] ?? checklist['name'] ?? 'Checklist';

          try {
            // Get checkpoints for this checklist
            final checkpoints = await checklistService.getCheckpoints(
              checklistId.toString(),
            );

            final List<Map<String, dynamic>> checkpointRows = [];

            for (final checkpoint in checkpoints) {
              final checkpointData = checkpoint;
              final checkpointId =
                  checkpointData['_id'] ?? checkpointData['id'];
              final checkpointName =
                  checkpointData['checkpoint_name'] ??
                  checkpointData['name'] ??
                  '';
              final questionText =
                  checkpointData['question'] ??
                  checkpointData['question_text'] ??
                  '';

              try {
                // Extract answer for this checkpoint
                final executorData = executorAnswers[checkpointId.toString()];
                final reviewerData = reviewerAnswers[checkpointId.toString()];

                // Determine defect: Y if answers differ, N if same
                final executorAnswer = executorData?['answer'];
                final reviewerAnswer = reviewerData?['answer'];
                final defectDetected =
                    executorAnswer != null &&
                        reviewerAnswer != null &&
                        _normalizeAnswer(executorAnswer) !=
                            _normalizeAnswer(reviewerAnswer)
                    ? 'Y'
                    : 'N';

                // Get defect category and severity - show actual names if available
                String defectCategory = '';
                String defectSeverity = '';
                // First try to get categoryId from checkpoint data
                String? categoryId;

                // Check if checkpoint has categoryId field
                if (checkpointData['categoryId'] != null &&
                    checkpointData['categoryId'].toString().trim().isNotEmpty) {
                  categoryId = checkpointData['categoryId'].toString();
                }

                // Also check defect object for categoryId and severity
                if (checkpointData['defect'] != null) {
                  final defectData = checkpointData['defect'];
                  if (categoryId == null &&
                      defectData['categoryId'] != null &&
                      defectData['categoryId'].toString().trim().isNotEmpty) {
                    categoryId = defectData['categoryId'].toString();
                  }
                  if (defectData['severity'] != null &&
                      defectData['severity'].toString().trim().isNotEmpty) {
                    defectSeverity = defectData['severity'].toString();
                  }
                }

                // If we have a categoryId, fetch the category name from template
                if (categoryId != null && categoryId.isNotEmpty) {
                  try {
                    final template = await templateService.fetchTemplate();
                    final categories =
                        template['defectCategories'] as List<dynamic>? ?? [];
                    final category = categories.firstWhereOrNull((cat) {
                      if (cat is Map<String, dynamic>) {
                        return (cat['_id'] ?? '').toString() == categoryId;
                      }
                      return false;
                    });
                    if (category != null && category is Map<String, dynamic>) {
                      defectCategory = (category['name'] ?? '').toString();
                    }
                  } catch (e) {
                    print('⚠️ Failed to fetch defect category name: $e');
                  }
                }

                if (defectDetected == 'Y') {
                  totalDefects++;
                }

                totalCheckpoints++;

                // Store row data
                checkpointRows.add({
                  'checkpointName': checkpointName,
                  'questionText': questionText,
                  'executorName': executor?.userName ?? '',
                  'executorAnswer': _convertAnswerToString(executorAnswer),
                  'executorComment':
                      executorData?['remark'] ?? executorData?['comment'] ?? '',
                  'reviewerName': reviewer?.userName ?? '',
                  'reviewerAnswer': _convertAnswerToString(reviewerAnswer),
                  'reviewerComment':
                      reviewerData?['remark'] ?? reviewerData?['comment'] ?? '',
                  'defectDetected': defectDetected,
                  'defectCategory': defectCategory,
                  'defectSeverity': defectSeverity,
                  'loopbackCount': loopbackCount,
                  'conflictCount': conflictCount,
                });
              } catch (e) {
                print('    ⚠️ Error processing checkpoint: $e');
              }
            }

            // Store checklist with its checkpoints
            if (checkpointRows.isNotEmpty) {
              checklistData.add({
                'checklistName': checklistName,
                'checkpoints': checkpointRows,
              });
            }
          } catch (e) {
            print('  ⚠️ Error fetching checkpoints: $e');
          }
        }

        // Calculate defect rate
        final defectRate = totalCheckpoints > 0
            ? ((totalDefects / totalCheckpoints) * 100).toStringAsFixed(2)
            : '0.00';

        // Define styles for phase sheets
        final statsLabelStyle = CellStyle(
          bold: true,
          fontSize: 11,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        final statsValueStyle = CellStyle(
          fontSize: 11,
          bold: true,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        final tableHeaderStyle = CellStyle(
          bold: true,
          fontSize: 11,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        final dataCellStyle = CellStyle(
          fontSize: 10,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          verticalAlign: VerticalAlign.Top,
        );

        final defectYesStyle = CellStyle(
          bold: true,
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        final defectNoStyle = CellStyle(
          bold: true,
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        final checklistHeaderStyle = CellStyle(
          bold: true,
          fontSize: 12,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );

        // Write compact statistics at the top (vertical layout)
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        );
        cell.value = TextCellValue('Total Checkpoints');
        cell.cellStyle = statsLabelStyle;

        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        );
        cell.value = IntCellValue(totalCheckpoints);
        cell.cellStyle = statsValueStyle;
        rowIndex++;

        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        );
        cell.value = TextCellValue('Total Defects');
        cell.cellStyle = statsLabelStyle;

        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        );
        cell.value = IntCellValue(totalDefects);
        cell.cellStyle = statsValueStyle;
        rowIndex++;

        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        );
        cell.value = TextCellValue('Defect Rate (%)');
        cell.cellStyle = statsLabelStyle;

        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        );
        cell.value = TextCellValue(defectRate);
        cell.cellStyle = statsValueStyle;
        rowIndex++;

        // Empty row for spacing
        rowIndex++;

        // Define table headers
        final headers = [
          '',
          'Executor Name',
          'Executor Answer',
          'Executor Comment',
          'Reviewer Name',
          'Reviewer Answer',
          'Reviewer Comment',
          'Defect Detected (Y/N)',
          'Defect Category',
          'Defect Severity',
          'Loopback Count',
          'Conflict Count',
        ];

        // Write data grouped by checklist
        for (final checklistGroup in checklistData) {
          // Write checklist header
          final checklistHeaderCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          );
          checklistHeaderCell.value = TextCellValue(
            checklistGroup['checklistName'],
          );
          checklistHeaderCell.cellStyle = checklistHeaderStyle;

          // Merge cells across all columns for checklist header
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            CellIndex.indexByColumnRow(
              columnIndex: headers.length - 1,
              rowIndex: rowIndex,
            ),
          );
          rowIndex++;

          // Write table headers
          for (int i = 0; i < headers.length; i++) {
            final headerCell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
            );
            headerCell.value = TextCellValue(headers[i]);
            headerCell.cellStyle = tableHeaderStyle;
          }
          rowIndex++;

          // Write checkpoint rows for this checklist
          final checkpoints =
              checklistGroup['checkpoints'] as List<Map<String, dynamic>>;
          for (final row in checkpoints) {
            final rowData = [
              row['questionText'],
              row['executorName'],
              row['executorAnswer'],
              row['executorComment'],
              row['reviewerName'],
              row['reviewerAnswer'],
              row['reviewerComment'],
              row['defectDetected'],
              row['defectCategory'],
              row['defectSeverity'],
              row['loopbackCount'],
              row['conflictCount'],
            ];

            for (int i = 0; i < rowData.length; i++) {
              final value = rowData[i];
              final dataCell = sheet.cell(
                CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
              );
              dataCell.value = _toCellValue(value);

              // Apply special styling for defect detected column
              if (i == 7) {
                // Defect Detected column (now at index 7, was 8)
                dataCell.cellStyle = value == 'Y'
                    ? defectYesStyle
                    : defectNoStyle;
              } else {
                dataCell.cellStyle = dataCellStyle;
              }
            }
            rowIndex++;
          }

          // Empty row between checklists
          rowIndex++;
        }

        // Set column widths for better readability
        sheet.setColumnWidth(0, 75); // Assessment Item (wider for questions)
        sheet.setColumnWidth(1, 15); // Executor Name
        sheet.setColumnWidth(2, 15); // Executor Answer
        sheet.setColumnWidth(3, 30); // Executor Comment
        sheet.setColumnWidth(4, 15); // Reviewer Name
        sheet.setColumnWidth(5, 15); // Reviewer Answer
        sheet.setColumnWidth(6, 30); // Reviewer Comment
        sheet.setColumnWidth(7, 20); // Defect Detected
        sheet.setColumnWidth(8, 20); // Defect Category
        sheet.setColumnWidth(9, 18); // Defect Severity
        sheet.setColumnWidth(10, 15); // Loopback Count
        sheet.setColumnWidth(11, 15); // Conflict Count

        print(
          '✓ $sheetName created with $totalCheckpoints checkpoints, $totalDefects defects',
        );
      } catch (e) {
        print('⚠️ Error processing phase: $e');
      }
    }
  }

  /// Normalize answer for comparison (Yes/No only)
  String _normalizeAnswer(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'yes' : 'no';
    if (value is String) return value.toLowerCase();
    return value.toString().toLowerCase();
  }

  /// Convert answer value to string (Yes/No/Null)
  String _convertAnswerToString(dynamic value) {
    if (value == null) return 'Null';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is String) {
      if (value.toLowerCase() == 'yes' || value == 'true') return 'Yes';
      if (value.toLowerCase() == 'no' || value == 'false') return 'No';
      return value;
    }
    return value.toString();
  }

  /// Convert any value to CellValue for Excel
  CellValue _toCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is String) return TextCellValue(value);
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }

  /// Format date to string
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
