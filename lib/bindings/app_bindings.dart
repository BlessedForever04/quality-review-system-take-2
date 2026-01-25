import 'package:get/get.dart';
import '../controllers/projects_controller.dart';
import '../controllers/team_controller.dart';
import '../controllers/admin_dashboard_ui_controller.dart';
import '../controllers/template_management_controller.dart';
import '../services/http_client.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/project_membership_service.dart';
import '../services/template_service.dart';
import '../services/stage_service.dart';
import '../services/phase_checklist_service.dart';
import '../services/project_checklist_service.dart';
import '../services/defect_categorization_service.dart';
import '../controllers/auth_controller.dart';
import '../pages/employee_pages/checklist_controller.dart';
import '../services/checklist_answer_service.dart';
import '../services/approval_service.dart';
import '../services/excel_export_service.dart';
import '../services/master_excel_export_service.dart';
import '../controllers/export_controller.dart';

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
    Get.put<ApprovalService>(
      ApprovalService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<TemplateService>(
      TemplateService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<StageService>(
      StageService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<PhaseChecklistService>(
      PhaseChecklistService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<ProjectChecklistService>(
      ProjectChecklistService(Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<DefectCategorizationService>(
      DefectCategorizationService(Get.find<SimpleHttp>()),
      permanent: true,
    );

    // Export services
    Get.put<ExcelExportService>(
      ExcelExportService(
        projectService: Get.find<ProjectService>(),
        membershipService: Get.find<ProjectMembershipService>(),
        checklistService: Get.find<PhaseChecklistService>(),
        answerService: Get.find<ChecklistAnswerService>(),
        stageService: Get.find<StageService>(),
        templateService: Get.find<TemplateService>(),
      ),
      permanent: true,
    );
    Get.put<MasterExcelExportService>(
      MasterExcelExportService(httpClient: Get.find<SimpleHttp>()),
      permanent: true,
    );
    Get.put<ExportController>(
      ExportController(
        excelExportService: Get.find<ExcelExportService>(),
        masterExcelExportService: Get.find<MasterExcelExportService>(),
      ),
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
    Get.lazyPut<TemplateManagementController>(
      () => TemplateManagementController(),
      fenix: true,
    );
  }
}
