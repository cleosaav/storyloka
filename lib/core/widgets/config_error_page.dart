import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Layar error konfigurasi ketika SUPABASE_URL / SUPABASE_ANON_KEY belum diisi — PRD §3.
class ConfigErrorPage extends StatelessWidget {
  final VoidCallback? onRetry;

  const ConfigErrorPage({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.inkDark : AppColors.ink;
    final secondaryTextColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    'Konfigurasi Belum Lengkap',
                    style: AppText.cardHeading(color: primaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'Aplikasi membutuhkan kredensial Supabase untuk terhubung ke server backend.',
                    style: AppText.body(color: secondaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.sageGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Langkah penanganan:',
                          style: AppText.bodyMedium(
                            color: isDark ? AppColors.inkDark : AppColors.deepTeal,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '1. Buka file .env di folder StoryLoka Anda.\n'
                          '2. Salin SUPABASE_URL & SUPABASE_ANON_KEY dari dashboard Supabase.\n'
                          '3. Simpan file lalu tekan tombol di bawah untuk memuat ulang.',
                          style: AppText.caption(color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Periksa Ulang Konfigurasi',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
