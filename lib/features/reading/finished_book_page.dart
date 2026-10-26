import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/book_widgets.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/reading_repository.dart';

/// Halaman Selesai Membaca (Finished Book) — PRD §7.4.
///
/// Menampilkan ucapan selamat, ilustrasi perayaan ringan, ringkasan buku dan durasi baca.
/// Otomatis kembali ke Home setelah 5 detik jika tombol tidak ditekan (timer dibatalkan di dispose).
class FinishedBookPage extends StatefulWidget {
  final String id;

  const FinishedBookPage({super.key, required this.id});

  @override
  State<FinishedBookPage> createState() => _FinishedBookPageState();
}

class _FinishedBookPageState extends State<FinishedBookPage> {
  UserBook? _book;
  int _totalReadingSeconds = 0;
  bool _isLoading = true;
  Timer? _autoRedirectTimer;
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final library = context.read<LibraryRepository>();
      final readingRepo = context.read<ReadingRepository>();

      final book = await library.getBookById(widget.id);
      final sessions = await readingRepo.getSessionsForBook(widget.id);
      final totalSec = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

      if (!mounted) return;

      setState(() {
        _book = book;
        _totalReadingSeconds = totalSec;
        _isLoading = false;
      });

      _startAutoRedirect();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _startAutoRedirect();
    }
  }

  void _startAutoRedirect() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          timer.cancel();
        }
      });
    });

    _autoRedirectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  void _goHomeNow() {
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    context.go('/home');
  }

  String _formatTotalDuration(int seconds) {
    if (seconds <= 0) return '0 menit';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}j ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, r) {
        _autoRedirectTimer?.cancel();
        _countdownTimer?.cancel();
      },
      child: Scaffold(
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.primaryColor),
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageMargin,
                        vertical: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: AppSpacing.l),

                          // Ilustrasi Perayaan Ringan (ikon piala & buku dalam badge melingkar)
                          Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.softApricot.withValues(alpha: isDark ? 0.2 : 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.softApricot : AppColors.softApricot,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 58,
                            color: isDark ? AppColors.softApricot : AppColors.deepTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),

                      // Ucapan Selamat (Fraunces)
                      Text(
                        'Selamat!',
                        style: AppText.pageHeading(
                          color: isDark ? AppColors.inkDark : AppColors.deepTeal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Kamu telah menyelesaikan buku ini',
                        style: AppText.cardHeading(
                          color: isDark ? AppColors.mutedDark : AppColors.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Cover Buku
                      if (_book != null) ...[
                        BookCover(
                          coverUrl: _book!.coverUrl,
                          width: 80,
                          height: 120,
                          borderRadius: 12,
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          _book!.title,
                          style: AppText.sectionHeading(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_book!.authors != null && _book!.authors!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _book!.authors!,
                            style: AppText.caption(
                              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.l),

                        // Ringkasan: Total Halaman & Total Durasi
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.m,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${_book!.pageCount ?? _book!.currentPage}',
                                      style: AppText.sectionHeading(
                                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Halaman Selesai',
                                      textAlign: TextAlign.center,
                                      style: AppText.caption(
                                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 32,
                                width: 1,
                                color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      _formatTotalDuration(_totalReadingSeconds),
                                      style: AppText.sectionHeading(
                                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Waktu Membaca',
                                      textAlign: TextAlign.center,
                                      style: AppText.caption(
                                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      // Tombol Back to Home + Countdown
                      PrimaryButton(
                        label: 'Kembali ke Beranda ($_countdown dtk)',
                        icon: Icons.home_rounded,
                        onPressed: _goHomeNow,
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }
}
