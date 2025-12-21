import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/template_service.dart';

// Admin Checklist Template Management Page
// - 3 phases (P1, P2, P3) with backend integration
// - Manage Checklist Groups (add/edit/delete)
// - Manage Questions within each group (add/edit/delete)
// - All operations persist to database via TemplateService
// - Phase data loaded from MongoDB template singleton

class AdminChecklistTemplatePage extends StatefulWidget {
  const AdminChecklistTemplatePage({super.key});

  @override
  State<AdminChecklistTemplatePage> createState() =>
      _AdminChecklistTemplatePageState();
}

class _AdminChecklistTemplatePageState extends State<AdminChecklistTemplatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Independent state per phase
  late List<TemplateGroup> _p1Groups;
  late List<TemplateGroup> _p2Groups;
  late List<TemplateGroup> _p3Groups;

  // Defect categories
  late List<DefectCategory> _defectCategories;

  bool _isLoading = true;
  String? _errorMessage;

  // Getter for TemplateService - ensures it's always available
  TemplateService get _templateService => Get.find<TemplateService>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize empty lists
    _p1Groups = [];
    _p2Groups = [];
    _p3Groups = [];
    _defectCategories = [];

    // Load template from backend
    _loadTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load template from backend database
  Future<void> _loadTemplate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch template from backend
      final templateData = await _templateService.fetchTemplate();

      setState(() {
        // Parse stage1 (Phase 1)
        _p1Groups = _parseStageData(templateData['stage1'] ?? []);

        // Parse stage2 (Phase 2)
        _p2Groups = _parseStageData(templateData['stage2'] ?? []);

        // Parse stage3 (Phase 3)
        _p3Groups = _parseStageData(templateData['stage3'] ?? []);

        // Parse defect categories
        _defectCategories = _parseDefectCategories(
          templateData['defectCategories'] ?? [],
        );

        _isLoading = false;
      });
    } catch (e) {
      // If template doesn't exist, create it
      if (e.toString().contains('Template not found')) {
        try {
          await _templateService.createOrUpdateTemplate();
          // Retry loading
          await _loadTemplate();
        } catch (createError) {
          setState(() {
            _errorMessage = 'Failed to create template: $createError';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error loading template: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Parse backend stage data into TemplateGroup list
  List<TemplateGroup> _parseStageData(List<dynamic> stageData) {
    return stageData.map((checklistData) {
      final id = (checklistData['_id'] ?? '').toString();
      final text = (checklistData['text'] ?? '').toString();
      final checkpointsData =
          checklistData['checkpoints'] as List<dynamic>? ?? [];

      final questions = checkpointsData.map((cpData) {
        return TemplateQuestion(
          id: (cpData['_id'] ?? '').toString(),
          text: (cpData['text'] ?? '').toString(),
          categoryId: (cpData['categoryId'] ?? '').toString().isEmpty
              ? null
              : (cpData['categoryId'] ?? '').toString(),
        );
      }).toList();

      return TemplateGroup(
        id: id,
        name: text,
        questions: questions,
        expanded: false,
      );
    }).toList();
  }

  /// Parse defect categories from backend
  List<DefectCategory> _parseDefectCategories(List<dynamic> categoriesData) {
    return categoriesData.map((catData) {
      return DefectCategory(
        id: (catData['_id'] ?? '').toString(),
        name: (catData['name'] ?? '').toString(),
        color: Color(
          int.parse(
            (catData['color'] ?? 'FF2196F3').substring(0, 8),
            radix: 16,
          ),
        ),
      );
    }).toList();
  }

  // ID helpers removed - now using MongoDB IDs from backend

  /// Manage defect categories
  Future<void> _manageCategories() async {
    await showDialog(
      context: context,
      builder: (ctx) => _DefectCategoryManager(
        categories: _defectCategories,
        onSave: (updatedCategories) async {
          setState(() => _isLoading = true);
          try {
            // Save to backend
            await _templateService.updateDefectCategories(updatedCategories);
            await _loadTemplate();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Categories updated successfully'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
      ),
    );
  }

  void _setGroupsForPhase(int index, List<TemplateGroup> groups) {
    setState(() {
      switch (index) {
        case 0:
          _p1Groups = groups;
          break;
        case 1:
          _p2Groups = groups;
          break;
        case 2:
        default:
          _p3Groups = groups;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Checklist Template Management',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                  // Manage Categories button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _manageCategories,
                    icon: const Icon(Icons.category),
                    label: const Text('Manage Categories'),
                  ),
                  const SizedBox(width: 8),
                  // Reload button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload Template',
                    onPressed: _isLoading ? null : _loadTemplate,
                  ),
                ],
              ),
            ),

            // Loading or error state
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading template...'),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTemplate,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Phase tabs
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF2196F3),
                        unselectedLabelColor: Colors.black87,
                        indicatorColor: const Color(0xFF2196F3),
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Phase 1'),
                          Tab(text: 'Phase 2'),
                          Tab(text: 'Phase 3'),
                        ],
                      ),
                      SizedBox(
                        height: 12,
                        child: Container(
                          color: Colors.black12,
                          width: double.infinity,
                          height: 1,
                        ),
                      ),
                      // Fill remaining space with TabBarView to avoid overflow
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _PhaseEditor(
                              key: const ValueKey('phase-1'),
                              phaseIndex: 0,
                              groups: _p1Groups,
                              onChanged: (g) => _setGroupsForPhase(0, g),
                              templateService: _templateService,
                              onReload: _loadTemplate,
                              defectCategories: _defectCategories,
                            ),
                            _PhaseEditor(
                              key: const ValueKey('phase-2'),
                              phaseIndex: 1,
                              groups: _p2Groups,
                              onChanged: (g) => _setGroupsForPhase(1, g),
                              templateService: _templateService,
                              onReload: _loadTemplate,
                              defectCategories: _defectCategories,
                            ),
                            _PhaseEditor(
                              key: const ValueKey('phase-3'),
                              phaseIndex: 2,
                              groups: _p3Groups,
                              onChanged: (g) => _setGroupsForPhase(2, g),
                              templateService: _templateService,
                              onReload: _loadTemplate,
                              defectCategories: _defectCategories,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PhaseEditor extends StatefulWidget {
  final int phaseIndex;
  final List<TemplateGroup> groups;
  final ValueChanged<List<TemplateGroup>> onChanged;
  final TemplateService templateService;
  final Future<void> Function() onReload;
  final List<DefectCategory> defectCategories;

  const _PhaseEditor({
    super.key,
    required this.phaseIndex,
    required this.groups,
    required this.onChanged,
    required this.templateService,
    required this.onReload,
    required this.defectCategories,
  });

  @override
  State<_PhaseEditor> createState() => _PhaseEditorState();
}

class _PhaseEditorState extends State<_PhaseEditor> {
  late List<TemplateGroup> _groups;
  bool _isSaving = false;

  String get _stage => 'stage${widget.phaseIndex + 1}';

  @override
  void initState() {
    super.initState();
    _groups = widget.groups.map((g) => g.copy()).toList();
  }

  @override
  void didUpdateWidget(covariant _PhaseEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.groups, widget.groups)) {
      _groups = widget.groups.map((g) => g.copy()).toList();
    }
  }

  /// Add checklist group to backend
  Future<void> _addGroup() async {
    final name = await _promptGroupName();
    if (name == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.addChecklist(
        stage: _stage,
        checklistName: name,
      );

      // Reload to get updated data with MongoDB IDs
      await widget.onReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist group added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Edit checklist group in backend
  Future<void> _editGroup(TemplateGroup group) async {
    final name = await _promptGroupName(initial: group.name);
    if (name == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.updateChecklist(
        checklistId: group.id,
        stage: _stage,
        newName: name,
      );

      await widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist group updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Remove checklist group from backend
  Future<void> _removeGroup(TemplateGroup group) async {
    final confirm = await _confirmDelete(
      title: 'Remove Checklist Group?',
      message: 'This will delete "${group.name}" and its questions.',
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.deleteChecklist(
        checklistId: group.id,
        stage: _stage,
      );

      await widget.onReload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Add question (checkpoint) to backend
  Future<void> _addQuestion(TemplateGroup group) async {
    final q = await _promptQuestion(categories: widget.defectCategories);
    if (q == null) return;

    setState(() => _isSaving = true);

    try {
      final response = await widget.templateService.addCheckpoint(
        checklistId: group.id,
        stage: _stage,
        questionText: q.text,
        categoryId: q.categoryId,
      );
      final stageData = response[_stage] as List<dynamic>?;
      var appliedFromResponse = false;

      if (stageData != null) {
        Map<String, dynamic>? updatedGroupData;
        for (final item in stageData) {
          if (item is Map<String, dynamic> &&
              item['_id']?.toString() == group.id) {
            updatedGroupData = item;
            break;
          }
        }

        if (updatedGroupData != null) {
          final questionsData =
              (updatedGroupData['checkpoints'] as List<dynamic>? ?? []);
          final updatedQuestions = questionsData
              .map(
                (cp) => TemplateQuestion(
                  id: (cp['_id'] ?? '').toString(),
                  text: (cp['text'] ?? '').toString(),
                  categoryId: (cp['categoryId'] ?? '').toString().isEmpty
                      ? null
                      : (cp['categoryId'] ?? '').toString(),
                ),
              )
              .toList();

          setState(() {
            _groups = _groups.map((g) {
              if (g.id == group.id) {
                return TemplateGroup(
                  id: g.id,
                  name: g.name,
                  questions: updatedQuestions,
                  expanded: g.expanded,
                );
              }
              return g;
            }).toList();
          });
          widget.onChanged(_groups);
          appliedFromResponse = true;
        }
      }

      if (!appliedFromResponse) {
        setState(() {
          _groups = _groups.map((g) {
            if (g.id == group.id) {
              return TemplateGroup(
                id: g.id,
                name: g.name,
                questions: [
                  ...g.questions,
                  TemplateQuestion(id: q.id, text: q.text),
                ],
                expanded: g.expanded,
              );
            }
            return g;
          }).toList();
        });
        widget.onChanged(_groups);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Edit question (checkpoint) in backend
  Future<void> _editQuestion(
    TemplateGroup group,
    TemplateQuestion question,
  ) async {
    final updated = await _promptQuestion(
      initial: question,
      categories: widget.defectCategories,
    );
    if (updated == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.updateCheckpoint(
        checkpointId: question.id,
        checklistId: group.id,
        stage: _stage,
        newText: updated.text,
        categoryId: updated.categoryId,
      );

      await widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Remove question (checkpoint) from backend
  Future<void> _removeQuestion(TemplateGroup group, TemplateQuestion q) async {
    final confirm = await _confirmDelete(
      title: 'Remove Question?',
      message: 'This will delete the selected question.',
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.deleteCheckpoint(
        checkpointId: q.id,
        checklistId: group.id,
        stage: _stage,
      );

      await widget.onReload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _isSaving ? null : _addGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Checklist Group'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _groups.isEmpty
                    ? _EmptyState(
                        title: 'No checklist groups yet',
                        subtitle: 'Click "Add Checklist Group" to create one.',
                      )
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, i) {
                          final group = _groups[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.black12),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: group.expanded,
                              onExpansionChanged: (v) =>
                                  setState(() => group.expanded = v),
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              leading: const Icon(
                                Icons.view_list,
                                color: Color(0xFF2196F3),
                              ),
                              title: Text(
                                group.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 26,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit Group',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editGroup(group),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete Group',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeGroup(group),
                                  ),
                                ],
                              ),
                              children: [
                                // Questions list
                                ...group.questions.map(
                                  (q) => _QuestionRow(
                                    question: q,
                                    onEdit: () => _editQuestion(group, q),
                                    onDelete: () => _removeQuestion(group, q),
                                    defectCategories: widget.defectCategories,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _addQuestion(group),
                                    style: TextButton.styleFrom(
                                      textStyle: const TextStyle(fontSize: 16),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Question'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Loading overlay when saving
        if (_isSaving)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// UI: Single question row with Yes/No preview radios and optional remark field (disabled preview)
class _QuestionRow extends StatelessWidget {
  final TemplateQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<DefectCategory> defectCategories;

  const _QuestionRow({
    required this.question,
    required this.onEdit,
    required this.onDelete,
    required this.defectCategories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = defectCategories.firstWhere(
      (c) => c.id == question.categoryId,
      orElse: () =>
          DefectCategory(id: '', name: 'Uncategorized', color: Colors.grey),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.text,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: category.color),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: category.color.computeLuminance() > 0.5
                              ? Colors.black
                              : category.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Edit Question',
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete Question',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
          // Remark preview removed per requirement
        ],
      ),
    );
  }
}

// Models (kept simple and local)
// Removed Yes/No preview state per requirement

class TemplateQuestion {
  TemplateQuestion({
    required this.id,
    required this.text,
    this.hasRemark = false,
    this.remarkHint,
    this.categoryId,
  });

  final String id;
  String text;
  bool hasRemark;
  String? remarkHint;
  String? categoryId;
  // PreviewAnswer removed

  TemplateQuestion copy() => TemplateQuestion(
    id: id,
    text: text,
    hasRemark: hasRemark,
    remarkHint: remarkHint,
    categoryId: categoryId,
  );
}

class DefectCategory {
  DefectCategory({required this.id, required this.name, required this.color});

  final String id;
  String name;
  Color color;

  DefectCategory copy() => DefectCategory(id: id, name: name, color: color);

  Map<String, dynamic> toJson() {
    final json = {
      'name': name,
      'color': color.value.toRadixString(16).padLeft(8, '0'),
    };
    // Only include _id if it looks like a MongoDB ObjectId (24 hex chars)
    // Don't include temporary client-side IDs
    if (id.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
      json['_id'] = id;
    }
    return json;
  }
}

class TemplateGroup {
  TemplateGroup({
    required this.id,
    required this.name,
    this.questions = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  bool expanded;

  TemplateGroup copy() => TemplateGroup(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
  );
}

// Dialogs & helpers
Future<String?> _promptGroupName({String? initial}) async {
  return await _textPrompt(
    title: initial == null ? 'Add Checklist Group' : 'Edit Checklist Group',
    label: 'Group Name',
    initial: initial,
  );
}

Future<TemplateQuestion?> _promptQuestion({
  TemplateQuestion? initial,
  List<DefectCategory> categories = const [],
}) async {
  return await showDialog<TemplateQuestion>(
    context: Get.context!,
    builder: (ctx) => _QuestionDialog(initial: initial, categories: categories),
  );
}

Future<String?> _textPrompt({
  required String title,
  required String label,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  const dialogWidth = 460.0;
  return showDialog<String>(
    context: Get.context!,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<bool?> _confirmDelete({
  required String title,
  required String message,
}) async {
  return showDialog<bool>(
    context: Get.context!,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// A very small empty state widget to keep consistent styling.
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// Question Dialog with Category Selection
class _QuestionDialog extends StatefulWidget {
  final TemplateQuestion? initial;
  final List<DefectCategory> categories;

  const _QuestionDialog({this.initial, required this.categories});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _textController;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initial?.text ?? '');
    _selectedCategoryId = widget.initial?.categoryId;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Defect Category',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: const Text('Select category'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  ...widget.categories.map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(cat.name),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isEmpty) {
              Navigator.pop(context);
              return;
            }

            final question = TemplateQuestion(
              id:
                  widget.initial?.id ??
                  'q_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
              text: text,
              categoryId: _selectedCategoryId,
            );
            Navigator.pop(context, question);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Defect Category Manager Dialog
class _DefectCategoryManager extends StatefulWidget {
  final List<DefectCategory> categories;
  final Future<void> Function(List<DefectCategory>) onSave;

  const _DefectCategoryManager({
    required this.categories,
    required this.onSave,
  });

  @override
  State<_DefectCategoryManager> createState() => _DefectCategoryManagerState();
}

class _DefectCategoryManagerState extends State<_DefectCategoryManager> {
  late List<DefectCategory> _categories;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categories = widget.categories.map((c) => c.copy()).toList();
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF2196F3);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children:
                    [
                      Colors.red,
                      Colors.orange,
                      Colors.yellow,
                      Colors.green,
                      Colors.blue,
                      Colors.purple,
                      Colors.pink,
                      Colors.teal,
                    ].map((color) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() => selectedColor = color);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedColor == color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        _categories.add(
          DefectCategory(
            id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
            name: nameController.text.trim(),
            color: selectedColor,
          ),
        );
      });
    }
  }

  void _deleteCategory(int index) {
    setState(() {
      _categories.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Defect Categories'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: _categories.isEmpty
                  ? const Center(
                      child: Text('No categories yet. Add one to get started.'),
                    )
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) {
                        final cat = _categories[i];
                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(cat.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteCategory(i),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _addCategory,
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onSave(_categories);
                    if (mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// Uses Get.context to open dialogs without passing BuildContext around.
