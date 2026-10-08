import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/levels/data/level_repository.dart';
import 'package:merge_drop/features/levels/domain/level.dart';

/// Loads the shipped catalogue exactly the way the app does, so a broken asset
/// bundle fails in CI instead of on a player's phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shipped level catalogue', () {
    late List<Level> levels;

    setUpAll(() async {
      levels = <Level>[];
      for (var chapter = 1; chapter <= 20; chapter++) {
        final path =
            'assets/levels/chapter_${chapter.toString().padLeft(2, '0')}.json';
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded['chapter'], chapter);
        expect(decoded['levels'], isA<List<dynamic>>());
        for (final entry in decoded['levels'] as List<dynamic>) {
          levels.add(Level.fromJson(entry as Map<String, dynamic>));
        }
      }
    });

    test('ships 500 levels across 20 chapters of 25', () {
      expect(levels.length, 500);
      for (var chapter = 1; chapter <= 20; chapter++) {
        final inChapter =
            levels.where((l) => l.chapter == chapter).toList();
        expect(inChapter.length, 25, reason: 'chapter $chapter');
      }
    });

    test('level ids are contiguous and match their chapter', () {
      levels.sort((a, b) => a.id.compareTo(b.id));
      for (var i = 0; i < levels.length; i++) {
        expect(levels[i].id, i + 1);
        expect(levels[i].chapter, (i ~/ 25) + 1);
      }
    });

    test('every level has a positive objective and ordered star thresholds', () {
      for (final level in levels) {
        expect(level.objective.target, greaterThan(0),
            reason: 'level ${level.id}');
        expect(level.stars.threeStarScore,
            greaterThanOrEqualTo(level.stars.twoStarScore),
            reason: 'level ${level.id}');
        expect(level.difficulty.spawnWeights.isNotEmpty, isTrue);
      }
    });

    test('no level seals every column at the start', () {
      for (final level in levels) {
        final occupied = <(int, int)>{
          for (final spawn in level.initialBlocks) (spawn.row, spawn.column),
        };
        var sealed = 0;
        for (var column = 0; column < 6; column++) {
          var free = false;
          for (var row = 11; row >= 0; row--) {
            if (!occupied.contains((row, column))) {
              free = true;
              break;
            }
          }
          if (!free) sealed++;
        }
        expect(sealed, lessThan(6), reason: 'level ${level.id} is a dead end');
      }
    });

    test('every level round-trips through JSON', () {
      for (final level in levels) {
        final restored = Level.fromJson(level.toJson());
        expect(restored.id, level.id);
        expect(restored.objective.type, level.objective.type);
        expect(restored.objective.target, level.objective.target);
        expect(restored.stars, level.stars);
        expect(restored.initialBlocks.length, level.initialBlocks.length);
      }
    });

    test('the objective mix is varied', () {
      final counts = <String, int>{};
      for (final level in levels) {
        counts[level.objective.type.name] =
            (counts[level.objective.type.name] ?? 0) + 1;
      }
      expect(counts.length, greaterThanOrEqualTo(5),
          reason: 'the catalogue must use most objective types');
      for (final type in <String>[
        'reachScore',
        'createNumber',
        'comboCount',
        'mergeCount',
        'reachNumber',
      ]) {
        expect(counts[type], greaterThan(0), reason: 'no $type levels');
      }
    });

    test('levels 1-20 are the hand-curated tutorial band', () {
      final curated = levels.where((l) => l.isCurated).toList();
      expect(curated.length, 20);
      expect(curated.map((l) => l.id).toSet(),
          Set<int>.from(List<int>.generate(20, (i) => i + 1)));
    });

    test('the repository falls back to generation for a missing asset', () async {
      final repository = AssetLevelRepository(
        assetPathPrefix: 'assets/levels-does-not-exist/',
      );
      await repository.load();
      expect(repository.count, greaterThan(0));
      expect(repository.maxLevelId, greaterThanOrEqualTo(25));
      expect(repository.chapterOf(3)?.id, 1);
    });
  });
}
