import '../../../app/localization/app_strings.dart';
import '../../levels/domain/level_objective.dart';
import '../domain/daily_challenge.dart';

/// Localised label helpers for the daily challenge.
abstract final class DailyLabels {
  const DailyLabels._();

  /// Objective text of [challenge].
  static String objectiveText(DailyChallenge challenge) {
    final level = challenge.level;
    return AppStrings.tr(
      level.objective.localizationKey,
      <String, Object?>{'target': level.objective.target},
    );
  }

  /// Short human label for the objective type.
  static String objectiveTypeLabel(DailyChallenge challenge) {
    return switch (challenge.level.objective.type) {
      ObjectiveType.reachScore => 'Score',
      ObjectiveType.createNumber => 'Create',
      ObjectiveType.mergeCount => 'Merge',
      ObjectiveType.reachNumber => 'Reach',
      ObjectiveType.completeWithinMoves => 'Speed',
      ObjectiveType.comboCount => 'Chain',
    };
  }
}
