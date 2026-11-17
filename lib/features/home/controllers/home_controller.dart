import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../projects/models/project_model.dart';
import '../../tasks/models/task_model.dart';

class HomeController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _firestore = Get.find<FirestoreService>();

  final projects = <ProjectModel>[].obs;
  final tasks = <TaskModel>[].obs;

  final isLoading = false.obs;

  String get userName => _auth.currentUser?.name ?? '';
  String get userRole => _auth.currentUser?.role ?? '';

  bool get isAdmin => _auth.currentUser?.isAdmin ?? false;
  bool get isManager => _auth.currentUser?.isManager ?? false;
  bool get isAgent => _auth.currentUser?.isAgent ?? false;

  int get totalTasks => tasks.length;

  double get totalHours =>
      tasks.fold(0, (sum, task) => sum + task.estimatedHours);

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;

      if (user == null) return;

      projects.assignAll(await _firestore.getProjects(user));

      if (user.isAgent) {
        tasks.assignAll(await _firestore.getTasks(user: user));
      } else {
        tasks.clear();

        for (final project in projects) {
          final projectTasks = await _firestore.getTasks(
            user: user,
            projectId: project.id,
          );

          tasks.addAll(projectTasks);
        }
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
