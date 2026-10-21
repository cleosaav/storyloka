import 'package:flutter/material.dart';

/// StoryLoka color tokens — source of truth: PRD §4.1–4.2 + design-system.md §2.
/// Jangan tambah warna baru tanpa alasan; catat di DEVIATIONS.md jika perlu.
class AppColors {
  AppColors._();

  // ─── Light Theme ───
  static const Color warmIvory = Color(0xFFFAF6EF);
  static const Color deepTeal = Color(0xFF164E59);
  static const Color oceanTeal = Color(0xFF245C67);
  static const Color softApricot = Color(0xFFF5B65D);
  static const Color palePeach = Color(0xFFFBE9D7);
  static const Color sageGreen = Color(0xFFA8BDA8);
  static const Color ink = Color(0xFF26383A);
  static const Color mutedGray = Color(0xFF859395);
  static const Color white = Color(0xFFFFFFFF);
  static const Color borderNeutral = Color(0xFFE4E2DA);
  static const Color trackNeutral = Color(0xFFE3E7DF);
  static const Color error = Color(0xFFB54747);
  static const Color success = Color(0xFF3F7658);

  // ─── Dark Theme ───
  static const Color bgDark = Color(0xFF101819);
  static const Color surfaceDark = Color(0xFF1A2527);
  static const Color borderDark = Color(0xFF2C3B3D);
  static const Color inkDark = Color(0xFFF2EDE3);
  static const Color mutedDark = Color(0xFF8FA0A2);
  static const Color primaryDark = Color(0xFF2F7F8C);
  static const Color trackDark = Color(0xFF2A3638);

  // softApricot, sageGreen, error, success sama di dark mode.
}
