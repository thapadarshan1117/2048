/// Constraints applied to the board before the first drop.
///
/// Sealed so that new restrictions can be added without breaking saved data
/// or the level JSON format.
sealed class BoardRestriction {
  const BoardRestriction();

  const factory BoardRestriction.none() = NoRestriction;

  const factory BoardRestriction.restrictedColumns(Set<int> columns) =
      RestrictedColumnsRestriction;

  const factory BoardRestriction.maxHeight(int maxRows) = HeightLimitRestriction;

  /// `true` when a block may occupy [row]/[column].
  bool allows(int row, int column);

  String get kind;
}

class NoRestriction extends BoardRestriction {
  const NoRestriction();

  @override
  bool allows(int row, int column) => true;

  @override
  String get kind => 'none';
}

/// Columns the player is not allowed to drop into.
class RestrictedColumnsRestriction extends BoardRestriction {
  const RestrictedColumnsRestriction(this.columns);

  final Set<int> columns;

  @override
  bool allows(int row, int column) => !columns.contains(column);

  @override
  String get kind => 'restrictedColumns';
}

/// Blocks may never occupy any row above [topRow]. Rows above [topRow] are
/// dead space: the player cannot drop there and gravity never lifts a block
/// into it.
class HeightLimitRestriction extends BoardRestriction {
  const HeightLimitRestriction(this.topRow);

  final int topRow;

  @override
  bool allows(int row, int column) => row >= topRow;

  @override
  String get kind => 'maxHeight';
}

/// Tunable knobs that shape how a level (or infinite mode) plays.
///
/// Everything here is data, so remote configuration can retune the whole game
/// without shipping a new build.
class DifficultyProfile {
  const DifficultyProfile({
    this.spawnWeights = const <int, int>{2: 65, 4: 25, 8: 10},
    this.spawnProbability = 1.0,
    this.maxSpawnValue = 8,
    this.targetScore = 0,
    this.restriction = const BoardRestriction.none(),
    this.moveLimit,
    this.chainBonusMultiplier = 1.0,
  });

  /// Relative weight per spawnable value, e.g. `{2: 65, 4: 25, 8: 10}`.
  final Map<int, int> spawnWeights;

  /// Probability that the generator honours the full weight table. When the
  /// roll fails, the minimum value is spawned instead - a simple lever for
  /// making early levels calmer without rewriting the weights.
  final double spawnProbability;

  /// Hard ceiling on generated values (also enforced by the weight table).
  final int maxSpawnValue;

  /// Score the level generator aims for when computing star thresholds.
  final int targetScore;

  final BoardRestriction restriction;

  /// `null` means unlimited moves.
  final int? moveLimit;

  /// Scales chain-reaction score, letting later chapters feel more explosive.
  final double chainBonusMultiplier;

  /// Lowest value the generator can produce.
  int get minSpawnValue {
    if (spawnWeights.isEmpty) return 2;
    return spawnWeights.keys.reduce((a, b) => a < b ? a : b);
  }

  /// Values the generator may produce, ascending.
  List<int> get spawnableValues {
    final values = spawnWeights.keys.where((v) => v <= maxSpawnValue).toList()
      ..sort();
    return values.isEmpty ? <int>[2] : values;
  }

  DifficultyProfile copyWith({
    Map<int, int>? spawnWeights,
    double? spawnProbability,
    int? maxSpawnValue,
    int? targetScore,
    BoardRestriction? restriction,
    int? moveLimit,
    double? chainBonusMultiplier,
  }) {
    return DifficultyProfile(
      spawnWeights: spawnWeights ?? this.spawnWeights,
      spawnProbability: spawnProbability ?? this.spawnProbability,
      maxSpawnValue: maxSpawnValue ?? this.maxSpawnValue,
      targetScore: targetScore ?? this.targetScore,
      restriction: restriction ?? this.restriction,
      moveLimit: moveLimit ?? this.moveLimit,
      chainBonusMultiplier: chainBonusMultiplier ?? this.chainBonusMultiplier,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'spawnWeights': spawnWeights.map((k, v) => MapEntry(k.toString(), v)),
        'spawnProbability': spawnProbability,
        'maxSpawnValue': maxSpawnValue,
        'targetScore': targetScore,
        'restriction': restriction.kind,
        'restrictionTopRow': restriction is HeightLimitRestriction
            ? (restriction as HeightLimitRestriction).topRow
            : null,
        'restrictedColumns': restriction is RestrictedColumnsRestriction
            ? (restriction as RestrictedColumnsRestriction).columns.toList()
            : null,
        'moveLimit': moveLimit,
        'chainBonusMultiplier': chainBonusMultiplier,
      };

  factory DifficultyProfile.fromJson(Map<String, dynamic> json) {
    final rawWeights = (json['spawnWeights'] as Map<String, dynamic>?);
    final weights = <int, int>{};
    if (rawWeights != null) {
      rawWeights.forEach((key, value) {
        final parsed = int.tryParse(key);
        if (parsed != null && parsed > 0) {
          weights[parsed] = (value as num).toInt();
        }
      });
    }
    if (weights.isEmpty) weights.addAll(const <int, int>{2: 65, 4: 25, 8: 10});

    return DifficultyProfile(
      spawnWeights: weights,
      spawnProbability: (json['spawnProbability'] as num? ?? 1.0).toDouble(),
      maxSpawnValue: (json['maxSpawnValue'] as num? ?? 8).toInt(),
      targetScore: (json['targetScore'] as num? ?? 0).toInt(),
      restriction: _restrictionFromJson(json),
      moveLimit: (json['moveLimit'] as num?)?.toInt(),
      chainBonusMultiplier:
          (json['chainBonusMultiplier'] as num? ?? 1.0).toDouble(),
    );
  }

  /// Rebuilds a restriction from its `kind` plus payload fields.
  ///
  /// Both parts are required: persisting only the kind would silently turn a
  /// height-limited level into an unrestricted one on reload.
  static BoardRestriction _restrictionFromJson(Map<String, dynamic> json) {
    final kind = json['restriction'] as String?;
    final topRow = (json['restrictionTopRow'] as num?)?.toInt();
    final columns = (json['restrictedColumns'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toSet();
    return switch (kind) {
      'restrictedColumns' when columns != null && columns.isNotEmpty =>
        BoardRestriction.restrictedColumns(columns),
      'maxHeight' when topRow != null => BoardRestriction.maxHeight(topRow),
      _ => const BoardRestriction.none(),
    };
  }
}
