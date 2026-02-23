import 'package:flutter/material.dart';

class AppTheme {
  // Central color tokens for easy tuning
  static const Color actionRed = Color(0xFFFF8A80); // slightly lighter action/login red
  // Moderate background red (not too dark) for welcome / pages
  static const Color bgDeep = Color(0xFFB71C1C); // dark-but-normal background red

  static ThemeData lightTheme() {
    final base = ThemeData.light();
    return base.copyWith(
      // Login / action color: lighter red so it sits above the darker background
      primaryColor: actionRed,
      colorScheme: base.colorScheme.copyWith(primary: actionRed, secondary: Colors.deepOrangeAccent),
      scaffoldBackgroundColor: Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 14))),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: actionRed)),
  cardTheme: base.cardTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 8, color: Colors.white),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
