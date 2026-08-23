import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'couture_palette.dart';

/// App-wide Material 3 theme. Poppins for all text.
///
/// This is what dialogs, date pickers, text fields and chips inherit — every
/// surface a screen does NOT paint itself. It reads [CouturePalette] directly
/// now that every screen has moved onto it; `AppColors` was retired with the
/// last one, exactly as the rollout note in CLAUDE.md said it would be.
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Brightness brightness) {
    final Color base = brightness == Brightness.light
        ? CouturePalette.ink
        : CouturePalette.inkDark;
    final Color muted = brightness == Brightness.light
        ? CouturePalette.inkSoft
        : CouturePalette.inkSoftDark;

    return GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: base,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: base,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: base,
      ),
    );
  }

  /// [brand] is the shop's per-instance colour (item 9); when null the house
  /// Deep Teal is used. It drives the seed, buttons, focus ring and nav accent
  /// so each resold instance feels bespoke without touching every widget.
  static ThemeData light({Color? brand}) {
    final Color primary = brand ?? CouturePalette.indigo;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: CouturePalette.terracotta,
      surface: CouturePalette.card,
      error: CouturePalette.terracottaDeep,
      // Material tints its "container" roles from the seed, which turned a
      // selected segmented button lavender. These are the app's own washes.
      primaryContainer: CouturePalette.indigoWash,
      onPrimaryContainer: CouturePalette.indigo,
      secondaryContainer: CouturePalette.indigoWash,
      onSecondaryContainer: CouturePalette.indigo,
      surfaceContainerHighest: CouturePalette.quiet,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      dividerColor: CouturePalette.line,
      scaffoldBackgroundColor: CouturePalette.paper,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: CouturePalette.card,
        foregroundColor: CouturePalette.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CouturePalette.ink,
        ),
        iconTheme: const IconThemeData(color: CouturePalette.ink),
      ),
      cardTheme: CardThemeData(
        color: CouturePalette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CouturePalette.line),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fill: CouturePalette.card,
        border: CouturePalette.line,
        hint: CouturePalette.inkFaint,
        focus: primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CouturePalette.quiet,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: CouturePalette.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CouturePalette.line),
        ),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
        color: CouturePalette.line,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CouturePalette.card,
        selectedItemColor: primary,
        unselectedItemColor: CouturePalette.inkFaint,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark({Color? brand}) {
    final Color primary = brand ?? CouturePalette.indigoLight;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: brand ?? CouturePalette.indigo,
      brightness: Brightness.dark,
      primaryContainer: CouturePalette.indigoWashDark,
      onPrimaryContainer: CouturePalette.indigoLight,
      secondaryContainer: CouturePalette.indigoWashDark,
      onSecondaryContainer: CouturePalette.indigoLight,
      surfaceContainerHighest: CouturePalette.quietDark,
      primary: primary,
      secondary: CouturePalette.terracotta,
      surface: CouturePalette.cardDark,
      error: CouturePalette.terracottaDeep,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        onSurface: CouturePalette.inkDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),
      brightness: Brightness.dark,
      dividerColor: CouturePalette.lineDark,
      scaffoldBackgroundColor: CouturePalette.paperDark,
      iconTheme: const IconThemeData(color: CouturePalette.inkDark),
      primaryIconTheme: const IconThemeData(color: CouturePalette.inkDark),
      textTheme: _textTheme(Brightness.dark),
      listTileTheme: ListTileThemeData(
        iconColor: CouturePalette.inkDark,
        textColor: CouturePalette.inkDark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: CouturePalette.inkDark,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: CouturePalette.inkSoftDark,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CouturePalette.cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CouturePalette.inkDark,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: CouturePalette.inkSoftDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CouturePalette.quietDark,
        contentTextStyle: GoogleFonts.poppins(
          color: CouturePalette.inkDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CouturePalette.cardDark,
        foregroundColor: CouturePalette.inkDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CouturePalette.inkDark,
        ),
        iconTheme: const IconThemeData(color: CouturePalette.inkDark),
        actionsIconTheme: const IconThemeData(color: CouturePalette.inkDark),
      ),
      cardTheme: CardThemeData(
        color: CouturePalette.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CouturePalette.lineDark),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fill: CouturePalette.cardDark,
        border: CouturePalette.lineDark,
        hint: CouturePalette.inkSoftDark.withValues(alpha: 0.6),
        focus: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          side: const BorderSide(color: Colors.white, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CouturePalette.quietDark,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: CouturePalette.inkDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CouturePalette.lineDark),
        ),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CouturePalette.cardDark,
        selectedItemColor: Colors.white,
        unselectedItemColor: CouturePalette.inkSoftDark,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: CouturePalette.lineDark,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fill,
    required Color border,
    required Color hint,
    Color focus = CouturePalette.indigo,
  }) {
    OutlineInputBorder buildBorder(Color color, {double width = 1.2}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: hint,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: hint,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: buildBorder(border),
      enabledBorder: buildBorder(border),
      focusedBorder: buildBorder(focus, width: 1.6),
      errorBorder: buildBorder(CouturePalette.terracottaDeep),
      focusedErrorBorder:
          buildBorder(CouturePalette.terracottaDeep, width: 1.6),
    );
  }
}
