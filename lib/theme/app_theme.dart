import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4656F0)),
    );

    final titles = GoogleFonts.bebasNeueTextTheme(base.textTheme); // agressivo nos títulos
    final body    = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: body.copyWith(
        titleLarge: titles.titleLarge?.copyWith(fontSize: 28, letterSpacing: 0.4),
        titleMedium: titles.titleMedium?.copyWith(fontSize: 22, letterSpacing: 0.2),
        titleSmall: titles.titleSmall?.copyWith(fontSize: 18),
        headlineSmall: titles.headlineSmall?.copyWith(fontSize: 24),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
        centerTitle: false,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.dark,
      ),
    );

    final titles = GoogleFonts.bebasNeueTextTheme(base.textTheme);
    final body   = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black, // preto mesmo
      colorScheme: base.colorScheme.copyWith(
        surface: const Color(0xFF101214),
        surfaceContainer: const Color(0xFF0B0C0E),
        surfaceContainerHigh: const Color(0xFF13161A),
        outline: Colors.grey.shade600,
      ),
      textTheme: body.copyWith(
        titleLarge: titles.titleLarge?.copyWith(fontSize: 28, letterSpacing: 0.4),
        titleMedium: titles.titleMedium?.copyWith(fontSize: 22, letterSpacing: 0.2),
        titleSmall: titles.titleSmall?.copyWith(fontSize: 18),
        headlineSmall: titles.headlineSmall?.copyWith(fontSize: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF13161A),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1C2025),
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E1012),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,     // contraste no fundo preto
        foregroundColor: Colors.black,     // ícone/texto visíveis
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
