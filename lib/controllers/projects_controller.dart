import 'package:get/get.dart';
import '../models/project.dart';
import '../services/project_service.dart';

class ProjectsController extends GetxController {
  final RxList<Project> projects = <Project>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  List<Project> get all => projects;
  late final ProjectService _service;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<ProjectService>();
    // Load from backend on startup
    fetchFromBackend(() => _service.getAll());
  }

  // Find projects where a given employee name is executor
  List<Project> byExecutor(String name) =>
    projects.where((p) => (p.executor?.trim().toLowerCase() ?? '') == name.trim().toLowerCase()).toList();

  Project _normalize(Project p) {
    final allowedPriorities = {'Low','Medium','High'};
    final allowedStatuses = {'Pending','In Progress','Completed','Not Started'};
    String priority = allowedPriorities.contains(p.priority) ? p.priority : 'Medium';
    String status = allowedStatuses.contains(p.status) ? p.status : 'Not Started';
    final exec = (p.executor?.trim().isNotEmpty ?? false) ? p.executor!.trim() : null;
    final assigned = (p.assignedEmployees ?? [])
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
    return p.copyWith(
      priority: priority,
      status: status,
      executor: exec,
      assignedEmployees: assigned.isEmpty ? null : assigned,
      title: p.title.trim().isEmpty ? 'Untitled' : p.title.trim(),
      description: (p.description?.trim().isNotEmpty ?? false) ? p.description!.trim() : null,
    );
  }

  // Find projects assigned to given employee id in assignedEmployees
  List<Project> byAssigneeId(String employeeId) => projects
    .where((p) => (p.assignedEmployees ?? const [])
      .any((e) => e.trim() == employeeId.trim()))
    .toList();

  void loadInitial(List<Project> initial) {
    projects.assignAll(initial.map(_normalize));
  }

  void addProject(Project p) {
  // optimistic update; backend create can be added later
    projects.add(_normalize(p));
  }

  void updateProject(String id, Project updated) {
    final idx = projects.indexWhere((e) => e.id == id);
    if (idx != -1) projects[idx] = _normalize(updated);
  }

  Future<void> fetchFromBackend(Future<List<Project>> Function() loader) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await loader();
      projects.assignAll(list.map(_normalize));
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void deleteProject(String id) {
    projects.removeWhere((e) => e.id == id);
  }

  Future<void> removeProjectRemote(String id) async {
    try {
      await _service.delete(id);
      deleteProject(id);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<Project> createProjectRemote(Project p) async {
    try {
      final created = await _service.create(p);
      addProject(created);
      return created;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<Project> saveProjectRemote(Project p) async {
    try {
      final saved = await _service.update(p);
      updateProject(saved.id, saved);
      return saved;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }
}
