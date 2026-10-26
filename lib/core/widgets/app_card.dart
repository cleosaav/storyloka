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
/// Mendukung layout vertikal (default) dan horizontal (EmptyStateCard.horizontal).
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final bool isHorizontal;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required String this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  }) : isHorizontal = false;

  const EmptyStateCard.horizontal({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  }) : isHorizontal = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final iconBg = isDark
        ? AppColors.surfaceDark
        : AppColors.sageGreen.withValues(alpha: 0.25);

    if (isHorizontal) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final hasTitle = title != null && title!.trim().isNotEmpty;
            final isNarrow = constraints.maxWidth < 340 || textScale > 1.15;

            final iconWidget = Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: primaryColor),
            );

            Widget actionButton() {
              if (actionLabel == null || onAction == null) {
                return const SizedBox.shrink();
              }
              return PrimaryButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
              );
            }

            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasTitle) ...[
                              Text(
                                title!,
                                style: AppText.cardHeading(
                                  color: isDark ? AppColors.inkDark : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              message,
                              style: hasTitle
                                  ? AppText.caption(
                                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                    )
                                  : AppText.body(
                                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AppSpacing.m),
                    actionButton(),
                  ],
                ],
              );
            }

            // Susunan horizontal penuh (ikon di kiri; judul, subteks, tombol di kanan)
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconWidget,
                const SizedBox(width: AppSpacing.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle) ...[
                        Text(
                          title!,
                          style: AppText.cardHeading(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text(
                        message,
                        style: hasTitle
                            ? AppText.caption(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              )
                            : AppText.body(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: AppSpacing.m),
                        actionButton(),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: primaryColor),
          ),
          const SizedBox(height: AppSpacing.m),
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              style: AppText.cardHeading(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            style: AppText.metadata(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.l),
            PrimaryButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
