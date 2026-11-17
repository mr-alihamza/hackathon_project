import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../models/task_model.dart';

class TaskController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _firestore = Get.find<FirestoreService>();

  final tasks = <TaskModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;

      if (user == null) return;

      tasks.assignAll(await _firestore.getTasks(user: user));

      tasks.sort((a, b) => a.deadline.compareTo(b.deadline));
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
