import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../auth/models/user_model.dart';

class TranscriptController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _firestore = Get.find<FirestoreService>();
  final _gemini = Get.find<GeminiService>();

  final transcriptController = TextEditingController();

  final isLoading = false.obs;
  final generatedProjects = <Map<String, dynamic>>[].obs;
  final validationErrors = <String>[].obs;

  int get totalProjects => generatedProjects.length;

  int get totalTasks => generatedProjects.fold<int>(
    0,
    (total, project) => total + (project['tasks'] as List).length,
  );

  Future<void> generateProjects() async {
    if (isLoading.value) return;

    final user = _auth.currentUser;

    if (user == null || !user.isAdmin) {
      Get.snackbar('Access denied', 'Only administrators can create projects.');
      return;
    }

    final transcript = transcriptController.text.trim();

    if (transcript.isEmpty) {
      Get.snackbar(
        'Missing transcript',
        'Please paste the meeting transcript.',
      );
      return;
    }

    try {
      isLoading.value = true;
      validationErrors.clear();
      generatedProjects.clear();

      final team = await _firestore.getTeamMembers();

      final draft = await _gemini.generateProjects(
        transcript: transcript,
        team: team,
      );

      final projects = _validateAndMap(draft, team);

      if (validationErrors.isNotEmpty) {
        return;
      }

      if (projects.isEmpty) {
        throw Exception('No valid projects were generated.');
      }

      // Save only after every project and task passes validation.
      await _firestore.saveGeneratedProjects(projects);

      generatedProjects.assignAll(projects);

      Get.snackbar(
        'Successfully created',
        '$totalProjects projects and $totalTasks tasks saved.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Creation failed',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _validateAndMap(
    Map<String, dynamic> draft,
    List<UserModel> team,
  ) {
    final errors = <String>[];
    final result = <Map<String, dynamic>>[];

    final employees = <String, UserModel>{
      for (final member in team) member.employeeCode: member,
    };

    final rawProjects = draft['projects'];

    if (rawProjects is! List || rawProjects.isEmpty) {
      validationErrors.assign(
        ['Gemini did not return any projects.'] as String,
      );
      return [];
    }

    for (int i = 0; i < rawProjects.length; i++) {
      final raw = rawProjects[i];

      if (raw is! Map) {
        errors.add('Project ${i + 1}: Invalid project structure.');
        continue;
      }

      final project = Map<String, dynamic>.from(raw);

      final name = _requiredString(project, 'name');
      final clientName = _requiredString(project, 'clientName');
      final description = _requiredString(project, 'description');
      final managerCode = _requiredString(project, 'managerCode');
      final deadline = _parseDate(project['deadline']);

      if (name == null || clientName == null || description == null) {
        errors.add('Project ${i + 1}: Missing project information.');
        continue;
      }

      if (deadline == null) {
        errors.add('$name: Invalid project deadline.');
        continue;
      }

      final manager = employees[managerCode];

      if (manager == null || !manager.isManager) {
        errors.add(
          '$name: Manager "$managerCode" does not exist or is not a manager.',
        );
        continue;
      }

      final rawTasks = project['tasks'];

      if (rawTasks is! List || rawTasks.isEmpty) {
        errors.add('$name: At least one task is required.');
        continue;
      }

      final validTasks = <Map<String, dynamic>>[];
      bool projectValid = true;

      for (int j = 0; j < rawTasks.length; j++) {
        final rawTask = rawTasks[j];

        if (rawTask is! Map) {
          errors.add('$name, task ${j + 1}: Invalid structure.');
          projectValid = false;
          continue;
        }

        final task = Map<String, dynamic>.from(rawTask);

        final title = _requiredString(task, 'title');
        final taskDescription = _requiredString(task, 'description');
        final assigneeCode = _requiredString(task, 'assigneeCode');
        final taskDeadline = _parseDate(task['deadline']);
        final hours = _parseHours(task['estimatedHours']);

        if (title == null || taskDescription == null || assigneeCode == null) {
          errors.add('$name, task ${j + 1}: Missing required information.');
          projectValid = false;
          continue;
        }

        final agent = employees[assigneeCode];

        if (agent == null || !agent.isAgent) {
          errors.add(
            '$name / $title: "$assigneeCode" is not a valid developer.',
          );
          projectValid = false;
          continue;
        }

        if (taskDeadline == null) {
          errors.add('$name / $title: Invalid task deadline.');
          projectValid = false;
          continue;
        }

        if (taskDeadline.isAfter(deadline)) {
          errors.add(
            '$name / $title: Task deadline exceeds the project deadline.',
          );
          projectValid = false;
          continue;
        }

        if (hours == null || hours <= 0) {
          errors.add('$name / $title: Estimated hours must be positive.');
          projectValid = false;
          continue;
        }

        validTasks.add({
          'title': title,
          'description': taskDescription,
          'assigneeId': agent.id,
          'assigneeName': agent.name,
          'deadline': _formatDate(taskDeadline),
          'estimatedHours': hours,
        });
      }

      if (!projectValid || validTasks.length != rawTasks.length) {
        continue;
      }

      result.add({
        'name': name,
        'clientName': clientName,
        'description': description,
        'managerId': manager.id,
        'managerName': manager.name,
        'deadline': _formatDate(deadline),
        'tasks': validTasks,
      });
    }

    validationErrors.assignAll(errors);

    return errors.isEmpty ? result : [];
  }

  String? _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];

    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  DateTime? _parseDate(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null || _formatDate(parsed) != value) {
      return null;
    }

    return parsed;
  }

  double? _parseHours(dynamic value) {
    if (value is! num) return null;

    final hours = value.toDouble();

    if (!hours.isFinite || hours <= 0) return null;

    return hours;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  @override
  void onClose() {
    transcriptController.dispose();
    super.onClose();
  }
}
