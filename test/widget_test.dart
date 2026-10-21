import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/providers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('StoryLokaApp smoke test — auth flow and bottom navigation 5 tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: buildAppProviders(),
        child: const StoryLokaApp(),
      ),
    );

    // Pump untuk menyelesaikan inisialisasi splash dan redirect ke /login
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verifikasi berada di halaman Login
    expect(find.text('Selamat Datang Kembali'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    // Tap tombol Login untuk masuk ke Home
    await tester.tap(find.text('Login'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Pastikan tab Home aktif dan menampilkan StoryLoka tanpa chip demo
    expect(find.text('StoryLoka'), findsOneWidget);
    expect(find.text('Mode demo'), findsNothing);

    // Tap tab Library
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);

    // Tap tab Tools
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    expect(find.text('Kesan & Pesan'), findsOneWidget);

    // Tap tab Profile
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Pilihan Tema'), findsOneWidget);
    expect(find.text('Kunci Biometrik (Fingerprint / Face ID)'), findsOneWidget);
  });
}
