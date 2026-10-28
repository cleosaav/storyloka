import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'helpers/demo_widgets.dart';
import 'package:storyloka/core/widgets/progress_and_badge.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/book_detail/wishlist_book_detail_page.dart';
import 'package:storyloka/features/home/home_page.dart';
import 'package:storyloka/features/library/library_page.dart';

void main() {
  group('Fase A3 — LibraryRepository & Move to Collection Logic', () {
    late FakeLibraryRepository libraryRepo;

    setUp(() {
      fakeRepositoriesEnableLatency = false;
      libraryRepo = FakeLibraryRepository();
    });

    tearDown(() {
      fakeRepositoriesEnableLatency = true;
    });

    test('Reading Summary numbers are correctly computed from repository data', () async {
      final books = await libraryRepo.getBooks();
      final active = books.where((b) => !b.isDeleted).toList();

      final collectionBooks =
          active.where((b) => b.listType == ListType.collection).toList();
      final readingBooks =
          collectionBooks.where((b) => b.status == BookStatus.reading).toList();
      final finishedBooks =
          collectionBooks.where((b) => b.status == BookStatus.finished).toList();

      expect(collectionBooks.length, 4);
      expect(readingBooks.length, 1);
      expect(finishedBooks.length, 1);
    });

    test('Currently Reading returns the most recent book with status=reading', () async {
      final currentlyReading = await libraryRepo.getCurrentlyReading();
      expect(currentlyReading, isNotNull);
      expect(currentlyReading!.status, BookStatus.reading);
      expect(currentlyReading.listType, ListType.collection);
      expect(currentlyReading.title, 'Laskar Pelangi');
    });

    test('Moving a book from wishlist to collection updates listType', () async {
      final wishlistBooks = await libraryRepo.getBooks(listType: ListType.wishlist);
      expect(wishlistBooks.isNotEmpty, true);
      final targetBook = wishlistBooks.first;

      final updated = await libraryRepo.moveToCollection(targetBook.id);
      expect(updated.listType, ListType.collection);

      final freshCollection = await libraryRepo.getBooks(listType: ListType.collection);
      expect(freshCollection.any((b) => b.id == targetBook.id), true);

      final freshWishlist = await libraryRepo.getBooks(listType: ListType.wishlist);
      expect(freshWishlist.any((b) => b.id == targetBook.id), false);
    });

    test('Soft delete removes book from active list', () async {
      final booksBefore = await libraryRepo.getBooks();
      final bookToDelete = booksBefore.first;

      await libraryRepo.deleteBook(bookToDelete.id);

      final booksAfter = await libraryRepo.getBooks();
      expect(booksAfter.any((b) => b.id == bookToDelete.id), false);
    });
  });

  group('Fase A3 — UI Home & Library Widget Tests', () {
    late FakeLibraryRepository libraryRepo;
    late AuthController authController;

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          Provider<LibraryRepository>.value(value: libraryRepo),
          ChangeNotifierProvider<AuthController>.value(value: authController),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      );
    }

    setUp(() async {
      fakeRepositoriesEnableLatency = false;
      libraryRepo = FakeLibraryRepository();
      final sessionStore = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);

      authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: demoControls,
      );

      await authController.register(
        name: 'Budi Santoso',
        email: 'budi@demo.com',
        password: 'password123',
      );
    });

    tearDown(() {
      fakeRepositoriesEnableLatency = true;
    });

    testWidgets('HomePage renders Header sapaan, Reading Summary, Currently Reading, Collection, Wishlist', (tester) async {
      await tester.pumpWidget(createTestApp(const HomePage()));
      await tester.pumpAndSettle();

      // 1. Header Sapaan & Avatar
      expect(find.textContaining('Hello, Budi Santoso!'), findsOneWidget);
      expect(find.text('Mau baca apa hari ini?'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // Inisial avatar

      // 2. Reading Summary labels & dynamic numbers
      expect(find.text('Koleksi'), findsOneWidget);
      expect(find.text('Sedang dibaca'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // 4 Koleksi dari demo

      // 3. Currently Reading
      expect(find.text('Currently Reading'), findsOneWidget);
      expect(find.text('Laskar Pelangi'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      // 4. My Collection & My Wishlist sections with "See all"
      expect(find.text('My Collection'), findsOneWidget);
      expect(find.text('My Wishlist'), findsOneWidget);
      expect(find.text('See all'), findsNWidgets(2));
    });

    testWidgets('LibraryPage renders search bar, filter tabs, and grid items with StatusBadge', (tester) async {
      await tester.pumpWidget(createTestApp(const LibraryPage()));
      await tester.pumpAndSettle();

      // 1. Title & FilterTabs
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Wishlist'), findsOneWidget);

      // 2. Search bar
      expect(find.byType(TextField), findsOneWidget);

      // 3. Collection items & StatusBadge
      expect(find.byType(StatusBadge), findsWidgets);
      expect(find.text('Laskar Pelangi'), findsOneWidget);

      // 4. Switch to Wishlist tab
      await tester.tap(find.text('Wishlist'));
      await tester.pumpAndSettle();

      // 5. Wishlist items should be shown
      expect(find.text('Bumi Manusia'), findsOneWidget);
    });

    testWidgets('LibraryPage local search filters items by title', (tester) async {
      await tester.pumpWidget(createTestApp(const LibraryPage()));
      await tester.pumpAndSettle();

      // Type "Laskar" in search
      await tester.enterText(find.byType(TextField), 'Laskar');
      await tester.pumpAndSettle();

      expect(find.text('Laskar Pelangi'), findsOneWidget);
      expect(find.text('Filosofi Kopi'), findsNothing);
    });

    testWidgets('WishlistBookDetailPage renders single "Add to Collection" button and moves book', (tester) async {
      final wishlist = await libraryRepo.getBooks(listType: ListType.wishlist);
      final book = wishlist.first;

      await tester.pumpWidget(createTestApp(WishlistBookDetailPage(id: book.id)));
      await tester.pumpAndSettle();

      // Cek satu tombol utama Add to Collection
      expect(find.text('Add to Collection'), findsOneWidget);
      expect(find.text('Synopsis'), findsOneWidget);
      expect(find.text('Book Price'), findsOneWidget);
      expect(find.text('Find Nearby Bookstores'), findsOneWidget);

      // Tekan Add to Collection
      await tester.tap(find.text('Add to Collection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verifikasi buku sudah pindah ke koleksi
      final check = await libraryRepo.getBookById(book.id);
      expect(check?.listType, ListType.collection);
    });

    testWidgets('HomePage displays empty Currently Reading card when no book is reading', (tester) async {
      // Kosongkan demo data di repo
      libraryRepo.setUseDemoData(false);

      await tester.pumpWidget(createTestApp(const HomePage()));
      await tester.pumpAndSettle();

      // Kondisi 1: Start Your Reading Journey
      expect(find.text('Start Your Reading Journey'), findsOneWidget);
      expect(find.text('Your next favorite book is waiting for you.'), findsOneWidget);
      expect(find.text('Add Book'), findsWidgets);
    });

    testWidgets('LibraryPage displays EmptyStateCard when collection is empty', (tester) async {
      libraryRepo.setUseDemoData(false);

      await tester.pumpWidget(createTestApp(const LibraryPage()));
      await tester.pumpAndSettle();

      expect(find.text('Koleksi Masih Kosong'), findsOneWidget);
      expect(find.text('Tambahkan buku yang sedang atau pernah Anda baca ke dalam koleksi Anda.'), findsOneWidget);

      // Pindah ke tab Wishlist
      await tester.tap(find.text('Wishlist'));
      await tester.pumpAndSettle();

      expect(find.text('Wishlist Masih Kosong'), findsOneWidget);
      expect(find.text('Simpan buku yang ingin Anda baca di kemudian hari ke daftar wishlist.'), findsOneWidget);
    });

    testWidgets('LibraryPage long press opens delete confirmation dialog and cancels or deletes', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(const LibraryPage()));
      await tester.pumpAndSettle();

      // Long press buku pertama
      final bookItem = find.text('Laskar Pelangi');
      expect(bookItem, findsOneWidget);
      await tester.longPress(bookItem);
      await tester.pumpAndSettle();

      // Dialog konfirmasi muncul
      expect(find.text('Hapus dari Koleksi?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // Batal hapus
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus dari Koleksi?'), findsNothing);
      expect(find.text('Laskar Pelangi'), findsOneWidget);
    });
  });
}
