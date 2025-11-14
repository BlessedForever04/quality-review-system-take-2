import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/admin_pages/admin_main_layout.dart';
import 'package:quality_review/pages/employee_pages/employee_main_layoutl.dart';
import '../controllers/auth_controller.dart';

// ---------- Controller using GetX ----------
class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  var isLoading = false.obs;

  void login() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        "Error",
        "Please enter both email and password",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      final auth = Get.put(AuthController());
      final user = await auth.login(email, password);
      final isAdmin = user.role.toLowerCase() == 'admin';
      Get.off(() => isAdmin ? AdminMainLayout() : EmployeeMainLayout());
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

// ---------- Login Screen ----------
class LoginPage extends StatelessWidget {
  final LoginController controller = Get.put(LoginController());

  LoginPage({super.key});

  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Container(
            height: 500,
            width: MediaQuery.of(context).size.width / 3.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(
                    255,
                    0,
                    59,
                    236,
                  ).withValues(alpha: 0.3),
                  spreadRadius: 10,
                  blurRadius: 310,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 45,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    "Sign in to your account to continue",
                    style: TextStyle(color: Color.fromARGB(255, 37, 37, 37)),
                  ),
                  const SizedBox(height: 40),

                  // --- Email Field ---
                  TextField(
                    controller: controller.emailController,
                    cursorColor: Colors.blue,
                    cursorHeight: 20,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.grey[50],
                      labelText: "Email",
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller.passwordController,
                    cursorColor: Colors.blue,
                    cursorHeight: 20,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.key),
                      filled: true,
                      fillColor: Colors.grey[50],
                      labelText: "Password",
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Login Button ---
                  Obx(() {
                    if (controller.isLoading.value) {
                      return const CircularProgressIndicator();
                    }
                    return GestureDetector(
                      onTap: controller.login,
                      child: Container(
                        height: 42,
                        width: MediaQuery.of(context).size.width / 3.1,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Text(
                            "Login",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
