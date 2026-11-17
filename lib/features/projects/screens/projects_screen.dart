import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../controllers/project_controller.dart';
import '../models/project_model.dart';

class ProjectsScreen extends GetView<ProjectController> {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget();
        }

        return RefreshIndicator(
          onRefresh: controller.loadProjects,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppHeader(
                title: 'All Projects',
                subtitle: 'Your accessible client engagements',
              ),
              const SizedBox(height: 20),
              if (controller.projects.isEmpty)
                const SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No projects found',
                    description: 'There are no accessible projects yet.',
                  ),
                )
              else
                ...controller.projects.map(_projectCard),
            ],
          ),
        );
      }),
    );
  }

  Widget _projectCard(ProjectModel project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Get.toNamed(AppRoutes.projectDetails, arguments: project.id),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _detail(Icons.business_outlined, 'Client', project.clientName),
              _detail(Icons.person_outline, 'Manager', project.managerName),
              _detail(
                Icons.calendar_today_outlined,
                'Deadline',
                project.deadline.toString().split(' ').first,
              ),
              const Divider(height: 25),
              Row(
                children: [
                  _badge(Icons.task_alt, '${project.taskCount} Tasks'),
                  const SizedBox(width: 9),
                  _badge(
                    Icons.schedule,
                    '${project.totalEstimatedHours.toStringAsFixed(0)} Hours',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 9),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
