import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _lightSeed = Color(0xFF0B3D2E);
const _accent = Color(0xFF16C784);
const _amber = Color(0xFFF5A623);
const _lightBg = Color(0xFFFAFAF7);
const _darkBg = Color(0xFF0E1513);
const _lightSurface = Color(0xFFFFFFFF);
const _darkSurface = Color(0xFF1A2420);
const _lightText = Color(0xFF12211C);
const _darkText = Color(0xFFE8F0EC);

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: _lightSeed, brightness: Brightness.light), useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      cardColor: _lightSurface,
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: _lightText),
      appBarTheme: const AppBarTheme(backgroundColor: _lightSurface, foregroundColor: _lightText, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: _lightSeed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
      cardTheme: CardThemeData(color: _lightSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: _lightBg, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: _darkBg, brightness: Brightness.dark), useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      cardColor: _darkSurface,
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: _darkText),
      appBarTheme: const AppBarTheme(backgroundColor: _darkSurface, foregroundColor: _darkText, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: _darkBg, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
      cardTheme: CardThemeData(color: _darkSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Color(0xFF12211C), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
    );
  }
}

TextStyle counterStyle(BuildContext c, {Color? color}) => TextStyle(fontFamily: 'Manrope', fontSize: 40, fontWeight: FontWeight.w800, color: color ?? _amber, fontFeatures: const [FontFeature.tabularFigures()]);
