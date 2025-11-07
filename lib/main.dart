import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/employee_dashboard.dart';

import 'pages/admin_pages/team_page.dart';
import 'components/sidebar.dart';
import 'pages/admin_pages/dashboard_page.dart';

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
      home: EmployeeDashboard(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;

  final pages = [DashboardPage(), TeamPage()];

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
            child: Sidebar(
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
