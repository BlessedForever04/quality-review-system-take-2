import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class EmployeeSidebar extends StatelessWidget {
  final void Function()? onCreate;
  final int selectedIndex;
  final void Function(int)? onItemSelected;

  const EmployeeSidebar({
    super.key,
    this.onCreate,
    this.selectedIndex = 0,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF135BEC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Dashboard",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Nav items
          SidebarItem(
            icon: Icons.dashboard,
            label: "Dashboard",
            active: selectedIndex == 0,
            onTap: () => onItemSelected?.call(0),
          ),
          SidebarItem(
            icon: Icons.group,
            label: "My Projects",
            active: selectedIndex == 1,
            onTap: () => onItemSelected?.call(1),
          ),
          const Spacer(),

          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 12),

          // Profile
          Obx(() {
            final authCtrl = Get.find<AuthController>();
            final user = authCtrl.currentUser.value;
            final name = user?.name ?? 'User';
            final role = user?.role ?? 'user';
            final displayRole = role == 'admin' ? 'Admin' : 'Employee';

            return Row(
              children: [
                const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        displayRole,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color.fromRGBO(19, 91, 236, 0.1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? const Color(0xFF135BEC) : Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFF135BEC) : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
