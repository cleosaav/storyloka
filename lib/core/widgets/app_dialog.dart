import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// AppDialog — Modal dialog bertema Cozy Botanical (PRD §4.5, design-system.md §4).
/// Menggunakan radius cardRadius (20), warna background tema (white / surfaceDark),
/// border neutral / borderDark, dan tipografi Fraunces/DM Sans.
class AppDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;

  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
  });

  /// Helper untuk menampilkan AppDialog kustom
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    String? message,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialog(
        title: Text(
          title,
          style: AppText.cardHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        content: content ??
            (message != null
                ? Text(
                    message,
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  )
                : null),
        actions: actions,
      ),
    );
  }

  /// Helper untuk dialog konfirmasi dua aksi (Batal & Konfirmasi)
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Konfirmasi',
    String cancelLabel = 'Batal',
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(
          title,
          style: AppText.cardHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        content: Text(
          message,
          style: AppText.body(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
        ),
        actions: [
          TertiaryButton(
            label: cancelLabel,
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TertiaryButton(
            label: confirmLabel,
            color: isDestructive
                ? AppColors.error
                : (isDark ? AppColors.primaryDark : AppColors.deepTeal),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.s),
      contentPadding: contentPadding ??
          const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.m),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.m),
      title: title,
      content: content,
      actions: actions,
    );
  }
}
