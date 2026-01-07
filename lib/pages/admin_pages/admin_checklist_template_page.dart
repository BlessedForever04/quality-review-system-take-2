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

        // Auto-load 41 default categories if none exist or only old useless ones
        if (_defectCategories.isEmpty || _defectCategories.length <= 4) {
          print('?? Loading 41 default defect categories automatically...');
          _defectCategories = _getDefaultDefectCategories();
          // Save them to backend immediately
          _templateService
              .updateDefectCategories(_defectCategories)
              .then((_) {
                print('? Default categories saved to backend');
              })
              .catchError((e) {
                print('? Failed to save default categories: $e');
              });
        }

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
      final sectionsData = checklistData['sections'] as List<dynamic>? ?? [];

      // Parse direct questions on the group
      final questions = checkpointsData.map((cpData) {
        return TemplateQuestion(
          id: (cpData['_id'] ?? '').toString(),
          text: (cpData['text'] ?? '').toString(),
        );
      }).toList();

      // Parse sections with their questions
      final sections = sectionsData.map((sectionData) {
        final sectionId = (sectionData['_id'] ?? '').toString();
        final sectionText = (sectionData['text'] ?? '').toString();
        final sectionCheckpoints =
            sectionData['checkpoints'] as List<dynamic>? ?? [];

        final sectionQuestions = sectionCheckpoints.map((cpData) {
          return TemplateQuestion(
            id: (cpData['_id'] ?? '').toString(),
            text: (cpData['text'] ?? '').toString(),
          );
        }).toList();

        return TemplateSection(
          id: sectionId,
          name: sectionText,
          questions: sectionQuestions,
          expanded: false,
        );
      }).toList();

      return TemplateGroup(
        id: id,
        name: text,
        questions: questions,
        sections: sections,
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
        keywords:
            (catData['keywords'] as List<dynamic>?)
                ?.map((k) => k.toString())
                .toList() ??
            [],
      );
    }).toList();
  }

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

  // ID helpers removed - now using MongoDB IDs from backend

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
                  // Reload button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload Template',
                    onPressed: _isLoading ? null : _loadTemplate,
                  ),
                  // Manage Categories button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _manageCategories,
                    icon: const Icon(Icons.category),
                    label: const Text('Manage Categories'),
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
                            ),
                            _PhaseEditor(
                              key: const ValueKey('phase-2'),
                              phaseIndex: 1,
                              groups: _p2Groups,
                              onChanged: (g) => _setGroupsForPhase(1, g),
                              templateService: _templateService,
                              onReload: _loadTemplate,
                            ),
                            _PhaseEditor(
                              key: const ValueKey('phase-3'),
                              phaseIndex: 2,
                              groups: _p3Groups,
                              onChanged: (g) => _setGroupsForPhase(2, g),
                              templateService: _templateService,
                              onReload: _loadTemplate,
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

  const _PhaseEditor({
    super.key,
    required this.phaseIndex,
    required this.groups,
    required this.onChanged,
    required this.templateService,
    required this.onReload,
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

  /// Remove question (checkpoint) from backend
  Future<void> _removeQuestion(
    TemplateGroup group,
    TemplateSection? section,
    TemplateQuestion q,
  ) async {
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
        sectionId: section?.id,
      );

      // Update local state instead of reloading
      setState(() {
        if (section != null) {
          // Remove from section
          section.questions.removeWhere((question) => question.id == q.id);
        } else {
          // Remove from group
          group.questions.removeWhere((question) => question.id == q.id);
        }
      });
      widget.onChanged(_groups);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted successfully')),
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

  /// Add section to checklist group
  Future<void> _addSection(TemplateGroup group) async {
    final name = await _promptSectionName();
    if (name == null) return;

    setState(() => _isSaving = true);

    try {
      final response = await widget.templateService.addSection(
        checklistId: group.id,
        stage: _stage,
        sectionName: name,
      );

      // Parse response to get new section with ID
      final stageData = response[_stage] as List<dynamic>?;
      if (stageData != null) {
        final updatedGroup = stageData.firstWhere(
          (g) => g['_id'].toString() == group.id,
          orElse: () => null,
        );
        if (updatedGroup != null) {
          final sectionsData = updatedGroup['sections'] as List<dynamic>? ?? [];
          final newSectionData = sectionsData.last;
          final newSection = TemplateSection(
            id: newSectionData['_id'].toString(),
            name: newSectionData['text'].toString(),
            questions: [],
          );
          setState(() {
            group.sections.add(newSection);
          });
          widget.onChanged(_groups);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section added successfully')),
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

  /// Edit section in checklist group
  Future<void> _editSection(
    TemplateGroup group,
    TemplateSection section,
  ) async {
    final name = await _promptSectionName(initial: section.name);
    if (name == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.updateSection(
        checklistId: group.id,
        sectionId: section.id,
        stage: _stage,
        newName: name,
      );

      // Update local state instead of reloading
      setState(() {
        section.name = name;
      });
      widget.onChanged(_groups);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section updated successfully')),
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

  /// Delete section from checklist group
  Future<void> _removeSection(
    TemplateGroup group,
    TemplateSection section,
  ) async {
    final confirm = await _confirmDelete(
      title: 'Remove Section?',
      message: 'This will delete "${section.name}" and all its questions.',
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.deleteSection(
        checklistId: group.id,
        sectionId: section.id,
        stage: _stage,
      );

      // Update local state instead of reloading
      setState(() {
        group.sections.removeWhere((s) => s.id == section.id);
      });
      widget.onChanged(_groups);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section deleted successfully')),
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

  /// Update question method signature for optional section
  Future<void> _addQuestion(
    TemplateGroup group, {
    TemplateSection? section,
  }) async {
    final q = await _promptQuestion();
    if (q == null) return;

    setState(() => _isSaving = true);

    try {
      final response = await widget.templateService.addCheckpoint(
        checklistId: group.id,
        stage: _stage,
        questionText: q.text,
        sectionId: section?.id,
      );

      // Parse response to get new checkpoint with ID
      final stageData = response[_stage] as List<dynamic>?;
      if (stageData != null) {
        final updatedGroup = stageData.firstWhere(
          (g) => g['_id'].toString() == group.id,
          orElse: () => null,
        );
        if (updatedGroup != null) {
          if (section != null) {
            // Find the section and get the new checkpoint
            final sectionsData =
                updatedGroup['sections'] as List<dynamic>? ?? [];
            final updatedSection = sectionsData.firstWhere(
              (s) => s['_id'].toString() == section.id,
              orElse: () => null,
            );
            if (updatedSection != null) {
              final checkpointsData =
                  updatedSection['checkpoints'] as List<dynamic>? ?? [];
              if (checkpointsData.isNotEmpty) {
                final newCheckpoint = checkpointsData.last;
                setState(() {
                  section.questions.add(
                    TemplateQuestion(
                      id: newCheckpoint['_id'].toString(),
                      text: newCheckpoint['text'].toString(),
                    ),
                  );
                });
              }
            }
          } else {
            // Add to group directly
            final checkpointsData =
                updatedGroup['checkpoints'] as List<dynamic>? ?? [];
            if (checkpointsData.isNotEmpty) {
              final newCheckpoint = checkpointsData.last;
              setState(() {
                group.questions.add(
                  TemplateQuestion(
                    id: newCheckpoint['_id'].toString(),
                    text: newCheckpoint['text'].toString(),
                  ),
                );
              });
            }
          }
          widget.onChanged(_groups);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question added successfully')),
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

  /// Edit question with optional section parameter
  Future<void> _editQuestion(
    TemplateGroup group,
    TemplateSection? section,
    TemplateQuestion question,
  ) async {
    final updated = await _promptQuestion(initial: question);
    if (updated == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.templateService.updateCheckpoint(
        checkpointId: question.id,
        checklistId: group.id,
        stage: _stage,
        newText: updated.text,
        sectionId: section?.id,
      );

      // Update local state instead of reloading
      setState(() {
        question.text = updated.text;
        question.hasRemark = updated.hasRemark;
        question.remarkHint = updated.remarkHint;
      });
      widget.onChanged(_groups);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
                            // Direct questions on the group
                            ...group.questions.map(
                              (q) => _QuestionRow(
                                question: q,
                                onEdit: () => _editQuestion(group, null, q),
                                onDelete: () => _removeQuestion(group, null, q),
                              ),
                            ),
                            // Sections (optional containers)
                            ...group.sections.map((section) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: Colors.grey[50],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Colors.black12,
                                    width: 1,
                                  ),
                                ),
                                child: ExpansionTile(
                                  initiallyExpanded: section.expanded,
                                  onExpansionChanged: (v) =>
                                      setState(() => section.expanded = v),
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  title: Text(
                                    section.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit Section',
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () =>
                                            _editSection(group, section),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Section',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _removeSection(group, section),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    // Questions in this section
                                    ...section.questions.map((q) {
                                      return _QuestionRow(
                                        question: q,
                                        onEdit: () =>
                                            _editQuestion(group, section, q),
                                        onDelete: () =>
                                            _removeQuestion(group, section, q),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => _addQuestion(
                                          group,
                                          section: section,
                                        ),
                                        style: TextButton.styleFrom(
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Add Question'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            // Buttons to add direct question or section
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _addQuestion(group),
                                  style: TextButton.styleFrom(
                                    textStyle: const TextStyle(fontSize: 14),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Question'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _addSection(group),
                                  style: TextButton.styleFrom(
                                    textStyle: const TextStyle(fontSize: 14),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Section'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// UI: Single question row with Yes/No preview radios and optional remark field (disabled preview)
class _QuestionRow extends StatelessWidget {
  final TemplateQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionRow({
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              question.text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
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
  });

  final String id;
  String text;
  bool hasRemark;
  String? remarkHint;

  TemplateQuestion copy() => TemplateQuestion(
    id: id,
    text: text,
    hasRemark: hasRemark,
    remarkHint: remarkHint,
  );
}

// Section model for optional section containers within groups
class TemplateSection {
  TemplateSection({
    required this.id,
    required this.name,
    this.questions = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  bool expanded;

  TemplateSection copy() => TemplateSection(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
  );
}

class DefectCategory {
  DefectCategory({
    required this.id,
    required this.name,
    this.keywords = const [],
  });

  final String id;
  String name;
  List<String> keywords;

  DefectCategory copy() =>
      DefectCategory(id: id, name: name, keywords: List<String>.from(keywords));

  Map<String, dynamic> toJson() {
    final json = {'name': name, 'keywords': keywords};
    // Only include _id if it looks like a MongoDB ObjectId (24 hex chars)
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
    this.sections = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  List<TemplateSection> sections;
  bool expanded;

  TemplateGroup copy() => TemplateGroup(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
    sections: sections.map((s) => s.copy()).toList(),
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

Future<TemplateQuestion?> _promptQuestion({TemplateQuestion? initial}) async {
  return await showDialog<TemplateQuestion>(
    context: Get.context!,
    builder: (ctx) => _QuestionDialog(initial: initial),
  );
}

Future<String?> _promptSectionName({String? initial}) async {
  return await _textPrompt(
    title: initial == null ? 'Add Section' : 'Edit Section',
    label: 'Section Name',
    initial: initial,
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

// Question Dialog (without category selection)
// Note: Defect categories are assigned during review, not in the template
class _QuestionDialog extends StatefulWidget {
  final TemplateQuestion? initial;

  const _QuestionDialog({this.initial});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initial?.text ?? '');
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
            );
            Navigator.pop(context, question);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Default seed categories with keywords
List<DefectCategory> _getDefaultDefectCategories() {
  return [
    // Geometry/Modeling Issues (6)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_1',
      name: 'Incorrect Modelling Strategy - Geometry',
      keywords: [
        'geometry',
        'modelling',
        'model',
        'incorrect strategy',
        'geometric',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_2',
      name: 'Incorrect Modelling Strategy - Material',
      keywords: [
        'material',
        'modelling',
        'properties',
        'material properties',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_3',
      name: 'Incorrect Modelling Strategy - Loads',
      keywords: [
        'loads',
        'loading',
        'force',
        'boundary condition',
        'load case',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_4',
      name: 'Incorrect Modelling Strategy - BC',
      keywords: ['bc', 'boundary condition', 'constraint', 'support', 'fixed'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_5',
      name: 'Incorrect Modelling Strategy - Assumptions',
      keywords: [
        'assumptions',
        'assumption',
        'simplification',
        'unclear',
        'not documented',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_6',
      name: 'Incorrect Modelling Strategy - Acceptance Criteria',
      keywords: [
        'acceptance',
        'criteria',
        'acceptance criteria',
        'requirements',
        'specification',
      ],
    ),
    // Mesh Issues (7)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_7',
      name: 'Incorrect geometry units',
      keywords: ['units', 'geometry units', 'mm', 'cm', 'meter', 'measurement'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_8',
      name: 'Incorrect meshing',
      keywords: ['meshing', 'mesh', 'element', 'discretization', 'refinement'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_9',
      name: 'Defective mesh quality',
      keywords: [
        'mesh quality',
        'defective',
        'aspect ratio',
        'distorted',
        'poor quality',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_10',
      name: 'Incorrect contact definition',
      keywords: [
        'contact',
        'contact definition',
        'interface',
        'interaction',
        'friction',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_11',
      name: 'Incorrect beam/bolt modeling',
      keywords: ['beam', 'bolt', 'modeling', 'connection', 'fastener'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_12',
      name: 'RBE/RBE3 are not modeled properly',
      keywords: ['rbe', 'rbe3', 'rigid element', 'constraint', 'coupling'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_13',
      name: 'Incorrect loads and Boundary Condition',
      keywords: [
        'loads',
        'boundary condition',
        'load application',
        'force',
        'constraint',
      ],
    ),
    // Element/Quality Issues (8)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_14',
      name: 'Incorrect connectivity',
      keywords: [
        'connectivity',
        'nodes',
        'element connectivity',
        'connection',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_15',
      name: 'Incorrect degree of element order',
      keywords: [
        'degree of element',
        'order',
        'linear',
        'quadratic',
        'polynomial',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_16',
      name: 'Incorrect element quality',
      keywords: [
        'element quality',
        'distorted',
        'skewed',
        'aspect ratio',
        'defective',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_17',
      name: 'Incorrect bolt size',
      keywords: ['bolt', 'size', 'diameter', 'incorrect', 'dimension'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_18',
      name: 'Incorrect elements order',
      keywords: ['elements', 'order', 'sequence', 'incorrect', 'wrong'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_19',
      name: 'Incorrect elements quality',
      keywords: ['elements', 'quality', 'poor', 'defective', 'invalid'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_20',
      name: 'Incorrect end loads',
      keywords: ['end loads', 'terminal loads', 'force', 'moment', 'incorrect'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_21',
      name: 'Too refined mesh at the non critical regions',
      keywords: [
        'refined mesh',
        'over meshing',
        'unnecessary refinement',
        'non critical',
        'wasteful',
      ],
    ),
    // Support/Scope Issues (4)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_22',
      name: 'Support Gap',
      keywords: [
        'support',
        'gap',
        'missing support',
        'incomplete support',
        'void',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_23',
      name: 'Support Location',
      keywords: [
        'support',
        'location',
        'positioning',
        'placement',
        'incorrect position',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_24',
      name: 'Incorrect Scope',
      keywords: ['scope', 'boundary', 'region', 'area', 'out of scope'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_25',
      name: 'free pages',
      keywords: ['free pages', 'blank pages', 'empty', 'unneeded'],
    ),
    // Material/Properties (2)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_26',
      name: 'Incorrect mass modeling',
      keywords: ['mass', 'mass modeling', 'density', 'weight', 'incorrect'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_27',
      name: 'Incorrect material properties',
      keywords: [
        'material',
        'properties',
        'young modulus',
        'poisson',
        'density',
        'incorrect',
      ],
    ),
    // Output/Request Issues (3)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_28',
      name: 'Incorrect global output request',
      keywords: [
        'global output',
        'output request',
        'results request',
        'missing output',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_29',
      name: 'Incorrect loadstep creation',
      keywords: [
        'loadstep',
        'load step',
        'step creation',
        'load case',
        'step definition',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_30',
      name: 'Incorrect output request',
      keywords: ['output', 'request', 'results', 'incorrect', 'missing'],
    ),
    // Results/Analysis Issues (5)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_31',
      name: 'Incorrect Interpretation',
      keywords: [
        'interpretation',
        'analysis',
        'conclusion',
        'incorrect',
        'misunderstood',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_32',
      name: 'Incorrect Results location and Values',
      keywords: [
        'results',
        'values',
        'location',
        'incorrect',
        'wrong',
        'mismatch',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_33',
      name: 'Incorrect Observation',
      keywords: ['observation', 'comment', 'note', 'incorrect', 'inaccurate'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_34',
      name: 'Incorrect Naming',
      keywords: ['naming', 'name', 'label', 'title', 'incorrect', 'misspelled'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_35',
      name: 'Missing Results Plot',
      keywords: ['results', 'plot', 'graph', 'chart', 'missing', 'absent'],
    ),
    // Documentation (3)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_36',
      name: 'Incomplete conclusion, suggestions',
      keywords: [
        'conclusion',
        'suggestions',
        'incomplete',
        'missing',
        'recommendations',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_37',
      name: 'Template not followed',
      keywords: [
        'template',
        'followed',
        'not followed',
        'deviation',
        'non compliance',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_38',
      name: 'Checklist not followed',
      keywords: [
        'checklist',
        'followed',
        'not followed',
        'incomplete',
        'skipped',
      ],
    ),
    // Process (3)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_39',
      name: 'Planning sheet not followed',
      keywords: [
        'planning sheet',
        'plan',
        'not followed',
        'deviation',
        'unplanned',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_40',
      name: 'Folder Structure not followed',
      keywords: [
        'folder structure',
        'directory',
        'organization',
        'not followed',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_41',
      name: 'Name/revision report incorrect',
      keywords: [
        'name',
        'revision',
        'report',
        'incorrect',
        'wrong',
        'mismatch',
      ],
    ),
    // Other (1)
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_42',
      name: 'Typo Textual Error',
      keywords: ['typo', 'spelling', 'grammar', 'text', 'error', 'mistake'],
    ),
  ];
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
          ),
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
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        _categories.add(
          DefectCategory(
            id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
            name: nameController.text.trim(),
          ),
        );
      });
    }
  }

  void _loadDefaultCategories() {
    setState(() {
      _categories = _getDefaultDefectCategories();
    });
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
        width: 700,
        height: 500,
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
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(
                                cat.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: cat.keywords.isNotEmpty
                                  ? Text(
                                      'Keywords: ${cat.keywords.join(", ")}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteCategory(i),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _loadDefaultCategories,
                  icon: const Icon(Icons.download),
                  label: const Text('Load Default Categories'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ],
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
