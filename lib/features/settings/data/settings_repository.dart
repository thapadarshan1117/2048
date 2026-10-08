import 'dart:convert';

import '../../../core/services/preferences_service.dart';
import '../domain/app_settings.dart';

/// Where settings are stored.
abstract interface class SettingsRepository {
  AppSettings read();

  Future<void> write(AppSettings settings);

  Future<void> reset();
}

/// `SharedPreferences`-backed settings storage.
class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._prefs);

  static const String _key = 'settings.v1';

  final PreferencesService _prefs;

  @override
  AppSettings read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppSettings.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return AppSettings.defaults;
      return AppSettings.fromJson(decoded);
    } on Object {
      // Corrupt settings must never block startup: fall back to defaults.
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> write(AppSettings settings) =>
      _prefs.putString(_key, jsonEncode(settings.toJson()));

  @override
  Future<void> reset() => _prefs.putString(_key, jsonEncode(AppSettings.defaults.toJson()));
}
