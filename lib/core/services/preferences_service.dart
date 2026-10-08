import 'package:shared_preferences/shared_preferences.dart';

/// Thin, injectable wrapper over `SharedPreferences`.
///
/// Every repository in the app goes through this so storage can be swapped for
/// SQLite / Isar / a cloud backend later without touching feature code.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async =>
      PreferencesService(await SharedPreferences.getInstance());

  /// The raw store, for the few repositories that need list access.
  SharedPreferences get sharedPreferences => _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> putString(String key, String value) => _prefs.setString(key, value);

  int getInt(String key, {int fallback = 0}) => _prefs.getInt(key) ?? fallback;

  Future<void> putInt(String key, int value) => _prefs.setInt(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> putBool(String key, bool value) => _prefs.setBool(key, value);

  double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(key) ?? fallback;

  Future<void> putDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? <String>[];

  Future<void> putStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clear() => _prefs.clear();
}
