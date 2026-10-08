import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/monetization/domain/entitlements.dart';

void main() {
  group('Entitlements', () {
    test('a new player owns nothing', () {
      const entitlements = Entitlements.none;
      expect(entitlements.removeAds, isFalse);
      expect(entitlements.hasAnyPurchase, isFalse);
    });

    test('removeAds is recorded and round-trips', () {
      const entitlements = Entitlements(removeAds: true);
      expect(entitlements.hasAnyPurchase, isTrue);
      expect(Entitlements.fromJson(entitlements.toJson()), entitlements);
    });

    test('coin packs round-trip', () {
      const entitlements = Entitlements(coinPacks: 2);
      expect(Entitlements.fromJson(entitlements.toJson()), entitlements);
    });

    test('copyWith only changes what it is given', () {
      const base = Entitlements(removeAds: true, coinPacks: 1);
      final updated = base.copyWith(coinPacks: 4);
      expect(updated.removeAds, isTrue);
      expect(updated.coinPacks, 4);
    });
  });

  group('ProductCatalogue', () {
    test('coin packs are ordered cheapest first', () {
      final coins = ProductCatalogue.coinPacks.map((p) => p.coins).toList();
      expect(coins, orderedEquals(<int>[500, 1500, 5000]));
    });

    test('every pack has a unique id and a localisation key', () {
      final ids = ProductCatalogue.coinPacks.map((p) => p.id).toSet();
      expect(ids.length, ProductCatalogue.coinPacks.length);
      for (final pack in ProductCatalogue.coinPacks) {
        expect(pack.priceKey.startsWith('shop_pack_'), isTrue);
      }
    });
  });
}
