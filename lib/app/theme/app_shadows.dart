import 'package:flutter/material.dart';

/// Shared shadow presets.
abstract final class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 28,
      offset: Offset(0, 14),
    ),
  ];

  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(
      color: Color(0x66FFB020),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];
}
