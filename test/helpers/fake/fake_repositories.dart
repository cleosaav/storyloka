import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:storyloka/data/models/app_user.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/models/reading_session.dart';
import 'package:storyloka/data/models/ledger_block.dart';
import 'package:storyloka/data/models/game_score.dart';
import 'package:storyloka/data/models/chat_message.dart';
import 'package:storyloka/data/repositories/auth_repository.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/data/static/team_feedback.dart';
import 'package:storyloka/data/repositories/chat_repository.dart';
import 'package:storyloka/data/repositories/currency_repository.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import '../demo_widgets.dart';

const _uuid = Uuid();

/// Flag untuk mengaktifkan/menonaktifkan latensi pada unit test.
bool fakeRepositoriesEnableLatency = true;

/// Latensi simulasi untuk Fake repository — PRD §13.0 aturan 4 & 6.
Future<T> _simulateLatency<T>(T value, {DemoControls? demoControls}) async {
  if (demoControls?.simulateNetworkError == true) {
    throw Exception('Simulasi kesalahan jaringan aktif. Periksa koneksi internet Anda.');
  }
  if (!fakeRepositoriesEnableLatency) return value;
  if (demoControls?.simulateSlowLatency == true) {
    await Future.delayed(const Duration(milliseconds: 2000));
    return value;
  }
  final ms = 300 + Random().nextInt(500); // 300–800 ms
  await Future.delayed(Duration(milliseconds: ms));
  return value;
}

// ═══════════════════════════════════════════════════
// Data Demo — ~12 buku nyata tanpa cover, PRD §13.0 aturan 5.
// ═══════════════════════════════════════════════════

final List<BookSearchResult> _demoBooks = [
  const BookSearchResult(
    googleBooksId: 'demo_1',
    title: 'Laskar Pelangi',
    authors: 'Andrea Hirata',
    genre: 'Fiction',
    isbn: '9789793062792',
    publisher: 'Bentang Pustaka',
    pageCount: 529,
    synopsis:
        'Kisah masa kecil sepuluh anak dari keluarga miskin di Belitung yang berjuang untuk bersekolah.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_2',
    title: 'Bumi Manusia',
    authors: 'Pramoedya Ananta Toer',
    genre: 'Historical Fiction',
    isbn: '9789799731234',
    publisher: 'Hasta Mitra',
    pageCount: 535,
    synopsis:
        'Novel berlatar akhir abad ke-19, mengisahkan Minke, seorang priyayi Jawa yang berhadapan dengan kolonialisme Belanda.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_3',
    title: 'Atomic Habits',
    authors: 'James Clear',
    genre: 'Self-Improvement',
    isbn: '9780735211292',
    publisher: 'Avery',
    pageCount: 320,
    synopsis:
        'Panduan praktis membangun kebiasaan baik dan membuang kebiasaan buruk lewat perubahan kecil.',
    priceAmount: 16.99,
    priceCurrency: 'USD',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_4',
    title: 'Sapiens: A Brief History of Humankind',
    authors: 'Yuval Noah Harari',
    genre: 'History',
    isbn: '9780062316097',
    publisher: 'Harper',
    pageCount: 443,
    synopsis:
        'Harari menelusuri sejarah umat manusia dari era Homo sapiens awal hingga revolusi ilmiah dan teknologi.',
    priceAmount: 14.99,
    priceCurrency: 'USD',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_5',
    title: 'Filosofi Teras',
    authors: 'Henry Manampiring',
    genre: 'Philosophy',
    isbn: '9786024526986',
    publisher: 'Kompas',
    pageCount: 346,
    synopsis:
        'Penerapan filosofi Stoisisme dalam kehidupan sehari-hari modern, ditulis dengan gaya santai dan mudah dipahami.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_6',
    title: 'The Hobbit',
    authors: 'J.R.R. Tolkien',
    genre: 'Fantasy',
    isbn: '9780547928227',
    publisher: 'Houghton Mifflin Harcourt',
    pageCount: 300,
    synopsis:
        'Petualangan Bilbo Baggins, hobbit yang enggan berpetualang namun terlibat dalam perjalanan epik bersama para kurcaci.',
    priceAmount: 9.99,
    priceCurrency: 'USD',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_7',
    title: 'Cantik Itu Luka',
    authors: 'Eka Kurniawan',
    genre: 'Fiction',
    isbn: '9789792232585',
    publisher: 'Gramedia Pustaka Utama',
    pageCount: 480,
    synopsis:
        'Novel realisme magis yang berlatar Indonesia era kolonial hingga pasca-kemerdekaan.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_8',
    title: 'Thinking, Fast and Slow',
    authors: 'Daniel Kahneman',
    genre: 'Psychology',
    isbn: '9780374533557',
    publisher: 'Farrar, Straus and Giroux',
    pageCount: 499,
    synopsis:
        'Kahneman menguraikan dua sistem berpikir yang membentuk keputusan manusia.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_9',
    title: 'Ronggeng Dukuh Paruk',
    authors: 'Ahmad Tohari',
    genre: 'Fiction',
    isbn: '9789792232592',
    publisher: 'Gramedia Pustaka Utama',
    pageCount: 407,
    synopsis:
        'Kisah Srintil, seorang ronggeng dari desa terpencil yang hidupnya diwarnai cinta, politik, dan tradisi.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_10',
    title: 'Educated',
    authors: 'Tara Westover',
    genre: 'Memoir',
    isbn: '9780399590504',
    publisher: 'Random House',
    pageCount: 334,
    synopsis:
        'Memoar seorang perempuan yang dibesarkan di keluarga survivalist di Idaho dan berhasil meraih PhD.',
    priceAmount: 12.99,
    priceCurrency: 'USD',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_11',
    title: 'Laut Bercerita',
    authors: 'Leila S. Chudori',
    genre: 'Fiction',
    isbn: '9786024246945',
    publisher: 'Kepustakaan Populer Gramedia',
    pageCount: 394,
    synopsis:
        'Novel tentang aktivis mahasiswa era Orde Baru yang menjadi korban penculikan, diceritakan dari sudut pandang laut.',
  ),
  const BookSearchResult(
    googleBooksId: 'demo_12',
    title: 'Dune',
    authors: 'Frank Herbert',
    genre: 'Science Fiction',
    isbn: '9780441013593',
    publisher: 'Ace',
    pageCount: 688,
    synopsis:
        'Di planet gurun Arrakis, Paul Atreides harus menguasai kekuatan politik, agama, dan ekologi untuk bertahan.',
    priceAmount: 10.99,
    priceCurrency: 'USD',
  ),
];

