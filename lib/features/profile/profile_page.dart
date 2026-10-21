import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/providers.dart';
import '../../core/services/secure_session_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/reading_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Profile — PRD §7.8.
///
/// Fitur:
/// - Header: foto profil (lingkaran, tap untuk ganti), nama, email, bio singkat, tombol Edit Profil.
/// - Ringkasan buku: "{n} di koleksi • {m} wishlist • {k} selesai" + total waktu membaca ("Xj Ym").
/// - Reading Ledger link (/profile/ledger).
/// - Tampilan: Light / Dark / Auto (Segmented button, auto mengikuti sistem).
/// - Login biometrik: switch.
/// - Notifikasi: pengingat membaca (switch + time picker default 20:00) & notifikasi stopwatch (switch).
/// - Logout dengan dialog konfirmasi.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _collectionCount = 0;
  int _wishlistCount = 0;
  int _finishedCount = 0;
  int _totalReadingSeconds = 0;
  bool _isLoadingSummary = true;

  // Notifikasi UI State (Tahap A — UI saja)
  bool _readingReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _stopwatchNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final libraryRepo = context.read<LibraryRepository>();
      final readingRepo = context.read<ReadingRepository>();

      final books = await libraryRepo.getBooks();
      final totalSeconds = await readingRepo.getTotalReadingSeconds();

      if (mounted) {
        setState(() {
          _collectionCount =
              books.where((b) => b.listType == ListType.collection).length;
          _wishlistCount =
              books.where((b) => b.listType == ListType.wishlist).length;
          _finishedCount =
              books.where((b) => b.status == BookStatus.finished).length;
          _totalReadingSeconds = totalSeconds;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  String _formatReadingTime(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}j ${minutes}m';
    }
    return '${minutes}m';
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.deepTeal,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
      AppSnackBar.show(
        context,
        message: 'Pengingat membaca diatur pukul ${_formatTimeOfDay(picked)}.',
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          title: Text(
            'Konfirmasi Keluar',
            style: AppText.cardHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda akan dihapus dari perangkat ini.',
            style: AppText.body(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Batal',
                style: AppText.button(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await context.read<AuthController>().logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeController = context.watch<ThemeController>();
    final demoControls = context.watch<DemoControls>();
    final authController = context.watch<AuthController>();
    final sessionStore = context.read<SecureSessionStore>();

    final user = authController.currentUser;
    final userName = user?.name ?? 'Demo Reader';
    final userEmail = user?.email ?? 'demo@storyloka.app';
    final userBio = user?.bio?.isNotEmpty == true
        ? user!.bio!
        : 'Pencinta buku dan penjelajah cerita.';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.deepTeal,
        onRefresh: _loadSummary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Profile Card
              AppCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Lingkaran (Tap untuk Edit)
                        GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Stack(
                            children: [
                              _buildAvatarWidget(avatarUrl, isDark),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.deepTeal,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.surfaceDark
                                          : AppColors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 12,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        // Info Nama, Email, Bio
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: AppText.cardHeading(
                                  color: isDark
                                      ? AppColors.inkDark
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: AppText.metadata(
                                  color: isDark
                                      ? AppColors.mutedDark
                                      : AppColors.mutedGray,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Text(
                                userBio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption(
                                  color: isDark
                                      ? AppColors.inkDark
                                      : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await context.push('/profile/edit');
                          _loadSummary();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profil'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.primaryDark
                              : AppColors.deepTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // 2. Ringkasan Buku (Reading Summary — PRD §7.8)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bar_chart_rounded,
                          size: 20,
                          color: AppColors.deepTeal,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            'Ringkasan Bacaan',
                            style: AppText.cardHeading(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    if (_isLoadingSummary)
                      const LinearProgressIndicator(color: AppColors.deepTeal)
                    else ...[
                      Text(
                        '$_collectionCount di koleksi • $_wishlistCount wishlist • $_finishedCount selesai',
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: isDark
                                ? AppColors.mutedDark
                                : AppColors.mutedGray,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Total waktu membaca: ${_formatReadingTime(_totalReadingSeconds)}',
                              style: AppText.metadata(
                                color: isDark
                                    ? AppColors.mutedDark
                                    : AppColors.mutedGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // 3. Card Reading Ledger (Blockchain Sederhana — PRD §10.2)
              AppCard(
                onTap: () => context.push('/profile/ledger'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryDark.withValues(alpha: 0.2)
                            : AppColors.deepTeal.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.deepTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reading Ledger',
                            style: AppText.bodyMedium(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Riwayat buku selesai terenkripsi SHA-256',
                            style: AppText.caption(
                              color: isDark
                                  ? AppColors.mutedDark
                                  : AppColors.mutedGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedGray,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 4. Section Pengaturan Tampilan
              Text(
                'Tampilan',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Segmented Button: Light / Dark / Auto (PRD §7.8)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilihan Tema',
                      style: AppText.bodyMedium(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light', maxLines: 1),
                            icon: Icon(Icons.light_mode_outlined, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark', maxLines: 1),
                            icon: Icon(Icons.dark_mode_outlined, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('Auto', maxLines: 1),
                            icon: Icon(Icons.brightness_auto_outlined, size: 16),
                          ),
                        ],
                        selected: {themeController.themeMode},
                        onSelectionChanged: (newSelection) {
                          themeController.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 4),
                          ),
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return isDark
                                  ? AppColors.primaryDark
                                  : AppColors.deepTeal;
                            }
                            return Colors.transparent;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.white;
                            }
                            return isDark
                                ? AppColors.inkDark
                                : AppColors.ink;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      themeController.themeMode == ThemeMode.system
                          ? 'Auto: Mengikuti tema sistem perangkat (sensor cahaya Tahap B).'
                          : themeController.themeMode == ThemeMode.dark
                              ? 'Tema gelap aktif.'
                              : 'Tema terang (Warm Ivory) aktif.',
                      style: AppText.caption(
                        color: isDark
                            ? AppColors.mutedDark
                            : AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              // 5. Section Keamanan
              Text(
                'Keamanan',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Biometric switch
              FutureBuilder<bool>(
                future: sessionStore.isBiometricEnabled(),
                builder: (context, snapshot) {
                  final isBioEnabled = snapshot.data ?? false;
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile.adaptive(
                      title: Text(
                        'Kunci Biometrik (Fingerprint / Face ID)',
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        isBioEnabled
                            ? 'Aktif — Lock screen muncul saat membuka aplikasi'
                            : 'Nonaktif — Langsung masuk tanpa biometrik',
                        style: AppText.caption(
                          color: isDark
                              ? AppColors.mutedDark
                              : AppColors.mutedGray,
                        ),
                      ),
                      activeThumbColor: isDark
                          ? AppColors.primaryDark
                          : AppColors.deepTeal,
                      value: isBioEnabled,
                      onChanged: (val) async {
                        await authController.setBiometricEnabled(val);
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.l),

              // 6. Section Notifikasi (UI Saja — PRD §7.8)
              Text(
                'Notifikasi',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Pengingat Membaca
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: Text(
                        'Pengingat Membaca Harian',
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        _readingReminderEnabled
                            ? 'Aktif setiap hari pukul ${_formatTimeOfDay(_reminderTime)}'
                            : 'Nonaktif',
                        style: AppText.caption(
                          color: isDark
                              ? AppColors.mutedDark
                              : AppColors.mutedGray,
                        ),
                      ),
                      activeThumbColor: isDark
                          ? AppColors.primaryDark
                          : AppColors.deepTeal,
                      value: _readingReminderEnabled,
                      onChanged: (val) {
                        setState(() => _readingReminderEnabled = val);
                      },
                    ),
                    if (_readingReminderEnabled) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.oceanTeal,
                          size: 20,
                        ),
                        title: Text(
                          'Pukul ${_formatTimeOfDay(_reminderTime)}',
                          style: AppText.bodyMedium(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _pickReminderTime,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? AppColors.primaryDark
                                : AppColors.deepTeal,
                          ),
                          child: const Text('Ubah Jam'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Notifikasi Stopwatch
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile.adaptive(
                  title: Text(
                    'Notifikasi Stopwatch Sesi',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  subtitle: Text(
                    _stopwatchNotificationEnabled
                        ? 'Menampilkan notifikasi ongoing saat timer berjalan'
                        : 'Nonaktif',
                    style: AppText.caption(
                      color: isDark
                          ? AppColors.mutedDark
                          : AppColors.mutedGray,
                    ),
                  ),
                  activeThumbColor:
                      isDark ? AppColors.primaryDark : AppColors.deepTeal,
                  value: _stopwatchNotificationEnabled,
                  onChanged: (val) {
                    setState(() => _stopwatchNotificationEnabled = val);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 7. Demo Controls section (kDebugMode)
              if (kDebugMode) ...[
                Text(
                  'Mode Demo & QA (Debug)',
                  style: AppText.sectionHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                NotesCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bug_report_outlined,
                            size: 20,
                            color: AppColors.deepTeal,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              'Status Demo Controls:',
                              style: AppText.bodyMedium(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        '• Data Kosong: ${demoControls.isDataEmpty ? "Aktif" : "Nonaktif"}\n'
                        '• Simulasi Error: ${demoControls.simulateNetworkError ? "Aktif" : "Nonaktif"}\n'
                        '• Latensi Lambat: ${demoControls.simulateSlowLatency ? "Aktif (2s)" : "Normal"}\n'
                        '• Lewati Biometrik: ${demoControls.bypassBiometric ? "Aktif" : "Nonaktif"}',
                        style: AppText.metadata(color: AppColors.ink),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      PrimaryButton(
                        label: 'Buka Demo Controls',
                        icon: Icons.tune_rounded,
                        onPressed: () => DemoControlsSheet.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // 8. Logout Button
              Center(
                child: TertiaryButton(
                  label: 'Keluar dari Akun (Logout)',
                  icon: Icons.logout_rounded,
                  color: AppColors.error,
                  onPressed: () => _confirmLogout(context),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String? avatarUrl, bool isDark) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (!kIsWeb && File(avatarUrl).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(avatarUrl),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        );
      } else if (avatarUrl.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            avatarUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultAvatar(isDark),
          ),
        );
      }
    }
    return _defaultAvatar(isDark);
  }

  Widget _defaultAvatar(bool isDark) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: isDark
          ? AppColors.primaryDark.withValues(alpha: 0.3)
          : AppColors.sageGreen.withValues(alpha: 0.4),
      child: Icon(
        Icons.person_rounded,
        size: 38,
        color: isDark ? AppColors.inkDark : AppColors.deepTeal,
      ),
    );
  }
}
