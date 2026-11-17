import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../controllers/home_controller.dart';
import '../../projects/models/project_model.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NovaWorks',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget();
        }

        return RefreshIndicator(
          onRefresh: controller.loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppHeader(
                title: 'Hello, ${controller.userName.split(' ').first}',
                subtitle: _welcomeMessage,
              ),
              const SizedBox(height: 24),
              _roleCard,
              const SizedBox(height: 22),
              _quickActions,
              const SizedBox(height: 26),
              _statistics,
              const SizedBox(height: 28),
              AppHeader(
                title: controller.isAgent ? 'My Tasks' : 'Projects',
                subtitle: controller.isAgent
                    ? 'Your assigned work'
                    : 'Your accessible projects',
                action: TextButton(
                  onPressed: () => Get.toNamed(
                    controller.isAgent ? AppRoutes.tasks : AppRoutes.projects,
                  ),
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 14),
              if (controller.isAgent)
                ...controller.tasks
                    .take(5)
                    .map(
                      (task) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              Icons.task_alt,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${task.projectName} • ${task.estimatedHours} hours',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    )
              else if (controller.projects.isEmpty)
                const SizedBox(
                  height: 220,
                  child: EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No projects yet',
                    description: 'Your projects will appear here.',
                  ),
                )
              else
                ...controller.projects
                    .take(5)
                    .map((project) => _projectCard(project)),
            ],
          ),
        );
      }),
    );
  }

  String get _welcomeMessage {
    if (controller.isAdmin) {
      return 'Manage your company projects and team.';
    }

    if (controller.isManager) {
      return 'Manage your assigned client projects.';
    }

    return 'Here is your assigned development work.';
  }

  Widget get _roleCard {
    final role = controller.userRole;

    final color = role == 'ADMIN'
        ? AppColors.admin
        : role == 'MANAGER'
        ? AppColors.manager
        : AppColors.agent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 24,
            child: Icon(Icons.person_outline, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 25,
          ),
        ],
      ),
    );
  }

  Widget get _quickActions {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (controller.isAdmin)
          _actionButton(
            'Create from AI',
            Icons.auto_awesome,
            AppRoutes.transcript,
          ),
        if (controller.isAdmin || controller.isManager)
          _actionButton('Projects', Icons.folder_outlined, AppRoutes.projects),
        if (controller.isAgent)
          _actionButton('My Tasks', Icons.checklist_rounded, AppRoutes.tasks),
        _actionButton('Team', Icons.groups_outlined, AppRoutes.team),
      ],
    );
  }

  Widget _actionButton(String title, IconData icon, String route) {
    return InkWell(
      onTap: () => Get.toNamed(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _statistics {
    return Row(
      children: [
        _statCard(
          'Projects',
          controller.projects.length.toString(),
          Icons.folder_copy_outlined,
        ),
        const SizedBox(width: 12),
        _statCard('Tasks', controller.totalTasks.toString(), Icons.task_alt),
        const SizedBox(width: 12),
        _statCard(
          'Hours',
          controller.totalHours.toStringAsFixed(0),
          Icons.schedule,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(ProjectModel project) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(13),
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder_outlined, color: AppColors.primary),
        ),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${project.clientName}\n${project.taskCount} tasks • ${project.deadline.toString().split(' ').first}',
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Get.toNamed(AppRoutes.projectDetails, arguments: project.id),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Get.find<AuthService>().logout();
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
