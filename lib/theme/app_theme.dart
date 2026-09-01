import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EpoCanvas Mail - Material 3 Design System
/// Mirrors the web app dark/light aesthetic.
class AppTheme {
  // ─── Brand Palette ───────────────────────────────────────────────────────
  static const Color blue = Color(0xFF4F8EF7);
  static const Color blueDark = Color(0xFF3B7DE8);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);

  // ─── Light surface tokens ────────────────────────────────────────────────
  static const Color lightBgBase = Color(0xFFF4F7FC);
  static const Color lightBgSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E9F2);
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightSecondaryText = Color(0xFF6B7280);

  // ─── Dark surface tokens ─────────────────────────────────────────────────
  static const Color darkBgBase = Color(0xFF0B0F19);
  static const Color darkBgSurface = Color(0xFF141414);
  static const Color darkBgElevated = Color(0xFF1E2235);
  static const Color darkBorder = Color(0xFF2D3148);
  static const Color darkOnSurface = Color(0xFFE8EAF6);
  static const Color darkSecondaryText = Color(0xFF94A3B8);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        primary: blue,
        bgBase: lightBgBase,
        bgSurface: lightBgSurface,
        bgElevated: lightBgBase,
        border: lightBorder,
        onSurface: lightOnSurface,
        secondaryText: lightSecondaryText,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        primary: blue,
        bgBase: darkBgBase,
        bgSurface: darkBgSurface,
        bgElevated: darkBgElevated,
        border: darkBorder,
        onSurface: darkOnSurface,
        secondaryText: darkSecondaryText,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color bgBase,
    required Color bgSurface,
    required Color bgElevated,
    required Color border,
    required Color onSurface,
    required Color secondaryText,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      bodyLarge: GoogleFonts.outfit(color: onSurface, fontSize: 15),
      bodyMedium: GoogleFonts.outfit(color: onSurface, fontSize: 14),
      bodySmall: GoogleFonts.outfit(color: secondaryText, fontSize: 12),
      titleMedium: GoogleFonts.outfit(color: onSurface, fontWeight: FontWeight.w600),
      labelLarge: GoogleFonts.outfit(color: onSurface, fontSize: 14, fontWeight: FontWeight.w500),
    );

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: green,
        onSecondary: Colors.white,
        error: red,
        onError: Colors.white,
        surface: bgSurface,
        onSurface: onSurface,
        surfaceContainerHighest: bgBase,
        outline: border,
      ),
      scaffoldBackgroundColor: bgBase,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgSurface,
        foregroundColor: onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      cardTheme: CardTheme(
        color: bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red),
        ),
        labelStyle: GoogleFonts.outfit(color: secondaryText),
        hintStyle: GoogleFonts.outfit(color: secondaryText.withOpacity(0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: GoogleFonts.outfit(fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: secondaryText,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.outfit(),
      ),
    );
  }

  // ─── Avatar color from seed string ──────────────────────────────────────
  static const _avatarColors = [
    Color(0xFF4F8EF7),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
  ];

  static Color avatarColor(String seed) {
    if (seed.isEmpty) return _avatarColors[0];
    return _avatarColors[seed.codeUnitAt(0) % _avatarColors.length];
  }

  static String initials(String name, {String fallback = '?'}) {
    if (name.isEmpty) return fallback;
    final parts = name.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
