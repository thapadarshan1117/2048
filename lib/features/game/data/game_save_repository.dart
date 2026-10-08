import 'dart:convert';

import '../../../core/services/preferences_service.dart';
import '../domain/game_snapshot.dart';
import 'game_snapshot_codec.dart';

/// Where an in-progress game is stored.
abstract interface class GameSaveRepository {
  /// The resumable snapshot, or `null` when there is nothing to resume.
  GameSnapshot? readActive();

  Future<void> writeActive(GameSnapshot snapshot);

  Future<void> clearActive();

  /// Persisted booster inventory (booster id -> owned count).
  Map<String, int> readInventory();

  Future<void> writeInventory(Map<String, int> inventory);
}

/// `SharedPreferences`-backed save storage.
///
/// Decoding is total: a corrupt or stale snapshot is discarded while the rest
/// of the player's progress is preserved, so a bad save can never brick the
/// game.
class LocalGameSaveRepository implements GameSaveRepository {
  const LocalGameSaveRepository(this._prefs);

  static const String _activeKey = 'game.active.v1';
  static const String _inventoryKey = 'game.inventory.v1';

  final PreferencesService _prefs;

  @override
  GameSnapshot? readActive() =>
      GameSnapshotCodec.decode(_prefs.getString(_activeKey) ?? '');

  @override
  Future<void> writeActive(GameSnapshot snapshot) =>
      _prefs.putString(_activeKey, GameSnapshotCodec.encode(snapshot));

  @override
  Future<void> clearActive() => _prefs.remove(_activeKey);

  @override
  Map<String, int> readInventory() {
    final raw = _prefs.getString(_inventoryKey);
    if (raw == null || raw.isEmpty) return const <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <String, int>{};
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toInt().clamp(0, 999)),
      );
    } on Object {
      return const <String, int>{};
    }
  }

  @override
  Future<void> writeInventory(Map<String, int> inventory) => _prefs.putString(
        _inventoryKey,
        jsonEncode(inventory.map((key, value) => MapEntry(key, value))),
      );
}
