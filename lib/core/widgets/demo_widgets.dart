import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Controller untuk simulasi kondisi testing di Demo Mode (hanya kDebugMode).
/// PRD §13.0 aturan 6: DemoControls (bottom sheet dari Profile): ganti data berisi/kosong,
/// simulasi error jaringan, simulasi lambat, lewati biometrik.
class DemoControls extends ChangeNotifier {
  bool _isDataEmpty = false;
  bool _simulateNetworkError = false;
  bool _simulateSlowLatency = false;
  bool _bypassBiometric = false;

  bool get isDataEmpty => _isDataEmpty;
  bool get simulateNetworkError => _simulateNetworkError;
  bool get simulateSlowLatency => _simulateSlowLatency;
  bool get bypassBiometric => _bypassBiometric;

  void toggleDataEmpty(bool value) {
    _isDataEmpty = value;
    notifyListeners();
  }

  void toggleNetworkError(bool value) {
    _simulateNetworkError = value;
    notifyListeners();
  }

  void toggleSlowLatency(bool value) {
    _simulateSlowLatency = value;
    notifyListeners();
  }

  void toggleBypassBiometric(bool value) {
    _bypassBiometric = value;
    notifyListeners();
  }

  void reset() {
    _isDataEmpty = false;
    _simulateNetworkError = false;
    _simulateSlowLatency = false;
    _bypassBiometric = false;
    notifyListeners();
  }
}

/// Chip kecil "Mode demo" — PRD §13.0 aturan 5.
/// Setiap layar yang menampilkan data demo memunculkan chip kecil "Mode demo" (Home dan Add Book).
class DemoModeChip extends StatelessWidget {
  final VoidCallback? onTap;

  const DemoModeChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.softApricot.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.softApricot.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFC07A15),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Mode demo',
              style: AppText.caption(
                color: const Color(0xFF8A5300),
              ).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet untuk mengontrol demo mode state (kDebugMode).
class DemoControlsSheet extends StatelessWidget {
  const DemoControlsSheet({super.key});

  static Future<void> show(BuildContext context) {
    if (!kDebugMode) return Future.value();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DemoControlsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.warmIvory;
    final demo = context.watch<DemoControls>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Demo Controls (Debug Only)',
                  style: AppText.cardHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Gunakan kontrol ini untuk memeriksa seluruh state tampilan aplikasi (loading, empty, error).',
              style: AppText.metadata(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ),
            const Divider(height: AppSpacing.xl),
            SwitchListTile.adaptive(
              title: Text(
                'Data Kosong (Empty State)',
                style: AppText.bodyMedium(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              subtitle: Text(
                'Tampilkan koleksi/wishlist dalam keadaan kosong',
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              activeThumbColor: AppColors.deepTeal,
              value: demo.isDataEmpty,
              onChanged: demo.toggleDataEmpty,
            ),
            SwitchListTile.adaptive(
              title: Text(
                'Simulasi Error Jaringan',
                style: AppText.bodyMedium(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              subtitle: Text(
                'Simulasikan kegagalan panggilan repository',
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              activeThumbColor: AppColors.error,
              value: demo.simulateNetworkError,
              onChanged: demo.toggleNetworkError,
            ),
            SwitchListTile.adaptive(
              title: Text(
                'Simulasi Respon Lambat (2s)',
                style: AppText.bodyMedium(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              subtitle: Text(
                'Perpanjang latensi untuk menguji loading spinner & skeleton',
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              activeThumbColor: AppColors.softApricot,
              value: demo.simulateSlowLatency,
              onChanged: demo.toggleSlowLatency,
            ),
            SwitchListTile.adaptive(
              title: Text(
                'Lewati Biometrik',
                style: AppText.bodyMedium(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              subtitle: Text(
                'Simulasi langsung lolos biometrik pada lock screen',
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              activeThumbColor: AppColors.success,
              value: demo.bypassBiometric,
              onChanged: demo.toggleBypassBiometric,
            ),
            const SizedBox(height: AppSpacing.l),
            Center(
              child: TextButton(
                onPressed: demo.reset,
                child: const Text('Reset Pengaturan Demo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
