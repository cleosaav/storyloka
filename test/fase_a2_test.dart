import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/features/add_book/add_book_page.dart';
import 'package:storyloka/features/add_book/scan_page.dart';
import 'package:storyloka/features/book_detail/search_book_detail_page.dart';

void main() {
  group('Fase A2 — Book Search & Library Repositories Test', () {
    late FakeBookSearchRepository searchRepo;
    late FakeLibraryRepository libraryRepo;

    setUp(() {
      fakeRepositoriesEnableLatency = false;
      searchRepo = FakeBookSearchRepository();
      libraryRepo = FakeLibraryRepository();
    });

    tearDown(() {
      fakeRepositoriesEnableLatency = true;
    });

    test('FakeBookSearchRepository searches by title, author, and isbn', () async {
      // 1. Search by title
      final titleResults = await searchRepo.search('bumi', filter: 'title');
      expect(titleResults.isNotEmpty, true);
      expect(titleResults.first.title.toLowerCase().contains('bumi'), true);

      // 2. Search by author
      final authorResults = await searchRepo.search('pramoedya', filter: 'author');
      expect(authorResults.isNotEmpty, true);
      expect(authorResults.first.authors?.toLowerCase().contains('pramoedya'), true);

      // 3. Search by ISBN
      final isbnResults = await searchRepo.search('9789799731234', filter: 'isbn');
      expect(isbnResults.isNotEmpty, true);
      expect(isbnResults.first.isbn, '9789799731234');
    });

    test('FakeBookSearchRepository randomBook returns a valid demo book', () async {
      final random = await searchRepo.randomBook();
      expect(random, isNotNull);
      expect(random!.title.isNotEmpty, true);
    });

    test('FakeLibraryRepository prevents duplicates and handles soft delete resurrection', () async {
      final now = DateTime.now();
      const testId = 'test_google_books_unique_1';

      final userBook1 = UserBook(
        id: 'book_1',
        userId: 'demo_user',
        googleBooksId: testId,
        title: 'Buku Tes Unik',
        listType: ListType.collection,
        status: BookStatus.notStarted,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Add first time
      await libraryRepo.addBook(userBook1);
      final initialList = await libraryRepo.getBooks(listType: ListType.collection);
      expect(initialList.any((b) => b.googleBooksId == testId), true);

      // 2. Add second time with same googleBooksId -> should NOT create duplicate
      final userBookDuplicate = UserBook(
        id: 'book_duplicate',
        userId: 'demo_user',
        googleBooksId: testId,
        title: 'Buku Tes Unik',
        listType: ListType.collection,
        status: BookStatus.notStarted,
        createdAt: now,
        updatedAt: now,
      );
      await libraryRepo.addBook(userBookDuplicate);
      final afterDupList = await libraryRepo.getBooks(listType: ListType.collection);
      final matching = afterDupList.where((b) => b.googleBooksId == testId).toList();
      expect(matching.length, 1);

      // 3. Soft delete and resurrect
      await libraryRepo.deleteBook(matching.first.id);
      final afterDelete = await libraryRepo.getBooks(listType: ListType.collection);
      expect(afterDelete.any((b) => b.googleBooksId == testId), false);

      // Resurrect via addBook
      await libraryRepo.addBook(userBook1);
      final afterResurrect = await libraryRepo.getBooks(listType: ListType.collection);
      expect(afterResurrect.any((b) => b.googleBooksId == testId), true);
    });

    test('FakeLibraryRepository moves book from wishlist to collection without duplication', () async {
      final now = DateTime.now();
      const testId = 'wishlist_to_move_1';

      final wishBook = UserBook(
        id: 'wish_1',
        userId: 'demo_user',
        googleBooksId: testId,
        title: 'Buku Wishlist Pindah',
        listType: ListType.wishlist,
        status: BookStatus.notStarted,
        createdAt: now,
        updatedAt: now,
      );

      await libraryRepo.addBook(wishBook);
      final wishList = await libraryRepo.getBooks(listType: ListType.wishlist);
      expect(wishList.any((b) => b.googleBooksId == testId), true);

      // Move via moveToCollection
      await libraryRepo.moveToCollection('wish_1');

      final wishListAfter = await libraryRepo.getBooks(listType: ListType.wishlist);
      final collListAfter = await libraryRepo.getBooks(listType: ListType.collection);

      expect(wishListAfter.any((b) => b.googleBooksId == testId), false);
      expect(collListAfter.any((b) => b.googleBooksId == testId), true);
    });
  });

  group('Fase A2 — UI & Widget Tests', () {
    late FakeBookSearchRepository searchRepo;
    late FakeLibraryRepository libraryRepo;

    setUp(() {
      fakeRepositoriesEnableLatency = false;
      searchRepo = FakeBookSearchRepository();
      libraryRepo = FakeLibraryRepository();
    });

    tearDown(() {
      fakeRepositoriesEnableLatency = true;
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          Provider<BookSearchRepository>.value(value: searchRepo),
          Provider<LibraryRepository>.value(value: libraryRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      );
    }

    testWidgets('AddBookPage displays search bar, filter chips, and scan entry row', (tester) async {
      await tester.pumpWidget(createTestApp(const AddBookPage()));
      await tester.pumpAndSettle();

      // Memastikan elemen utama AddBookPage ada
      expect(find.text('Add a Book'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Author'), findsOneWidget);
      expect(find.text('ISBN'), findsOneWidget);
      expect(find.text('Scan Barcode'), findsOneWidget);
      expect(find.text('Discover Books'), findsOneWidget);
    });

    testWidgets('ScanPage displays camera simulator and manual ISBN input', (tester) async {
      await tester.pumpWidget(createTestApp(const ScanPage()));
      await tester.pumpAndSettle();

      expect(find.text('Scan Barcode'), findsOneWidget);
      expect(find.text('Input ISBN Manual'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari ISBN'), findsOneWidget);
    });

    testWidgets('SearchBookDetailPage displays book detail, synopsis, price, and add buttons', (tester) async {
      const demoResult = BookSearchResult(
        googleBooksId: 'demo_test_1',
        title: 'Buku Uji Coba',
        authors: 'Penulis Hebat',
        genre: 'Sastra',
        isbn: '9781234567890',
        publisher: 'Penerbit Utama',
        pageCount: 250,
        synopsis: 'Ini adalah sinopsis lengkap dari buku uji coba untuk Fase A2.',
        priceAmount: 85000,
        priceCurrency: 'IDR',
      );

      await tester.pumpWidget(createTestApp(
        const SearchBookDetailPage(book: demoResult),
      ));
      await tester.pumpAndSettle();

      // Validasi konten tampilan
      expect(find.text('Buku Uji Coba'), findsOneWidget);
      expect(find.text('Penulis Hebat'), findsOneWidget);
      expect(find.text('Sastra'), findsOneWidget);
      expect(find.text('Synopsis'), findsOneWidget);
      expect(find.text('Book Price'), findsOneWidget);
      expect(find.text('Find Nearby Bookstores'), findsOneWidget);
      expect(find.text('Open Maps'), findsOneWidget);

      // Tombol awal
      expect(find.text('Add to Collection'), findsOneWidget);
      expect(find.text('Add to Wishlist'), findsOneWidget);

      // Tekan Add to Collection
      await tester.tap(find.text('Add to Collection'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(seconds: 4));

      // Label tombol berubah menjadi Added to Collection (disabled)
      expect(find.text('Added to Collection'), findsOneWidget);

      // Pastikan tersimpan di library
      final coll = await libraryRepo.getBooks(listType: ListType.collection);
      expect(coll.any((b) => b.googleBooksId == 'demo_test_1'), true);
    });
  });
}
