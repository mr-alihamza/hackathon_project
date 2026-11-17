import 'package:get/get.dart';

import '../../../core/services/firestore_service.dart';
import '../../auth/models/user_model.dart';

class TeamController extends GetxController {
  final _firestore = Get.find<FirestoreService>();

  final members = <UserModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTeam();
  }

  Future<void> loadTeam() async {
    try {
      isLoading.value = true;

      members.assignAll(await _firestore.getTeamMembers());

      members.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
