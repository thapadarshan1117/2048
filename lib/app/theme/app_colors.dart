import 'package:flutter/material.dart';

/// The game's palette.
///
/// Every colour used by the UI or the renderer comes from here, so there are no
/// magic hex values scattered across the codebase.
abstract final class AppColors {
  const AppColors._();

  /// Background gradients - deep indigo to violet, so a bright playfield pops.
  static const Color backgroundTop = Color(0xFF1B1035);
  static const Color backgroundBottom = Color(0xFF2D1B4E);

  /// Surface / panel tones.
  static const Color surface = Color(0xFF3A2A63);
  static const Color surfaceElevated = Color(0xFF4A3780);
  static const Color surfaceDim = Color(0xFF241645);

  /// Primary accent (calls to action).
  static const Color primary = Color(0xFFFFB020);
  static const Color primaryDark = Color(0xFFC97A00);
  static const Color primaryLight = Color(0xFFFFD469);

  /// Secondary accent.
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color secondaryDark = Color(0xFF2A9D96);

  /// Semantic.
  static const Color success = Color(0xFF4CD964);
  static const Color danger = Color(0xFFFF5C5C);
  static const Color warning = Color(0xFFFFB020);
  static const Color info = Color(0xFF5AC8FA);

  /// Text.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC7BBE0);
  static const Color textMuted = Color(0xFF8E80AE);
  static const Color textOnAccent = Color(0xFF2A1B05);

  /// Board.
  static const Color boardBackground = Color(0xFF241645);
  static const Color cellBackground = Color(0xFF1C1233);
  static const Color cellBorder = Color(0xFF3A2A63);
  static const Color columnFeedback = Color(0x40FFB020);

  /// Coins and premium currency.
  static const Color coin = Color(0xFFFFC94D);
  static const Color coinDark = Color(0xFFD99A16);

  /// Block value ramp - value 2 through 8192.
  ///
  /// The ramp is shared between the UI, the Flame renderer and the level map,
  /// which is what keeps block colours consistent everywhere.
  static const List<Color> blockRamp = <Color>[
    Color(0xFF7EE8FA), // 2
    Color(0xFF4ECDC4), // 4
    Color(0xFF5AC8FA), // 8
    Color(0xFF5B8DEF), // 16
    Color(0xFF8E7CFF), // 32
    Color(0xFFB36BFF), // 64
    Color(0xFFE86BD1), // 128
    Color(0xFFFF7BA8), // 256
    Color(0xFFFF9F6B), // 512
    Color(0xFFFFB020), // 1024
    Color(0xFFFFD400), // 2048
    Color(0xFFB4FF39), // 4096
    Color(0xFF39FF88), // 8192
  ];

  /// Colour for a block of [value] (a power of two).
  static Color blockColor(int value) {
    var exponent = 0;
    while (value > 1) {
      value >>= 1;
      exponent++;
    }
    if (exponent < 2) return blockRamp.first;
    final index = exponent - 2;
    if (index >= blockRamp.length) return blockRamp.last;
    return blockRamp[index];
  }

  /// Gradient companion for [blockColor]; gives blocks their polished feel.
  static List<Color> blockGradient(int value) {
    final base = blockColor(value);
    return <Color>[
      Color.lerp(base, Colors.white, 0.18)!,
      base,
      Color.lerp(base, Colors.black, 0.18)!,
    ];
  }

  /// Stars on the level map.
  static const Color starFilled = Color(0xFFFFD400);
  static const Color starEmpty = Color(0xFF3A2A63);

  /// Chapter themes, one per chapter in the shipped catalogue.
  static const List<List<Color>> chapterThemes = <List<Color>>[
    <Color>[Color(0xFF7EE8FA), Color(0xFF4ECDC4)],
    <Color>[Color(0xFF5AC8FA), Color(0xFF5B8DEF)],
    <Color>[Color(0xFF8E7CFF), Color(0xFFB36BFF)],
    <Color>[Color(0xFFE86BD1), Color(0xFFFF7BA8)],
    <Color>[Color(0xFFFF9F6B), Color(0xFFFFB020)],
    <Color>[Color(0xFFFFD400), Color(0xFFB4FF39)],
    <Color>[Color(0xFF39FF88), Color(0xFF4ECDC4)],
    <Color>[Color(0xFF4ECDC4), Color(0xFF5AC8FA)],
    <Color>[Color(0xFF5B8DEF), Color(0xFF8E7CFF)],
    <Color>[Color(0xFFB36BFF), Color(0xFFE86BD1)],
    <Color>[Color(0xFFFF7BA8), Color(0xFFFF9F6B)],
    <Color>[Color(0xFFFFB020), Color(0xFFFFD400)],
    <Color>[Color(0xFFB4FF39), Color(0xFF39FF88)],
    <Color>[Color(0xFF39FF88), Color(0xFF7EE8FA)],
    <Color>[Color(0xFF7EE8FA), Color(0xFF5AC8FA)],
    <Color>[Color(0xFF5AC8FA), Color(0xFF8E7CFF)],
    <Color>[Color(0xFF8E7CFF), Color(0xFFE86BD1)],
    <Color>[Color(0xFFE86BD1), Color(0xFFFF9F6B)],
    <Color>[Color(0xFFFF9F6B), Color(0xFFFFB020)],
    <Color>[Color(0xFFFFD400), Color(0xFFB4FF39)],
  ];

  /// Theme colours for chapter [id] (1-based).
  static List<Color> chapterTheme(int id) =>
      chapterThemes[(id - 1) % chapterThemes.length];
}
