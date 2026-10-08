/// Small, fast, fully deterministic pseudo random number generator.
///
/// `dart:math`'s [Random] is *not* guaranteed to produce the same sequence
/// across platforms or SDK versions, and this game needs byte-identical
/// sequences for:
///
///  * reproducible unit tests,
///  * the daily challenge (identical puzzle for every player),
///  * the level simulator (stable balance numbers).
///
/// A 32-bit xorshift keeps the implementation dependency-free, portable to
/// the web (where Dart integers are IEEE-754 doubles) and cheap enough to call
/// thousands of times per frame-free simulation.
class Rng {
  Rng([int seed = 1]) : _state = _sanitize(seed);

  static const int _mask32 = 0xFFFFFFFF;

  /// xorshift32 rejects a zero state because it is a fixed point.
  static int _sanitize(int seed) {
    final s = seed & _mask32;
    return s == 0 ? 0x9E3779B9 : s;
  }

  int _state;

  int get state => _state;

  /// Derives a new generator from this one without disturbing its sequence.
  Rng fork([int salt = 0]) => Rng((_state ^ (salt * 0x85EBCA6B)) & _mask32);

  /// Uniform 32-bit unsigned integer.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask32;
    x ^= x >> 17;
    x ^= (x << 5) & _mask32;
    _state = x & _mask32;
    return _state;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform integer in `[0, max)`.
  int nextIntBelow(int max) {
    assert(max > 0, 'max must be positive');
    if (max <= 0) return 0;
    return (nextDouble() * max).floor().clamp(0, max - 1);
  }

  /// Uniform integer in `[min, max]` inclusive.
  int nextIntInRange(int min, int max) {
    if (max <= min) return min;
    return min + nextIntBelow(max - min + 1);
  }

  /// `true` with probability [probability] (0..1).
  bool nextBool([double probability = 0.5]) => nextDouble() < probability;

  /// Picks one element of [items] uniformly. Returns `null` for empty lists.
  T? pick<T>(List<T> items) {
    if (items.isEmpty) return null;
    return items[nextIntBelow(items.length)];
  }

  /// Picks one element of [items] uniformly. Returns `null` for empty lists.
  T? pick<T>(List<T> items) {
    if (items.isEmpty) return null;
    return items[nextIntBelow(items.length)];
  }

  /// In-place Fisher-Yates shuffle.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextIntBelow(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// Weighted pick. [weights] must have the same length as [items]; every
  /// weight must be `>= 0` and at least one must be `> 0`.
  ///
  /// Returns `null` when the selection is degenerate so callers can fall back
  /// to a safe default instead of throwing during gameplay.
  static int weightedIndex(List<double> weights, double roll) {
    if (weights.isEmpty) return -1;
    var total = 0.0;
    for (final w in weights) {
      if (w < 0) return -1;
      total += w;
    }
    if (total <= 0) return -1;
    var target = roll.clamp(0.0, 0.999999) * total;
    for (var i = 0; i < weights.length; i++) {
      target -= weights[i];
      if (target < 0) return i;
    }
    return weights.length - 1;
  }
}
