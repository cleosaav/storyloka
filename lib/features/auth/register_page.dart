import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../core/widgets/responsive_body.dart';
import 'auth_controller.dart';

/// Halaman Register — PRD §7.1 & §13.0 Fase A1.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    bool isValid = true;

    // 1. Nama wajib diisi
    if (name.isEmpty) {
      _nameError = 'Nama lengkap wajib diisi';
      isValid = false;
    }

    // 2. Email format valid
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

    // 3. Password minimal 8 karakter
    if (password.isEmpty) {
      _passwordError = 'Password wajib diisi';
      isValid = false;
    } else if (password.length < 8) {
      _passwordError = 'Password minimal 8 karakter';
      isValid = false;
    }

    // 4. Konfirmasi password harus sama
    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Konfirmasi password wajib diisi';
      isValid = false;
    } else if (confirmPassword != password) {
      _confirmPasswordError = 'Konfirmasi password tidak cocok';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;

    final auth = context.read<AuthController>();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await auth.register(
      name: name,
      email: email,
      password: password,
    );

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
          'Daftar Akun',
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
              // Header Editorial
              Text(
                'Buat Akun Baru',
                style: AppText.pageHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Mulai perjalanan membaca dan kelola koleksi buku Anda.',
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

              // Field Nama
              AppTextField(
                controller: _nameController,
                label: 'Nama Lengkap',
                hintText: 'Nama Anda',
                errorText: _nameError,
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                  auth.clearError();
                },
              ),
              const SizedBox(height: AppSpacing.l),

              // Field Email
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

              // Field Password
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
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                  auth.clearError();
                },
              ),
              const SizedBox(height: AppSpacing.l),

              // Field Konfirmasi Password
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Password',
                hintText: 'Ulangi password di atas',
                obscureText: true,
                errorText: _confirmPasswordError,
                textInputAction: TextInputAction.done,
                prefixIcon: Icon(
                  Icons.lock_reset_rounded,
                  size: 20,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                onSubmitted: (_) => _handleRegister(),
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() => _confirmPasswordError = null);
                  }
                  auth.clearError();
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Tombol Daftar
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Daftar',
                  isLoading: auth.isLoading,
                  onPressed: auth.isLoading ? null : _handleRegister,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Link ke Login
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sudah punya akun?',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  TertiaryButton(
                    label: 'Masuk',
                    color: isDark
                        ? AppColors.primaryDark
                        : AppColors.deepTeal,
                    onPressed: () {
                      auth.clearError();
                      context.pop();
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
