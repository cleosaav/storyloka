import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/app_card.dart';
import 'package:storyloka/core/widgets/app_dropdown.dart';
import 'package:storyloka/core/services/time_converter_service.dart';
import 'package:storyloka/data/repositories/currency_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';
import 'package:storyloka/features/tools/time_converter_page.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(360, 640),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      padding: EdgeInsets.zero,
    ),
    child: MultiProvider(
      providers: [
        Provider<CurrencyRepository>(
          create: (_) => FakeCurrencyRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Fase U3: AppDropdown & Input Tests', () {
    testWidgets('1. AppDropdown terbuka DI BAWAH field (posisi atas menu >= posisi bawah field)', (tester) async {
      String selected = 'IDR';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 100, left: 24, right: 24),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AppDropdown<String>(
                    label: 'Pilih Mata Uang',
                    value: selected,
                    items: const [
                      AppDropdownItem(value: 'IDR', label: 'IDR · Rupiah'),
                      AppDropdownItem(value: 'USD', label: 'USD · Dolar AS'),
                      AppDropdownItem(value: 'EUR', label: 'EUR · Euro'),
                    ],
                    onChanged: (v) => setState(() => selected = v!),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Temukan TextField pemicu dari DropdownMenu
      final fieldFinder = find.byType(TextField);
      expect(fieldFinder, findsOneWidget);
      final fieldBottomY = tester.getBottomLeft(fieldFinder).dy;

      // Buka dropdown dengan mengetuk ikon trailing atau textfield
      await tester.tap(fieldFinder);
      await tester.pumpAndSettle();

      // MenuItemButton yang muncul di dalam overlay menu
      final itemFinder = find.widgetWithText(MenuItemButton, 'USD · Dolar AS');
      expect(itemFinder, findsOneWidget);

      final menuTopY = tester.getTopLeft(itemFinder).dy;

      // Verifikasi kriteria: posisi atas menu dropdown >= posisi bawah field
      expect(menuTopY, greaterThanOrEqualTo(fieldBottomY - 1.0),
          reason: 'Menu dropdown harus terbuka di bawah field input (tidak menimpa)');
    });

    testWidgets('2. AppDropdown lebar menu sama dengan lebar field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AppDropdown<String>(
                  value: 'A',
                  items: const [
                    AppDropdownItem(value: 'A', label: 'Pilihan A'),
                    AppDropdownItem(value: 'B', label: 'Pilihan B'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownBox = tester.renderObject(find.byType(DropdownMenu<String>)) as RenderBox;
      expect(dropdownBox.size.width, equals(300.0));
    });

    testWidgets('3. TimeConverterPage menggunakan AppDropdown dan format tanggal lokal id_ID', (tester) async {
      await tester.pumpWidget(_buildTestApp(child: const TimeConverterPage()));
      await tester.pumpAndSettle();

      // Dropdown zona waktu berbasis AppDropdown
      expect(find.byType(AppDropdown<TimeZone>), findsOneWidget);

      // Kartu hasil menggunakan AppCard
      expect(find.byType(AppCard), findsWidgets);

      // Tanggal dalam kartu hasil memakai format bahasa Indonesia (bukan Thu/Mon dsb)
      // Tanggal mencakup hari berbahasa Indonesia seperti Sen/Sel/Rab/Kam/Jum/Sab/Min
      final indoDays = RegExp(r'(Sen|Sel|Rab|Kam|Jum|Sab|Min)');
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final hasIndoDate = textWidgets.any((t) => t.data != null && indoDays.hasMatch(t.data!));
      expect(hasIndoDate, isTrue, reason: 'Tanggal kartu hasil harus berformat locale Indonesia (id_ID)');

      // Verifikasi tidak ada label ganda seperti "UTC+7 (WIB)" pada baris WIB
      expect(find.text('UTC+7 (WIB)'), findsNothing);
    });

    testWidgets('4. TimeConverterPage _PickerChip memiliki target sentuh minimal 44 dan Semantics', (tester) async {
      await tester.pumpWidget(_buildTestApp(child: const TimeConverterPage()));
      await tester.pumpAndSettle();

      final semanticsChips = find.bySemanticsLabel(RegExp(r'Pilih (tanggal|waktu)'));
      expect(semanticsChips, findsNWidgets(2));

      // Verifikasi tinggi minimal >= 44
      for (final element in semanticsChips.evaluate()) {
        final box = element.renderObject as RenderBox;
        expect(box.size.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('5. TimeConverterPage bebas overflow pada layar 360 px dengan teks skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        child: const TimeConverterPage(),
        size: const Size(360, 640),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'TimeConverterPage bebas overflow pada teks skala 1.3');
    });

    testWidgets('6. CurrencyConverterPage menggunakan AppDropdown dan tombol swap berfungsi', (tester) async {
      await tester.pumpWidget(_buildTestApp(child: const CurrencyConverterPage()));
      await tester.pumpAndSettle();

      // Terdapat 2 AppDropdown untuk 'Dari' dan 'Ke'
      expect(find.byType(AppDropdown<String>), findsNWidgets(2));

      // Tekan tombol swap
      final swapButton = find.byTooltip('Tukar');
      expect(swapButton, findsOneWidget);
      await tester.tap(swapButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('7. CurrencyConverterPage bebas overflow pada layar 360 px dengan teks skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        child: const CurrencyConverterPage(),
        size: const Size(360, 640),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'CurrencyConverterPage bebas overflow pada teks skala 1.3');
    });
  });
}
