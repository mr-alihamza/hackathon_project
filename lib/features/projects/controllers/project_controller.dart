import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../models/project_model.dart';
import '../../tasks/models/task_model.dart';

class ProjectController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _firestore = Get.find<FirestoreService>();

  final projects = <ProjectModel>[].obs;
  final selectedProject = Rxn<ProjectModel>();
  final projectTasks = <TaskModel>[].obs;

  final isLoading = false.obs;
  final isDetailLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProjects();
  }

  Future<void> loadProjects() async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;

      if (user == null) return;

      projects.assignAll(await _firestore.getProjects(user));

      projects.sort((a, b) => a.deadline.compareTo(b.deadline));
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openProject(String projectId) async {
    try {
      isDetailLoading.value = true;

      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Session expired.');
      }

      final project = await _firestore.getProjectById(projectId);

      if (project == null) {
        throw Exception('Project not found.');
      }

      // Check the current user's permitted project list.
      final allowed = await _firestore.getProjects(user);

      if (!allowed.any((item) => item.id == projectId)) {
        throw Exception('You do not have access to this project.');
      }

      selectedProject.value = project;

      projectTasks.assignAll(
        await _firestore.getTasks(user: user, projectId: projectId),
      );
    } catch (e) {
      selectedProject.value = null;
      projectTasks.clear();

      Get.snackbar(
        'Access denied',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      isDetailLoading.value = false;
    }
  }
}
