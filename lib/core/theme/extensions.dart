import 'package:flutter/material.dart';

/// Theme extensions for custom app properties
extension PlayifyThemeExtension on ThemeData {
  // Add custom theme extensions here
  // Example:
  // PlayifyColors? get playifyColors =>
  //     extension<PlayifyColors>()?.data;
}

/// Custom theme extension for app-specific colors
@immutable
class PlayifyColorsExtension extends ThemeExtension<PlayifyColorsExtension> {
  const PlayifyColorsExtension({
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color info;

  @override
  ThemeExtension<PlayifyColorsExtension> copyWith({
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return PlayifyColorsExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  ThemeExtension<PlayifyColorsExtension> lerp(
    covariant ThemeExtension<PlayifyColorsExtension>? other,
    double t,
  ) {
    if (other is! PlayifyColorsExtension) return this;
    return PlayifyColorsExtension(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}