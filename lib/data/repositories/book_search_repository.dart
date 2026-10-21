/// Hasil pencarian buku — PRD §9.1 (Google Books API mapping).
class BookSearchResult {
  final String googleBooksId;
  final String title;
  final String? authors;
  final String? genre;
  final String? isbn;
  final String? publisher;
  final int? pageCount;
  final String? coverUrl;
  final String? synopsis;
  final double? priceAmount;
  final String? priceCurrency;

  const BookSearchResult({
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.genre,
    this.isbn,
    this.publisher,
    this.pageCount,
    this.coverUrl,
    this.synopsis,
    this.priceAmount,
    this.priceCurrency,
  });
}

/// Kontrak pencarian buku — PRD §13.0.
abstract class BookSearchRepository {
  /// Cari buku berdasarkan query dan filter.
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  });

  /// Ambil buku acak (untuk shake to discover).
  Future<BookSearchResult?> randomBook();
}
