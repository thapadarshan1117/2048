import 'package:equatable/equatable.dart';

/// What the player owns.
///
/// The app never asks a store directly: this value object is the single source
/// of truth for "what has been bought", and it is refreshed from
/// `PurchaseService` after every transaction or restore.
class Entitlements extends Equatable {
  const Entitlements({this.removeAds = false, this.coinPacks = 0});

  /// `true` when the remove-ads purchase is active.
  final bool removeAds;

  /// Number of consumable coin packs purchased in this session.
  final int coinPacks;

  static const Entitlements none = Entitlements();

  bool get hasAnyPurchase => removeAds || coinPacks > 0;

  Entitlements copyWith({bool? removeAds, int? coinPacks}) => Entitlements(
        removeAds: removeAds ?? this.removeAds,
        coinPacks: coinPacks ?? this.coinPacks,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'removeAds': removeAds,
        'coinPacks': coinPacks,
      };

  static Entitlements fromJson(Map<String, dynamic> json) => Entitlements(
        removeAds: json['removeAds'] as bool? ?? false,
        coinPacks: (json['coinPacks'] as num? ?? 0).toInt(),
      );

  @override
  List<Object?> get props => <Object?>[removeAds, coinPacks];
}

/// The products the MVP offers.
///
/// Kept as data so the shop screen renders whatever is here without a code
/// change, and so the store ids live in exactly one place.
abstract final class ProductCatalogue {
  const ProductCatalogue._();

  /// Non-consumable: removes interstitials for good.
  static const String removeAds = 'remove_ads';

  /// Coin bundles, cheapest first.
  static const List<({String id, int coins, String priceKey})> coinPacks =
      <({String id, int coins, String priceKey})>[
    (id: 'coins_small', coins: 500, priceKey: 'shop_pack_small'),
    (id: 'coins_medium', coins: 1500, priceKey: 'shop_pack_medium'),
    (id: 'coins_large', coins: 5000, priceKey: 'shop_pack_large'),
  ];
}
