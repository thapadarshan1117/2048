import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/data/game_snapshot_codec.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/game_engine.dart';
import 'package:merge_drop/features/game/domain/game_mode.dart';
import 'package:merge_drop/features/game/domain/game_snapshot.dart';
import 'package:merge_drop/features/game/domain/game_state.dart';
import 'package:merge_drop/features/levels/domain/difficulty_profile.dart';

const DifficultyProfile _profile = DifficultyProfile();

GameSnapshot _snapshot({int moves = 2, int levelId = 4}) {
  final engine = GameEngine.start(
    board: GameBoard.empty(rows: 12, columns: 6),
    profile: _profile,
    seed: 31337,
  );
  for (var i = 0; i < moves; i++) {
    engine.drop(i % 6);
  }
  return GameSnapshot(
    version: GameSnapshot.currentVersion,
    mode: GameMode.level,
    levelId: levelId,
    core: engine.toCore(),
    undo: engine.state.undoHistory
        .map((state) => GameStateCore(
              board: state.board,
              nextBlockId: state.nextBlockId,
              nextBlockValue: state.nextBlockValue,
              stats: state.stats,
              score: state.score,
              movesUsed: state.movesUsed,
              rngState: state.rngState,
            ))
        .toList(),
    savedAtMs: 1759900000000,
  );
}

void main() {
  group('GameSnapshotCodec', () {
    test('round-trips a snapshot', () {
      final snapshot = _snapshot();
      final decoded =
          GameSnapshotCodec.decode(GameSnapshotCodec.encode(snapshot));
      expect(decoded, isNotNull);
      expect(decoded!.version, snapshot.version);
      expect(decoded.mode, GameMode.level);
      expect(decoded.levelId, 4);
      expect(decoded.core.board.values, snapshot.core.board.values);
      expect(decoded.core.score, snapshot.core.score);
      expect(decoded.core.movesUsed, snapshot.core.movesUsed);
      expect(decoded.savedAtMs, 1759900000000);
    });

    test('undo history survives a save', () {
      final snapshot = _snapshot(moves: 3);
      expect(snapshot.undo.length, 3);
      final decoded =
          GameSnapshotCodec.decode(GameSnapshotCodec.encode(snapshot));
      expect(decoded!.undo.length, 3);
      expect(decoded.undo.last.board.values, snapshot.undo.last.board.values);
    });

    test('an empty payload decodes to null', () {
      expect(GameSnapshotCodec.decode(''), isNull);
    });

    test('a malformed payload decodes to null instead of throwing', () {
      for (final payload in <String>[
        'not json',
        '[]',
        'null',
        '{"v":1}',
        '{"v":"one","core":{}}',
        '{"v":1,"core":"nope"}',
        '{"v":1,"core":{"rows":12,"columns":6,"cells":"nope"}}',
      ]) {
        expect(GameSnapshotCodec.decode(payload), isNull,
            reason: 'payload should be rejected: $payload');
      }
    });

    test('a future version is rejected', () {
      final payload = GameSnapshotCodec.encode(_snapshot());
      final bumped = payload.replaceFirst('"v":1', '"v":99');
      expect(GameSnapshotCodec.decode(bumped), isNull);
    });

    test('a finished board is not resumable', () {
      final engine = GameEngine.start(
        board: GameBoard.empty(rows: 2, columns: 2),
        profile: _profile,
        seed: 1,
      );
      for (var column = 0; column < 2; column++) {
        for (var i = 0; i < 2; i++) {
          engine.drop(column);
        }
      }
      final snapshot = GameSnapshot(
        version: GameSnapshot.currentVersion,
        mode: GameMode.level,
        core: engine.toCore(),
      );
      expect(
        GameSnapshotCodec.decode(GameSnapshotCodec.encode(snapshot)),
        isNull,
      );
    });

    test('a restored engine reproduces the session', () {
      final original = _snapshot(moves: 4, levelId: 9);
      final decoded =
          GameSnapshotCodec.decode(GameSnapshotCodec.encode(original))!;
      final engine = GameEngine.restore(core: decoded.core, profile: _profile);
      expect(engine.state.board.values, original.core.board.values);
      expect(engine.state.score, original.core.score);
      expect(engine.state.nextBlockValue, original.core.nextBlockValue);
    });

    test('infinite mode round-trips without a level id', () {
      final engine = GameEngine.start(
        board: GameBoard.empty(rows: 12, columns: 6),
        profile: _profile,
        mode: GameMode.infinite,
        seed: 8,
      );
      engine.drop(2);
      final snapshot = GameSnapshot(
        version: GameSnapshot.currentVersion,
        mode: GameMode.infinite,
        core: engine.toCore(),
      );
      final decoded =
          GameSnapshotCodec.decode(GameSnapshotCodec.encode(snapshot));
      expect(decoded!.mode, GameMode.infinite);
      expect(decoded.levelId, isNull);
    });
  });
}