// ═══════════════════════════════════════════════════
// Fake Auth — PRD §7.1 & §13.0 Fase A1
// ═══════════════════════════════════════════════════

class FakeAuthRepository implements AuthRepository {
  final SecureSessionStore _sessionStore;
  AppUser? currentUser;

  FakeAuthRepository({SecureSessionStore? sessionStore})
      : _sessionStore = sessionStore ?? SecureSessionStore();

  @override
  Future<AppUser> login(String email, String password) async {
    await _simulateLatency(null);

    // Simulasi password salah sesuai PRD §13.0 Fase A1
    if (password.toLowerCase() == 'wrong') {
      throw Exception('INVALID_CREDENTIALS');
    }

    // Ambil nama dari user yang tersimpan sebelumnya jika email sama, atau fallback
    final storedUser = await _sessionStore.getUser();
    final name = (storedUser != null && storedUser.email.toLowerCase() == email.toLowerCase())
        ? storedUser.name
        : 'Demo Reader';

    currentUser = AppUser(
      id: storedUser?.id ?? _uuid.v4(),
      name: name,
      email: email,
      createdAt: storedUser?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Simpan session fake di secure storage agar alur restart bisa diuji
    await _sessionStore.saveSession(
      token: 'fake-token-${_uuid.v4()}',
      user: currentUser!,
    );

    return currentUser!;
  }

  @override
  Future<AppUser> register(
      String name, String email, String password) async {
    await _simulateLatency(null);

    // Simulasi email sudah terdaftar sesuai PRD §13.0 Fase A1
    if (email.toLowerCase() == 'taken@demo.com') {
      throw Exception('EMAIL_TAKEN');
    }

    currentUser = AppUser(
      id: _uuid.v4(),
      name: name,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Simpan session fake di secure storage
    await _sessionStore.saveSession(
      token: 'fake-token-${_uuid.v4()}',
      user: currentUser!,
    );

    return currentUser!;
  }

  @override
  Future<void> logout() async {
    await _simulateLatency(null);
    currentUser = null;
    await _sessionStore.clearSession();
  }

  @override
  Future<AppUser?> validateSession() async {
    await _simulateLatency(null);
    final storedUser = await _sessionStore.getUser();
    if (storedUser != null) {
      currentUser = storedUser;
      return currentUser;
    }
    return null;
  }

  @override
  Future<bool> hasSession() async {
    final has = await _sessionStore.hasSession();
    if (has && currentUser == null) {
      currentUser = await _sessionStore.getUser();
    }
    return has;
  }
}

// ═══════════════════════════════════════════════════
// Fake Profile
// ═══════════════════════════════════════════════════

class FakeProfileRepository implements ProfileRepository {
  final FakeAuthRepository _auth;

  FakeProfileRepository(this._auth);

  @override
  Future<AppUser> getProfile() async {
    await _simulateLatency(null);
    return _auth.currentUser ??
        AppUser(
          id: 'demo',
          name: 'Demo User',
          email: 'demo@storyloka.app',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<AppUser> updateProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    await _simulateLatency(null);
    if (_auth.currentUser != null) {
      _auth.currentUser = _auth.currentUser!.copyWith(
        name: name,
        bio: bio,
        avatarUrl: avatarPath,
        updatedAt: DateTime.now(),
      );
    }
    return _auth.currentUser!;
  }
}

// ═══════════════════════════════════════════════════
// Fake Book Search
// ═══════════════════════════════════════════════════

class FakeBookSearchRepository implements BookSearchRepository {
  final DemoControls? demoControls;

  FakeBookSearchRepository({this.demoControls});

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  }) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    final q = query.toLowerCase();
    return _demoBooks.where((b) {
      switch (filter) {
        case 'author':
          return b.authors?.toLowerCase().contains(q) ?? false;
        case 'isbn':
          return b.isbn?.contains(q) ?? false;
        default:
          return b.title.toLowerCase().contains(q);
      }
    }).take(maxResults).toList();
  }

