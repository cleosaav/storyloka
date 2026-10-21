/// Enum untuk list_type buku.
enum ListType {
  collection,
  wishlist;

  String get value => name;

  static ListType fromString(String s) =>
      ListType.values.firstWhere((e) => e.name == s);
}

/// Enum untuk status buku.
enum BookStatus {
  notStarted('not_started', 'Belum dibaca'),
  reading('reading', 'Sedang dibaca'),
  finished('finished', 'Selesai');

  final String value;
  final String label;
  const BookStatus(this.value, this.label);

  static BookStatus fromString(String s) =>
      BookStatus.values.firstWhere((e) => e.value == s);
}

/// Model buku milik pengguna — PRD §8.1 (tabel user_books).
class UserBook {
  final String id;
  final String userId;
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
  final ListType listType;
  final BookStatus status;
  final int currentPage;
  final int? rating;
  final String? review;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? lastReadAt;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const UserBook({
    required this.id,
    required this.userId,
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
    required this.listType,
    this.status = BookStatus.notStarted,
    this.currentPage = 0,
    this.rating,
    this.review,
    this.startedAt,
    this.finishedAt,
    this.lastReadAt,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  UserBook copyWith({
    ListType? listType,
    BookStatus? status,
    int? currentPage,
    int? pageCount,
    int? rating,
    String? review,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? lastReadAt,
    bool? isDeleted,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return UserBook(
      id: id,
      userId: userId,
      googleBooksId: googleBooksId,
      title: title,
      authors: authors,
      genre: genre,
      isbn: isbn,
      publisher: publisher,
      pageCount: pageCount ?? this.pageCount,
      coverUrl: coverUrl,
      synopsis: synopsis,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
      listType: listType ?? this.listType,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Progress membaca (0.0 – 1.0).
  double get progress {
    if (pageCount == null || pageCount! <= 0) return 0.0;
    return (currentPage / pageCount!).clamp(0.0, 1.0);
  }

  /// Persen membaca.
  int get progressPercent => (progress * 100).round();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'google_books_id': googleBooksId,
        'title': title,
        'authors': authors,
        'genre': genre,
        'isbn': isbn,
        'publisher': publisher,
        'page_count': pageCount,
        'cover_url': coverUrl,
        'synopsis': synopsis,
        'price_amount': priceAmount,
        'price_currency': priceCurrency,
        'list_type': listType.value,
        'status': status.value,
        'current_page': currentPage,
        'rating': rating,
        'review': review,
        'started_at': startedAt?.toUtc().toIso8601String(),
        'finished_at': finishedAt?.toUtc().toIso8601String(),
        'last_read_at': lastReadAt?.toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory UserBook.fromMap(Map<String, dynamic> m) => UserBook(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        googleBooksId: m['google_books_id'] as String,
        title: m['title'] as String,
        authors: m['authors'] as String?,
        genre: m['genre'] as String?,
        isbn: m['isbn'] as String?,
        publisher: m['publisher'] as String?,
        pageCount: m['page_count'] as int?,
        coverUrl: m['cover_url'] as String?,
        synopsis: m['synopsis'] as String?,
        priceAmount: (m['price_amount'] as num?)?.toDouble(),
        priceCurrency: m['price_currency'] as String?,
        listType: ListType.fromString(m['list_type'] as String),
        status: BookStatus.fromString(m['status'] as String),
        currentPage: (m['current_page'] as int?) ?? 0,
        rating: m['rating'] as int?,
        review: m['review'] as String?,
        startedAt: _parseDateTime(m['started_at']),
        finishedAt: _parseDateTime(m['finished_at']),
        lastReadAt: _parseDateTime(m['last_read_at']),
        isDeleted: (m['is_deleted'] is int)
            ? m['is_deleted'] == 1
            : (m['is_deleted'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        syncStatus: (m['sync_status'] as String?) ?? 'pending',
      );

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }
}
