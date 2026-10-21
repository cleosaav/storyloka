import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

enum SnackBarType { success, error, warning, info }

/// Helper untuk menampilkan snackbar berdesain konsisten sesuai token StoryLoka.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        bgColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case SnackBarType.error:
        bgColor = AppColors.error;
        icon = Icons.error_outline_rounded;
        break;
      case SnackBarType.warning:
        bgColor = const Color(0xFFC07A15);
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.info:
        bgColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                message,
                style: AppText.bodyMedium(color: textColor).copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
        margin: const EdgeInsets.all(AppSpacing.m),
      ),
    );
  }
}
