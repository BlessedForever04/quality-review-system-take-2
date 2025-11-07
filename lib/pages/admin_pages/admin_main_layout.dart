
import 'package:flutter/material.dart';
import 'package:quality_review/components/admin_sidebar.dart';
import 'package:quality_review/pages/admin_pages/admin_dashboard_page.dart';
import 'package:quality_review/pages/admin_pages/employee_page.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int selectedIndex = 0;

  final pages = [AdminDashboardPage(), EmployeePage()];

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
            child: AdminSidebar(
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              onCreate: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Create New clicked dnf")),
                );
              },
            ),
          ),

          // Main Content (right) dndkf
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: pages[selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
