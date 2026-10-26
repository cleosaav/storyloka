import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/theme/app_colors.dart';
import 'package:storyloka/core/theme/app_text.dart';

double _contrastRatio(Color c1, Color c2) {
  final l1 = c1.computeLuminance();
  final l2 = c2.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Fase U4c: Token Dinamis, Tipografi & Dark Mode Contrast', () {
    testWidgets('1. AppColors ThemeContextX dan helpers meresolusi warna sesuai kecerahan tema', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.light(),
            child: Builder(
              builder: (context) {
                expect(context.isDark, isFalse);
                expect(context.primaryColor, AppColors.deepTeal);
                expect(context.inkColor, AppColors.ink);
                expect(context.surfaceColor, AppColors.white);
                expect(context.backgroundColor, AppColors.warmIvory);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.dark(),
            child: Builder(
              builder: (context) {
                expect(context.isDark, isTrue);
                expect(context.primaryColor, AppColors.primaryDark);
                expect(context.inkColor, AppColors.inkDark);
                expect(context.surfaceColor, AppColors.surfaceDark);
                expect(context.backgroundColor, AppColors.bgDark);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    test('2. Token AppText.gridBookTitle memakai font Fraunces dan ukuran >= 12 px', () {
      final style = AppText.gridBookTitle();
      expect(style.fontFamily, contains('Fraunces'));
      expect(style.fontSize, greaterThanOrEqualTo(12.0));
      expect(style.fontWeight, FontWeight.w600);
    });

    test('3. Token AppText.code memakai JetBrains Mono dan ukuran >= 12 px', () {
      final style = AppText.code();
      expect(style.fontFamily, contains('JetBrainsMono'));
      expect(style.fontSize, greaterThanOrEqualTo(12.0));
    });

    test('4. Rasio kontras teks dark mode (WCAG AA >= 4.5:1)', () {
      // inkDark pada bgDark
      final ratioBg = _contrastRatio(AppColors.inkDark, AppColors.bgDark);
      expect(ratioBg, greaterThanOrEqualTo(4.5),
          reason: 'inkDark ($ratioBg:1) harus memenuhi WCAG AA terhadap bgDark');

      // inkDark pada surfaceDark
      final ratioSurface = _contrastRatio(AppColors.inkDark, AppColors.surfaceDark);
      expect(ratioSurface, greaterThanOrEqualTo(4.5),
          reason: 'inkDark ($ratioSurface:1) harus memenuhi WCAG AA terhadap surfaceDark');

      // primaryDark pada surfaceDark (UI elements / graphical objects >= 3:1)
      final ratioPrimarySurface = _contrastRatio(AppColors.primaryDark, AppColors.surfaceDark);
      expect(ratioPrimarySurface, greaterThanOrEqualTo(3.0),
          reason: 'primaryDark ($ratioPrimarySurface:1) harus terbaca jelas pada surfaceDark');
    });
  });
}
