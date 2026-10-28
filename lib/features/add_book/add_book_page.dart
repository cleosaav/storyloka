import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/sensor_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/book_search_repository.dart';

enum SearchFilterType {
  title('Title', 'title', 'Search books by title...'),
  author('Author', 'author', 'Search books by author...'),
  isbn('ISBN', 'isbn', 'Search books by ISBN...');

  final String label;
  final String key;
  final String placeholder;

  const SearchFilterType(this.label, this.key, this.placeholder);
}

/// Metadata Genre Chip untuk Discover Books — PRD §7.3 & Tambahan Genre Chips.
class DiscoverGenre {
  final String label;
  final String subject;

  const DiscoverGenre({required this.label, required this.subject});
}

const List<DiscoverGenre> _discoverGenres = [
  DiscoverGenre(label: 'All', subject: 'all'),
  DiscoverGenre(label: 'Fiction', subject: 'fiction'),
  DiscoverGenre(label: 'History', subject: 'history'),
  DiscoverGenre(label: 'Science', subject: 'science'),
  DiscoverGenre(label: 'Biography', subject: 'biography'),
  DiscoverGenre(label: 'Self-Help', subject: 'self-improvement'),
  DiscoverGenre(label: 'Technology', subject: 'technology'),
  DiscoverGenre(label: 'Business', subject: 'business'),
  DiscoverGenre(label: 'Romance', subject: 'romance'),
  DiscoverGenre(label: 'Fantasy', subject: 'fantasy'),
  DiscoverGenre(label: 'Psychology', subject: 'psychology'),
];

class _GenreCacheEntry {
  final List<BookSearchResult> books;
  final DateTime timestamp;

  _GenreCacheEntry({required this.books, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) >= const Duration(minutes: 30);
}

/// Halaman Pencarian & Penambahan Buku — PRD §7.3 & Discover Books.
class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  StreamSubscription<void>? _shakeSubscription;

  SearchFilterType _selectedFilter = SearchFilterType.title;
  bool _isLoading = false;
  String? _errorMessage;
  List<BookSearchResult> _searchResults = [];
  bool _hasSearched = false;

  // State Discover Books
  DiscoverGenre _selectedGenre = _discoverGenres.first;
  bool _isDiscoverLoading = false;
  String? _discoverError;
  List<BookSearchResult> _discoverBooks = [];
  final Map<String, _GenreCacheEntry> _genreCache = {};
  int _discoverRequestId = 0;

