import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale.
///
/// The game ships no font files: it uses the platform default, which keeps the
/// download small and lets the system render the player's language correctly.
abstract final class AppTypography {
  const AppTypography._();

  static const String? _fontFamily = null;

  static TextStyle get displayLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get headline => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get title => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodyStrong => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: AppColors.textPrimary,
      );

  static TextStyle get label => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textMuted,
      );

  /// Large bold numerals used on blocks and score popups.
  static TextStyle number(double size, {Color color = AppColors.textPrimary}) =>
      TextStyle(
        fontFamily: _fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: color,
      );
}
