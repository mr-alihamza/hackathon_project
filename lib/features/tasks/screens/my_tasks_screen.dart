import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../controllers/task_controller.dart';

class MyTasksScreen extends GetView<TaskController> {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget();
        }

        if (controller.tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.task_alt,
            title: 'No assigned tasks',
            description: 'Your assigned development tasks will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadTasks,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppHeader(
                title: 'My Tasks',
                subtitle: 'Tasks assigned to your account',
              ),
              const SizedBox(height: 20),
              ...controller.tasks.map((task) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 13),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.projectName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          task.description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                task.deadline,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const Icon(
                              Icons.schedule,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${task.estimatedHours} hours',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}
