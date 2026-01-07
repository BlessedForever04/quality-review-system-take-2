import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/login.dart';
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
      home: LoginPage(),
    );
  }
}

// email : admin@gmail.com
// pass : admin1
