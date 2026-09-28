import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color surfaceBg = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: surfaceBg,
    primaryColor: primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textDark, size: 22),
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 16.5,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    ),
  );
}