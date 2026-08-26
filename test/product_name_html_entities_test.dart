// Regression test for the raw "&amp;" showing inside product names.
//
// Magento returns names HTML-escaped ("Cotton Vest &amp; Boxer Set for Boys"),
// but the app renders them as plain text, so the entity was visible on screen —
// first reported in the cart. The decode happens once at parse time, so this
// pins the parsers this store actually uses (cart, catalogue, search, wishlist,
// persisted cart) rather than a single widget: the order lines reuse
// product.name, so they are covered by the same fix.
//
// Worth pinning because the parsers are inconsistent by history — four of them
// already unescaped inline, five did not, and nothing failed loudly when a new
// one was added without it.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/product.dart';

void main() {
  const escaped = 'Cotton Vest &amp; Boxer Set for Boys';
  const decoded = 'Cotton Vest & Boxer Set for Boys';
  const domain = 'https://testing.locafy.market';

  group('product names decode HTML entities at parse time', () {
    test('cart lines — where the bug was reported', () {
      final product = Product.fromShopJson({
        'item_id': 11,
        'sku': 'VEST-14',
        'name': escaped,
        'price': 350,
        'qty': 1,
      }, domain);

      expect(product.name, decoded);
    });

    test('catalogue products', () {
      final product = Product.fromMagentoJson({
        'id': 42,
        'sku': 'VEST-14',
        'name': escaped,
        'status': 1,
      });

      expect(product.name, decoded);
    });

    test('search results', () {
      final product = Product.fromSearchJson({
        'entity_id': 42,
        'name': escaped,
        'sku': 'VEST-14',
      });

      expect(product.name, decoded);
    });

    test('the locally persisted cart', () {
      final product = Product.fromLocalJson({
        'id': 42,
        'sku': 'VEST-14',
        'name': escaped,
      });

      expect(product.name, decoded);
    });

    test('the other entities the store sends escaped', () {
      // &#39; (apostrophe) and &quot; are just as common in these names as
      // &amp; — decoding must not be special-cased to the ampersand.
      final product = Product.fromShopJson({
        'item_id': 12,
        'sku': 'DRESS-8',
        'name': 'Girl&#39;s 8&quot; Summer Dress &amp; Hat',
        'price': 500,
        'qty': 1,
      }, domain);

      expect(product.name, 'Girl\'s 8" Summer Dress & Hat');
    });

    test('a name with nothing to decode is left exactly as sent', () {
      final product = Product.fromShopJson({
        'item_id': 13,
        'sku': 'SOCK-2',
        'name': 'Plain Cotton Socks',
        'price': 60,
        'qty': 1,
      }, domain);

      expect(product.name, 'Plain Cotton Socks');
    });

    test('a missing name stays null instead of breaking the parse', () {
      // Feeds do omit the field; decoding must not turn that into a crash or
      // into the string "null" on screen.
      final product = Product.fromShopJson({
        'item_id': 14,
        'sku': 'SOCK-2',
        'price': 60,
        'qty': 1,
      }, domain);

      expect(product.name, isNull);
    });
  });
}
