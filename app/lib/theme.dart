import 'package:flutter/material.dart';

class ShmTheme {
  static const Color primary = Color(0xFF1565C0);       // Dunkelblau — Deutschland
  static const Color secondary = Color(0xFFFFCC00);     // Gelb — Deutschland
  static const Color accent = Color(0xFFD32F2F);        // Rot — Deutschland
  static const Color yes = Color(0xFF388E3C);           // Grün für "Ja"
  static const Color no = Color(0xFFD32F2F);            // Rot für "Nein"
  static const Color noQuorum = Color(0xFFBDBDBD);      // Grau — kein Quorum

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: const CardTheme(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}
