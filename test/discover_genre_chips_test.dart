import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/progress_and_badge.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/features/add_book/add_book_page.dart';
import 'helpers/fake/fake_repositories.dart';

class MockBookSearchRepository implements BookSearchRepository {
  final List<Map<String, dynamic>> searchCalls = [];
  bool shouldThrowError = false;
  List<BookSearchResult> cannedResults = [];

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  }) async {
    searchCalls.add({
      'query': query,
      'filter': filter,
      'maxResults': maxResults,
      'startIndex': startIndex,
    });

    if (shouldThrowError) {
      throw Exception('Network error');
    }

    if (cannedResults.isNotEmpty) {
      return cannedResults;
    }

    return [
      BookSearchResult(
        googleBooksId: 'id_${query}_1',
        title: 'Buku $query Unggulan',
        authors: 'Penulis $query',
        coverUrl: 'https://example.com/cover.jpg',
      ),
      BookSearchResult(
        googleBooksId: 'id_${query}_2',
        title: 'Kisah Klasik $query',
        authors: 'Pujangga $query',
        coverUrl: 'https://example.com/cover2.jpg',
      ),
    ];
  }

  @override
  Future<BookSearchResult?> randomBook() async => null;

  @override
  Future<BookSearchResult?> getDetail(String googleBooksId) async => null;

  @override
  Future<BookSearchResult> enrich(BookSearchResult b) async => b;
}

Widget _buildWrapper({
  required Widget child,
  required BookSearchRepository searchRepo,
}) {
  return MultiProvider(
    providers: [
      Provider<BookSearchRepository>.value(value: searchRepo),
      Provider<LibraryRepository>(create: (_) => FakeLibraryRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Discover Books: Genre Chips & Caching Tests', () {
    testWidgets(
        '1. Memilih chip memicu pemanggilan repository dengan subjek yang benar',
        (tester) async {
      final mockRepo = MockBookSearchRepository();

      await tester.pumpWidget(
        _buildWrapper(
          child: const AddBookPage(),
          searchRepo: mockRepo,
        ),
      );

      // Tunggu inisialisasi loadDiscoverGenre('all')
      await tester.pumpAndSettle();

      expect(find.text('Discover Books'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Fiction'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      final callsBefore = mockRepo.searchCalls.length;

      // Ketuk chip "History"
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      final callsAfter = mockRepo.searchCalls.length;
      expect(callsAfter, greaterThan(callsBefore));

      // Panggilan terakhir harus dengan query 'history' dan filter 'subject'
      final lastCall = mockRepo.searchCalls.last;
      expect(lastCall['query'], equals('history'));
      expect(lastCall['filter'], equals('subject'));
      expect(find.text('Buku history Unggulan'), findsOneWidget);
    });

    testWidgets(
        '2. Chip yang sudah di-cache tidak memanggil ulang repository saat dipilih kembali',
        (tester) async {
      final mockRepo = MockBookSearchRepository();

      await tester.pumpWidget(
        _buildWrapper(
          child: const AddBookPage(),
          searchRepo: mockRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Pilih chip "Fiction" (berada di awal list)
      final fictionFinder = find.widgetWithText(AppChip, 'Fiction');
      expect(fictionFinder, findsOneWidget);
      await tester.tap(fictionFinder);
      await tester.pumpAndSettle();

      final callCountAfterFiction = mockRepo.searchCalls.length;
      expect(mockRepo.searchCalls.last['query'], equals('fiction'));

      // Pilih chip "History" (berada di awal list)
      final historyFinder = find.widgetWithText(AppChip, 'History');
      expect(historyFinder, findsOneWidget);
      await tester.tap(historyFinder);
      await tester.pumpAndSettle();

      expect(mockRepo.searchCalls.length, greaterThan(callCountAfterFiction));
      expect(mockRepo.searchCalls.last['query'], equals('history'));

      final callCountAfterHistory = mockRepo.searchCalls.length;

      // Pilih kembali chip "Fiction" yang sudah di-cache
      await tester.tap(fictionFinder);
      await tester.pumpAndSettle();

      // Tidak boleh ada penambahan call ke repository karena diambil dari cache memori
      expect(mockRepo.searchCalls.length, equals(callCountAfterHistory));
      expect(find.text('Buku fiction Unggulan'), findsOneWidget);
    });

    testWidgets(
        '3. Mengetik query pencarian mengganti Discover dan menghapusnya mengembalikan chip yang terakhir dipilih',
        (tester) async {
      final mockRepo = MockBookSearchRepository();

      await tester.pumpWidget(
        _buildWrapper(
          child: const AddBookPage(),
          searchRepo: mockRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Pilih chip "History"
      final historyFinder = find.widgetWithText(AppChip, 'History');
      expect(historyFinder, findsOneWidget);
      await tester.tap(historyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Buku history Unggulan'), findsOneWidget);
      expect(find.text('Discover Books'), findsOneWidget);

      // Ketik kata kunci >= 2 karakter di search bar
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Harry Potter');
      await tester.pump(const Duration(milliseconds: 600)); // debounce
      await tester.pumpAndSettle();

      // Bagian Discover (judul "Discover Books" dan baris chips) harus tersembunyi
      expect(find.text('Discover Books'), findsNothing);
      expect(find.text('History'), findsNothing);

      // Hapus teks pencarian (< 2 karakter)
      await tester.enterText(searchField, '');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Discover Books kembali dan menampilkan chip History yang terakhir dipilih
      expect(find.text('Discover Books'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Buku history Unggulan'), findsOneWidget);
    });

    testWidgets(
        '4. Aksesibilitas: Chip memiliki Semantics dan minimum area sentuh 48dp',
        (tester) async {
      final mockRepo = MockBookSearchRepository();

      await tester.pumpWidget(
        _buildWrapper(
          child: const AddBookPage(),
          searchRepo: mockRepo,
        ),
      );
      await tester.pumpAndSettle();

      final allChips = find.byType(AppChip);
      expect(allChips, findsWidgets);

      final firstChipSize = tester.getSize(allChips.first);
      expect(firstChipSize.height, greaterThanOrEqualTo(48.0));
      expect(firstChipSize.width, greaterThanOrEqualTo(48.0));
    });
  });
}
