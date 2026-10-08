import 'dart:convert';

import '../domain/game_mode.dart';
import '../domain/game_snapshot.dart';
import '../domain/game_state.dart';

/// Serialises and validates [GameSnapshot]s.
///
/// Decoding is total: any malformed payload returns `null` instead of throwing,
/// and the caller discards the snapshot while keeping the rest of the player's
/// progress intact. A corrupt save must never crash the app.
class GameSnapshotCodec {
  const GameSnapshotCodec._();

  static const int supportedVersion = GameSnapshot.currentVersion;

  static String encode(GameSnapshot snapshot) {
    return jsonEncode(<String, dynamic>{
      'v': snapshot.version,
      'mode': snapshot.mode.name,
      'levelId': snapshot.levelId,
      'savedAt': snapshot.savedAtMs,
      'core': snapshot.core.toJson(),
      'undo': snapshot.undo.map((c) => c.toJson()).toList(),
    });
  }

  static GameSnapshot? decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final version = (decoded['v'] as num?)?.toInt();
      if (version == null || version > supportedVersion) return null;

      final coreJson = decoded['core'];
      if (coreJson is! Map<String, dynamic>) return null;
      final core = GameStateCore.tryFromJson(coreJson);
      if (core == null) return null;

      // A restored board must be playable; a snapshot that cannot accept a
      // single drop is a finished game, not a resumable one.
      if (!core.board.hasLegalDrop) return null;

      final undoRaw = (decoded['undo'] as List<dynamic>?) ?? const <dynamic>[];
      final undo = <GameStateCore>[];
      for (final entry in undoRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final parsed = GameStateCore.tryFromJson(entry);
        if (parsed != null) undo.add(parsed);
      }

      return GameSnapshot(
        version: version,
        mode: GameMode.fromName(decoded['mode'] as String?),
        levelId: (decoded['levelId'] as num?)?.toInt(),
        core: core,
        undo: undo,
        savedAtMs: (decoded['savedAt'] as num? ?? 0).toInt(),
      );
    } on Object {
      return null;
    }
  }
}
