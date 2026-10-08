import 'package:equatable/equatable.dart';

/// Coins and booster charges owned outside of a play session.
///
/// This is the state the shop and the profile screen render. It is deliberately
/// a plain value object: the game session keeps its own copy so a session can
/// never be corrupted by a shop purchase that happens while it is running, and
/// the two are reconciled through [ProgressRepository] on every write.
class BoosterInventoryState extends Equatable {
  const BoosterInventoryState({
    this.coins = 0,
    this.inventory = const <String, int>{},
    this.removeAdsOwned = false,
    this.messageKey,
  });

  /// Snapshot for a brand-new save.
  static const BoosterInventoryState empty = BoosterInventoryState();

  final int coins;
  final Map<String, int> inventory;

  /// `true` once the remove-ads purchase has been restored or completed.
  final bool removeAdsOwned;

  /// Localisation key for the last rejection, or `null` when there is none.
  final String? messageKey;

  int countOf(String boosterId) => inventory[boosterId] ?? 0;

  bool canAfford(int price) => coins >= price;

  BoosterInventoryState copyWith({
    int? coins,
    Map<String, int>? inventory,
    bool? removeAdsOwned,
    String? messageKey,
    bool clearMessage = false,
  }) {
    return BoosterInventoryState(
      coins: coins ?? this.coins,
      inventory: inventory ?? this.inventory,
      removeAdsOwned: removeAdsOwned ?? this.removeAdsOwned,
      messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
    );
  }

  @override
  List<Object?> get props => <Object?>[coins, inventory, removeAdsOwned, messageKey];
}
