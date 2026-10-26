import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Item data untuk [AppDropdown].
class AppDropdownItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.leading,
    this.trailing,
    this.enabled = true,
  });
}

/// `AppDropdown<T>` — Komponen dropdown reusable berbasis Material 3 DropdownMenu.
/// Menu terbuka di bawah field (lebar menu sama dengan lebar field),
/// surface dan border konsisten dengan token desain, item terpilih disorot lembut,
/// dan tinggi menu dibatasi serta dapat di-scroll (design-system.md §7).
class AppDropdown<T> extends StatefulWidget {
  final String? label;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final Widget? leadingIcon;
  final bool enabled;
  final double menuHeight;
  final FocusNode? focusNode;

  const AppDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.leadingIcon,
    this.enabled = true,
    this.menuHeight = 280,
    this.focusNode,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  late TextEditingController _controller;

  String _getLabelForValue(T? val) {
    if (val == null) return '';
    for (final item in widget.items) {
      if (item.value == val) {
        return item.label;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _getLabelForValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant AppDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newLabel = _getLabelForValue(widget.value);
      if (_controller.text != newLabel) {
        _controller.text = newLabel;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderNeutral;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.white;

    final entries = widget.items.map((item) {
      final isSelected = widget.value == item.value;
      return DropdownMenuEntry<T>(
        value: item.value,
        label: item.label,
        leadingIcon: item.leading,
        trailingIcon: item.trailing,
        enabled: item.enabled,
        style: MenuItemButton.styleFrom(
          backgroundColor: isSelected
              ? (isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.18)
                  : AppColors.sageGreen.withValues(alpha: 0.25))
              : null,
          foregroundColor: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.deepTeal)
              : (isDark ? AppColors.inkDark : AppColors.ink),
          textStyle: isSelected
              ? AppText.bodyMedium(
                  color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                ).copyWith(fontWeight: FontWeight.w600)
              : AppText.bodyMedium(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppText.caption(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        DropdownMenu<T>(
          controller: _controller,
          focusNode: widget.focusNode,
          initialSelection: widget.value,
          enabled: widget.enabled,
          expandedInsets: EdgeInsets.zero,
          menuHeight: widget.menuHeight,
          requestFocusOnTap: false,
          enableSearch: false,
          hintText: widget.hintText,
          leadingIcon: widget.leadingIcon,
          trailingIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            size: 22,
          ),
          selectedTrailingIcon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: primaryColor,
            size: 22,
          ),
          textStyle: AppText.bodyMedium(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(surfaceColor),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(4),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                side: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: 14,
            ),
            hintStyle: AppText.metadata(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            constraints: const BoxConstraints(
              maxHeight: AppSpacing.inputHeight,
              minHeight: AppSpacing.inputHeight,
            ),
          ),
          dropdownMenuEntries: entries,
          onSelected: (val) {
            widget.onChanged?.call(val);
          },
        ),
      ],
    );
  }
}
