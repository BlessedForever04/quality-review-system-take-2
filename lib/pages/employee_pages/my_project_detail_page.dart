import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../components/project_detail_info.dart';

class MyProjectDetailPage extends StatelessWidget {
  final Project project;
  final String? description;
  const MyProjectDetailPage({
    super.key,
    required this.project,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ProjectDetailInfo(
          project: project,
          descriptionOverride: description ?? project.description,
          showAssignedEmployees: false,
        ),
      ),
    );
  }
}
