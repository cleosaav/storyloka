import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';

void main() {
  group('Fase A0 — Fondasi & DemoControls Unit Test', () {
    test('DemoControls toggles states correctly', () {
      final controller = DemoControls();
      expect(controller.isDataEmpty, false);
      expect(controller.simulateNetworkError, false);
      expect(controller.simulateSlowLatency, false);
      expect(controller.bypassBiometric, false);

      controller.toggleDataEmpty(true);
      expect(controller.isDataEmpty, true);

      controller.toggleNetworkError(true);
      expect(controller.simulateNetworkError, true);

      controller.toggleSlowLatency(true);
      expect(controller.simulateSlowLatency, true);

      controller.toggleBypassBiometric(true);
      expect(controller.bypassBiometric, true);

      controller.reset();
      expect(controller.isDataEmpty, false);
      expect(controller.simulateNetworkError, false);
      expect(controller.simulateSlowLatency, false);
      expect(controller.bypassBiometric, false);
    });

    test('ThemeController toggles light and dark mode', () {
      final theme = ThemeController();
      expect(theme.isDark, false);
      expect(theme.themeMode, ThemeMode.light);

      theme.toggleTheme();
      expect(theme.isDark, true);
      expect(theme.themeMode, ThemeMode.dark);

      theme.setThemeMode(ThemeMode.light);
      expect(theme.isDark, false);
      expect(theme.themeMode, ThemeMode.light);
    });

    test('FakeLibraryRepository provides and clears demo data', () async {
      final repo = FakeLibraryRepository();

      // Normal state with demo data
      final books = await repo.getBooks();
      expect(books.isNotEmpty, true);

      // Toggle empty data
      repo.setUseDemoData(false);
      final emptyBooks = await repo.getBooks();
      expect(emptyBooks.isEmpty, true);

      // Re-enable demo data
      repo.setUseDemoData(true);
      final restoredBooks = await repo.getBooks();
      expect(restoredBooks.isNotEmpty, true);
    });
  });
}
