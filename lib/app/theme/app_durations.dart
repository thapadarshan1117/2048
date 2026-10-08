import 'package:flutter/material.dart';

/// Animation durations.
///
/// Every animation in the game uses one of these, so the whole product feels
/// like one system instead of a collection of tuned-by-eye durations.
abstract final class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration slower = Duration(milliseconds: 520);
  static const Duration celebration = Duration(milliseconds: 900);
}
