import 'booster.dart';
import 'hammer_booster.dart';
import 'shuffle_booster.dart';
import 'undo_booster.dart';
import 'upgrade_booster.dart';
import 'wildcard_booster.dart';

/// Central lookup for boosters.
///
/// Adding a booster means adding a class and one line here - no UI, save or
/// analytics code has to change.
class BoosterRegistry {
  const BoosterRegistry._();

  static const List<Booster> all = <Booster>[
    UndoBooster(),
    HammerBooster(),
    ShuffleBooster(),
    WildcardBooster(),
    UpgradeBooster(),
  ];

  /// Boosters shipped in the MVP build.
  static const List<Booster> core = <Booster>[
    UndoBooster(),
    HammerBooster(),
    ShuffleBooster(),
  ];

  static Booster? byId(String id) {
    for (final booster in all) {
      if (booster.id == id) return booster;
    }
    return null;
  }

  static Booster byIdOrDefault(String id) => byId(id) ?? const UndoBooster();

  static const List<String> defaultIds = <String>['undo', 'hammer', 'shuffle'];
}
