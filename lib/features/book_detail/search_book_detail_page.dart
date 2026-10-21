import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/location_service.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/book_search_repository.dart';
import '../../data/repositories/library_repository.dart';

/// Halaman Detail Buku hasil pencarian — PRD §7.3.
class SearchBookDetailPage extends StatefulWidget {
  final BookSearchResult book;

  const SearchBookDetailPage({
    super.key,
    required this.book,
  });

  @override
  State<SearchBookDetailPage> createState() => _SearchBookDetailPageState();
}

class _SearchBookDetailPageState extends State<SearchBookDetailPage> {
  bool _isCheckingStatus = true;
  bool _isAddingCollection = false;
  bool _isAddingWishlist = false;

  bool _isInCollection = false;
  bool _isInWishlist = false;
  String? _existingBookId;

  bool _isSynopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkExistingStatus();
  }

  Future<void> _checkExistingStatus() async {
    final library = context.read<LibraryRepository>();
    final existing =
        await library.findByGoogleBooksId(widget.book.googleBooksId);

    if (!mounted) return;
    setState(() {
      _isCheckingStatus = false;
      if (existing != null) {
        _existingBookId = existing.id;
        _isInCollection = existing.listType == ListType.collection;
        _isInWishlist = existing.listType == ListType.wishlist;
      }
    });
  }

  Future<void> _addToCollection() async {
    if (_isInCollection || _isAddingCollection) return;

    setState(() => _isAddingCollection = true);
    final library = context.read<LibraryRepository>();

    try {
      if (_isInWishlist && _existingBookId != null) {
        // Pindahkan dari wishlist ke collection — PRD §7.3
        await library.moveToCollection(_existingBookId!);
      } else {
        final now = DateTime.now();
        final userBook = UserBook(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          userId: 'demo_user',
          googleBooksId: widget.book.googleBooksId,
          title: widget.book.title,
          authors: widget.book.authors,
          genre: widget.book.genre,
          isbn: widget.book.isbn,
          publisher: widget.book.publisher,
          pageCount: widget.book.pageCount,
          coverUrl: widget.book.coverUrl,
          synopsis: widget.book.synopsis,
          priceAmount: widget.book.priceAmount,
          priceCurrency: widget.book.priceCurrency,
          listType: ListType.collection,
          status: BookStatus.notStarted,
          createdAt: now,
          updatedAt: now,
        );
        final added = await library.addBook(userBook);
        _existingBookId = added.id;
      }

      if (!mounted) return;
      setState(() {
        _isInCollection = true;
        _isInWishlist = false;
        _isAddingCollection = false;
      });

      AppSnackBar.show(
        context,
        message: 'Buku berhasil ditambahkan ke Koleksi',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAddingCollection = false);
      AppSnackBar.show(
        context,
        message: 'Gagal menambahkan buku ke Koleksi.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _addToWishlist() async {
    if (_isInWishlist || _isInCollection || _isAddingWishlist) return;

    setState(() => _isAddingWishlist = true);
    final library = context.read<LibraryRepository>();

    try {
      final now = DateTime.now();
      final userBook = UserBook(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: 'demo_user',
        googleBooksId: widget.book.googleBooksId,
        title: widget.book.title,
        authors: widget.book.authors,
        genre: widget.book.genre,
        isbn: widget.book.isbn,
        publisher: widget.book.publisher,
        pageCount: widget.book.pageCount,
        coverUrl: widget.book.coverUrl,
        synopsis: widget.book.synopsis,
        priceAmount: widget.book.priceAmount,
        priceCurrency: widget.book.priceCurrency,
        listType: ListType.wishlist,
        status: BookStatus.notStarted,
        createdAt: now,
        updatedAt: now,
      );

      final added = await library.addBook(userBook);
      if (!mounted) return;

      setState(() {
        _existingBookId = added.id;
        _isInWishlist = true;
        _isAddingWishlist = false;
      });

      AppSnackBar.show(
        context,
        message: 'Buku berhasil ditambahkan ke Wishlist',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAddingWishlist = false);
      AppSnackBar.show(
        context,
        message: 'Gagal menambahkan buku ke Wishlist.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _openMaps([String? query]) async {
    if (query != null && query.trim().isNotEmpty) {
      await LocationService.instance.openMapsWithQuery(context, query);
    } else {
      await LocationService.instance.openNearbyBookstores(context);
    }
  }

  void _showManualLocationSheet() {
    LocationService.instance.showManualLocationSheet(context);
  }

  String _cleanSynopsis(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Sinopsis tidak tersedia';
    }
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  String _formatPrice() {
    if (widget.book.priceAmount == null) {
      return 'Harga tidak tersedia';
    }
    final currency = widget.book.priceCurrency ?? '';
    final amount = widget.book.priceAmount!;

    if (currency.toUpperCase() == 'IDR') {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    }

    if (currency.toUpperCase() == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }

    return '$currency ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final book = widget.book;
    final synopsis = _cleanSynopsis(book.synopsis);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book Detail',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover besar (rasio 2:3, lebar ~140, tinggi 210)
            Center(
              child: BookCover(
                coverUrl: book.coverUrl,
                width: 140,
                height: 210,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Judul buku (Fraunces 24)
            Text(
              book.title,
              textAlign: TextAlign.center,
              style: AppText.bookTitle(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Penulis
            Text(
              book.authors ?? 'Penulis tidak diketahui',
              textAlign: TextAlign.center,
              style: AppText.body(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // Genre Chip
            if (book.genre != null && book.genre!.isNotEmpty)
              Center(child: GenreChip(genre: book.genre!)),

            const SizedBox(height: AppSpacing.m),

            // Detail Metadata (ISBN, Penerbit, Halaman)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.xs,
              children: [
                if (book.pageCount != null && book.pageCount! > 0)
                  _buildMetaItem(Icons.menu_book_rounded, '${book.pageCount} hlm'),
                if (book.isbn != null && book.isbn!.isNotEmpty)
                  _buildMetaItem(Icons.pin_rounded, 'ISBN: ${book.isbn}'),
                if (book.publisher != null && book.publisher!.isNotEmpty)
                  _buildMetaItem(Icons.business_rounded, book.publisher!),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Tombol Aksi: Add to Collection & Add to Wishlist
            if (_isCheckingStatus)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  // Add to Collection (Primary)
                  Expanded(
                    child: PrimaryButton(
                      label: _isInCollection ? 'Added to Collection' : 'Add to Collection',
                      isLoading: _isAddingCollection,
                      onPressed: _isInCollection ? null : _addToCollection,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  // Add to Wishlist (Secondary)
                  Expanded(
                    child: SecondaryButton(
                      label: _isInWishlist ? 'Added to Wishlist' : 'Add to Wishlist',
                      isLoading: _isAddingWishlist,
                      // Disabled jika sudah ada di wishlist atau sudah di collection
                      onPressed: (_isInWishlist || _isInCollection) ? null : _addToWishlist,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),

            // Card Synopsis + Read More
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Synopsis',
                    style: AppText.sectionHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    synopsis,
                    maxLines: _isSynopsisExpanded ? null : 6,
                    overflow: _isSynopsisExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: AppText.body(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  if (synopsis != 'Sinopsis tidak tersedia' && synopsis.length > 200) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isSynopsisExpanded = !_isSynopsisExpanded;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isSynopsisExpanded ? 'Read Less' : 'Read More',
                          style: AppText.button(
                            color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
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
