import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// AppCard — surface putih/ivory (surfaceDark di dark mode), radius 20, padding 16.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ?? (isDark ? AppColors.surfaceDark : AppColors.white);
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderNeutral;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      side: border ?? BorderSide(color: borderColor, width: 1.0),
    );

    final innerPadding =
        padding ?? const EdgeInsets.all(AppSpacing.cardPadding);

    if (onTap != null) {
      return Material(
        color: cardBg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: innerPadding,
            child: child,
          ),
        ),
      );
    }

    return Material(
      color: cardBg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: innerPadding,
        child: child,
      ),
    );
  }
}

/// NotesCard — Pale Peach background (PRD §4.1, 4.5).
class NotesCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const NotesCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.palePeach.withValues(alpha: 0.15)
        : AppColors.palePeach;

    return AppCard(
      color: bgColor,
      padding: padding,
      onTap: onTap,
      border: isDark
          ? const BorderSide(color: AppColors.borderDark)
          : BorderSide(color: AppColors.palePeach.withValues(alpha: 0.5)),
      child: child,
    );
  }
}

/// SupportCard — Sage green background lembut (PRD §4.1, 4.5).
class SupportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const SupportCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.sageGreen.withValues(alpha: 0.15)
        : AppColors.sageGreen.withValues(alpha: 0.25);

    return AppCard(
      color: bgColor,
      padding: padding,
      onTap: onTap,
      border: isDark
          ? const BorderSide(color: AppColors.borderDark)
          : BorderSide(color: AppColors.sageGreen.withValues(alpha: 0.4)),
      child: child,
    );
  }
}

/// EmptyStateCard — Ilustrasi kecil/ikon + pesan singkat + satu aksi utama.
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final iconBg = isDark
        ? AppColors.surfaceDark
        : AppColors.sageGreen.withValues(alpha: 0.2);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: primaryColor),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            title,
            style: AppText.cardHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            message,
            style: AppText.metadata(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
