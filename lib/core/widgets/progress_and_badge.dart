import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../../data/models/user_book.dart';

/// ReadingProgressBar — tinggi 6 px, ujung rounded, fill Deep Teal (primaryDark di dark mode),
/// track trackNeutral (trackDark di dark mode).
/// Selalu dengan teks "x / y pages" dan persentase (PRD §4.5, design-system.md §5).
class ReadingProgressBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool showText;

  const ReadingProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppColors.trackDark : AppColors.trackNeutral;
    final fillColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;

    final progress = totalPages > 0
        ? (currentPage / totalPages).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$currentPage / $totalPages pages',
                  style: AppText.caption(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$percent%',
                style: AppText.caption(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// StatusBadge — teks + warna + icon/indikator visual (PRD §4.5).
/// Jangan mengandalkan warna saja!
class StatusBadge extends StatelessWidget {
  final BookStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case BookStatus.notStarted:
        bgColor = isDark
            ? AppColors.mutedDark.withValues(alpha: 0.2)
            : AppColors.trackNeutral;
        textColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;
        icon = Icons.radio_button_unchecked;
        break;
      case BookStatus.reading:
        bgColor = AppColors.softApricot.withValues(alpha: 0.2);
        textColor = isDark ? AppColors.softApricot : const Color(0xFFC07A15);
        icon = Icons.auto_stories_outlined;
        break;
      case BookStatus.finished:
        bgColor = AppColors.success.withValues(alpha: 0.18);
        textColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.iconXs, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(color: textColor).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AppChip — pill, tinggi 32–36 px; selected = Deep Teal + teks putih (PRD §4.5).
class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final unselectedBg = isDark ? AppColors.surfaceDark : AppColors.white;
    final unselectedBorder =
        isDark ? AppColors.borderDark : AppColors.borderNeutral;
    final textColor = isSelected
        ? AppColors.white
        : (isDark ? AppColors.inkDark : AppColors.ink);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(AppSpacing.radius18),
            border: Border.all(
              color: isSelected ? selectedBg : unselectedBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppSpacing.iconS,
                  color: textColor,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.button(color: textColor),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FilterTabs — untuk pilihan kategori/filter (Collection | Wishlist atau Title | Author | ISBN).
class FilterTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FilterTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.borderNeutral.withValues(alpha: 0.4);

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radius22),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Text(
                  tabs[index],
                  style: AppText.button(
                    color: isSelected
                        ? AppColors.white
                        : (isDark ? AppColors.mutedDark : AppColors.mutedGray),
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
