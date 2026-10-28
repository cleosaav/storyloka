import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/app_button.dart';
import 'helpers/demo_widgets.dart';
import 'package:storyloka/data/models/app_user.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/auth_repository.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/login_page.dart';
import 'package:storyloka/features/book_detail/collection_book_detail_page.dart';
import 'package:storyloka/features/book_detail/search_book_detail_page.dart';
import 'package:storyloka/features/book_detail/wishlist_book_detail_page.dart';

Widget _buildTestWrapper({
  required Widget child,
  FakeLibraryRepository? libraryRepo,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final session = SecureSessionStore();
  final dControls = DemoControls();
  final tController = ThemeController();
  final authRepo = FakeAuthRepository(sessionStore: session);
  final aController = AuthController(
    authRepository: authRepo,
    sessionStore: session,
    demoControls: dControls,
  );
  final libRepo = libraryRepo ?? FakeLibraryRepository();
  final sRepo = FakeBookSearchRepository(demoControls: dControls);

  return MultiProvider(
    providers: [
      Provider<SecureSessionStore>.value(value: session),
      ChangeNotifierProvider<DemoControls>.value(value: dControls),
      ChangeNotifierProvider<ThemeController>.value(value: tController),
      ChangeNotifierProvider<AuthController>.value(value: aController),
      Provider<LibraryRepository>.value(value: libRepo),
      Provider<BookSearchRepository>.value(value: sRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: child,
    ),
  );
}

class _MockRealAuthRepository implements AuthRepository {
  @override
  Future<AppUser> login(String email, String password) async => throw UnimplementedError();
  @override
  Future<AppUser> register(String name, String email, String password) async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AppUser?> validateSession() async => null;
  @override
  Future<bool> hasSession() async => false;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
  });

  tearDownAll(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase U4a Tests', () {
    testWidgets('1a. LoginPage menampilkan form login bersih tanpa elemen demo', (tester) async {
      await tester.pumpWidget(_buildTestWrapper(child: const LoginPage()));
      await tester.pumpAndSettle();

      expect(find.text('Catatan Mode Demo (Fase A1)'), findsNothing);
      expect(find.text('Mode demo'), findsNothing);
    });

    testWidgets('1b. LoginPage mengosongkan kredensial & menyembunyikan catatan demo di mode nyata', (tester) async {
      final session = SecureSessionStore();
      final dControls = DemoControls();
      final authRepo = _MockRealAuthRepository();
      final aController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: dControls,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SecureSessionStore>.value(value: session),
            ChangeNotifierProvider<DemoControls>.value(value: dControls),
            ChangeNotifierProvider<ThemeController>.value(value: ThemeController()),
            ChangeNotifierProvider<AuthController>.value(value: aController),
            Provider<LibraryRepository>.value(value: FakeLibraryRepository()),
            Provider<BookSearchRepository>.value(value: FakeBookSearchRepository()),
          ],
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('reader@storyloka.app'), findsNothing);
      expect(find.text('password123'), findsNothing);
      expect(find.text('Catatan Mode Demo (Fase A1)'), findsNothing);
    });

    testWidgets('2. SearchBookDetailPage: TertiaryButton Read More minHeight >= 44 dan tidak ada duplikasi penerbit di Card Harga', (tester) async {
      const searchResult = BookSearchResult(
        googleBooksId: 'sr-1',
        title: 'Laskar Pelangi',
        authors: 'Andrea Hirata',
        publisher: 'Bentang Pustaka',
        pageCount: 529,
        synopsis: 'Sebuah sinopsis yang cukup panjang untuk memicu tombol Read More dan Read Less pada kartu sinopsis halaman detail buku StoryLoka. Paragraf ini harus memiliki lebih dari 200 karakter agar teks tombol Read More muncul dengan sempurna.',
        priceAmount: 89000,
        priceCurrency: 'IDR',
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          child: const SearchBookDetailPage(book: searchResult),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol Read More berupa TertiaryButton
      final readMoreFinder = find.widgetWithText(TertiaryButton, 'Read More');
      expect(readMoreFinder, findsOneWidget);

      // Verifikasi target sentuh >= 44 px
      final buttonSize = tester.getSize(readMoreFinder);
      expect(buttonSize.height, greaterThanOrEqualTo(44.0));
      expect(buttonSize.width, greaterThanOrEqualTo(44.0));

      // Duplikasi penerbit di card harga tidak muncul lagi (hanya muncul di metadata)
      // "Penerbit: Bentang Pustaka" tidak boleh ada, yang ada adalah metadata item "Bentang Pustaka"
      expect(find.text('Penerbit: Bentang Pustaka'), findsNothing);
      expect(find.text('Bentang Pustaka'), findsOneWidget);
    });

    testWidgets('3. CollectionBookDetailPage: Read More TertiaryButton >= 44 dan Bintang Rating area sentuh 44x44', (tester) async {
      final libraryRepo = FakeLibraryRepository();
      final dummyBook = UserBook(
        id: 'book-1',
        userId: 'test_user',
        googleBooksId: 'gb-1',
        title: 'Bumi Manusia',
        authors: 'Pramoedya Ananta Toer',
        listType: ListType.collection,
        status: BookStatus.finished,
        synopsis: 'Sebuah sinopsis yang sangat panjang untuk memicu tombol Read More dan Read Less pada kartu sinopsis halaman detail buku StoryLoka. Teks ini melebihi dua ratus karakter agar kondisional teks ekspansi aktif.',
        pageCount: 535,
        rating: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(dummyBook);

      await tester.pumpWidget(
        _buildTestWrapper(
          child: const CollectionBookDetailPage(id: 'book-1'),
          libraryRepo: libraryRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Read More TertiaryButton
      final readMoreFinder = find.widgetWithText(TertiaryButton, 'Read More');
      expect(readMoreFinder, findsOneWidget);
      final readMoreSize = tester.getSize(readMoreFinder);
      expect(readMoreSize.height, greaterThanOrEqualTo(44.0));

      // Bintang rating: harus ada 5 semantics label "Beri rating X bintang" dan ukuran touch target minimal 44x44
      final star1Semantics = find.bySemanticsLabel('Beri rating 1 bintang');
      expect(star1Semantics, findsOneWidget);

      final star1Size = tester.getSize(star1Semantics);
      expect(star1Size.width, greaterThanOrEqualTo(44.0));
      expect(star1Size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('4. WishlistBookDetailPage: TertiaryButton Read More minHeight >= 44', (tester) async {
      final libraryRepo = FakeLibraryRepository();
      final dummyBook = UserBook(
        id: 'wish-1',
        userId: 'test_user',
        googleBooksId: 'gb-2',
        title: 'Cantik Itu Luka',
        authors: 'Eka Kurniawan',
        listType: ListType.wishlist,
        status: BookStatus.notStarted,
        synopsis: 'Sebuah sinopsis yang sangat panjang untuk memicu tombol Read More dan Read Less pada kartu sinopsis halaman detail buku StoryLoka. Teks ini melebihi dua ratus karakter agar kondisional teks ekspansi aktif.',
        pageCount: 480,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(dummyBook);

      await tester.pumpWidget(
        _buildTestWrapper(
          child: const WishlistBookDetailPage(id: 'wish-1'),
          libraryRepo: libraryRepo,
        ),
      );
      await tester.pumpAndSettle();

      final readMoreFinder = find.widgetWithText(TertiaryButton, 'Read More');
      expect(readMoreFinder, findsOneWidget);
      final readMoreSize = tester.getSize(readMoreFinder);
      expect(readMoreSize.height, greaterThanOrEqualTo(44.0));
    });
  });
}
