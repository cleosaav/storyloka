import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import '../../data/models/user_book.dart';
import '../../data/repositories/book_search_repository.dart';
import '../../data/repositories/library_repository.dart';

/// Halaman Detail Buku Collection — PRD §7.4 & Fase S3.
class CollectionBookDetailPage extends StatefulWidget {
  final String id;

  const CollectionBookDetailPage({super.key, required this.id});

  @override
  State<CollectionBookDetailPage> createState() => _CollectionBookDetailPageState();
}

class _CollectionBookDetailPageState extends State<CollectionBookDetailPage> {
  UserBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSynopsisExpanded = false;
  late TextEditingController _reviewController;
  int _selectedRating = 0;
  bool _isSavingReview = false;
  bool _isEnriching = false;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
    _loadBook();
  }

  @override
  void dispose() {
    _reviewController.dispose();
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
        _selectedRating = book.rating ?? 0;
        _reviewController.text = book.review ?? '';
        setState(() {
          _book = book;
          _isLoading = false;
        });
        _enrichIfNeeded(book);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat detail buku.';
      });
    }
  }

  Future<void> _enrichIfNeeded(UserBook book) async {
    if (_isEnriching) return;
    final needsSynopsis =
        book.synopsis == null || book.synopsis!.trim().isEmpty;
    final needsPages = book.pageCount == null || book.pageCount! <= 0;
    final needsPrice = book.priceAmount == null;

    if (!needsSynopsis && !needsPages && !needsPrice) return;
    if (book.googleBooksId.isEmpty) return;

    _isEnriching = true;
    if (mounted) setState(() {});
    try {
      final searchRepo = context.read<BookSearchRepository>();
      final detail = await searchRepo.getDetail(book.googleBooksId);
      if (!mounted || detail == null) return;

      bool hasNewData = false;
      int? newPageCount = book.pageCount;
      String? newSynopsis = book.synopsis;
      double? newPriceAmount = book.priceAmount;
      String? newPriceCurrency = book.priceCurrency;
      String? newGenre = book.genre;

      if (needsPages && detail.pageCount != null && detail.pageCount! > 0) {
        newPageCount = detail.pageCount;
        hasNewData = true;
      }
      if (needsSynopsis &&
          detail.synopsis != null &&
          detail.synopsis!.trim().isNotEmpty) {
        newSynopsis = detail.synopsis;
        hasNewData = true;
      }
      if (needsPrice && detail.priceAmount != null) {
        newPriceAmount = detail.priceAmount;
        newPriceCurrency = detail.priceCurrency;
        hasNewData = true;
      }
      if ((book.genre == null || book.genre!.isEmpty) &&
          detail.genre != null &&
          detail.genre!.isNotEmpty) {
        newGenre = detail.genre;
        hasNewData = true;
      }

      if (hasNewData && mounted) {
        final library = context.read<LibraryRepository>();
        final updated = book.copyWith(
          pageCount: newPageCount,
          synopsis: newSynopsis,
          priceAmount: newPriceAmount,
          priceCurrency: newPriceCurrency,
          genre: newGenre,
          updatedAt: DateTime.now(),
          syncStatus: 'pending',
        );
        await library.updateBook(updated);
        if (mounted) {
          setState(() {
            _book = updated;
          });
        }
      }
    } catch (_) {
      // Background enrichment gagal, abaikan
    } finally {
      _isEnriching = false;
      if (mounted) setState(() {});
    }
  }

  String _cleanSynopsis(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Sinopsis tidak tersedia';
    }
    final noHtml = text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return noHtml.isEmpty ? 'Sinopsis tidak tersedia' : noHtml;
  }

  Future<void> _confirmRemove() async {
    if (_book == null) return;

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Hapus dari Koleksi?',
      message: 'Apakah Anda yakin ingin menghapus "${_book!.title}" dari koleksi Anda?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final library = context.read<LibraryRepository>();
      await library.deleteBook(_book!.id);
      if (!mounted) return;

      AppSnackBar.show(
        context,
        message: 'Buku berhasil dihapus dari koleksi',
        type: SnackBarType.info,
      );

      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/library?filter=collection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book Detail',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        actions: [
          if (_book != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? AppColors.inkDark : AppColors.ink,
              ),
              onSelected: (val) {
                if (val == 'remove') {
                  _confirmRemove();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: AppSpacing.s),
                      Text('Remove from library', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
                label: 'Coba Lagi',
                onPressed: _loadBook,
              ),
            ],
          ),
        ),
      );
    }

    final book = _book!;
    final synopsis = _cleanSynopsis(book.synopsis);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final useColumnLayout = screenWidth < 340 || textScale > 1.15;

    return RefreshIndicator(
      onRefresh: _loadBook,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Buku
            Center(
              child: Hero(
                tag: 'book_cover_${book.id}',
                child: BookCover(
                  coverUrl: book.coverUrl,
                  width: 140,
                  borderRadius: 16,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Judul Buku
            Text(
              book.title,
              style: AppText.bookTitle(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),

            // Penulis
            if (book.authors != null && book.authors!.isNotEmpty)
              Text(
                book.authors!,
                style: AppText.bodyMedium(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: AppSpacing.m),

            // Genre & Metadata chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                if (book.genre != null && book.genre!.isNotEmpty)
                  GenreChip(genre: book.genre!),
                if (book.pageCount != null && book.pageCount! > 0)
                  _buildMetaItem(Icons.auto_stories, '${book.pageCount} halaman'),
                if (book.isbn != null && book.isbn!.isNotEmpty)
                  _buildMetaItem(Icons.qr_code, 'ISBN: ${book.isbn}'),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2 tombol: Start Reading (primary) & Update Progress (secondary)
            if (useColumnLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: 'Start Reading',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () async {
                      if (book.status != BookStatus.reading) {
                        final updated = book.copyWith(
                          status: BookStatus.reading,
                          startedAt: book.startedAt ?? DateTime.now(),
                          lastReadAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await context.read<LibraryRepository>().updateBook(updated);
                      }
                      if (!mounted) return;
                      await context.push('/reading/timer/${book.id}');
                      if (mounted) _loadBook();
                    },
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SecondaryButton(
                    label: 'Update Progress',
                    icon: Icons.edit_note_rounded,
                    onPressed: () async {
                      await context.push('/reading/progress/${book.id}');
                      if (mounted) _loadBook();
                    },
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Start Reading',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () async {
                        if (book.status != BookStatus.reading) {
                          final updated = book.copyWith(
                            status: BookStatus.reading,
                            startedAt: book.startedAt ?? DateTime.now(),
                            lastReadAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );
                          await context.read<LibraryRepository>().updateBook(updated);
                        }
                        if (!mounted) return;
                        await context.push('/reading/timer/${book.id}');
                        if (mounted) _loadBook();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Update Progress',
                      icon: Icons.edit_note_rounded,
                      onPressed: () async {
                        await context.push('/reading/progress/${book.id}');
                        if (mounted) _loadBook();
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),

            // Card Reading Status
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Reading Status',
                          style: AppText.sectionHeading(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      StatusBadge(status: book.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  ReadingProgressBar(
                    currentPage: book.currentPage,
                    totalPages: book.pageCount ?? 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Card Synopsis
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Synopsis',
                        style: AppText.sectionHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      if (_isEnriching)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (_isEnriching && (synopsis == 'Sinopsis tidak tersedia' || synopsis.isEmpty)) ...[
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.trackNeutral,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity * 0.75,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.trackNeutral,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      ),
                    ),
                  ] else ...[
                    Text(
                      synopsis,
                      maxLines: _isSynopsisExpanded ? null : 6,
                      overflow: _isSynopsisExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: synopsis == 'Sinopsis tidak tersedia'
                          ? AppText.body(
                              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                            ).copyWith(fontStyle: FontStyle.italic)
                          : AppText.body(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ).copyWith(height: 1.6),
                    ),
                    if (synopsis != 'Sinopsis tidak tersedia' && synopsis.length > 200) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TertiaryButton(
                          label: _isSynopsisExpanded ? 'Read Less' : 'Read More',
                          color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                          trailingIcon: _isSynopsisExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSynopsisExpanded = !_isSynopsisExpanded;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Card Your Rating (PRD §7.4: aktif hanya setelah status = finished)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Rating',
                    style: AppText.sectionHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isSelected = _selectedRating >= starNum;
                      final isFinished = book.status == BookStatus.finished;
                      return Semantics(
                        button: true,
                        enabled: isFinished,
                        label: 'Beri rating $starNum bintang',
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: InkWell(
                            onTap: isFinished
                                ? () {
                                    setState(() {
                                      _selectedRating = starNum;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(AppSpacing.radius22),
                            child: Center(
                              child: Icon(
                                isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: AppSpacing.iconXl,
                                color: isFinished
                                    ? AppColors.softApricot
                                    : (isDark ? AppColors.mutedDark : AppColors.mutedGray),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (book.status != BookStatus.finished)
                    Text(
                      'Selesaikan buku ini untuk memberi review.',
                      style: AppText.caption(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    )
                  else ...[
                    const SizedBox(height: AppSpacing.s),
                    AppTextField(
                      controller: _reviewController,
                      hintText: 'Tulis review Anda untuk buku ini...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PrimaryButton(
                        label: _isSavingReview ? 'Menyimpan...' : 'Save Review',
                        onPressed: _isSavingReview
                            ? null
                            : () async {
                                setState(() => _isSavingReview = true);
                                try {
                                  final updated = book.copyWith(
                                    rating: _selectedRating > 0 ? _selectedRating : null,
                                    review: _reviewController.text.trim().isNotEmpty
                                        ? _reviewController.text.trim()
                                        : null,
                                    updatedAt: DateTime.now(),
                                  );
                                  await context.read<LibraryRepository>().updateBook(updated);
                                  if (!mounted) return;
                                  setState(() {
                                    _book = updated;
                                    _isSavingReview = false;
                                  });
                                  AppSnackBar.show(
                                    context,
                                    message: 'Review berhasil disimpan!',
                                    type: SnackBarType.info,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _isSavingReview = false);
                                  AppSnackBar.show(
                                    context,
                                    message: 'Gagal menyimpan review: $e',
                                    type: SnackBarType.error,
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: (screenWidth - 48).clamp(160.0, 520.0)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
