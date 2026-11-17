import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const heading = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const body = TextStyle(fontSize: 14, color: AppColors.textPrimary);

  static const small = TextStyle(fontSize: 12, color: AppColors.textSecondary);
}
