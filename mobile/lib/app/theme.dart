import 'package:flutter/material.dart';

class CoreHivesTheme {
  static const _seed = Color(0xFF0F6B4C); // deep green, finance-neutral
  static const cashInColor = Color(0xFF1E8E5A);
  static const cashOutColor = Color(0xFFC0392B);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        fontFamily: 'Inter',
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        fontFamily: 'Inter',
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );
}
