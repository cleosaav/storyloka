import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/demo_widgets.dart';
import 'auth_controller.dart';

/// Halaman Lock Screen (Biometrik) — PRD §7.1 & §13.0 Fase A1 / B2.
/// Muncul jika pengguna memiliki session aktif dan fitur biometrik diaktifkan.
class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoBypass();
      _promptBiometric();
    });
  }

  void _checkAutoBypass() {
    final demo = context.read<DemoControls>();
    if (demo.bypassBiometric) {
      _handleUnlock();
    }
  }

  Future<void> _promptBiometric() async {
    final demo = context.read<DemoControls>();
    if (demo.bypassBiometric) return;

    final bioService = context.read<BiometricService?>();
    if (bioService == null) return;

    final canAuth = await bioService.canAuthenticate();
    if (canAuth) {
      final success = await bioService.authenticate(
        localizedReason: 'Sentuh sensor biometrik untuk melanjutkan membaca di StoryLoka',
      );
      if (success && mounted) {
        _handleUnlock();
      }
    }
  }

  void _handleUnlock() {
    final auth = context.read<AuthController>();
    auth.unlockBiometric();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _handlePasswordFallback() async {
    final auth = context.read<AuthController>();
    await auth.loginWithPasswordFallback();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final auth = context.watch<AuthController>();
    final userName = auth.currentUser?.name ?? 'Pembaca StoryLoka';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.l),
            child: Center(child: DemoModeChip()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.l,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Lingkaran Avatar / Icon Kunci
              GestureDetector(
                onTap: _promptBiometric,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.softApricot.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.softApricot,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 48,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Sapaan Editorial
              Text(
                'Selamat Datang Kembali,',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                userName,
                style: AppText.pageHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Aplikasi terkunci. Sentuh sensor biometrik untuk melanjutkan membaca.',
                style: AppText.body(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Tombol Simulasi Biometrik (Hanya di mode demo — PRD §13.0 Fase A1)
              if (kDebugMode) ...[
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Simulasi Biometrik (Demo)',
                    icon: Icons.fingerprint_rounded,
                    onPressed: _handleUnlock,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
              ],

              // Tombol Coba Lagi
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  label: 'Coba Lagi',
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    await _promptBiometric();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              // Tombol Login dengan Password (menghapus session lokal -> /login)
              TextButton(
                onPressed: _handlePasswordFallback,
                child: Text(
                  'Login dengan password',
                  style: AppText.button(
                    color: isDark
                        ? AppColors.mutedDark
                        : AppColors.mutedGray,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
            ],
          ),
        ),
      ),
    );
  }
}
