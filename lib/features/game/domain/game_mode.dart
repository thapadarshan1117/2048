/// Which rule-set a session is playing under.
enum GameMode {
  /// A numbered level with objectives and stars.
  level,

  /// Endless mode with no level limit and rising difficulty.
  infinite,

  /// The deterministic daily puzzle.
  dailyChallenge;

  String get analyticsName => name;

  static GameMode fromName(String? name) {
    for (final mode in GameMode.values) {
      if (mode.name == name) return mode;
    }
    return GameMode.level;
  }
}