  @override
  void initState() {
    super.initState();
    // Shake via sensors_plus — PRD §10.3: langganan hanya saat Add Book aktif.
    _startShakeListener();

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    // Muat initial Discover books ("All")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDiscoverGenre(_selectedGenre);
      }
    });
  }

  @override
  void dispose() {
    _stopShakeListener();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Mulai mendengarkan shake — PRD §10.3.
  void _startShakeListener() {
    SensorService.instance.startListening();
    _shakeSubscription = SensorService.instance.shakeStream.listen((_) {
      if (mounted) _pickRandomBook();
    });
  }

  /// Hentikan pendengaran shake saat keluar halaman — PRD §10.3.
  void _stopShakeListener() {
    _shakeSubscription?.cancel();
    _shakeSubscription = null;
    SensorService.instance.stopListening();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _hasSearched = false;
        _isLoading = false;
        _errorMessage = null;
        _searchResults = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final repository = context.read<BookSearchRepository>();
      final results = await repository.search(
        query,
        filter: _selectedFilter.key,
        maxResults: 20,
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat hasil pencarian. Periksa koneksi Anda.';
      });
    }
  }

  /// Memuat rekomendasi buku untuk chip genre yang dipilih dengan caching dan penanganan race condition.
  Future<void> _loadDiscoverGenre(DiscoverGenre genre, {bool forceRefresh = false}) async {
    final requestId = ++_discoverRequestId;

    // Cek cache memori jika bukan force refresh
    if (!forceRefresh) {
      final cached = _genreCache[genre.subject];
      if (cached != null && !cached.isExpired) {
        setState(() {
          _selectedGenre = genre;
          _discoverBooks = cached.books;
          _isDiscoverLoading = false;
          _discoverError = null;
        });
        return;
      }
    }

    setState(() {
      _selectedGenre = genre;
      _isDiscoverLoading = true;
      _discoverError = null;
    });

    try {
      final repository = context.read<BookSearchRepository>();
      List<BookSearchResult> books;

      if (genre.subject == 'all') {
        // Chip "All": campuran 3 subjek acak, Future.wait, deduplikasi, maksimal ~18 buku
        final allSubjects = _discoverGenres
            .where((g) => g.subject != 'all')
            .map((g) => g.subject)
            .toList();
        final random = Random();
        allSubjects.shuffle(random);
        final selectedSubjects = allSubjects.take(3).toList();

        final results = await Future.wait(
          selectedSubjects.map((subj) {
            final startIdx = random.nextInt(21); // acak 0-20
            return repository.search(
              subj,
              filter: 'subject',
              maxResults: 6,
              startIndex: startIdx,
            ).catchError((_) => <BookSearchResult>[]);
          }),
        );

        final combined = <BookSearchResult>[];
        final seenIds = <String>{};
        final seenTitles = <String>{};

        for (final list in results) {
          for (final b in list) {
            final cleanTitle = b.title.trim().toLowerCase();
            if (cleanTitle.isNotEmpty &&
                !seenIds.contains(b.googleBooksId) &&
                !seenTitles.contains(cleanTitle)) {
              seenIds.add(b.googleBooksId);
              seenTitles.add(cleanTitle);
              combined.add(b);
            }
          }
        }
        combined.shuffle(random);
        books = combined.take(18).toList();
      } else {
        // Chip genre spesifik: 1 kali search(subjek, filter: 'subject', maxResults: 18, startIndex: 0-20)
        final random = Random();
        final startIndex = random.nextInt(21);
        final rawBooks = await repository.search(
          genre.subject,
          filter: 'subject',
          maxResults: 18,
          startIndex: startIndex,
        );

        // Buang buku tanpa judul & deduplikasi
        final filtered = <BookSearchResult>[];
        final seenIds = <String>{};
        for (final b in rawBooks) {
          if (b.title.trim().isNotEmpty && !seenIds.contains(b.googleBooksId)) {
            seenIds.add(b.googleBooksId);
            filtered.add(b);
          }
        }
        books = filtered;
      }

      // Race condition check: hanya permintaan terakhir yang diperbarui
      if (!mounted || requestId != _discoverRequestId) return;

      // Simpan ke cache
      _genreCache[genre.subject] = _GenreCacheEntry(
        books: books,
        timestamp: DateTime.now(),
      );

      setState(() {
        _discoverBooks = books;
        _isDiscoverLoading = false;
        _discoverError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _discoverRequestId) return;
      setState(() {
        _isDiscoverLoading = false;
        _discoverError = 'Gagal memuat rekomendasi buku. Periksa koneksi Anda.';
      });
    }
  }

  Future<void> _pickRandomBook() async {
    AppSnackBar.show(
      context,
      message: 'Mencari buku acak...',
      type: SnackBarType.info,
    );

    try {
      final repository = context.read<BookSearchRepository>();
      final book = await repository.randomBook();
      if (!mounted) return;

      if (book != null) {
        context.push('/book/search', extra: book);
      } else {
        AppSnackBar.show(
          context,
          message: 'Tidak ada buku ditemukan. Coba lagi.',
          type: SnackBarType.warning,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Gagal memilih buku acak. Periksa koneksi Anda.',
        type: SnackBarType.error,
      );
    }
  }

  void _onFilterSelected(SearchFilterType filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });

    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _performSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add a Book',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar + Shake/Shuffle Icon Button
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: (query) {
                        _debounceTimer?.cancel();
                        if (query.trim().length >= 2) {
                          _performSearch(query.trim());
                        }
                      },
                      textInputAction: TextInputAction.search,
                      hintText: _selectedFilter.placeholder,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? AppIconButton(
                              tooltip: 'Hapus pencarian',
                              icon: Icons.clear_rounded,
                              size: 20,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  // Shake to discover button (aksesibilitas/emulator) — PRD §7.3
                  Material(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.sageGreen.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.mutedDark.withValues(alpha: 0.3)
                            : AppColors.sageGreen,
                      ),
                    ),
                    child: SizedBox(
                      width: AppSpacing.inputHeight,
                      height: AppSpacing.inputHeight,
                      child: AppIconButton(
                        tooltip: 'Shake to Discover (Buku Acak)',
                        icon: Icons.shuffle_rounded,
                        color: isDark
                            ? AppColors.softApricot
                            : AppColors.deepTeal,
                        onPressed: _pickRandomBook,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Type Selector: Title | Author | ISBN
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: FilterTabs(
                tabs: SearchFilterType.values
                    .map((filter) => filter.label)
                    .toList(),
                selectedIndex:
                    SearchFilterType.values.indexOf(_selectedFilter),
                onTabSelected: (index) =>
                    _onFilterSelected(SearchFilterType.values[index]),
              ),
            ),

            // Scan Barcode Entry Row
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s,
              ),
              child: AppCard(
                onTap: () => context.push('/scan'),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.softApricot
                                : AppColors.deepTeal)
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: isDark
                            ? AppColors.softApricot
                            : AppColors.deepTeal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Barcode',
                            style: AppText.sectionHeading(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ),
                          ),
                          Text(
                            'Find a book by scanning its ISBN',
                            style: AppText.caption(
                              color: isDark
                                  ? AppColors.mutedDark
                                  : AppColors.mutedGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color:
                          isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s),

            // Area Konten Dinamis: Jika mencari -> Search Results; Jika belum mencari -> Discover Books
            Expanded(
              child: _hasSearched
                  ? _buildSearchResults(context)
                  : _buildDiscoverContent(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Konten State Awal: Discover Books dengan CustomScrollView
  Widget _buildDiscoverContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio =
        textScale > 1.0 ? 0.52 / (1.0 + (textScale - 1.0) * 0.8) : 0.52;

    return RefreshIndicator(
      color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      onRefresh: () => _loadDiscoverGenre(_selectedGenre, forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header Judul "Discover Books"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                'Discover Books',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
            ),
          ),

          // Baris Chip Genre horizontal scrollable
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _discoverGenres.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.s),
                  itemBuilder: (context, index) {
                    final genre = _discoverGenres[index];
                    final isSelected = _selectedGenre.subject == genre.subject;

                    return AppChip(
                      label: genre.label,
                      isSelected: isSelected,
                      onTap: () {
                        if (!isSelected) {
                          _loadDiscoverGenre(genre);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.s),
          ),

          // Area Grid / Shimmer / Error / Empty
          _buildDiscoverGridSliver(context, childAspectRatio),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverGridSliver(
      BuildContext context, double childAspectRatio) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Shimmer Loading pada area grid saja
    if (_isDiscoverLoading) {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.l,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildShimmerItem(isDark),
          childCount: 6,
        ),
      );
    }

    // 2. Error State per chip
    if (_discoverError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.m,
          ),
          child: EmptyStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal Memuat Rekomendasi',
            message: _discoverError!,
            actionLabel: 'Coba Lagi',
            onAction: () =>
                _loadDiscoverGenre(_selectedGenre, forceRefresh: true),
          ),
        ),
      );
    }

    // 3. Empty State per chip
    if (_discoverBooks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.m,
          ),
          child: EmptyStateCard(
            icon: Icons.menu_book_rounded,
            title: 'Belum Ada Buku',
            message:
                'Tidak ada buku ditemukan untuk genre ${_selectedGenre.label}. Silakan coba genre lain.',
            actionLabel: 'Coba Lagi',
            onAction: () =>
                _loadDiscoverGenre(_selectedGenre, forceRefresh: true),
          ),
        ),
      );
    }

    // 4. Success Grid Buku
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.l,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = _discoverBooks[index];
          return BookGridCard(
            title: book.title,
            authors: book.authors,
            coverUrl: book.coverUrl,
            onTap: () {
              context.push('/book/search', extra: book);
            },
          );
        },
        childCount: _discoverBooks.length,
      ),
    );
  }

  /// Hasil pencarian saat pengguna mengetik >= 2 karakter
  Widget _buildSearchResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio =
        textScale > 1.0 ? 0.52 / (1.0 + (textScale - 1.0) * 0.8) : 0.52;

    // 1. Loading State (Shimmer skeleton 3 kolom)
    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.l,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildShimmerItem(isDark),
      );
    }

    // 2. Error State (+ tombol Coba Lagi)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: EmptyStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Terjadi Kesalahan',
            message: _errorMessage!,
            actionLabel: 'Coba Lagi',
            onAction: () => _performSearch(_searchController.text.trim()),
          ),
        ),
      );
    }

    // 3. Empty State (Pencarian tidak menemukan hasil)
    if (_searchResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: 'Buku Tidak Ditemukan',
            message: 'Coba gunakan kata kunci atau filter lain.',
          ),
        ),
      );
    }

    // 4. Success State (Grid 3 kolom BookGridCard)
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.l,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return BookGridCard(
          title: book.title,
          authors: book.authors,
          coverUrl: book.coverUrl,
          onTap: () {
            context.push('/book/search', extra: book);
          },
        );
      },
    );
  }

  Widget _buildShimmerItem(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.mutedGray.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.mutedGray.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          width: 60,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.mutedGray.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          ),
        ),
      ],
    );
  }
}

