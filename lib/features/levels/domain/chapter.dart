/// A group of levels with its own visual theme.
///
/// ```text
/// Chapter 1  levels 1-25
/// Chapter 2  levels 26-50
/// ...
/// ```
class Chapter {
  const Chapter({
    required this.id,
    required this.startLevel,
    required this.endLevel,
    required this.themeKey,
    required this.nameKey,
  });

  final int id;
  final int startLevel;
  final int endLevel;

  /// Localisation key of the chapter's visual theme.
  final String themeKey;

  /// Localisation key of the chapter's display name.
  final String nameKey;

  int get levelCount => endLevel - startLevel + 1;

  bool contains(int levelId) => levelId >= startLevel && levelId <= endLevel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chapter': id,
        'theme': themeKey,
        'nameKey': nameKey,
        'startLevel': startLevel,
        'endLevel': endLevel,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: (json['chapter'] as num).toInt(),
        themeKey: json['theme'] as String? ?? 'theme_dawn',
        nameKey: json['nameKey'] as String? ?? 'chapter_1',
        startLevel: (json['startLevel'] as num).toInt(),
        endLevel: (json['endLevel'] as num).toInt(),
      );
}
