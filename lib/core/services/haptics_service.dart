import 'package:flutter/services.dart';

/// What kind of physical feedback a moment deserves.
enum HapticKind {
  /// A block landed.
  drop,

  /// A merge completed.
  merge,

  /// A large merge (128+) or a long chain.
  bigMerge,

  /// A booster was used.
  booster,

  /// The level was won.
  levelComplete,

  /// The level was lost.
  levelFailed,
}

/// Optional haptic feedback.
///
/// Every call is a no-op when the player has turned vibration off.
abstract interface class HapticsService {
  void setEnabled(bool enabled);

  void trigger(HapticKind kind);
}

/// `HapticFeedback` backed implementation.
class FlutterHapticsService implements HapticsService {
  FlutterHapticsService({this.enabled = true});

  bool enabled;

  @override
  void setEnabled(bool value) => enabled = value;

  @override
  void trigger(HapticKind kind) {
    if (!enabled) return;
    switch (kind) {
      case HapticKind.drop:
        HapticFeedback.selectionClick();
      case HapticKind.merge:
        HapticFeedback.lightImpact();
      case HapticKind.bigMerge:
        HapticFeedback.heavyImpact();
      case HapticKind.booster:
        HapticFeedback.mediumImpact();
      case HapticKind.levelComplete:
        HapticFeedback.heavyImpact();
      case HapticKind.levelFailed:
        HapticFeedback.mediumImpact();
    }
  }
}

/// No-op implementation for tests.
class NoopHapticsService implements HapticsService {
  const NoopHapticsService();

  @override
  void setEnabled(bool enabled) {}

  @override
  void trigger(HapticKind kind) {}
}
