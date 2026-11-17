import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_header.dart';
import '../controllers/transcript_controller.dart';

class TranscriptScreen extends GetView<TranscriptController> {
  const TranscriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Project Creation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppHeader(
            title: 'Meeting to Projects',
            subtitle: 'Convert your meeting into organized work.',
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gemini will analyze the meeting, identify the agreed projects and tasks, match employees from your directory, and save the results to Firestore.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Meeting transcript',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller.transcriptController,
            minLines: 14,
            maxLines: 22,
            maxLength: 50000,
            decoration: const InputDecoration(
              hintText: 'Paste the complete meeting transcript here...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Obx(
            () => CustomButton(
              title: 'Generate Projects with AI',
              icon: Icons.auto_awesome,
              isLoading: controller.isLoading.value,
              onPressed: controller.generateProjects,
            ),
          ),
          Obx(() {
            if (controller.validationErrors.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please correct the following information',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...controller.validationErrors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $error',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update the transcript and generate again. Nothing was saved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            if (controller.generatedProjects.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Successfully created',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${controller.totalProjects} projects and ${controller.totalTasks} tasks have been saved.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 15),
                  ...controller.generatedProjects.map((project) {
                    final tasks = project['tasks'] as List;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              project['clientName'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${tasks.length} tasks • ${project['managerName']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 15),
                  CustomButton(
                    title: 'Go to Dashboard',
                    onPressed: () => Get.offAllNamed('/home'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
