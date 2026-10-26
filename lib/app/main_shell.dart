import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text.dart';

/// MainShell — Scaffold dengan bottom navigation 5 tab (PRD §4.6, design-system.md §6).
/// Tab: 0: Home, 1: Library, 2: Add (tombol tengah apricot 56px), 3: Tools, 4: Profile.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderNeutral;
    final activeColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final inactiveColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  isActive: currentIndex == 0,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  label: 'Library',
                  icon: Icons.library_books_outlined,
                  activeIcon: Icons.library_books_rounded,
                  isActive: currentIndex == 1,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                _buildCenterAddButton(
                  context: context,
                  isActive: currentIndex == 2,
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  label: 'Tools',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  isActive: currentIndex == 3,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                _buildNavItem(
                  context: context,
                  index: 4,
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  isActive: currentIndex == 4,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: AppSpacing.iconL,
                  color: isActive ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppText.caption(
                    color: isActive ? activeColor : inactiveColor,
                  ).copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                // Indikator aktif kecil soft apricot — PRD §4.6
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.softApricot : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol Add di tengah: 56px lingkaran softApricot dengan plus dinamis
  Widget _buildCenterAddButton({
    required BuildContext context,
    required bool isActive,
  }) {
    final plusColor = context.primaryColor;

    return Semantics(
      label: 'Add Book',
      selected: isActive,
      button: true,
      child: GestureDetector(
        onTap: () => _onItemTapped(2),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.softApricot,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.softApricot.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: isActive
                ? Border.all(color: plusColor, width: 2)
                : null,
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: plusColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
