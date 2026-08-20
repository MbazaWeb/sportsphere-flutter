import 'package:flutter/material.dart';

/// SportSphere color palette
/// 
/// ⚠️ IMPORTANT: This file maintains the EXACT same visual colors
///    Only NAMES have been fixed to match actual color values
class SportSphereColors {
  // ============================================================
  // BACKGROUND & SURFACE COLORS
  // ============================================================
  
  /// Dark navy background
  static const Color background = Color(0xFF020A14);
  
  /// Dark surface layer 1
  static const Color surface = Color(0xFF061525);
  
  /// Dark surface layer 2
  static const Color surface2 = Color(0xFF091C30);

  // ============================================================
  // BRAND COLORS - MAINTAINED EXACTLY AS BEFORE
  // ============================================================
  
  /// Primary brand color - Gold (#F5C518)
  /// ⚠️ NOTE: This is GOLD, not blue. The app uses gold as primary brand color.
  static const Color primary = Color(0xFFF5C518);
  
  /// Brand gold - alias for primary
  static const Color gold = Color(0xFFF5C518);

  /// ⚠️ DEPRECATED: Use [primary] or [gold] instead
  /// This was incorrectly named "electricBlue" but was actually gold
  @Deprecated('Use primary or gold instead - this was never blue!')
  static const Color electricBlue = gold;
  
  /// ⚠️ DEPRECATED: Use [amber] instead
  /// This was incorrectly named "brightBlue" but was actually amber/yellow
  @Deprecated('Use amber instead - this was never blue!')
  static const Color brightBlue = Color(0xFFFFD54F);
  
  /// ⚠️ DEPRECATED: Use [goldLine] instead
  /// This was incorrectly named "lineBlue" but was actually gold
  @Deprecated('Use goldLine instead - this was never blue!')
  static const Color lineBlue = Color(0xFF8A7420);

  // ============================================================
  // CORRECTLY NAMED COLORS (SAME VISUAL VALUES)
  // ============================================================
  
  /// Bright amber/yellow accent
  static const Color amber = Color(0xFFFFD54F);
  
  /// Gold line color (darker gold for borders/dividers)
  static const Color goldLine = Color(0xFF8A7420);

  // ============================================================
  // SEMANTIC COLORS (NEW - REQUIRED FOR THEME SYSTEM)
  // ============================================================
  
  /// Primary color (gold) - used for buttons, highlights, etc.
  static const Color primaryColor = Color(0xFFF5C518);
  
  /// Secondary color (amber) - used for accents, badges
  static const Color secondaryColor = Color(0xFFFFD54F);
  
  /// Error/Danger color - red
  static const Color errorColor = Color(0xFFFF3B61);
  
  /// Success color - green
  static const Color successColor = Color(0xFF76D42B);
  
  /// Warning color - orange
  static const Color warningColor = Color(0xFFFF8A00);

  // ============================================================
  // TEXT COLORS (NEW - FOR PROPER THEME)
  // ============================================================
  
  /// Primary text color (white)
  static const Color textPrimary = Color(0xFFF7FAFF);
  
  /// Secondary/muted text color
  static const Color textMuted = Color(0xFF8FA3B8);
  
  /// Text on colored backgrounds
  static const Color textOnPrimary = Color(0xFF020A14); // Black text on gold

  // ============================================================
  // EXISTING COLORS - PRESERVED EXACTLY AS BEFORE
  // ============================================================
  
  /// White text color
  static const Color white = Color(0xFFF7FAFF);
  
  /// Muted text color
  static const Color muted = Color(0xFF8FA3B8);
  
  /// Danger/error color (red)
  static const Color danger = Color(0xFFFF3B61);
  
  /// Sport orange (warning/accent)
  static const Color sportOrange = Color(0xFFFF8A00);
  
  /// Sport green (success/accent)
  static const Color sportGreen = Color(0xFF76D42B);

  // ============================================================
  // CONVENIENCE - Keep old names for backward compatibility
  // ============================================================
  
  // These are aliases to maintain existing code compatibility
  // They will be removed in future versions - please migrate to new names
  static const Color get oldElectricBlue => primaryColor; // ⚠️ Was NEVER blue!
  static const Color get oldBrightBlue => secondaryColor; // ⚠️ Was NEVER blue!
  static const Color get oldLineBlue => goldLine;        // ⚠️ Was NEVER blue!
}

// ============================================================
// THEME EXTENSION - For Material Theme integration
// ============================================================

/// Extension to easily access SportSphere colors from Theme
extension SportSphereThemeColors on BuildContext {
  /// Get the SportSphere color palette
  SportSphereColors get sportSphereColors => const SportSphereColors();
  
  /// Primary brand color (gold)
  Color get primaryColor => SportSphereColors.primaryColor;
  
  /// Secondary color (amber)
  Color get secondaryColor => SportSphereColors.secondaryColor;
  
  /// Error color
  Color get errorColor => SportSphereColors.errorColor;
  
  /// Success color
  Color get successColor => SportSphereColors.successColor;
  
  /// Warning color
  Color get warningColor => SportSphereColors.warningColor;
}