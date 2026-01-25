import 'package:get/get.dart';
import '../models/project_template.dart';
import '../models/stage_template.dart';
import '../models/checklist_template.dart';
import '../services/template_service.dart';

export '../models/checklist_template.dart';

/// Controller for managing project templates
/// Handles CRUD operations for templates, stages, and checklists
class TemplateManagementController extends GetxController {
  final TemplateService templateService = Get.find<TemplateService>();

  // Observable lists
  final RxList<ProjectTemplate> templates = RxList<ProjectTemplate>();
  final RxList<ChecklistTemplate> checklists = RxList<ChecklistTemplate>();

  // Current state
  final Rx<ProjectTemplate?> currentTemplate = Rx<ProjectTemplate?>(null);
  final RxBool isLoading = RxBool(false);
  final RxString errorMessage = RxString('');

  @override
  void onInit() {
    super.onInit();
    _loadTemplates();
    _loadChecklists();
  }

  /// Load all project templates from backend
  Future<void> _loadTemplates() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      // This would be implemented in the backend
      // For now, initialize with empty list
      templates.value = [];
    } catch (e) {
      errorMessage.value = 'Error loading templates: $e';
      print('❌ Error loading templates: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load all checklist templates from backend
  Future<void> _loadChecklists() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      // This would be implemented in the backend
      // For now, initialize with empty list
      checklists.value = [];
    } catch (e) {
      errorMessage.value = 'Error loading checklists: $e';
      print('❌ Error loading checklists: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a new project template
  Future<ProjectTemplate?> createProjectTemplate({
    required String name,
    required String description,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final newTemplate = ProjectTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        stages: [],
        createdAt: DateTime.now(),
      );

      templates.add(newTemplate);
      currentTemplate.value = newTemplate;

      print('✅ Project template created: ${newTemplate.name}');
      return newTemplate;
    } catch (e) {
      errorMessage.value = 'Error creating template: $e';
      print('❌ Error creating template: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a project template
  Future<bool> updateProjectTemplate(ProjectTemplate template) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final index = templates.indexWhere((t) => t.id == template.id);
      if (index >= 0) {
        templates[index] = template.copyWith(updatedAt: DateTime.now());
        if (currentTemplate.value?.id == template.id) {
          currentTemplate.value = templates[index];
        }
        print('✅ Template updated: ${template.name}');
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = 'Error updating template: $e';
      print('❌ Error updating template: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a project template
  Future<bool> deleteProjectTemplate(String templateId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      templates.removeWhere((t) => t.id == templateId);
      if (currentTemplate.value?.id == templateId) {
        currentTemplate.value = null;
      }
      print('✅ Template deleted: $templateId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error deleting template: $e';
      print('❌ Error deleting template: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a stage to a template
  Future<bool> addStageToTemplate({
    required String templateId,
    required String stageName,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final template = templates.firstWhereOrNull((t) => t.id == templateId);
      if (template == null) return false;

      final newStage = StageTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: stageName,
        order: template.stages.length + 1,
        checklistIds: [],
        createdAt: DateTime.now(),
      );

      final updatedTemplate = template.addStage(newStage);
      await updateProjectTemplate(updatedTemplate);

      print('✅ Stage added: $stageName to template: $templateId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error adding stage: $e';
      print('❌ Error adding stage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a stage in a template
  Future<bool> updateStageInTemplate({
    required String templateId,
    required StageTemplate updatedStage,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final template = templates.firstWhereOrNull((t) => t.id == templateId);
      if (template == null) return false;

      final updatedTemplate = template.updateStage(updatedStage);
      await updateProjectTemplate(updatedTemplate);

      print('✅ Stage updated: ${updatedStage.name}');
      return true;
    } catch (e) {
      errorMessage.value = 'Error updating stage: $e';
      print('❌ Error updating stage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove a stage from a template
  Future<bool> removeStageFromTemplate({
    required String templateId,
    required String stageId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final template = templates.firstWhereOrNull((t) => t.id == templateId);
      if (template == null) return false;

      final updatedTemplate = template.removeStage(stageId);
      await updateProjectTemplate(updatedTemplate);

      print('✅ Stage removed: $stageId from template: $templateId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error removing stage: $e';
      print('❌ Error removing stage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add checklist to a stage
  Future<bool> addChecklistToStage({
    required String templateId,
    required String stageId,
    required String checklistId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final template = templates.firstWhereOrNull((t) => t.id == templateId);
      if (template == null) return false;

      final stage = template.getStageById(stageId);
      if (stage == null) return false;

      final updatedStage = stage.addChecklist(checklistId);
      final updatedTemplate = template.updateStage(updatedStage);
      await updateProjectTemplate(updatedTemplate);

      print('✅ Checklist added to stage: $stageId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error adding checklist to stage: $e';
      print('❌ Error adding checklist to stage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove checklist from a stage
  Future<bool> removeChecklistFromStage({
    required String templateId,
    required String stageId,
    required String checklistId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final template = templates.firstWhereOrNull((t) => t.id == templateId);
      if (template == null) return false;

      final stage = template.getStageById(stageId);
      if (stage == null) return false;

      final updatedStage = stage.removeChecklist(checklistId);
      final updatedTemplate = template.updateStage(updatedStage);
      await updateProjectTemplate(updatedTemplate);

      print('✅ Checklist removed from stage: $stageId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error removing checklist from stage: $e';
      print('❌ Error removing checklist from stage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a new checklist template
  Future<ChecklistTemplate?> createChecklistTemplate({
    required String name,
    required String description,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final newChecklist = ChecklistTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        sections: [],
        createdAt: DateTime.now(),
      );

      checklists.add(newChecklist);
      print('✅ Checklist template created: ${newChecklist.name}');
      return newChecklist;
    } catch (e) {
      errorMessage.value = 'Error creating checklist: $e';
      print('❌ Error creating checklist: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a checklist template
  Future<bool> updateChecklistTemplate(ChecklistTemplate checklist) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final index = checklists.indexWhere((c) => c.id == checklist.id);
      if (index >= 0) {
        checklists[index] = checklist.copyWith(updatedAt: DateTime.now());
        print('✅ Checklist updated: ${checklist.name}');
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = 'Error updating checklist: $e';
      print('❌ Error updating checklist: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a checklist template
  Future<bool> deleteChecklistTemplate(String checklistId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      checklists.removeWhere((c) => c.id == checklistId);
      print('✅ Checklist deleted: $checklistId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error deleting checklist: $e';
      print('❌ Error deleting checklist: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a section to a checklist
  Future<bool> addSectionToChecklist({
    required String checklistId,
    required String sectionName,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final newSection = ChecklistSection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: sectionName,
        questions: [],
      );

      final updatedChecklist = checklist.addSection(newSection);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Section added to checklist: $checklistId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error adding section: $e';
      print('❌ Error adding section: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a section in a checklist
  Future<bool> updateSectionInChecklist({
    required String checklistId,
    required ChecklistSection updatedSection,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final updatedChecklist = checklist.updateSection(updatedSection);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Section updated in checklist: $checklistId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error updating section: $e';
      print('❌ Error updating section: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove a section from a checklist
  Future<bool> removeSectionFromChecklist({
    required String checklistId,
    required String sectionId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final updatedChecklist = checklist.removeSection(sectionId);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Section removed from checklist: $checklistId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error removing section: $e';
      print('❌ Error removing section: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a question to a section in a checklist
  Future<bool> addQuestionToSection({
    required String checklistId,
    required String sectionId,
    required String questionText,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final section = checklist.sections.firstWhereOrNull(
        (s) => s.id == sectionId,
      );
      if (section == null) return false;

      final newQuestion = ChecklistQuestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: questionText,
      );

      final updatedSection = section.addQuestion(newQuestion);
      final updatedChecklist = checklist.updateSection(updatedSection);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Question added to section: $sectionId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error adding question: $e';
      print('❌ Error adding question: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove a question from a section
  Future<bool> removeQuestionFromSection({
    required String checklistId,
    required String sectionId,
    required String questionId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final section = checklist.sections.firstWhereOrNull(
        (s) => s.id == sectionId,
      );
      if (section == null) return false;

      final updatedSection = section.removeQuestion(questionId);
      final updatedChecklist = checklist.updateSection(updatedSection);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Question removed from section: $sectionId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error removing question: $e';
      print('❌ Error removing question: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a question in a section
  Future<bool> updateQuestionInSection({
    required String checklistId,
    required String sectionId,
    required ChecklistQuestion updatedQuestion,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final checklist = checklists.firstWhereOrNull((c) => c.id == checklistId);
      if (checklist == null) return false;

      final section = checklist.sections.firstWhereOrNull(
        (s) => s.id == sectionId,
      );
      if (section == null) return false;

      final updatedSection = section.updateQuestion(updatedQuestion);
      final updatedChecklist = checklist.updateSection(updatedSection);
      await updateChecklistTemplate(updatedChecklist);

      print('✅ Question updated in section: $sectionId');
      return true;
    } catch (e) {
      errorMessage.value = 'Error updating question: $e';
      print('❌ Error updating question: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
