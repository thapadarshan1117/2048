import '../../levels/domain/difficulty_profile.dart';
import 'rng.dart';

/// Controlled block generator.
///
/// Generation is *never* fully random: values are drawn from a weighted table
/// supplied by the level's [DifficultyProfile], so difficulty is a data
/// decision rather than an accident. The generator is seeded, which makes it
/// reproducible for tests, for the daily challenge and for the simulator.
class BlockGenerator {
  BlockGenerator({
    required this.profile,
    int? seed,
    Rng? rng,
  }) : rng = rng ?? Rng(seed ?? 1) {
    _values = profile.spawnableValues;
    _weights = List<double>.unmodifiable(
      _values.map((v) => (profile.spawnWeights[v] ?? 0).toDouble()),
    );
  }

  final DifficultyProfile profile;
  final Rng rng;

  late final List<int> _values;
  late final List<double> _weights;

  /// Small look-ahead so the HUD can preview the *actual* next value without
  /// consuming it.
  final List<int> _queue = <int>[];

  /// Value the next drop will use. Peeking does not consume the value.
  int peek() {
    while (_queue.isEmpty) {
      _queue.add(_draw());
    }
    return _queue.first;
  }

  /// The two upcoming values - `[next, afterNext]`.
  List<int> peekAhead([int count = 2]) {
    while (_queue.length < count) {
      _queue.add(_draw());
    }
    return List<int>.unmodifiable(_queue.take(count));
  }

  /// Draws the next value.
  int next() {
    while (_queue.isEmpty) {
      _queue.add(_draw());
    }
    return _queue.removeAt(0);
  }

  int _draw() {
    if (profile.spawnProbability < 1.0 &&
        rng.nextDouble() > profile.spawnProbability) {
      return profile.minSpawnValue;
    }
    final index = Rng.weightedIndex(_weights, rng.nextDouble());
    if (index < 0 || index >= _values.length) return profile.minSpawnValue;
    return _values[index];
  }

  /// An independent generator with the same pending queue and RNG position.
  BlockGenerator clone() {
    final copy = BlockGenerator(profile: profile, rng: Rng(rng.state));
    copy._queue.addAll(_queue);
    return copy;
  }

  /// Draws several values at once (used by the simulator to avoid per-call
  /// overhead and by tests to assert distribution shape).
  List<int> nextBatch(int count) =>
      List<int>.generate(count, (_) => next());

  /// Observed share of each value over [sampleSize] draws - a cheap sanity
  /// check used by the level validator.
  Map<int, double> sampleDistribution(int sampleSize) {
    final counts = <int, int>{};
    for (var i = 0; i < sampleSize; i++) {
      final value = next();
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts.map((key, value) => MapEntry(key, value / sampleSize));
  }
}
