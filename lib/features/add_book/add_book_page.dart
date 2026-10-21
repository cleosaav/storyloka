import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

/// Halaman Pencarian & Penambahan Buku — PRD §7.3.
class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  SearchFilterType _selectedFilter = SearchFilterType.title;
  bool _isLoading = false;
  String? _errorMessage;
  List<BookSearchResult> _searchResults = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _pickRandomBook() async {
    try {
      final repository = context.read<BookSearchRepository>();
      final book = await repository.randomBook();
      if (!mounted) return;

      if (book != null) {
        context.push('/book/search', extra: book);
      } else {
        AppSnackBar.show(
          context,
          message: 'Buku demo tidak tersedia saat ini.',
          type: SnackBarType.warning,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Gagal memilih buku acak.',
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.l),
            child: Center(child: DemoModeChip()),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar + Shake/Shuffle Icon Button
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: _selectedFilter.placeholder,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.m,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                // Shake to discover button (Buku acak demo)
                Material(
                  color: isDark ? AppColors.surfaceDark : AppColors.sageGreen.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    side: BorderSide(
                      color: isDark ? AppColors.mutedDark.withValues(alpha: 0.3) : AppColors.sageGreen,
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Shake to Discover (Buku Acak)',
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: isDark ? AppColors.softApricot : AppColors.deepTeal,
                    ),
                    onPressed: _pickRandomBook,
                  ),
                ),
              ],
            ),
          ),

          // Search Type Selector: Title | Author | ISBN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<SearchFilterType>(
                showSelectedIcon: false,
                segments: SearchFilterType.values
                    .map((filter) => ButtonSegment<SearchFilterType>(
                          value: filter,
                          label: Text(filter.label, maxLines: 1),
                        ))
                    .toList(),
                selected: {_selectedFilter},
                onSelectionChanged: (newSelection) =>
                    _onFilterSelected(newSelection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  ),
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isDark
                          ? AppColors.primaryDark
                          : AppColors.deepTeal;
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return isDark ? AppColors.inkDark : AppColors.ink;
                  }),
                ),
              ),
            ),
          ),

          // Scan Barcode Entry Row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.m,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: AppCard(
              onTap: () => context.push('/scan'),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.softApricot : AppColors.deepTeal).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: isDark ? AppColors.softApricot : AppColors.deepTeal,
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
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s),

          // Area Konten Dinamis (Initial, Loading, Empty, Error, Success Grid)
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Loading State (Shimmer skeleton 3 kolom)
    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.l),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.52,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.l,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
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
                  borderRadius: BorderRadius.circular(4),
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
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      );
    }

    // 2. Error State (+ tombol Coba Lagi)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.body(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: () => _performSearch(_searchController.text.trim()),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Initial State (Belum mencari atau query < 2 karakter)
    if (!_hasSearched) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primaryDark : AppColors.deepTeal).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 48,
                  color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Discover Books',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Search by title, author, or ISBN to find your next read.',
                textAlign: TextAlign.center,
                style: AppText.body(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Empty State (Pencarian tidak menemukan hasil)
    if (_searchResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Buku tidak ditemukan',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Coba gunakan kata kunci atau filter lain.',
                textAlign: TextAlign.center,
                style: AppText.body(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Success State (Grid 3 kolom BookGridCard)
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.l),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.52,
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
}
