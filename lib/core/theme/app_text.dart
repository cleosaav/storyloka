import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens — PRD §4.3, design-system.md §3.
/// Fraunces SemiBold: headings, judul buku, angka besar.
/// DM Sans: body, tombol, metadata, caption, label, navigasi.
class AppText {
  AppText._();

  // ─── Fraunces (heading / display) ───

  /// Page heading — 30
  static TextStyle pageHeading({Color? color}) => GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  /// Judul buku detail — 24
  static TextStyle bookTitle({Color? color}) => GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color,
      );

  /// Section heading — 20
  static TextStyle sectionHeading({Color? color}) => GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  /// Card heading — 18
  static TextStyle cardHeading({Color? color}) => GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  /// Stopwatch / angka besar — 48–80
  static TextStyle displayLarge({Color? color, double fontSize = 64}) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: color,
      );

  /// Angka display medium (36–40) untuk skor besar atau hasil konversi nilai.
  static TextStyle displayMedium({Color? color, double fontSize = 36}) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  // ─── DM Sans (body / controls) ───

  /// Body 16 Regular
  static TextStyle body({Color? color}) => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  /// Body Bold 16 Medium
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      );

  /// Tombol 14–16 Medium
  static TextStyle button({Color? color, double fontSize = 14}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color,
      );

  /// Metadata 14 Regular
  static TextStyle metadata({Color? color}) => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// Caption 12 Medium
  static TextStyle caption({Color? color}) => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color,
      );

  // ─── Grid & Code Tokens ───

  /// Judul buku di kartu grid pustaka — Fraunces 12 SemiBold (design-system.md §3)
  static TextStyle gridBookTitle({Color? color}) => GoogleFonts.fraunces(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color,
      );

  /// Teks monospace / hash kode (PRD §10.2) — minimum 12 px
  static TextStyle code({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.4,
        color: color,
      );
}
