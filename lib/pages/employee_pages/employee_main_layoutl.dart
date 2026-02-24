import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/components/empolyee_sidebar.dart';
import 'package:quality_review/pages/employee_pages/employee_dashboard.dart';
import 'package:quality_review/pages/employee_pages/myproject.dart';
import 'package:quality_review/pages/employee_pages/leader_performance.dart';
import '../../controllers/auth_controller.dart';
import '../login.dart';

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
  int selectedIndex = 0;

  final pages = [EmployeeDashboard(), Myproject(), LeaderPerformance()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar (left)
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: EmployeeSidebar(
                    selectedIndex: selectedIndex,
                    onItemSelected: (index) {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    onCreate: () {
                      Get.snackbar(
                        'Info',
                        'Create New clicked dnf',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      onPressed: () async {
                        await Get.find<AuthController>().logout();
                        Get.offAll(() => LoginPage());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content (right) dndkf
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }
}
