import 'block_spawn.dart';
import 'difficulty_profile.dart';
import 'level_objective.dart';
import 'star_thresholds.dart';

/// A single level.
///
/// Levels are pure data. The game never hardcodes level behaviour, which is
/// what lets the catalogue scale past 500 entries and be tuned remotely.
class Level {
  const Level({
    required this.id,
    required this.objective,
    required this.difficulty,
    this.moveLimit,
    this.initialBlocks = const <BlockSpawn>[],
    this.allowedBoosters = const <String>['undo', 'hammer', 'shuffle'],
    this.stars = const StarThresholds.trivial(),
    this.chapter = 1,
    this.isCurated = false,
    this.tutorialStepKey,
    this.nameKey,
  });

  final int id;
  final LevelObjective objective;

  /// `null` means unlimited moves.
  final int? moveLimit;

  final List<BlockSpawn> initialBlocks;

  /// Booster ids the player may bring into this level.
  final List<String> allowedBoosters;

  final DifficultyProfile difficulty;
  final StarThresholds stars;

  /// 1-based chapter this level belongs to.
  final int chapter;

  /// `true` for the hand-designed tutorial levels.
  final bool isCurated;

  /// Optional contextual tutorial hint shown at a specific point.
  final String? tutorialStepKey;

  /// Optional display name; `null` falls back to "Level N".
  final String? nameKey;

  bool allowsBooster(String boosterId) => allowedBoosters.contains(boosterId);

  int get effectiveMoveLimit => moveLimit ?? difficulty.moveLimit ?? 0;

  bool get hasMoveLimit => effectiveMoveLimit > 0;

  Level copyWith({
    int? id,
    LevelObjective? objective,
    int? moveLimit,
    List<BlockSpawn>? initialBlocks,
    List<String>? allowedBoosters,
    DifficultyProfile? difficulty,
    StarThresholds? stars,
    int? chapter,
    bool? isCurated,
    String? tutorialStepKey,
    String? nameKey,
  }) {
    return Level(
      id: id ?? this.id,
      objective: objective ?? this.objective,
      moveLimit: moveLimit ?? this.moveLimit,
      initialBlocks: initialBlocks ?? this.initialBlocks,
      allowedBoosters: allowedBoosters ?? this.allowedBoosters,
      difficulty: difficulty ?? this.difficulty,
      stars: stars ?? this.stars,
      chapter: chapter ?? this.chapter,
      isCurated: isCurated ?? this.isCurated,
      tutorialStepKey: tutorialStepKey ?? this.tutorialStepKey,
      nameKey: nameKey ?? this.nameKey,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'chapter': chapter,
        'objective': objective.toJson(),
        'moveLimit': moveLimit,
        'initialBlocks': initialBlocks.map((b) => b.toJson()).toList(),
        'allowedBoosters': allowedBoosters,
        'difficulty': difficulty.toJson(),
        'stars': stars.toJson(),
        'curated': isCurated,
        if (tutorialStepKey != null) 'tutorialStep': tutorialStepKey,
        if (nameKey != null) 'nameKey': nameKey,
      };

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: (json['id'] as num).toInt(),
      chapter: (json['chapter'] as num? ?? 1).toInt(),
      objective: LevelObjective.decode(
        (json['objective'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      moveLimit: (json['moveLimit'] as num?)?.toInt(),
      initialBlocks: ((json['initialBlocks'] as List<dynamic>?) ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(BlockSpawn.fromJson)
          .toList(),
      allowedBoosters:
          ((json['allowedBoosters'] as List<dynamic>?) ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
      difficulty: DifficultyProfile.fromJson(
        (json['difficulty'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      stars: StarThresholds.fromJson(
        (json['stars'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      isCurated: json['curated'] as bool? ?? false,
      tutorialStepKey: json['tutorialStep'] as String?,
      nameKey: json['nameKey'] as String?,
    );
  }
}
