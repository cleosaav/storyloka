import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import 'auth_controller.dart';

/// Splash Page — PRD §7.1.
/// Menampilkan identitas StoryLoka (Fraunces) dan ilustrasi daun/buku,
/// lalu memverifikasi session lokal di secure storage.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuth();
    });
  }

  Future<void> _initAuth() async {
    if (mounted) {
      await context.read<AuthController>().checkSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Ilustrasi buku + daun botanical
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.sageGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.sageGreen.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Nama Aplikasi (Fraunces SemiBold 30)
              Text(
                'StoryLoka',
                style: AppText.pageHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Tagline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  'Personal Book Management & Reading Companion',
                  style: AppText.metadata(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Indikator loading
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
