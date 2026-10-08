/// Fixed numbers that describe the game itself.
///
/// Nothing here is a design decision that should be tuned per level - those
/// live in `DifficultyProfile`. These are the invariants of the rule set.
abstract final class GameConstants {
  const GameConstants._();

  /// Default board size (portrait, one-handed play).
  static const int defaultRows = 12;
  static const int defaultColumns = 6;

  /// Levels per chapter.
  static const int levelsPerChapter = 25;

  /// Total levels in the shipped catalogue.
  static const int totalLevels = 500;

  /// Highest value the art and audio systems have a treatment for.
  static const int maxRenderableValue = 8192;

  /// Score awarded for surviving a drop without merging.
  static const int dropScore = 0;

  /// Chain step at which the combo multiplier stops growing.
  static const int maxComboStep = 9;

  /// Interstitial cadence: show one every N completed levels.
  static const int interstitialEveryNLevels = 4;

  /// Starting coin balance for a new player.
  static const int startingCoins = 150;

  /// Boosters a new player starts with.
  static const Map<String, int> startingBoosters = <String, int>{
    'undo': 3,
    'hammer': 1,
    'shuffle': 1,
  };

  /// Coin prices of the in-run booster shop.
  static const Map<String, int> boosterPrices = <String, int>{
    'undo': 60,
    'hammer': 90,
    'shuffle': 120,
    'wildcard': 150,
    'upgrade': 200,
  };

  /// Seconds of inactivity before the session is auto-saved and paused.
  static const int autoSaveSeconds = 5;
}
