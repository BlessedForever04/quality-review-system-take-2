import 'package:get/get.dart';
import '../controllers/projects_controller.dart';
import '../controllers/team_controller.dart';
import '../controllers/admin_dashboard_ui_controller.dart';
import '../services/http_client.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/project_membership_service.dart';
import '../controllers/auth_controller.dart';
import '../pages/employee_pages/checklist_controller.dart';
import '../services/checklist_answer_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Core HTTP client and services
    Get.put<SimpleHttp>(SimpleHttp(), permanent: true);
    Get.put<ProjectService>(
      ProjectService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<UserService>(UserService(Get.find<SimpleHttp>()), permanent: true);
    Get.put<RoleService>(RoleService(Get.find<SimpleHttp>()), permanent: true);
    Get.put<ProjectMembershipService>(
      ProjectMembershipService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    // Direct checklist answer service (simplified API)
    Get.put<ChecklistAnswerService>(
      ChecklistAnswerService(Get.find<SimpleHttp>()),
      permanent: true,
    );

    // ChecklistController (permanent service)
    Get.put<ChecklistController>(ChecklistController(), permanent: true);

    final auth = Get.put<AuthController>(AuthController(), permanent: true);
    // Kick off auth restore (fire and forget)
    auth.init();

    // Controllers
    Get.lazyPut<ProjectsController>(() => ProjectsController(), fenix: true);
    Get.lazyPut<TeamController>(() => TeamController(), fenix: true);
    Get.lazyPut<AdminDashboardUIController>(
      () => AdminDashboardUIController(),
      fenix: true,
    );
  }
}
