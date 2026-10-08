import 'package:equatable/equatable.dart';

/// Languages the game is prepared for.
///
/// The MVP ships English; the rest are placeholders so the localisation
/// plumbing is exercised from day one.
enum AppLanguage {
  english('en', 'English'),
  nepali('ne', 'Nepali'),
  hindi('hi', 'Hindi'),
  spanish('es', 'Spanish'),
  portuguese('pt', 'Portuguese');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return AppLanguage.english;
  }
}

/// Player-controlled settings.
class AppSettings extends Equatable {
  const AppSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.language = AppLanguage.english,
    this.removeAdsPurchased = false,
    this.showFps = false,
  });

  final bool soundEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final AppLanguage language;
  final bool removeAdsPurchased;

  /// Debug overlay toggle; never surfaced in release builds.
  final bool showFps;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    AppLanguage? language,
    bool? removeAdsPurchased,
    bool? showFps,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      removeAdsPurchased: removeAdsPurchased ?? this.removeAdsPurchased,
      showFps: showFps ?? this.showFps,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sound': soundEnabled,
        'music': musicEnabled,
        'vibration': vibrationEnabled,
        'notifications': notificationsEnabled,
        'language': language.code,
        'removeAds': removeAdsPurchased,
        'showFps': showFps,
      };

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
        soundEnabled: json['sound'] as bool? ?? true,
        musicEnabled: json['music'] as bool? ?? true,
        vibrationEnabled: json['vibration'] as bool? ?? true,
        notificationsEnabled: json['notifications'] as bool? ?? true,
        language: AppLanguage.fromCode(json['language'] as String?),
        removeAdsPurchased: json['removeAds'] as bool? ?? false,
        showFps: json['showFps'] as bool? ?? false,
      );

  @override
  List<Object?> get props => <Object?>[
        soundEnabled,
        musicEnabled,
        vibrationEnabled,
        notificationsEnabled,
        language,
        removeAdsPurchased,
        showFps,
      ];
}
