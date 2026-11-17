import 'package:get/get.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/gemini_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FirestoreService>(() => FirestoreService(), fenix: true);

    Get.lazyPut<GeminiService>(() => GeminiService(), fenix: true);
  }
}
