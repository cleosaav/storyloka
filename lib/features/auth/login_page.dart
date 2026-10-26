import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../core/widgets/responsive_body.dart';
import '../../data/repositories/fake/fake_repositories.dart';
import 'auth_controller.dart';

/// Halaman Login — PRD §7.1 & §13.0 Fase A1.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _credentialsInitialized = false;

  String? _emailError;
  String? _passwordError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_credentialsInitialized) {
      _credentialsInitialized = true;
      final auth = context.read<AuthController>();
      final isFake = AppConfig.useFakeData || (auth.authRepository is FakeAuthRepository);
      if (isFake) {
        _emailController.text = 'reader@storyloka.app';
        _passwordController.text = 'password123';
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool isValid = true;

    if (email.isEmpty) {
      _emailError = 'Email wajib diisi';
      isValid = false;
    } else {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(email)) {
        _emailError = 'Format email tidak valid';
        isValid = false;
      }
    }

    if (password.isEmpty) {
      _passwordError = 'Password wajib diisi';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleLogin() async {
    if (!_validateForm()) return;

    final auth = context.read<AuthController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await auth.login(email, password);
    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthController>();
    final isFake = AppConfig.useFakeData || (auth.authRepository is FakeAuthRepository);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StoryLoka',
          style: AppText.cardHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.l),
            child: Center(child: DemoModeChip()),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.m),
              // Judul Editorial
              Text(
                'Selamat Datang Kembali',
                style: AppText.pageHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Masuk untuk melanjutkan jurnal membaca Anda.',
                style: AppText.body(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Banner error dari backend / controller jika ada
              if (auth.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: AppText.caption(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
              ],

              // Form fields
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'nama@domain.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                prefixIcon: Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                  auth.clearError();
                },
              ),
              const SizedBox(height: AppSpacing.l),

              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Minimal 8 karakter',
                obscureText: true,
                errorText: _passwordError,
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                  auth.clearError();
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Tombol Login
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Login',
                  isLoading: auth.isLoading,
                  onPressed: auth.isLoading ? null : _handleLogin,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Navigasi ke Register
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Belum punya akun?',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  TertiaryButton(
                    label: 'Daftar',
                    color: isDark
                        ? AppColors.primaryDark
                        : AppColors.deepTeal,
                    onPressed: () {
                      auth.clearError();
                      context.push('/register');
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // Kartu bantuan mode demo (hanya tampil jika useFakeData && kDebugMode)
              if (isFake && kDebugMode) ...[
                const SizedBox(height: AppSpacing.l),
                NotesCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: AppSpacing.iconM,
                            color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              'Catatan Mode Demo (Fase A1)',
                              style: AppText.caption(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '• Masukkan email apa saja & password ≥ 8 karakter.\n'
                        '• Password "wrong" untuk simulasi kredensial salah.\n'
                        '• Email "taken@demo.com" untuk simulasi email terdaftar.',
                        style: AppText.caption(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
