import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/login.dart';
import 'package:quality_review/pages/admin_pages/admin_main_layout.dart';
import 'package:quality_review/pages/employee_pages/employee_main_layoutl.dart';
import 'controllers/auth_controller.dart';
import 'bindings/app_bindings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Quality Review Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: false,
      ),
      initialBinding: AppBindings(),
      // Pick initial screen based on restored auth state (reactive)F
      home: _HomeRouter(),
    );
  }
}

class _HomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final user = auth.currentUser.value;
      if (user == null) return LoginPage();
      final isAdmin = user.role.toLowerCase() == 'admin';
      return isAdmin ? AdminMainLayout() : EmployeeMainLayout();
    });
  }
}

// email : admin@gmail.com
// pass : admin1
