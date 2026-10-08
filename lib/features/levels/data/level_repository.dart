import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/chapter.dart';
import '../domain/level.dart';
import 'level_generator.dart';

/// Where levels come from.
abstract interface class LevelRepository {
  /// Loads the catalogue. Safe to call more than once.
  Future<void> load();

  /// All known levels, ordered by id.
  List<Level> get levels;

  /// All chapters, ordered by id.
  List<Chapter> get chapters;

  /// The level with [id], or `null` when it does not exist.
  Level? levelById(int id);

  /// Highest level id available in the catalogue.
  int get maxLevelId;

  /// Chapters containing [levelId].
  Chapter? chapterOf(int levelId);

  /// Total number of levels.
  int get count;
}

/// Loads levels from `assets/levels/chapter_XX.json`.
///
/// The shipped catalogue is a build artefact of `tool/generate_levels.dart`.
/// If an asset is missing or corrupt the repository silently falls back to
/// generating that level on the fly, so a broken asset bundle degrades into
/// "slightly different level" instead of "game will not start".
class AssetLevelRepository implements LevelRepository {
  AssetLevelRepository({
    this.assetPathPrefix = 'assets/levels/',
    this.chapterCount = 20,
    this.levelsPerChapter = LevelGenerator.defaultLevelsPerChapter,
    LevelGenerator? generator,
  }) : _generator = generator ??
            const LevelGenerator(
              simulator: null,
              games: 0,
            );

  final String assetPathPrefix;
  final int chapterCount;
  final int levelsPerChapter;
  final LevelGenerator _generator;

  final List<Level> _levels = <Level>[];
  final List<Chapter> _chapters = <Chapter>[];
  final Map<int, Level> _byId = <int, Level>{};
  bool _loaded = false;

  @override
  Future<void> load() async {
    if (_loaded) return;
    _levels.clear();
    _chapters.clear();
    _byId.clear();

    for (var chapter = 1; chapter <= chapterCount; chapter++) {
      final path = '$assetPathPrefix${_chapterFileName(chapter)}';
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('chapter payload is not an object');
        }
        final rawLevels = (decoded['levels'] as List<dynamic>?) ??
            const <dynamic>[];
        final parsed = <Level>[];
        for (final entry in rawLevels) {
          if (entry is! Map<String, dynamic>) continue;
          try {
            parsed.add(Level.fromJson(entry));
          } on Object {
            // A single broken level must not take the whole chapter down.
            continue;
          }
        }
        if (parsed.isEmpty) {
          throw const FormatException('chapter contains no usable levels');
        }
        _levels.addAll(parsed);
        _chapters.add(Chapter.fromJson(decoded));
      } on Object {
        // Fall back to generating this chapter so the game always has content.
        final start = (chapter - 1) * levelsPerChapter + 1;
        final end = chapter * levelsPerChapter;
        for (var id = start; id <= end; id++) {
          _levels.add(_generator.generate(id, calibrate: false));
        }
        _chapters.add(Chapter(
          id: chapter,
          startLevel: start,
          endLevel: end,
          themeKey: 'theme_${((chapter - 1) % 20 + 1)}',
          nameKey: 'chapter_$chapter',
        ));
      }
    }

    _levels.sort((a, b) => a.id.compareTo(b.id));
    _chapters.sort((a, b) => a.id.compareTo(b.id));
    for (final level in _levels) {
      _byId[level.id] = level;
    }
    _loaded = true;
  }

  static String _chapterFileName(int chapter) =>
      'chapter_${chapter.toString().padLeft(2, '0')}.json';

  @override
  List<Level> get levels => List<Level>.unmodifiable(_levels);

  @override
  List<Chapter> get chapters => List<Chapter>.unmodifiable(_chapters);

  @override
  Level? levelById(int id) => _byId[id];

  @override
  int get maxLevelId => _levels.isEmpty ? 0 : _levels.last.id;

  @override
  Chapter? chapterOf(int levelId) {
    for (final chapter in _chapters) {
      if (chapter.contains(levelId)) return chapter;
    }
    return null;
  }

  @override
  int get count => _levels.length;
}

/// In-memory catalogue used by tests and by the debug tools.
class InMemoryLevelRepository implements LevelRepository {
  InMemoryLevelRepository(this._levels);

  final List<Level> _levels;

  @override
  Future<void> load() async {}

  @override
  List<Level> get levels => List<Level>.unmodifiable(_levels);

  @override
  List<Chapter> get chapters {
    final byChapter = <int, List<Level>>{};
    for (final level in _levels) {
      byChapter.putIfAbsent(level.chapter, () => <Level>[]).add(level);
    }
    return byChapter.entries.map((entry) {
      final sorted = entry.value..sort((a, b) => a.id.compareTo(b.id));
      return Chapter(
        id: entry.key,
        startLevel: sorted.first.id,
        endLevel: sorted.last.id,
        themeKey: 'theme_${((entry.key - 1) % 20 + 1)}',
        nameKey: 'chapter_${entry.key}',
      );
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Level? levelById(int id) {
    for (final level in _levels) {
      if (level.id == id) return level;
    }
    return null;
  }

  @override
  int get maxLevelId => _levels.isEmpty ? 0 : _levels.last.id;

  @override
  Chapter? chapterOf(int levelId) {
    for (final chapter in chapters) {
      if (chapter.contains(levelId)) return chapter;
    }
    return null;
  }

  @override
  int get count => _levels.length;
}
