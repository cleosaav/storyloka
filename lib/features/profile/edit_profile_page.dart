import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Edit Profil — PRD §7.8.
///
/// Fitur:
/// - Mengubah nama (wajib diisi, dengan validasi)
/// - Mengubah bio singkat (maksimal 160 karakter)
/// - Menampilkan email (disabled)
/// - Mengubah foto profil via [ImagePicker] (kamera atau galeri, kompresi <= 800px)
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;

  String? _avatarPath;
  String? _nameError;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _avatarPath = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _validate() {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      setState(() => _nameError = 'Nama lengkap wajib diisi.');
      return false;
    }
    if (text.length < 2) {
      setState(() => _nameError = 'Nama minimal 2 karakter.');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _avatarPath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Gagal memilih gambar: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _showImageSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubah Foto Profil',
                  style: AppText.cardHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_rounded,
                    color: AppColors.deepTeal,
                  ),
                  title: Text(
                    'Ambil Foto (Kamera)',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.oceanTeal,
                  ),
                  title: Text(
                    'Pilih dari Galeri',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_avatarPath != null && _avatarPath!.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Hapus Foto Profil',
                      style: AppText.bodyMedium(
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => _avatarPath = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final bio = _bioController.text.trim();

      // Panggil ProfileRepository
      final repo = context.read<ProfileRepository>();
      await repo.updateProfile(
        name: name,
        bio: bio.isNotEmpty ? bio : null,
        avatarPath: _avatarPath,
      );

      // Sinkronisasi ke AuthController
      if (mounted) {
        await context.read<AuthController>().updateProfile(
              name: name,
              bio: bio.isNotEmpty ? bio : null,
              avatarUrl: _avatarPath,
            );

        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Profil berhasil diperbarui.',
            type: SnackBarType.success,
          );

          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Gagal memperbarui profil: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget avatarImageWidget;
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      if (!kIsWeb && File(_avatarPath!).existsSync()) {
        avatarImageWidget = ClipOval(
          child: Image.file(
            File(_avatarPath!),
            width: AppSpacing.avatarImageSize,
            height: AppSpacing.avatarImageSize,
            fit: BoxFit.cover,
          ),
        );
      } else if (_avatarPath!.startsWith('http')) {
        avatarImageWidget = ClipOval(
          child: Image.network(
            _avatarPath!,
            width: AppSpacing.avatarImageSize,
            height: AppSpacing.avatarImageSize,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultAvatar(isDark),
          ),
        );
      } else {
        avatarImageWidget = _defaultAvatar(isDark);
      }
    } else {
      avatarImageWidget = _defaultAvatar(isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profil',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Picker Card
            Center(
              child: Stack(
                children: [
                  Container(
                    width: AppSpacing.avatarContainerSize,
                    height: AppSpacing.avatarContainerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                        width: 3,
                      ),
                    ),
                    child: Center(child: avatarImageWidget),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: context.primaryColor,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: Semantics(
                        label: 'Ubah foto profil',
                        button: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _showImageSourceSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.s),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: AppSpacing.iconM,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TertiaryButton(
              label: 'Ganti Foto',
              icon: Icons.edit_outlined,
              onPressed: _showImageSourceSheet,
            ),
            const SizedBox(height: AppSpacing.l),

            // Form fields
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Nama Lengkap *',
                    controller: _nameController,
                    hintText: 'Masukkan nama lengkap',
                    errorText: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) _validate();
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    label: 'Bio Singkat',
                    controller: _bioController,
                    hintText: 'Tulis bio atau kutipan favoritmu...',
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    label: 'Email (Tidak dapat diubah)',
                    controller: _emailController,
                    enabled: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Save button
            PrimaryButton(
              label: 'Simpan Perubahan',
              icon: Icons.save_rounded,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(bool isDark) {
    return CircleAvatar(
      radius: AppSpacing.avatarXLargeRadius,
      backgroundColor: isDark
          ? AppColors.primaryDark.withValues(alpha: 0.3)
          : AppColors.sageGreen.withValues(alpha: 0.4),
      child: Icon(
        Icons.person_rounded,
        size: AppSpacing.iconXxl,
        color: isDark ? AppColors.inkDark : AppColors.deepTeal,
      ),
    );
  }
}