  final Map<String, BookSearchResult> _mockDetails = {};

  void setMockDetail(String googleBooksId, BookSearchResult detail) {
    _mockDetails[googleBooksId] = detail;
  }

  @override
  Future<BookSearchResult?> getDetail(String googleBooksId) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return null;
    if (_mockDetails.containsKey(googleBooksId)) {
      return _mockDetails[googleBooksId];
    }
    try {
      return _demoBooks.firstWhere((b) => b.googleBooksId == googleBooksId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BookSearchResult?> randomBook() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return null;
    if (_demoBooks.isEmpty) return null;
    return _demoBooks[Random().nextInt(_demoBooks.length)];
  }

  @override
  Future<BookSearchResult> enrich(BookSearchResult b) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (b.isbn == null || b.isbn!.trim().isEmpty) {
      return b;
    }
    final needsSynopsis = b.synopsis == null || b.synopsis!.trim().isEmpty;
    final needsCover = b.coverUrl == null || b.coverUrl!.trim().isEmpty;

    if (!needsSynopsis && !needsCover) {
      return b;
    }

    return b.copyWith(
      synopsis: needsSynopsis ? 'Sinopsis dari Open Library (Demo)' : b.synopsis,
      coverUrl: needsCover
          ? 'https://covers.openlibrary.org/b/isbn/${b.isbn}-L.jpg?default=false'
          : b.coverUrl,
      synopsisSource: needsSynopsis ? 'Open Library' : b.synopsisSource,
    );
  }
}

// ═══════════════════════════════════════════════════
// Fake Library
// ═══════════════════════════════════════════════════

class FakeLibraryRepository implements LibraryRepository {
  final DemoControls? demoControls;
  final List<UserBook> _books = [];
  bool _useDemoData = true;
  bool _initialized = false;

  FakeLibraryRepository({this.demoControls});

  /// Toggle data demo (DemoControls).
  void setUseDemoData(bool value) {
    _useDemoData = value;
    if (!value) {
      _books.clear();
      _initialized = false;
    } else {
      _ensureDemoData();
    }
  }

