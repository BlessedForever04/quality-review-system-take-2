import 'package:get/get.dart';
import '../models/project.dart';

class ProjectDetailsController extends GetxController {
  late final Project initial;

  // Reactive fields
  final Rx<Project> _project = Rx<Project>(
    Project(
      id: 'init',
      title: 'Untitled',
      started: DateTime.now(),
      priority: 'Medium',
      status: 'Not Started',
    ),
  );
  final RxSet<String> selectedMemberIds = <String>{}.obs; // union of all roles
  final RxSet<String> teamLeaderIds = <String>{}.obs;
  final RxSet<String> executorIds = <String>{}.obs;
  final RxSet<String> reviewerIds = <String>{}.obs;

  Project get project => _project.value;
  String get description => project.description ?? '';

  void seed(Project p, {Iterable<String>? assigned}) {
    _project.value = p;
    if (assigned != null) {
      selectedMemberIds
        ..clear()
        ..addAll(assigned);
    } else if (p.assignedEmployees != null) {
      selectedMemberIds
        ..clear()
        ..addAll(p.assignedEmployees!);
    }
    // Clear role specific sets; they will be hydrated separately via memberships
    teamLeaderIds.clear();
    executorIds.clear();
    reviewerIds.clear();
  }

  void toggleMember(String id, bool value) {
    if (value) {
      selectedMemberIds.add(id);
    } else {
      selectedMemberIds.remove(id);
    }
  }

  void updateMeta({
    String? projectNo,
    String? internalOrderNo,
    String? title,
    DateTime? started,
    String? priority,
    String? status,
    String? executor,
    String? description,
  }) {
    final current = _project.value;
    _project.value = current.copyWith(
      projectNo: projectNo ?? current.projectNo,
      internalOrderNo: internalOrderNo ?? current.internalOrderNo,
      title: title ?? current.title,
      started: started ?? current.started,
      priority: (priority == null || priority.isEmpty)
          ? current.priority
          : priority,
      status: (status == null || status.isEmpty) ? current.status : status,
      executor: (executor == null || executor.isEmpty)
          ? current.executor
          : executor,
      description: description ?? current.description,
      assignedEmployees: selectedMemberIds.toList(),
    );
  }

  /// Populate role-specific selections from project membership list
  void seedMemberships(Iterable<dynamic> memberships) {
    // Expect objects that expose roleName and userId
    teamLeaderIds.clear();
    executorIds.clear();
    reviewerIds.clear();
    for (final m in memberships) {
      try {
        final roleName = (m.roleName ?? '').toString().trim().toLowerCase();
        final userId = (m.userId).toString();
        if (userId.isEmpty) continue;
        if (roleName == 'teamleader') {
          teamLeaderIds.add(userId);
        } else if (roleName == 'executor') {
          executorIds.add(userId);
        } else if (roleName == 'reviewer') {
          reviewerIds.add(userId);
        }
      } catch (_) {
        continue;
      }
    }
    // Maintain union for legacy fields
    selectedMemberIds
      ..clear()
      ..addAll(teamLeaderIds)
      ..addAll(executorIds)
      ..addAll(reviewerIds);
  }

  void toggleTeamLeader(String id, bool value) {
    if (value) {
      // Check if employee is already assigned to another role
      if (executorIds.contains(id) || reviewerIds.contains(id)) {
        throw Exception('Employee is already assigned as Executor or Reviewer');
      }
      // If trying to add more than 1 TeamLeader, reject it
      if (teamLeaderIds.length >= 1) {
        throw Exception('Only one TeamLeader can be assigned to a project');
      }
      teamLeaderIds.add(id);
    } else {
      teamLeaderIds.remove(id);
    }
    _rebuildUnion();
  }

  /// Check if TeamLeader limit would be exceeded
  bool canAddTeamLeader() => teamLeaderIds.length < 1;

  /// Get the count of selected TeamLeaders
  int getTeamLeaderCount() => teamLeaderIds.length;

  void toggleExecutor(String id, bool value) {
    if (value) {
      // Check if employee is already assigned to another role
      if (teamLeaderIds.contains(id) || reviewerIds.contains(id)) {
        throw Exception(
          'Employee is already assigned as TeamLeader or Reviewer',
        );
      }
      executorIds.add(id);
    } else {
      executorIds.remove(id);
    }
    _rebuildUnion();
  }

  void toggleReviewer(String id, bool value) {
    if (value) {
      // Check if employee is already assigned to another role
      if (teamLeaderIds.contains(id) || executorIds.contains(id)) {
        throw Exception(
          'Employee is already assigned as TeamLeader or Executor',
        );
      }
      reviewerIds.add(id);
    } else {
      reviewerIds.remove(id);
    }
    _rebuildUnion();
  }

  void _rebuildUnion() {
    selectedMemberIds
      ..clear()
      ..addAll(teamLeaderIds)
      ..addAll(executorIds)
      ..addAll(reviewerIds);
  }
}
