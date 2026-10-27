import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/book_widgets.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/book_search_repository.dart';
import '../../data/repositories/library_repository.dart';
import 'widgets/mini_bookstore_map.dart';

/// Halaman Detail Buku Wishlist — PRD §7.6 & Fase S3.
/// Menampilkan detail buku wishlist dengan satu tombol utama "Add to Collection"
/// yang memindahkan buku dari wishlist ke koleksi lalu kembali dengan konfirmasi.
class WishlistBookDetailPage extends StatefulWidget {
  final String id;

  const WishlistBookDetailPage({super.key, required this.id});

  @override
  State<WishlistBookDetailPage> createState() => _WishlistBookDetailPageState();
}

class _WishlistBookDetailPageState extends State<WishlistBookDetailPage> {
  UserBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMoving = false;
  bool _isSynopsisExpanded = false;
  bool _isEnriching = false;

  @override
  void initState() {
    super.initState();
    _loadBook();
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
          _errorMessage = 'Buku tidak ditemukan di wishlist.';
        });
      } else {
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
        _errorMessage = 'Gagal memuat detail buku. Periksa koneksi Anda.';
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

  Future<void> _moveToCollection() async {
    if (_book == null || _isMoving) return;

    setState(() => _isMoving = true);
    final library = context.read<LibraryRepository>();

    try {
      await library.moveToCollection(_book!.id);
      if (!mounted) return;

      AppSnackBar.show(
        context,
        message: 'Buku berhasil dipindahkan ke Koleksi',
        type: SnackBarType.success,
      );

      // Kembali ke halaman sebelumnya setelah berhasil memindahkan
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        try {
          context.go('/library?filter=collection');
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMoving = false);
      AppSnackBar.show(
        context,
        message: 'Gagal memindahkan buku ke Koleksi.',
        type: SnackBarType.error,
      );
    }
  }

  String _formatPrice() {
    final book = _book;
    if (book == null || book.priceAmount == null || book.priceAmount! <= 0) {
      return 'Harga tidak tersedia';
    }

    final currency = book.priceCurrency ?? 'IDR';
    if (currency.toUpperCase() == 'IDR') {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(book.priceAmount);
    } else {
      return '$currency ${book.priceAmount!.toStringAsFixed(2)}';
    }
  }

  void _openMaps() {
    context.push('/maps/bookstores');
  }

  void _showManualLocationSheet() {
    context.push('/maps/bookstores');
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
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.deepTeal),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Memuat detail wishlist...',
              style: AppText.body(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ),
          ],
        ),
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

            // Satu tombol utama: Add to Collection (PRD §7.6)
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Add to Collection',
                isLoading: _isMoving,
                icon: Icons.bookmark_add_rounded,
                onPressed: _isMoving ? null : _moveToCollection,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

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

            // Card Book Price
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.softApricot : AppColors.deepTeal)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    ),
                    child: Icon(
                      Icons.sell_rounded,
                      color: isDark ? AppColors.softApricot : AppColors.deepTeal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book Price',
                          style: AppText.bodyMedium(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPrice(),
                          style: AppText.sectionHeading(
                            color: isDark ? AppColors.softApricot : AppColors.deepTeal,
                          ),
                        ),
                        if (book.publisher != null && book.publisher!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Penerbit: ${book.publisher}',
                            style: AppText.caption(
                              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Card Find Nearby Bookstores
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Nearby Bookstores',
                    style: AppText.sectionHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Open Maps to find nearby sellers and browse in person.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  // Pratinjau kotak peta mini toko buku terdekat
                  MiniBookstoreMap(
                    onOpenFullMap: _openMaps,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Open Maps',
                          onPressed: () => _openMaps(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      IconButton(
                        tooltip: 'Pilih Kota Manual',
                        icon: const Icon(Icons.edit_location_alt_rounded),
                        onPressed: _showManualLocationSheet,
                      ),
                    ],
                  ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppText.caption(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
        ),
      ],
    );
  }
}
