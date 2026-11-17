import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Welcome back',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Sign in to manage your projects and team.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  CustomTextField(
                    label: 'Email address',
                    controller: controller.emailController,
                    hint: 'Enter your company email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 22),
                  Obx(
                    () => CustomTextField(
                      label: 'Password',
                      controller: controller.passwordController,
                      hint: 'Enter your password',
                      obscureText: controller.obscurePassword.value,
                      suffixIcon: IconButton(
                        onPressed: controller.togglePassword,
                        icon: Icon(
                          controller.obscurePassword.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Obx(
                    () => CustomButton(
                      title: 'Sign in',
                      icon: Icons.login_rounded,
                      isLoading: controller.isLoading.value,
                      onPressed: controller.login,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'NovaWorks Technologies  •  Lahore',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
