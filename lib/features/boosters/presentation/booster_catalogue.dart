import 'package:flutter/material.dart';

import '../../game/domain/boosters/booster.dart';
import '../../game/domain/boosters/booster_registry.dart';

/// One booster as the UI sees it: identity, icon and toolbar position.
///
/// Every label and description comes from [BoosterRegistry] (which owns the
/// localisation keys), so no screen can drift into hardcoding its own English
/// text for a booster.
typedef BoosterCatalogueEntry = ({String id, IconData icon});

/// Display metadata for the booster toolbar and the shop.
///
/// The toolbar order is a deliberate product decision: undo is the booster
/// players reach for most, so it sits closest to the thumb, and the two
/// block-targeting boosters sit at the end where a mis-tap is least costly.
abstract final class BoosterCatalogue {
  const BoosterCatalogue._();

  /// Toolbar order. Ids must exist in [BoosterRegistry].
  static const List<BoosterCatalogueEntry> toolbar = <BoosterCatalogueEntry>[
    (id: 'undo', icon: Icons.undo_rounded),
    (id: 'hammer', icon: Icons.hardware_rounded),
    (id: 'shuffle', icon: Icons.shuffle_rounded),
    (id: 'wildcard', icon: Icons.auto_awesome_rounded),
    (id: 'upgrade', icon: Icons.arrow_circle_up_rounded),
  ];

  /// Every booster the shop sells, in the same order as the toolbar.
  static List<Booster> get all => BoosterRegistry.all;

  static IconData iconFor(String id) {
    for (final entry in toolbar) {
      if (entry.id == id) return entry.icon;
    }
    return Icons.extension_rounded;
  }

  /// The boosters a level permits, in toolbar order.
  ///
  /// `allowed == null` means the level places no restriction.
  static List<BoosterCatalogueEntry> visibleIn(List<String>? allowed) {
    if (allowed == null) return toolbar;
    return toolbar.where((entry) => allowed.contains(entry.id)).toList();
  }

  /// Total charges of [id] the player owns, counting the free starting charges
  /// a new save is seeded with.
  static int countOf(Map<String, int> inventory, String id) {
    final owned = inventory[id];
    if (owned != null) return owned;
    return 0;
  }
}
