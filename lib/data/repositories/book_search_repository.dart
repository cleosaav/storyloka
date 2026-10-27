/// Hasil pencarian dan detail buku — PRD §9.1 & Fase S3.
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

  // Field detail tambahan — Fase S3
  final String? subtitle;
  final String? publishedDate;
  final String? language;
  final double? averageRating;
  final int? ratingsCount;
  final String? infoLink;
  final String? previewLink;
  final String? buyLink;
  final String? saleability;
  final String? priceCountry;
  final String? priceNote;
  final String? synopsisSource;

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
    this.subtitle,
    this.publishedDate,
    this.language,
    this.averageRating,
    this.ratingsCount,
    this.infoLink,
    this.previewLink,
    this.buyLink,
    this.saleability,
    this.priceCountry,
    this.priceNote,
    this.synopsisSource,
  });

  BookSearchResult copyWith({
    String? googleBooksId,
    String? title,
    String? authors,
    String? genre,
    String? isbn,
    String? publisher,
    int? pageCount,
    String? coverUrl,
    String? synopsis,
    double? priceAmount,
    String? priceCurrency,
    String? subtitle,
    String? publishedDate,
    String? language,
    double? averageRating,
    int? ratingsCount,
    String? infoLink,
    String? previewLink,
    String? buyLink,
    String? saleability,
    String? priceCountry,
    String? priceNote,
    String? synopsisSource,
  }) {
    return BookSearchResult(
      googleBooksId: googleBooksId ?? this.googleBooksId,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      genre: genre ?? this.genre,
      isbn: isbn ?? this.isbn,
      publisher: publisher ?? this.publisher,
      pageCount: pageCount ?? this.pageCount,
      coverUrl: coverUrl ?? this.coverUrl,
      synopsis: synopsis ?? this.synopsis,
      priceAmount: priceAmount ?? this.priceAmount,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      subtitle: subtitle ?? this.subtitle,
      publishedDate: publishedDate ?? this.publishedDate,
      language: language ?? this.language,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      infoLink: infoLink ?? this.infoLink,
      previewLink: previewLink ?? this.previewLink,
      buyLink: buyLink ?? this.buyLink,
      saleability: saleability ?? this.saleability,
      priceCountry: priceCountry ?? this.priceCountry,
      priceNote: priceNote ?? this.priceNote,
      synopsisSource: synopsisSource ?? this.synopsisSource,
    );
  }

  /// Menggabungkan data: nilai non-null dari [detail] menang — Fase S3.
  BookSearchResult mergeWith(BookSearchResult detail) {
    return BookSearchResult(
      googleBooksId: detail.googleBooksId.isNotEmpty
          ? detail.googleBooksId
          : googleBooksId,
      title: detail.title.isNotEmpty ? detail.title : title,
      authors: detail.authors ?? authors,
      genre: detail.genre ?? genre,
      isbn: detail.isbn ?? isbn,
      publisher: detail.publisher ?? publisher,
      pageCount: detail.pageCount ?? pageCount,
      coverUrl: detail.coverUrl ?? coverUrl,
      synopsis: detail.synopsis ?? synopsis,
      priceAmount: detail.priceAmount ?? priceAmount,
      priceCurrency: detail.priceCurrency ?? priceCurrency,
      subtitle: detail.subtitle ?? subtitle,
      publishedDate: detail.publishedDate ?? publishedDate,
      language: detail.language ?? language,
      averageRating: detail.averageRating ?? averageRating,
      ratingsCount: detail.ratingsCount ?? ratingsCount,
      infoLink: detail.infoLink ?? infoLink,
      previewLink: detail.previewLink ?? previewLink,
      buyLink: detail.buyLink ?? buyLink,
      saleability: detail.saleability ?? saleability,
      priceCountry: detail.priceCountry ?? priceCountry,
      priceNote: detail.priceNote ?? priceNote,
      synopsisSource: detail.synopsisSource ?? synopsisSource,
    );
  }
}

/// Kontrak pencarian dan detail buku — PRD §13.0 & Fase S3.
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

  /// Ambil detail lengkap buku berdasarkan Google Books ID — Fase S3.
  Future<BookSearchResult?> getDetail(String googleBooksId);
}
