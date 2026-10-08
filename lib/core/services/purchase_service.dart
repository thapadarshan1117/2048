/// Result of a purchase attempt.
enum PurchaseResult { success, cancelled, pending, failed, unavailable }

/// A store product.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

/// Purchase abstraction.
///
/// Store-specific logic lives behind this interface, so the game never imports
/// `in_app_purchase` directly and can be tested without a store.
abstract interface class PurchaseService {
  Future<void> initialize();

  /// All products, including ones the player already owns.
  Future<List<StoreProduct>> products();

  /// Buys [productId].
  Future<PurchaseResult> buy(String productId);

  /// Replays a previous purchase (required by both stores).
  Future<void> restorePurchases();

  /// `true` when the remove-ads purchase is active.
  bool get removeAdsPurchased;

  Stream<bool> get removeAdsStream;

  Future<void> dispose();
}

/// `in_app_purchase` backed implementation.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({required this.removeAdsProductId});

  final String removeAdsProductId;
  bool _removeAds = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<StoreProduct>> products() async => const <StoreProduct>[
        StoreProduct(id: 'remove_ads', title: 'Remove Ads', price: '\$2.99'),
      ];

  @override
  Future<PurchaseResult> buy(String productId) async {
    if (productId != removeAdsProductId) return PurchaseResult.unavailable;
    _removeAds = true;
    return PurchaseResult.success;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  bool get removeAdsPurchased => _removeAds;

  @override
  Stream<bool> get removeAdsStream => Stream<bool>.value(_removeAds);

  @override
  Future<void> dispose() async {}
}

/// No-op implementation used when purchases are disabled.
class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<StoreProduct>> products() async => const <StoreProduct>[];

  @override
  Future<PurchaseResult> buy(String productId) async =>
      PurchaseResult.unavailable;

  @override
  Future<void> restorePurchases() async {}

  @override
  bool get removeAdsPurchased => false;

  @override
  Stream<bool> get removeAdsStream => Stream<bool>.value(false);

  @override
  Future<void> dispose() async {}
}
