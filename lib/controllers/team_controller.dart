import 'package:get/get.dart';
import '../models/team_member.dart';
import '../services/user_service.dart';

class TeamController extends GetxController {
  final RxList<TeamMember> members = <TeamMember>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  late final UserService _service;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<UserService>();
    fetchFromBackend(() => _service.getAll());
  }

  TeamMember _normalize(TeamMember m) {
    final name = m.name.trim();
    final email = m.email.trim();
    // Map any legacy roles to the two canonical roles
    final role = (m.role.trim().toLowerCase() == 'team leader')
        ? 'Team Leader'
        : 'Executor/Reviewer';
    return m.copyWith(name: name, email: email, role: role);
  }

  void loadInitial(List<TeamMember> initial) {
    members.assignAll(initial.map(_normalize));
  }

  void addMember(TeamMember m) => members.insert(0, _normalize(m));
  void updateMember(String id, TeamMember updated) {
    final idx = members.indexWhere((e) => e.id == id);
    if (idx != -1) members[idx] = _normalize(updated);
  }

  void deleteMember(String id) => members.removeWhere((e) => e.id == id);
  
  // Backend-powered CRUD helpers
  Future<void> createMember(TeamMember m) async {
    try {
      final created = await _service.create(m);
      addMember(created);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> saveMember(TeamMember m) async {
    try {
      final saved = await _service.update(m);
      updateMember(saved.id, saved);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> removeMember(String id) async {
    try {
      await _service.delete(id);
      deleteMember(id);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  // Simple filters stored as reactive values
  final RxList<String> selectedRoles = <String>[].obs;
  final RxList<String> selectedStatuses = <String>[].obs;

  List<TeamMember> get filtered {
    // Work on a plain List derived from the reactive members to make filtering predictable.
    List<TeamMember> list = members.toList();
    if (selectedRoles.isNotEmpty) {
      list = list.where((m) => selectedRoles.contains(m.role)).toList();
    }
    if (selectedStatuses.isNotEmpty) {
      list = list.where((m) => selectedStatuses.contains(m.status)).toList();
    }
    return list;
  }

  void clearFilters() {
    selectedRoles.clear();
    selectedStatuses.clear();
  }

  TeamMember? findById(String id) {
    final idx = members.indexWhere((m) => m.id == id);
    return idx == -1 ? null : members[idx];
  }

  Future<void> fetchFromBackend(Future<List<TeamMember>> Function() loader) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await loader();
      members.assignAll(list.map(_normalize));
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
