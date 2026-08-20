import 'package:flutter/material.dart';

/// Theme extensions for custom app properties
extension SportSphereThemeExtension on ThemeData {
  // Add custom theme extensions here
  // Example:
  // SportSphereColors? get sportSphereColors =>
  //     extension<SportSphereColors>()?.data;
}

/// Custom theme extension for app-specific colors
@immutable
class SportSphereColorsExtension extends ThemeExtension<SportSphereColorsExtension> {
  const SportSphereColorsExtension({
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color info;

  @override
  ThemeExtension<SportSphereColorsExtension> copyWith({
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return SportSphereColorsExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  ThemeExtension<SportSphereColorsExtension> lerp(
    covariant ThemeExtension<SportSphereColorsExtension>? other,
    double t,
  ) {
    if (other is! SportSphereColorsExtension) return this;
    return SportSphereColorsExtension(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}