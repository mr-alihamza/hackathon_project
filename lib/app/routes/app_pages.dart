import 'package:get/get.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/login_screen.dart';

import '../../features/home/controllers/home_controller.dart';
import '../../features/home/screens/home_screen.dart';

import '../../features/team/controllers/team_controller.dart';
import '../../features/team/screens/team_screen.dart';

import '../../features/projects/controllers/project_controller.dart';
import '../../features/projects/screens/projects_screen.dart';
import '../../features/projects/screens/project_detail_screen.dart';

import '../../features/tasks/controllers/task_controller.dart';
import '../../features/tasks/screens/my_tasks_screen.dart';

import '../../features/transcript/controllers/transcript_controller.dart';
import '../../features/transcript/screens/transcript_screen.dart';

import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AuthController());
      }),
    ),

    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => HomeController());
      }),
    ),

    GetPage(
      name: AppRoutes.team,
      page: () => const TeamScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TeamController());
      }),
    ),

    GetPage(
      name: AppRoutes.projects,
      page: () => const ProjectsScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ProjectController());
      }),
    ),

    GetPage(
      name: AppRoutes.projectDetails,
      page: () => const ProjectDetailScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ProjectController>()) {
          Get.put(ProjectController());
        }

        Get.find<ProjectController>().openProject(Get.arguments as String);
      }),
    ),

    GetPage(
      name: AppRoutes.tasks,
      page: () => const MyTasksScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TaskController());
      }),
    ),

    GetPage(
      name: AppRoutes.transcript,
      page: () => const TranscriptScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TranscriptController());
      }),
    ),
  ];
}