  void _ensureDemoData() {
    if (_initialized || !_useDemoData) return;
    _initialized = true;

    final now = DateTime.now();
    // Buat beberapa buku demo di koleksi dengan berbagai status.
    _books.addAll([
      _createFromDemo(_demoBooks[0], ListType.collection,
          status: BookStatus.reading,
          currentPage: 150,
          startedAt: now.subtract(const Duration(days: 3)),
          lastReadAt: now.subtract(const Duration(hours: 2))),
      _createFromDemo(_demoBooks[2], ListType.collection,
          status: BookStatus.finished,
          currentPage: 320,
          startedAt: now.subtract(const Duration(days: 30)),
          finishedAt: now.subtract(const Duration(days: 7))),
      _createFromDemo(_demoBooks[5], ListType.collection,
          status: BookStatus.notStarted),
      _createFromDemo(_demoBooks[7], ListType.collection,
          status: BookStatus.notStarted),
      // Wishlist
      _createFromDemo(_demoBooks[1], ListType.wishlist),
      _createFromDemo(_demoBooks[3], ListType.wishlist),
      _createFromDemo(_demoBooks[4], ListType.wishlist),
    ]);
  }

  UserBook _createFromDemo(
    BookSearchResult src,
    ListType listType, {
    BookStatus status = BookStatus.notStarted,
    int currentPage = 0,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? lastReadAt,
  }) {
    final now = DateTime.now();
    return UserBook(
      id: _uuid.v4(),
      userId: 'demo_user',
      googleBooksId: src.googleBooksId,
      title: src.title,
      authors: src.authors,
      genre: src.genre,
      isbn: src.isbn,
      publisher: src.publisher,
      pageCount: src.pageCount,
      coverUrl: null, // tanpa cover — PRD §13.0 aturan 5
      synopsis: src.synopsis,
      priceAmount: src.priceAmount,
      priceCurrency: src.priceCurrency,
      listType: listType,
      status: status,
      currentPage: currentPage,
      startedAt: startedAt,
      finishedAt: finishedAt,
      lastReadAt: lastReadAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<UserBook>> getBooks({ListType? listType}) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) {
      return [];
    }
    _ensureDemoData();
    final active = _books.where((b) => !b.isDeleted);
    if (listType != null) {
      return active.where((b) => b.listType == listType).toList();
    }
    return active.toList();
  }

  @override
  Future<UserBook?> getBookById(String id) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) {
      return null;
    }
    _ensureDemoData();
    try {
      return _books.firstWhere((b) => b.id == id && !b.isDeleted);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserBook?> findByGoogleBooksId(String googleBooksId) async {
    if (demoControls?.isDataEmpty == true) {
      return null;
    }
    _ensureDemoData();
    try {
      return _books.firstWhere(
          (b) => b.googleBooksId == googleBooksId && !b.isDeleted);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserBook> addBook(UserBook book) async {
    _ensureDemoData();
    await _simulateLatency(null, demoControls: demoControls);
    if (book.googleBooksId.isNotEmpty) {
      final existingIdx = _books.indexWhere(
        (b) => b.googleBooksId == book.googleBooksId,
      );
      if (existingIdx >= 0) {
        final existing = _books[existingIdx];
        if (existing.isDeleted) {
          final restored = existing.copyWith(
            isDeleted: false,
            listType: book.listType,
            updatedAt: DateTime.now(),
          );
          _books[existingIdx] = restored;
          return restored;
        }
        if (existing.listType == ListType.wishlist &&
            book.listType == ListType.collection) {
          final moved = existing.copyWith(
            listType: ListType.collection,
            updatedAt: DateTime.now(),
          );
          _books[existingIdx] = moved;
          return moved;
        }
        return existing;
      }
    }
    _books.add(book);
    return book;
  }

  @override
  Future<UserBook> updateBook(UserBook book) async {
    await _simulateLatency(null, demoControls: demoControls);
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx >= 0) {
      _books[idx] = book;
    }
    return book;
  }

  @override
  Future<void> deleteBook(String id) async {
    await _simulateLatency(null, demoControls: demoControls);
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _books[idx] = _books[idx].copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<UserBook> moveToCollection(String id) async {
    await _simulateLatency(null, demoControls: demoControls);
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _books[idx] = _books[idx].copyWith(
        listType: ListType.collection,
        updatedAt: DateTime.now(),
      );
    }
    return _books[idx];
  }

  @override
  Future<UserBook?> getCurrentlyReading() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) {
      return null;
    }
    _ensureDemoData();
    final reading = _books
        .where((b) =>
            b.status == BookStatus.reading &&
            !b.isDeleted &&
            b.listType == ListType.collection)
        .toList();
    if (reading.isEmpty) return null;
    reading.sort((a, b) {
      final aTime = a.lastReadAt ?? a.startedAt ?? a.createdAt;
      final bTime = b.lastReadAt ?? b.startedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return reading.first;
  }
}

// ═══════════════════════════════════════════════════
// Fake Reading
// ═══════════════════════════════════════════════════

class FakeReadingRepository implements ReadingRepository {
  final DemoControls? demoControls;
  final List<ReadingSession> _sessions = [];

  FakeReadingRepository({this.demoControls});

  @override
  Future<void> saveSession(ReadingSession session) async {
    await _simulateLatency(null, demoControls: demoControls);
    _sessions.add(session);
  }

  @override
  Future<List<ReadingSession>> getSessionsForBook(String userBookId) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    return _sessions.where((s) => s.userBookId == userBookId).toList();
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    return List.of(_sessions);
  }

  @override
  Future<int> getTotalReadingSeconds() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return 0;
    return _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }
}

