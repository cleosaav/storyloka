import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/book_search_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../auth/auth_controller.dart';
import 'widgets/mini_bookstore_map.dart';

/// Halaman Detail Buku hasil pencarian — PRD §7.3 & Fase S3.
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
  late BookSearchResult _book;
  bool _isLoadingDetail = true;
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
    _book = widget.book;
    _checkExistingStatus();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final searchRepo = context.read<BookSearchRepository>();
      final detail = await searchRepo.getDetail(widget.book.googleBooksId);
      if (!mounted) return;
      if (detail != null) {
        setState(() {
          _book = _book.mergeWith(detail);
          _isLoadingDetail = false;
        });
      } else {
        setState(() => _isLoadingDetail = false);
      }
    } catch (_) {
      // Error (timeout / 429) tidak menghapus data yang sudah ada
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
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

    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } catch (_) {}
    if (auth != null && (auth.currentUser == null || auth.currentUser!.id.isEmpty)) {
      AppSnackBar.show(
        context,
        message: 'Silakan masuk terlebih dahulu untuk menambahkan ke Koleksi.',
        type: SnackBarType.warning,
      );
      return;
    }
    final userId = auth?.currentUser?.id ?? '';

    setState(() => _isAddingCollection = true);
    final library = context.read<LibraryRepository>();

    try {
      if (_isInWishlist && _existingBookId != null) {
        // Pindahkan dari wishlist ke collection — PRD §7.3
        await library.moveToCollection(_existingBookId!);
      } else {
        final now = DateTime.now();
        // Simpan data gabungan (detail yang lengkap), bukan data awal yang minim — Fase S3
        final userBook = UserBook(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          userId: userId,
          googleBooksId: _book.googleBooksId,
          title: _book.title,
          authors: _book.authors,
          genre: _book.genre,
          isbn: _book.isbn,
          publisher: _book.publisher,
          pageCount: _book.pageCount,
          coverUrl: _book.coverUrl,
          synopsis: _book.synopsis,
          priceAmount: _book.priceAmount,
          priceCurrency: _book.priceCurrency,
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

    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } catch (_) {}
    if (auth != null && (auth.currentUser == null || auth.currentUser!.id.isEmpty)) {
      AppSnackBar.show(
        context,
        message: 'Silakan masuk terlebih dahulu untuk menambahkan ke Wishlist.',
        type: SnackBarType.warning,
      );
      return;
    }
    final userId = auth?.currentUser?.id ?? '';

    setState(() => _isAddingWishlist = true);
    final library = context.read<LibraryRepository>();

    try {
      final now = DateTime.now();
      // Simpan data gabungan (detail yang lengkap), bukan data awal yang minim — Fase S3
      final userBook = UserBook(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: userId,
        googleBooksId: _book.googleBooksId,
        title: _book.title,
        authors: _book.authors,
        genre: _book.genre,
        isbn: _book.isbn,
        publisher: _book.publisher,
        pageCount: _book.pageCount,
        coverUrl: _book.coverUrl,
        synopsis: _book.synopsis,
        priceAmount: _book.priceAmount,
        priceCurrency: _book.priceCurrency,
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

  void _openMaps() {
    context.push('/maps/bookstores');
  }

  void _showManualLocationSheet() {
    context.push('/maps/bookstores');
  }

  String _cleanSynopsis(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Sinopsis tidak tersedia';
    }
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  String _formatPrice() {
    final amount = _book.priceAmount;
    final currency = _book.priceCurrency;

    if (amount == null || currency == null) {
      return 'Harga tidak tersedia';
    }

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

  String _getPriceUnavailableReason() {
    if (_book.saleability == 'NOT_FOR_SALE') {
      return 'Buku ini tidak dijual secara digital di Google Play Books.';
    }
    return 'Buku ini belum dijual di Google Play Books untuk wilayah Indonesia.';
  }

  Future<void> _openGooglePlayBooks() async {
    final link = _book.buyLink ??
        _book.infoLink ??
        'https://play.google.com/store/books/details?id=${_book.googleBooksId}';
    final uri = Uri.tryParse(link);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Tidak dapat membuka Google Play Books.',
            type: SnackBarType.error,
          );
        }
      }
    }
  }

  Future<void> _searchOnlineStores() async {
    final query = '${_book.title} ${_book.isbn ?? ''} beli buku'.trim();
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Tidak dapat membuka pencarian web.',
            type: SnackBarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final book = _book;
    final synopsis = _cleanSynopsis(book.synopsis);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final useColumnLayout = screenWidth < 340 || textScale > 1.15;

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
              Center(child: CircularProgressIndicator(color: context.primaryColor))
            else if (useColumnLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: _isInCollection ? 'Added to Collection' : 'Add to Collection',
                    isLoading: _isAddingCollection,
                    onPressed: _isInCollection ? null : _addToCollection,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SecondaryButton(
                    label: _isInWishlist ? 'Added to Wishlist' : 'Add to Wishlist',
                    isLoading: _isAddingWishlist,
                    onPressed: (_isInWishlist || _isInCollection) ? null : _addToWishlist,
                  ),
                ],
              )
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Synopsis',
                        style: AppText.sectionHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      if (_isLoadingDetail)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (_isLoadingDetail && (synopsis == 'Sinopsis tidak tersedia' || synopsis.isEmpty)) ...[
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
                      style: AppText.body(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
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
                    if (_book.synopsisSource == 'Open Library') ...[
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Sumber: Open Library',
                        style: AppText.caption(
                          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            if (_isLoadingDetail) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceDark : AppColors.trackNeutral,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                ),
                              ),
                            ] else ...[
                              Text(
                                _formatPrice(),
                                style: AppText.sectionHeading(
                                  color: isDark ? AppColors.softApricot : AppColors.deepTeal,
                                ),
                              ),
                              if (_book.priceNote != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _book.priceNote!,
                                  style: AppText.caption(
                                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_isLoadingDetail && _book.priceAmount == null) ...[
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      _getPriceUnavailableReason(),
                      style: AppText.caption(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.xs,
                      children: [
                        SecondaryButton(
                          key: const Key('btn_view_google_play'),
                          label: 'Lihat di Google Play Books',
                          icon: Icons.open_in_new_rounded,
                          onPressed: () => _openGooglePlayBooks(),
                        ),
                        TertiaryButton(
                          key: const Key('btn_search_online_stores'),
                          label: 'Cari harga di toko online',
                          icon: Icons.search_rounded,
                          onPressed: () => _searchOnlineStores(),
                        ),
                      ],
                    ),
                  ],
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
