import 'package:flutter/material.dart';
import 'package:quality_review/components/empolyee_sidebar.dart';
import 'package:quality_review/pages/employee_pages/employee_dashboard.dart';
import 'package:quality_review/pages/employee_pages/myproject.dart';

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
  int selectedIndex = 0;

  final pages = [EmployeeDashboard(), Myproject()];

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
            child: EmployeeSidebar(
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
