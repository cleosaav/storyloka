import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/responsive_body.dart';
import 'auth_controller.dart';

/// Halaman Login — PRD §7.1.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

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
    } else if (password.length < 8) {
      _passwordError = 'Password minimal 8 karakter';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StoryLoka',
          style: AppText.cardHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
