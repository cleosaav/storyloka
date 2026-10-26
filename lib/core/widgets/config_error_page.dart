import 'package:flutter/material.dart';

import '../config/env.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Layar error konfigurasi ketika file .env tidak ditemukan,
/// atau variabel wajib seperti SUPABASE_URL / SUPABASE_ANON_KEY kosong — PRD §3 & Fase R1.
class ConfigErrorPage extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool? isFileNotFound;
  final List<String>? missingVariables;
  final String? errorMessage;

  const ConfigErrorPage({
    super.key,
    this.onRetry,
    this.isFileNotFound,
    this.missingVariables,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.inkDark : AppColors.ink;
    final secondaryTextColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;

    final fileMissing = isFileNotFound ?? Env.isEnvFileNotFound;
    final missing = missingVariables ?? Env.missingVariables;

    String headingText;
    String descriptionText;

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      headingText = 'Inisialisasi Backend Gagal';
      descriptionText = errorMessage!;
    } else if (fileMissing) {
      headingText = 'File .env Tidak Ditemukan';
      descriptionText =
          'File konfigurasi .env tidak ditemukan di direktori proyek StoryLoka. '
          'Salin .env.example menjadi .env dan isi kredensial yang dibutuhkan.';
    } else if (missing.isNotEmpty) {
      headingText = 'Variabel .env Belum Lengkap';
      descriptionText =
          'Aplikasi berjalan dalam mode nyata namun variabel berikut masih kosong di file .env:\n'
          '${missing.map((v) => '• $v').join('\n')}';
    } else {
      headingText = 'Konfigurasi Belum Lengkap';
      descriptionText =
          'Aplikasi membutuhkan kredensial Supabase untuk terhubung ke server backend.';
    }

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
                    headingText,
                    style: AppText.cardHeading(color: primaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    descriptionText,
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
                          fileMissing
                              ? '1. Buat file .env di folder StoryLoka (salin dari .env.example).\n'
                                '2. Masukkan SUPABASE_URL dan SUPABASE_ANON_KEY.\n'
                                '3. Tekan tombol di bawah untuk mencoba kembali.'
                              : '1. Buka file .env di folder StoryLoka Anda.\n'
                                '2. Pastikan variabel di atas telah terisi dengan benar.\n'
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
                      label: 'Coba Lagi',
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
