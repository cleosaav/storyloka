import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/models/reading_session.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/profile/edit_profile_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:storyloka/features/profile/reading_ledger_page.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase A6: ThemeController — PRD §4.7 & §7.8', () {
    test('ThemeController dapat mengatur Light, Dark, dan Auto (System)', () {
      final controller = ThemeController();

      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isDark, isFalse);
      expect(controller.isAuto, isFalse);

      controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDark, isTrue);
      expect(controller.isAuto, isFalse);

      controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, ThemeMode.system);
      expect(controller.isDark, isFalse);
      expect(controller.isAuto, isTrue);

      controller.toggleTheme();
      expect(controller.themeMode, ThemeMode.light);
    });
  });

  group('Fase A6: AuthController updateProfile — PRD §7.8', () {
    test('updateProfile memperbarui nama, bio, avatar dan menyimpan ke session', () async {
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );

      // Login dulu
      await authController.login('reader@storyloka.app', 'password123');
      expect(authController.currentUser, isNotNull);

      await authController.updateProfile(
        name: 'Siti Pembaca',
        bio: 'Pencinta fiksi sejarah dan novel klasik.',
        avatarUrl: '/path/to/avatar.jpg',
      );

      expect(authController.currentUser!.name, 'Siti Pembaca');
      expect(authController.currentUser!.bio, 'Pencinta fiksi sejarah dan novel klasik.');
      expect(authController.currentUser!.avatarUrl, '/path/to/avatar.jpg');
    });
  });

  group('Fase A6: ProfilePage Widget Tests — PRD §7.8', () {
    testWidgets('Menampilkan Header pengguna, Reading Summary, dan switch pengaturan',
        (tester) async {
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final demoControls = DemoControls();
      final themeController = ThemeController();
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: demoControls,
      );
      final libraryRepo = FakeLibraryRepository();
      final readingRepo = FakeReadingRepository();
      final profileRepo = FakeProfileRepository(authRepo);

      await authController.login('test@storyloka.app', 'password123');
      await authController.updateProfile(
        name: 'Budi Santoso',
        bio: 'Membaca membuka jendela dunia.',
      );

      final dummyBook = UserBook(
        id: 'book-1',
        userId: authController.currentUser!.id,
        googleBooksId: 'gb-1',
        title: 'Bumi Manusia',
        authors: 'Pramoedya Ananta Toer',
        pageCount: 535,
        listType: ListType.collection,
        status: BookStatus.finished,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(dummyBook);

      await readingRepo.saveSession(ReadingSession(
        id: 's-1',
        userId: authController.currentUser!.id,
        userBookId: dummyBook.id,
        startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        endedAt: DateTime.now(),
        durationSeconds: 2700,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SecureSessionStore>.value(value: sessionStore),
            ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ChangeNotifierProvider<DemoControls>.value(value: demoControls),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            Provider<LibraryRepository>.value(value: libraryRepo),
            Provider<ReadingRepository>.value(value: readingRepo),
            Provider<ProfileRepository>.value(value: profileRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi header
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('test@storyloka.app'), findsOneWidget);
      expect(find.text('Membaca membuka jendela dunia.'), findsOneWidget);
      expect(find.text('Edit Profil'), findsOneWidget);

      // Verifikasi ringkasan buku
      expect(find.text('Ringkasan Bacaan'), findsOneWidget);
      expect(find.textContaining('di koleksi •'), findsOneWidget);
      expect(find.textContaining('Total waktu membaca:'), findsOneWidget);

      // Verifikasi card Reading Ledger
      expect(find.text('Reading Ledger'), findsOneWidget);

      // Verifikasi switch dan pilihan tema Light / Dark / Auto
      expect(find.text('Tampilan'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);

      // Tap opsi Dark
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Verifikasi switch biometrik & notifikasi
      expect(find.text('Kunci Biometrik (Fingerprint / Face ID)'), findsOneWidget);
      expect(find.text('Pengingat Membaca Harian'), findsOneWidget);
      expect(find.text('Notifikasi Stopwatch Sesi'), findsOneWidget);

      // Verifikasi tombol Logout
      expect(find.text('Keluar dari Akun (Logout)'), findsOneWidget);
    });

    testWidgets('Dialog konfirmasi logout memiliki aksi Batal dan Keluar', (tester) async {
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final demoControls = DemoControls();
      final themeController = ThemeController();
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: demoControls,
      );
      final libraryRepo = FakeLibraryRepository();
      final readingRepo = FakeReadingRepository();
      final profileRepo = FakeProfileRepository(authRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SecureSessionStore>.value(value: sessionStore),
            ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ChangeNotifierProvider<DemoControls>.value(value: demoControls),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            Provider<LibraryRepository>.value(value: libraryRepo),
            Provider<ReadingRepository>.value(value: readingRepo),
            Provider<ProfileRepository>.value(value: profileRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll ke tombol logout dan tap
      final logoutFinder = find.text('Keluar dari Akun (Logout)');
      await tester.ensureVisible(logoutFinder);
      await tester.pumpAndSettle();
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      // Verifikasi dialog muncul
      expect(find.text('Konfirmasi Keluar'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);

      // Tap Batal menutup dialog
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Keluar'), findsNothing);
    });
  });

  group('Fase A6: ReadingLedgerPage Widget Tests — PRD §10.2', () {
    testWidgets('Menampilkan Header penjelas, tombol Verify Ledger, dan blok genesis',
        (tester) async {
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );
      await authController.login('ledger@storyloka.app', 'password123');

      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);
      await ledgerService.ensureGenesisBlock(authController.currentUser!.id);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            Provider<LedgerRepository>.value(value: ledgerRepo),
            Provider<LedgerService>.value(value: ledgerService),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ReadingLedgerPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi penjelas faktual
      expect(find.text('Reading Ledger'), findsOneWidget);
      expect(find.text('Rantai Catatan Bacaan'), findsOneWidget);
      expect(find.textContaining('Setiap buku yang selesai kamu baca'), findsOneWidget);

      // Verifikasi tombol Verify Ledger
      expect(find.text('Verify Ledger'), findsOneWidget);

      // Verifikasi blok Genesis
      expect(find.text('Blok #0 (Genesis)'), findsOneWidget);
      expect(find.text('StoryLoka genesis'), findsOneWidget);

      // Tap tombol Verify Ledger
      await tester.tap(find.text('Verify Ledger'));
      await tester.pumpAndSettle();

      // Verifikasi hasil tampil dengan IKON + TEKS
      expect(find.text('Rantai Utuh & Valid'), findsOneWidget);
      expect(find.textContaining('terverifikasi utuh'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });
  });

  group('Fase A6: EditProfilePage Widget Tests — PRD §7.8', () {
    testWidgets('Validasi nama wajib dan simpan perubahan profil', (tester) async {
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );
      final profileRepo = FakeProfileRepository(authRepo);
      await authController.login('edit@storyloka.app', 'password123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            Provider<ProfileRepository>.value(value: profileRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: EditProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Profil'), findsOneWidget);
      expect(find.text('Ganti Foto'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);

      // Kosongkan nama dan simpan -> muncul error validasi
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, '');

      final saveButton = find.text('Simpan Perubahan');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);

      // Isi nama baru dan bio
      await tester.enterText(nameField, 'Nama Pengguna Baru');
      final bioField = find.byType(TextField).at(1);
      await tester.enterText(bioField, 'Bio baru yang keren.');

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(authController.currentUser!.name, 'Nama Pengguna Baru');
      expect(authController.currentUser!.bio, 'Bio baru yang keren.');
    });
  });
}