// ═══════════════════════════════════════════════════
// Fake Ledger
// ═══════════════════════════════════════════════════

class FakeLedgerRepository implements LedgerRepository {
  final DemoControls? demoControls;
  final List<LedgerBlock> _blocks = [];

  FakeLedgerRepository({this.demoControls});

  @override
  Future<List<LedgerBlock>> getBlocks() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    final sorted = List.of(_blocks)
      ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
    return sorted;
  }

  @override
  Future<void> saveBlock(LedgerBlock block) async {
    await _simulateLatency(null, demoControls: demoControls);
    _blocks.add(block);
  }

  @override
  Future<LedgerBlock?> getLastBlock() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return null;
    if (_blocks.isEmpty) return null;
    final sorted = List.of(_blocks)
      ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
    return sorted.last;
  }
}

// ═══════════════════════════════════════════════════
// Fake Feedback
// ═══════════════════════════════════════════════════

class FakeFeedbackRepository implements FeedbackRepository {
  final DemoControls? demoControls;

  FakeFeedbackRepository({this.demoControls});

  @override
  Future<List<TeamFeedback>> getAll() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    return teamFeedbacks;
  }
}

// ═══════════════════════════════════════════════════
// Fake Score
// ═══════════════════════════════════════════════════

class FakeScoreRepository implements ScoreRepository {
  final DemoControls? demoControls;
  final List<GameScore> _scores = [];

  FakeScoreRepository({this.demoControls});

  @override
  Future<List<GameScore>> getScores(String game) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    return _scores.where((s) => s.game == game).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  @override
  Future<void> saveScore(GameScore score) async {
    await _simulateLatency(null, demoControls: demoControls);
    _scores.add(score);
  }

  @override
  Future<int> getHighScore(String game) async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return 0;
    final scores = _scores.where((s) => s.game == game);
    if (scores.isEmpty) return 0;
    return scores.map((s) => s.score).reduce((a, b) => a > b ? a : b);
  }
}

// ═══════════════════════════════════════════════════
// Fake Chat
// ═══════════════════════════════════════════════════

class FakeChatRepository implements ChatRepository {
  final DemoControls? demoControls;
  final List<ChatMessage> _messages = [];

  FakeChatRepository({this.demoControls});

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
  }) async {
    await _simulateLatency(null, demoControls: demoControls);
    return 'Jawaban contoh (mode demo)';
  }

  @override
  Future<List<ChatMessage>> getHistory() async {
    await _simulateLatency(null, demoControls: demoControls);
    if (demoControls?.isDataEmpty == true) return [];
    return List.of(_messages);
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _messages.add(message);
  }

  @override
  Future<void> clearHistory() async {
    _messages.clear();
  }
}

// ═══════════════════════════════════════════════════
// Fake Currency
// ═══════════════════════════════════════════════════

class FakeCurrencyRepository implements CurrencyRepository {
  final DemoControls? demoControls;

  FakeCurrencyRepository({this.demoControls});

  @override
  Future<Map<String, double>> getRates(String baseCurrency) async {
    await _simulateLatency(null, demoControls: demoControls);
    // Kurs demo berlabel "Kurs contoh" — PRD §13.0, design-system.md §8.
    return {
      'IDR': 15500.0,
      'USD': 1.0,
      'EUR': 0.92,
      'JPY': 149.5,
      'SGD': 1.35,
    };
  }

  @override
  Future<DateTime?> getLastUpdated() async {
    return DateTime.now();
  }

  @override
  bool get isFromCache => false;
}
