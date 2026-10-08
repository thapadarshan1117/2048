import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../levels/data/level_repository.dart';
import '../../../progression/data/progress_repository.dart';
import '../../../progression/domain/level_progress.dart';

/// One row on the level map.
class LevelNodeData extends Equatable {
  const LevelNodeData({
    required this.levelId,
    required this.progress,
    required this.unlocked,
    required this.isCurrent,
  });

  final int levelId;
  final LevelProgress progress;
  final bool unlocked;
  final bool isCurrent;

  @override
  List<Object?> get props => <Object?>[levelId, unlocked, isCurrent, progress];
}

/// One chapter of the level map.
class ChapterData extends Equatable {
  const ChapterData({
    required this.id,
    required this.nameKey,
    required this.levels,
  });

  final int id;
  final String nameKey;
  final List<LevelNodeData> levels;

  int get starsEarned =>
      levels.fold<int>(0, (sum, node) => sum + node.progress.stars);

  bool get allComplete => levels.every((node) => node.progress.completed);

  @override
  List<Object?> get props => <Object?>[id, nameKey, levels];
}

/// State of the level map.
class LevelsState extends Equatable {
  const LevelsState({this.chapters = const <ChapterData>[]});

  final List<ChapterData> chapters;

  int get totalLevels =>
      chapters.fold<int>(0, (sum, chapter) => sum + chapter.levels.length);

  int get unlockedCount => chapters
      .expand((chapter) => chapter.levels)
      .where((node) => node.unlocked)
      .length;

  @override
  List<Object?> get props => <Object?>[chapters];
}

/// Builds the level map from the catalogue and the player's progress.
class LevelsCubit extends Cubit<LevelsState> {
  LevelsCubit({
    required LevelRepository levelRepository,
    required ProgressRepository progressRepository,
  })  : _levelRepository = levelRepository,
        _progressRepository = progressRepository,
        super(const LevelsState());

  final LevelRepository _levelRepository;
  final ProgressRepository _progressRepository;

  Future<void> load() async {
    await _levelRepository.load();
    final progress = _progressRepository.read();
    final chapters = <ChapterData>[];

    for (final chapter in _levelRepository.chapters) {
      final levels = <LevelNodeData>[];
      for (var id = chapter.startLevel; id <= chapter.endLevel; id++) {
        final level = _levelRepository.levelById(id);
        if (level == null) continue;
        levels.add(LevelNodeData(
          levelId: id,
          progress: progress.progress.progressFor(id),
          unlocked: progress.progress.isUnlocked(id),
          isCurrent: progress.progress.currentLevel == id,
        ));
      }
      if (levels.isEmpty) continue;
      chapters.add(ChapterData(
        id: chapter.id,
        nameKey: chapter.nameKey,
        levels: levels,
      ));
    }

    emit(LevelsState(chapters: chapters));
  }
}
