import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/providers.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/light_sensor_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/secure_session_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../core/widgets/progress_and_badge.dart';
import '../../core/widgets/responsive_body.dart';
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

  // Notifikasi Pengingat & Stopwatch — PRD §10.5
  bool _readingReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _stopwatchNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final reminder = await NotificationService.instance.isReminderEnabled();
      final time = await NotificationService.instance.getReminderTime();
      final stopwatch = await NotificationService.instance.isStopwatchNotifEnabled();
      if (mounted) {
        setState(() {
          _readingReminderEnabled = reminder;
          _reminderTime = time;
          _stopwatchNotificationEnabled = stopwatch;
        });
      }
    } catch (_) {}
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
              seedColor: isDark ? AppColors.primaryDark : AppColors.deepTeal,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
      if (_readingReminderEnabled) {
        await NotificationService.instance.saveReminderSettings(
          enabled: true,
          hour: picked.hour,
          minute: picked.minute,
        );
        final pending =
            await NotificationService.instance.getPendingNotificationRequests();
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message:
              'Pengingat membaca diatur pukul ${_formatTimeOfDay(picked)} (${pending.length} aktif).',
          type: SnackBarType.success,
        );
      } else {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: 'Pengingat membaca diatur pukul ${_formatTimeOfDay(picked)}.',
        );
      }
    }
  }

  Future<void> _showNotificationPermissionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(
          'Izin Notifikasi Dibutuhkan',
          style: AppText.cardHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        content: Text(
          'StoryLoka membutuhkan izin notifikasi agar dapat mengirimkan pengingat membaca harian dan stopwatch sesi membaca Anda. Silakan aktifkan izin di pengaturan perangkat.',
          style: AppText.body(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
        ),
        actions: [
          TertiaryButton(
            label: 'Batal',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          PrimaryButton(
            label: 'Buka Pengaturan',
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Konfirmasi Keluar',
      message:
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda akan dihapus dari perangkat ini.',
      cancelLabel: 'Batal',
      confirmLabel: 'Keluar',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await NotificationService.instance.cancelDailyReadingReminder();
      if (context.mounted) {
        await context.read<AuthController>().logout();
      }
      if (context.mounted) {
        context.go('/login');
      }
    }
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
      body: ResponsiveBody(
        child: RefreshIndicator(
          color: context.primaryColor,
          onRefresh: _loadSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
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
                        Semantics(
                          label: 'Ubah foto profil',
                          button: true,
                          child: GestureDetector(
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
                                      color: context.primaryColor,
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
                                      size: AppSpacing.iconXs,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Indikator Sinkronisasi — PRD §8.3
                        Flexible(
                          child: ListenableBuilder(
                            listenable: SyncService.instance,
                            builder: (context, _) {
                              final syncService = SyncService.instance;
                              final isSynced = syncService.state == SyncState.synced;
                              final isError = syncService.state == SyncState.error;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSynced
                                        ? Icons.cloud_done_outlined
                                        : (isError
                                            ? Icons.cloud_off_outlined
                                            : Icons.cloud_upload_outlined),
                                    size: 14,
                                    color: isSynced
                                        ? AppColors.success
                                        : (isError
                                            ? AppColors.error
                                            : (isDark
                                                ? AppColors.mutedDark
                                                : AppColors.mutedGray)),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      syncService.state.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption(
                                        color: isDark
                                            ? AppColors.mutedDark
                                            : AppColors.mutedGray,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        TertiaryButton(
                          label: 'Edit Profil',
                          icon: Icons.edit_outlined,
                          onPressed: () async {
                            await context.push('/profile/edit');
                            _loadSummary();
                          },
                        ),
                      ],
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
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 20,
                          color: context.primaryColor,
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
                      LinearProgressIndicator(color: context.primaryColor)
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
                      child: Icon(
                        Icons.shield_outlined,
                        color: context.primaryColor,
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
                    FilterTabs(
                      tabs: const ['Light', 'Dark', 'Auto'],
                      selectedIndex: themeController.userPreferenceMode == ThemeMode.light
                          ? 0
                          : themeController.userPreferenceMode == ThemeMode.dark
                              ? 1
                              : 2,
                      onTabSelected: (index) {
                        const modes = [
                          ThemeMode.light,
                          ThemeMode.dark,
                          ThemeMode.system,
                        ];
                        themeController.setThemeMode(modes[index]);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ListenableBuilder(
                      listenable: LightSensorService.instance,
                      builder: (context, _) {
                        final lightService = LightSensorService.instance;
                        final String descText;
                        if (themeController.userPreferenceMode == ThemeMode.system) {
                          if (lightService.isSensorAvailable && lightService.currentLux != null) {
                            descText = 'Cahaya sekitar: ${lightService.currentLux!.toStringAsFixed(0)} lux';
                          } else {
                            descText = lightService.autoModeDescription;
                          }
                        } else if (themeController.userPreferenceMode == ThemeMode.dark) {
                          descText = 'Tema gelap aktif.';
                        } else {
                          descText = 'Tema terang (Warm Ivory) aktif.';
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              descText,
                              style: AppText.caption(
                                color: isDark
                                    ? AppColors.mutedDark
                                    : AppColors.mutedGray,
                              ),
                            ),
                            if (kDebugMode &&
                                themeController.userPreferenceMode == ThemeMode.system) ...[
                              const SizedBox(height: AppSpacing.s),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Debug: Percepat hysteresis (1 dtk)',
                                    style: AppText.caption(
                                      color: isDark
                                          ? AppColors.mutedDark
                                          : AppColors.mutedGray,
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: lightService.fastHysteresis,
                                    onChanged: (val) {
                                      lightService.fastHysteresis = val;
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
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
                        if (val) {
                          final bioService = context.read<BiometricService?>();
                          final canAuth = await bioService?.canAuthenticate() ?? false;
                          if (!canAuth) {
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                message: 'Sensor biometrik tidak tersedia atau belum terdaftar di perangkat.',
                                type: SnackBarType.warning,
                              );
                            }
                            return;
                          }
                          final ok = await bioService?.authenticate(
                                localizedReason:
                                    'Konfirmasi biometrik untuk mengaktifkan kunci aplikasi',
                              ) ??
                              false;
                          if (!ok) {
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                message: 'Verifikasi biometrik dibatalkan atau tidak cocok.',
                                type: SnackBarType.error,
                              );
                            }
                            return;
                          }
                        }
                        await authController.setBiometricEnabled(val);
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.l),

              // 6. Section Notifikasi — PRD §10.5 & Fase R4
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
                      onChanged: (val) async {
                        if (val) {
                          await NotificationService.instance.requestPermission();
                          final allowed = await NotificationService.instance
                              .areNotificationsEnabled();
                          if (!allowed) {
                            if (context.mounted) {
                              setState(() => _readingReminderEnabled = false);
                              await _showNotificationPermissionDialog();
                            }
                            return;
                          }
                          setState(() => _readingReminderEnabled = true);
                          await NotificationService.instance.saveReminderSettings(
                            enabled: true,
                            hour: _reminderTime.hour,
                            minute: _reminderTime.minute,
                          );
                          final pending = await NotificationService.instance
                              .getPendingNotificationRequests();
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              message:
                                  'Pengingat membaca dijadwalkan pukul ${_formatTimeOfDay(_reminderTime)} (${pending.length} notifikasi aktif).',
                              type: SnackBarType.success,
                            );
                          }
                        } else {
                          setState(() => _readingReminderEnabled = false);
                          await NotificationService.instance.saveReminderSettings(
                            enabled: false,
                            hour: _reminderTime.hour,
                            minute: _reminderTime.minute,
                          );
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              message: 'Pengingat membaca harian dinonaktifkan.',
                            );
                          }
                        }
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
                        trailing: TertiaryButton(
                          label: 'Ubah Jam',
                          onPressed: _pickReminderTime,
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
                  onChanged: (val) async {
                    if (val) {
                      await NotificationService.instance.requestPermission();
                      final allowed = await NotificationService.instance
                          .areNotificationsEnabled();
                      if (!allowed) {
                        if (context.mounted) {
                          setState(() => _stopwatchNotificationEnabled = false);
                          await _showNotificationPermissionDialog();
                        }
                        return;
                      }
                      setState(() => _stopwatchNotificationEnabled = true);
                      await NotificationService.instance
                          .setStopwatchNotifEnabled(true);
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message:
                              'Notifikasi stopwatch sesi membaca berhasil diaktifkan.',
                          type: SnackBarType.success,
                        );
                      }
                    } else {
                      setState(() => _stopwatchNotificationEnabled = false);
                      await NotificationService.instance
                          .setStopwatchNotifEnabled(false);
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message:
                              'Notifikasi stopwatch sesi membaca dinonaktifkan.',
                        );
                      }
                    }
                  },
                ),
              ),

              // Tombol Debug Notifikasi (kDebugMode Saja) — Butir 6
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Kirim notifikasi tes sekarang',
                        icon: Icons.notifications_active_outlined,
                        onPressed: () async {
                          await NotificationService.instance.requestPermission();
                          final allowed = await NotificationService.instance
                              .areNotificationsEnabled();
                          if (!allowed) {
                            if (context.mounted) {
                              await _showNotificationPermissionDialog();
                            }
                            return;
                          }
                          await NotificationService.instance
                              .showInstantTestNotification();
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              message:
                                  'Notifikasi tes langsung terkirim! Cek bilah notifikasi.',
                              type: SnackBarType.success,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Jadwalkan tes 2 menit lagi',
                        icon: Icons.alarm_rounded,
                        onPressed: () async {
                          await NotificationService.instance.requestPermission();
                          final allowed = await NotificationService.instance
                              .areNotificationsEnabled();
                          if (!allowed) {
                            if (context.mounted) {
                              await _showNotificationPermissionDialog();
                            }
                            return;
                          }
                          final scheduled = await NotificationService.instance
                              .scheduleTestNotificationInMinutes(2);
                          final pending = await NotificationService.instance
                              .getPendingNotificationRequests();
                          if (context.mounted) {
                            final timeStr =
                                '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
                            AppSnackBar.show(
                              context,
                              message:
                                  'Notifikasi tes dijadwalkan pukul $timeStr (${pending.length} aktif).',
                              type: SnackBarType.success,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                          Icon(
                            Icons.bug_report_outlined,
                            size: 20,
                            color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              'Status Demo Controls:',
                              style: AppText.bodyMedium(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                              ),
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
                        style: AppText.metadata(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
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
    ),
  );
}

  Widget _buildAvatarWidget(String? avatarUrl, bool isDark) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (!kIsWeb && File(avatarUrl).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(avatarUrl),
            width: AppSpacing.avatarLargeRadius * 2,
            height: AppSpacing.avatarLargeRadius * 2,
            fit: BoxFit.cover,
          ),
        );
      } else if (avatarUrl.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            avatarUrl,
            width: AppSpacing.avatarLargeRadius * 2,
            height: AppSpacing.avatarLargeRadius * 2,
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
      radius: AppSpacing.avatarLargeRadius,
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
