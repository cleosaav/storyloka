import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/ledger_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/book_widgets.dart';
import '../../core/widgets/progress_and_badge.dart';
import '../../core/widgets/responsive_body.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/book_search_repository.dart';
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
  bool _needsTotalInput = false;
  bool _isEditingTotalPage = false;
  String? _totalPageError;
  String? _currentPageError;
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
        return;
      }

      _book = book;
      _currentPage = book.currentPage;
      int pages = book.pageCount ?? 0;

      // Coba isi total halaman otomatis dari sumber lain sebelum meminta pengguna (Fase S2)
      if (pages <= 0) {
        try {
          final searchRepo = context.read<BookSearchRepository>();
          int? autoPageCount;

          if (book.isbn != null && book.isbn!.trim().isNotEmpty) {
            final results = await searchRepo
                .search(book.isbn!, filter: 'isbn', maxResults: 1)
                .timeout(const Duration(seconds: 4));
            if (results.isNotEmpty &&
                results.first.pageCount != null &&
                results.first.pageCount! > 0) {
              autoPageCount = results.first.pageCount;
            }
          }

          if (autoPageCount == null && book.title.trim().isNotEmpty) {
            final results = await searchRepo
                .search(book.title, filter: 'title', maxResults: 3)
                .timeout(const Duration(seconds: 4));
            for (final r in results) {
              if (r.pageCount != null && r.pageCount! > 0) {
                autoPageCount = r.pageCount;
                break;
              }
            }
          }

          if (autoPageCount != null && autoPageCount > 0) {
            pages = autoPageCount;
            final updatedBook = book.copyWith(pageCount: autoPageCount);
            await library.updateBook(updatedBook);
            _book = updatedBook;
          }
        } catch (_) {
          // Abaikan kegagalan jaringan/timeout agar tidak menghalangi pengguna
        }
      }

      _totalPages = pages;
      _needsTotalInput = pages <= 0;
      _isEditingTotalPage = false;
      _totalPageError = null;
      _currentPageError = null;

      _pageController.text = '$_currentPage';
      _totalPageController.text = pages > 0 ? '$pages' : '';

      setState(() {
        _isLoading = false;
      });
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
      _currentPageError = null;
      _pageController.text = '$newPage';
    });
  }

  void _onPageTextChanged(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      setState(() {
        _currentPage = 0;
        _currentPageError = null;
      });
      return;
    }

    final parsed = int.tryParse(clean);
    if (parsed == null) {
      setState(() {
        _currentPageError = 'Format angka tidak valid';
      });
      return;
    }

    setState(() {
      _currentPage = parsed;
      if (parsed < 0) {
        _currentPageError = 'Halaman tidak boleh kurang dari 0';
      } else if (_totalPages > 0 && parsed > _totalPages) {
        _currentPageError = 'Halaman tidak boleh melebihi total ($_totalPages)';
      } else {
        _currentPageError = null;
      }
    });
  }

  void _onTotalPageTextChanged(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      setState(() {
        _totalPages = 0;
        _totalPageError = 'Total halaman wajib diisi';
      });
      return;
    }

    final parsed = int.tryParse(clean);
    if (parsed == null || parsed < 1 || parsed > 99999) {
      setState(() {
        _totalPages = parsed ?? 0;
        _totalPageError = 'Total halaman harus antara 1 sampai 99999';
      });
      return;
    }

    setState(() {
      _totalPages = parsed;
      _totalPageError = null;
      if (_currentPage > _totalPages) {
        _currentPageError = 'Halaman tidak boleh melebihi total ($_totalPages)';
      } else {
        _currentPageError = null;
      }
    });
  }

  bool get _canSave {
    if (_isSaving || _book == null) return false;
    if (_totalPageError != null || _currentPageError != null) return false;
    if (_totalPages < 1 || _totalPages > 99999) return false;
    if (_currentPage < 0 || _currentPage > _totalPages) return false;
    return true;
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
    if (!_canSave) return;

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

      _needsTotalInput = false;
      _isEditingTotalPage = false;

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

    if (_totalPages <= 0) {
      AppSnackBar.show(
        context,
        message: 'Mohon isi total halaman buku terlebih dahulu.',
        type: SnackBarType.error,
      );
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Selesaikan Buku Ini?',
      message:
          'Yakin sudah selesai membaca buku "${_book!.title}"? Buku akan ditandai selesai dan dicatat ke dalam Reading Ledger Anda.',
      cancelLabel: 'Batal',
      confirmLabel: 'Ya, Selesai',
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);

      final totalP = _totalPages;
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
      body: ResponsiveBody(
        padding: EdgeInsets.zero,
        child: _buildBody(isDark),
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
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                  color: AppColors.sageGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: context.primaryColor,
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      'Current Progress',
                      style: AppText.sectionHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                    if (!_needsTotalInput && !_isEditingTotalPage && _totalPages > 0)
                      GestureDetector(
                        key: const Key('change_total_pages_link'),
                        onTap: () {
                          setState(() {
                            _isEditingTotalPage = true;
                            _totalPageController.text = '$_totalPages';
                            _totalPageError = null;
                          });
                        },
                        child: Text(
                          'Ubah total halaman',
                          style: AppText.caption(
                            color: context.primaryColor,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
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

          // Total Halaman Buku (Wajib jika data belum ada, atau saat pengguna ingin mengubahnya)
          if (_needsTotalInput || _isEditingTotalPage) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _needsTotalInput
                              ? 'Total Halaman Buku (Wajib)'
                              : 'Ubah Total Halaman Buku',
                          style: AppText.bodyMedium(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isEditingTotalPage && !_needsTotalInput) ...[
                        const SizedBox(width: AppSpacing.s),
                        IconButton(
                          key: const Key('cancel_change_total_pages_button'),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Batal',
                          onPressed: () {
                            setState(() {
                              _isEditingTotalPage = false;
                              _totalPages = _book?.pageCount ?? 0;
                              _totalPageController.text =
                                  _totalPages > 0 ? '$_totalPages' : '';
                              _totalPageError = null;
                              if (_currentPage > _totalPages) {
                                _currentPageError =
                                    'Halaman tidak boleh melebihi total ($_totalPages)';
                              } else {
                                _currentPageError = null;
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _needsTotalInput
                        ? 'Buku ini belum memiliki data total halaman. Silakan isi terlebih dahulu (1 - 99999):'
                        : 'Masukkan total halaman buku yang benar (1 - 99999):',
                    style: AppText.caption(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    key: const Key('total_page_input'),
                    controller: _totalPageController,
                    hintText: 'Contoh: 350',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    errorText: _totalPageError,
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

                // Slider (aktif jika totalPages > 0, divisions null bila halaman besar agar tidak berat)
                if (_totalPages > 0) ...[
                  Slider(
                    value: _currentPage.clamp(0, _totalPages).toDouble(),
                    min: 0,
                    max: _totalPages.toDouble(),
                    divisions: _totalPages > 300 ? null : _totalPages,
                    semanticFormatterCallback: (val) =>
                        'Halaman ${val.round()} dari $_totalPages',
                    activeColor: context.primaryColor,
                    inactiveColor: isDark
                        ? AppColors.borderDark
                        : AppColors.sageGreen.withValues(alpha: 0.3),
                    onChanged: _onSliderChanged,
                  ),
                  const SizedBox(height: AppSpacing.s),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        key: const Key('current_page_input'),
                        controller: _pageController,
                        hintText: 'Halaman saat ini',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        errorText: _currentPageError,
                        onChanged: _onPageTextChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '/ ${_totalPages > 0 ? _totalPages : "?"} hlm',
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
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
            onPressed: _canSave ? _saveProgress : null,
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
