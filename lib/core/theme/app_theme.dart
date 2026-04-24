import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class AppTheme {
  // Brand Colors as requested
  static const Color primaryBlue = Color(0xFF4F7CFF);
  static const Color accentPurple = Color(0xFF7A5CFF);
  static const Color success = Color(0xFF16C784);
  static const Color danger = Color(0xFFFF5A5F);
  
  // Background & Surfaces
  static const Color darkBackground = Color(0xFF071120);
  static const Color darkCard = Color(0xFF121E32);
  static const Color textLight = Color(0xFFF8FAFC);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentPurple,
        surface: darkCard,
        error: danger,
        onSurface: textLight,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textLight, letterSpacing: -0.5),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme; // Force premium dark mode mapping
}
