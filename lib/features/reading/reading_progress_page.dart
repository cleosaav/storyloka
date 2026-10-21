import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/ledger_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/book_widgets.dart';
import '../../core/widgets/progress_and_badge.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/reading_repository.dart';

/// Halaman Pencatatan Progress Membaca — PRD §7.4.
class ReadingProgressPage extends StatefulWidget {
  final String id;
  final int? sessionDurationSeconds;

  const ReadingProgressPage({
    super.key,
    required this.id,
    this.sessionDurationSeconds,
  });

  @override
  State<ReadingProgressPage> createState() => _ReadingProgressPageState();
}

class _ReadingProgressPageState extends State<ReadingProgressPage> {
  UserBook? _book;
  bool _isLoading = true;
  String? _errorMessage;

  late TextEditingController _pageController;
  late TextEditingController _totalPageController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController();
    _totalPageController = TextEditingController();
    _loadBook();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _totalPageController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
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
        _book = book;
        _currentPage = book.currentPage;
        _totalPages = book.pageCount ?? 0;

        _pageController.text = '$_currentPage';
        _totalPageController.text = _totalPages > 0 ? '$_totalPages' : '';

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat progress buku.';
      });
    }
  }

  void _onSliderChanged(double value) {
    final newPage = value.round();
    setState(() {
      _currentPage = newPage;
      _pageController.text = '$newPage';
    });
  }

  void _onPageTextChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      setState(() {
        _currentPage = parsed.clamp(0, _totalPages > 0 ? _totalPages : parsed);
      });
    }
  }

  void _onTotalPageTextChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() {
        _totalPages = parsed;
        if (_currentPage > _totalPages) {
          _currentPage = _totalPages;
          _pageController.text = '$_currentPage';
        }
      });
    }
  }

  String _formatSessionDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m > 0) {
      return '$m menit $s detik';
    }
    return '$s detik';
  }

  Future<void> _saveProgress() async {
    if (_book == null || _isSaving) return;

    if (_totalPages <= 0) {
      AppSnackBar.show(
        context,
        message: 'Mohon isi total halaman buku terlebih dahulu.',
        type: SnackBarType.error,
      );
      return;
    }

    if (_currentPage < 0 || _currentPage > _totalPages) {
      AppSnackBar.show(
        context,
        message: 'Halaman saat ini harus antara 0 dan $_totalPages.',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final library = context.read<LibraryRepository>();
      final isFinished = _currentPage >= _totalPages;

      final updated = _book!.copyWith(
        currentPage: _currentPage,
        pageCount: _totalPages,
        status: isFinished
            ? BookStatus.finished
            : (_currentPage > 0 ? BookStatus.reading : _book!.status),
        lastReadAt: DateTime.now(),
        finishedAt: isFinished ? (_book!.finishedAt ?? DateTime.now()) : null,
        updatedAt: DateTime.now(),
      );

      await library.updateBook(updated);

      if (!mounted) return;

      AppSnackBar.show(
        context,
        message: 'Progress membaca berhasil disimpan!',
        type: SnackBarType.info,
      );

      if (isFinished) {
        // Jika halaman penuh, arahkan ke Finished Book
        await _finishBookFlow(updated);
      } else {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.show(
        context,
        message: 'Gagal menyimpan progress: $e',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _confirmFinishedThisBook() async {
    if (_book == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selesaikan Buku Ini?'),
          content: Text(
            'Yakin sudah selesai membaca buku "${_book!.title}"? Buku akan ditandai selesai dan dicatat ke dalam Reading Ledger Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepTeal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Selesai'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);

      final totalP = _totalPages > 0 ? _totalPages : (_book!.pageCount ?? _currentPage);
      final updated = _book!.copyWith(
        currentPage: totalP,
        pageCount: totalP,
        status: BookStatus.finished,
        finishedAt: DateTime.now(),
        lastReadAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final library = context.read<LibraryRepository>();
      await library.updateBook(updated);

      if (!mounted) return;
      await _finishBookFlow(updated);
    }
  }

  Future<void> _finishBookFlow(UserBook finishedBook) async {
    try {
      // 1. Hitung total durasi membaca untuk buku ini
      final readingRepo = context.read<ReadingRepository>();
      final sessions = await readingRepo.getSessionsForBook(finishedBook.id);
      final totalSeconds = sessions.fold<int>(
        0,
        (sum, s) => sum + s.durationSeconds,
      );

      // 2. Tambahkan ke Blockchain Ledger via LedgerService (idempoten & Proof of Work)
      if (mounted) {
        final ledgerService = context.read<LedgerService>();
        await ledgerService.appendFinishedBook(
          finishedBook,
          userId: finishedBook.userId,
          totalReadingSeconds: totalSeconds,
        );
      }

      if (!mounted) return;

      // 3. Navigasi ke Finished Book page
      context.pushReplacement('/reading/finished/${finishedBook.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.show(
        context,
        message: 'Gagal menyelesaikan buku: $e',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reading Progress',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepTeal),
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
    final sessionSec = widget.sessionDurationSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner durasi sesi barusan (jika baru selesai dari stopwatch)
          if (sessionSec != null && sessionSec > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.sageGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.deepTeal,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesi membaca tercatat!',
                          style: AppText.bodyMedium(
                            color: isDark ? AppColors.inkDark : AppColors.deepTeal,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Durasi sesi barusan: ${_formatSessionDuration(sessionSec)}',
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
            const SizedBox(height: AppSpacing.l),
          ],

          // Card Info Buku
          Row(
            children: [
              BookCover(
                coverUrl: book.coverUrl,
                width: 65,
                height: 98,
                borderRadius: 10,
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
                    const SizedBox(height: AppSpacing.s),
                    StatusBadge(status: book.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Card Progress Bar
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Progress',
                  style: AppText.sectionHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                ReadingProgressBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // Jika total pages belum diisi / 0: sediakan input total halaman wajib
          if (_totalPages <= 0) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Halaman Buku (Wajib)',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Buku ini belum memiliki data total halaman. Silakan isi terlebih dahulu:',
                    style: AppText.caption(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    controller: _totalPageController,
                    hintText: 'Contoh: 350',
                    keyboardType: TextInputType.number,
                    onChanged: _onTotalPageTextChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.l),
          ],

          // Slider & Input Halaman Saat Ini
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Halaman Terakhir Dibaca',
                  style: AppText.sectionHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),

                // Slider (aktif jika totalPages > 0)
                if (_totalPages > 0) ...[
                  Slider(
                    value: _currentPage.clamp(0, _totalPages).toDouble(),
                    min: 0,
                    max: _totalPages.toDouble(),
                    divisions: _totalPages > 0 ? _totalPages : 1,
                    activeColor: AppColors.deepTeal,
                    inactiveColor: isDark ? AppColors.borderDark : AppColors.sageGreen.withValues(alpha: 0.3),
                    onChanged: _onSliderChanged,
                  ),
                  const SizedBox(height: AppSpacing.s),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Halaman:',
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: AppTextField(
                        controller: _pageController,
                        hintText: 'Halaman',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: _onPageTextChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      'dari ${_totalPages > 0 ? _totalPages : "?"}',
                      style: AppText.body(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Tombol Save Progress & Finished This Book
          PrimaryButton(
            label: _isSaving ? 'Menyimpan...' : 'Save Progress',
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _saveProgress,
          ),
          const SizedBox(height: AppSpacing.m),
          SecondaryButton(
            label: 'Finished This Book',
            icon: Icons.done_all_rounded,
            onPressed: _isSaving ? null : _confirmFinishedThisBook,
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
