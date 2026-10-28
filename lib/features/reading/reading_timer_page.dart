import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/book_widgets.dart';
import '../../data/models/reading_session.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/reading_repository.dart';

/// Halaman Stopwatch Membaca (Reading Timer) — PRD §7.4.
///
/// Stopwatch dihitung dari timestamp asli (wall-clock time), bukan sekadar increment
/// variabel agar tetap akurat saat aplikasi diminimalkan atau masuk background.
class ReadingTimerPage extends StatefulWidget {
  final String id;

  const ReadingTimerPage({super.key, required this.id});

  @override
  State<ReadingTimerPage> createState() => _ReadingTimerPageState();
}

class _ReadingTimerPageState extends State<ReadingTimerPage> {
  UserBook? _book;
  bool _isLoading = true;
  String? _errorMessage;

  // State stopwatch berbasis timestamp
  bool _isRunning = false;
  DateTime? _startTimestamp;
  Duration _accumulatedDuration = Duration.zero;
  Timer? _ticker;

  static const Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadBookAndStart();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    NotificationService.instance.cancelStopwatchNotification();
    super.dispose();
  }

  Future<void> _loadBookAndStart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final library = context.read<LibraryRepository>();
      final book = await library.getBookById(widget.id);
      if (!mounted) return;

      if (book == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Buku tidak ditemukan di koleksi.';
        });
      } else {
        // Otomatis update status ke reading jika belum
        if (book.status != BookStatus.reading) {
          final updated = book.copyWith(
            status: BookStatus.reading,
            startedAt: book.startedAt ?? DateTime.now(),
            lastReadAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await library.updateBook(updated);
          if (!mounted) return;
          _book = updated;
        } else {
          _book = book;
        }

        setState(() {
          _isLoading = false;
        });

        // Langsung mulai stopwatch saat halaman dibuka
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal menyiapkan timer membaca.';
      });
    }
  }

  Duration get _currentElapsed {
    if (_isRunning && _startTimestamp != null) {
      return _accumulatedDuration + DateTime.now().difference(_startTimestamp!);
    }
    return _accumulatedDuration;
  }

  void _startTimer() {
    if (_isRunning) return;
    final now = DateTime.now();
    setState(() {
      _isRunning = true;
      _startTimestamp = now;
    });

    // Menghitung effective start time agar chronometer notifikasi memperhitungkan durasi terakumulasi
    final effectiveStartTime = now.subtract(_accumulatedDuration);
    NotificationService.instance.showStopwatchNotification(
      bookTitle: _book?.title ?? 'Buku',
      startTime: effectiveStartTime,
    );

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    final now = DateTime.now();
    _ticker?.cancel();
    final elapsed = _currentElapsed;
    setState(() {
      _isRunning = false;
      if (_startTimestamp != null) {
        _accumulatedDuration += now.difference(_startTimestamp!);
        _startTimestamp = null;
      }
    });

    // Saat pause, tampilkan notifikasi berstatus 'Dijeda' — PRD §10.5 & Fase R4
    NotificationService.instance.showStopwatchPausedNotification(
      bookTitle: _book?.title ?? 'Buku',
      elapsed: elapsed,
    );
  }

  void _togglePlayPause() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _finishReading() async {
    _ticker?.cancel();
    NotificationService.instance.cancelStopwatchNotification();
    final elapsed = _currentElapsed;
    final durationSeconds = elapsed.inSeconds;
    setState(() {
      _isRunning = false;
    });

    if (_book != null && durationSeconds > 0) {
      final session = ReadingSession(
        id: _uuid.v4(),
        userId: _book!.userId,
        userBookId: _book!.id,
        startedAt: DateTime.now().subtract(elapsed),
        endedAt: DateTime.now(),
        durationSeconds: durationSeconds,
        createdAt: DateTime.now(),
      );
      final readingRepo = context.read<ReadingRepository>();
      await readingRepo.saveSession(session);
    }

    if (!mounted) return;

    // Arahkan ke Reading Progress dengan membawa info durasi sesi
    context.pushReplacement(
      '/reading/progress/${widget.id}?duration=$durationSeconds',
    );
  }

  Future<bool> _handlePopScope() async {
    final elapsed = _currentElapsed;
    if (elapsed.inSeconds <= 0 && !_isRunning) {
      return true;
    }

    _pauseTimer();

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AppDialog(
          title: Text(
            'Keluar dari Sesi Membaca?',
            style: AppText.cardHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          content: Text(
            'Sesi membaca Anda sedang berlangsung. Apakah Anda ingin menyimpan sesi ini atau membuangnya?',
            style: AppText.body(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
          ),
          actions: [
            TertiaryButton(
              label: 'Buang',
              color: AppColors.error,
              onPressed: () => Navigator.of(ctx).pop('discard'),
            ),
            TertiaryButton(
              label: 'Lanjut Membaca',
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              onPressed: () => Navigator.of(ctx).pop('continue'),
            ),
            PrimaryButton(
              label: 'Simpan & Keluar',
              onPressed: () => Navigator.of(ctx).pop('save'),
            ),
          ],
        );
      },
    );

    if (action == 'save') {
      await _finishReading();
      return false;
    } else if (action == 'discard') {
      await NotificationService.instance.cancelStopwatchNotification();
      return true;
    } else {
      // Lanjut membaca
      _startTimer();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final allow = await _handlePopScope();
        if (!mounted) return;
        if (allow) {
          router.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Reading Timer',
            style: AppText.sectionHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          leading: AppIconButton(
            tooltip: 'Kembali',
            icon: Icons.arrow_back_rounded,
            onPressed: () async {
              final router = GoRouter.of(context);
              final allow = await _handlePopScope();
              if (!mounted) return;
              if (allow) {
                router.pop();
              }
            },
          ),
        ),
        body: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.primaryColor),
      );
    }

    if (_errorMessage != null || _book == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: isDark ? AppColors.mutedDark : AppColors.error,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _errorMessage ?? 'Buku tidak ditemukan',
                style: AppText.cardHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                label: 'Kembali',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    final book = _book!;
    final elapsed = _currentElapsed;
    final timeFormatted = _formatDuration(elapsed);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final stopwatchSize = (screenWidth * 0.55).clamp(180.0, 260.0);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.l,
            ),
            child: Column(
              children: [
                // Info ringkas buku di atas
                Row(
                  children: [
                    BookCover(
                      coverUrl: book.coverUrl,
                      width: 50,
                      height: 75,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: AppText.cardHeading(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (book.authors != null && book.authors!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              book.authors!,
                              style: AppText.caption(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Stopwatch besar dalam Ring Sage dengan ikon daun/buku
                Center(
                  child: Semantics(
                    label: 'Waktu membaca: $timeFormatted',
                    liveRegion: true,
                    child: Container(
                      width: stopwatchSize,
                      height: stopwatchSize,
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.warmIvory,
                        border: Border.all(
                          color: _isRunning
                              ? context.primaryColor
                              : (isDark ? AppColors.borderDark : AppColors.sageGreen),
                          width: 6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRunning ? context.primaryColor : AppColors.sageGreen)
                                .withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 24,
                            color: _isRunning
                                ? context.primaryColor
                                : (isDark ? AppColors.mutedDark : AppColors.mutedGray),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              timeFormatted,
                              style: AppText.displayMedium(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                                fontSize: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isRunning ? 'Sedang Membaca...' : 'Timer Dijeda',
                              style: AppText.caption(
                                color: _isRunning
                                    ? (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                                    : (isDark ? AppColors.mutedDark : AppColors.mutedGray),
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),

            // Kontrol: Play/Pause besar dan Finish Reading
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: _isRunning ? 'Pause' : 'Resume',
                    icon: _isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: _togglePlayPause,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  flex: 3,
                  child: SecondaryButton(
                    label: 'Finish Reading',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _finishReading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      ),
    ),
  ),
);
}
}
