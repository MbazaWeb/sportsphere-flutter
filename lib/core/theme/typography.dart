import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography — Inter via google_fonts (replaces Roboto)
class AppTypography {
  const AppTypography._();

  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  static TextTheme get textTheme =>
      GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w800,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.4,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8,
  );
}
