import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Primary button — Deep Teal, white text, 48px height.
/// Digunakan untuk aksi utama: Add to Collection, Start Reading, Read, Login, Save, Open Maps.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final isEnabled = onPressed != null && !isLoading;

    final child = SizedBox(
      height: AppSpacing.buttonHeight,
      width: width,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: AppColors.white),
                    const SizedBox(width: AppSpacing.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppText.button(color: AppColors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    return child;
  }
}

/// Secondary button — outline 1px Deep Teal, Deep Teal text, 48px height.
/// Digunakan untuk aksi pendamping: Add to Wishlist, Update, Update Progress.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      height: AppSpacing.buttonHeight,
      width: width,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: primaryColor.withValues(alpha: 0.5),
          side: BorderSide(
            color: isEnabled
                ? primaryColor
                : primaryColor.withValues(alpha: 0.3),
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: primaryColor),
                    const SizedBox(width: AppSpacing.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppText.button(color: primaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tertiary button — aksi ringan tanpa style dominan, touch target >= 44.
class TertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const TertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = color ?? (isDark ? AppColors.inkDark : AppColors.deepTeal);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: AppText.button(color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon button — target sentuh minimal 44 × 44 px, tooltip/semantics label.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? AppColors.inkDark : AppColors.deepTeal);

    return Semantics(
      label: tooltip,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.touchTarget,
          minHeight: AppSpacing.touchTarget,
        ),
        child: IconButton(
          icon: Icon(icon, size: size, color: iconColor),
          tooltip: tooltip,
          onPressed: onPressed,
          splashRadius: 24,
        ),
      ),
    );
  }
}
