// Covers the cart plumbing for configurable products (86d3g2npa #7/#9).
//
// The app used to post only the child sku to `carts/mine/items`, so Magento
// stored the line as a plain simple-product line: the website and the other app
// saw no selected variant, and the line could not be traced back to its parent.
// The fix posts the parent sku plus
// `product_option.extension_attributes.configurable_item_options` and parses
// those options back out on the way in.
//
// The two ends pinned here are the ones a wrong payload/parse breaks silently:
// the parse of a real cart-line body, and the cart key that has to agree between
// a locally added line and the same line rebuilt from the server.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/cart/mixin/cart_mixin.dart';
import 'package:magentoegypt/models/entities/product.dart';
import 'package:magentoegypt/models/entities/product_variation.dart';

void main() {
  group('Product.fromShopJson configurable options', () {
    // Shape captured from GET /rest/V1/carts/mine/items for a configurable
    // line: the sku is the *parent*, and the selection lives under
    // product_option.
    Map<String, dynamic> line() => {
          'item_id': 4321,
          'sku': 'PARENT-SKU',
          'qty': 2,
          'name': 'Kids T-Shirt',
          'price': 175,
          'product_option': {
            'extension_attributes': {
              'configurable_item_options': [
                {'option_id': '93', 'option_value': 177},
              ]
            }
          },
        };

    test('captures the selected super attributes', () {
      final product = Product.fromShopJson(line(), 'https://example.com');

      expect(product.sku, 'PARENT-SKU');
      expect(product.configurableItemOptions, hasLength(1));
      expect(product.configurableItemOptions!.first['option_id'], '93');
      // Stringified so it compares cleanly against the attribute option values,
      // which the API returns as ints in some responses and strings in others.
      expect(product.configurableItemOptions!.first['option_value'], '177');
    });

    test('a simple line carries no options rather than an empty list', () {
      final json = line()..remove('product_option');

      final product = Product.fromShopJson(json, 'https://example.com');

      expect(product.configurableItemOptions, isNull);
    });

    test('an option with no value is dropped instead of keying on null', () {
      final json = line();
      json['product_option']['extension_attributes']
          ['configurable_item_options'] = [
        {'option_id': '93'},
      ];

      final product = Product.fromShopJson(json, 'https://example.com');

      expect(product.configurableItemOptions, isNull);
    });
  });

  group('buildCartItemKey', () {
    Product parent() => Product()
      ..id = '10'
      ..sku = 'PARENT-SKU';

    test('a locally added line and the server rebuild land on the same key', () {
      // Local add: parent product + the child variation + the picked options.
      final local = buildCartItemKey(
        parent(),
        ProductVariation()..sku = 'CHILD-SKU-177',
        {'size': '177'},
      );
      // Server rebuild: same parent sku, no variation object, options resolved
      // from configurable_item_options.
      final rebuilt = buildCartItemKey(parent(), null, {'size': '177'});

      expect(local, rebuilt);
      // Without this the refresh would drop the variant context or duplicate
      // the row (86d3g2npa #9).
      expect(local, 'PARENT-SKU|size=177');
    });

    test('two variants of one parent stay separate rows', () {
      final small = buildCartItemKey(parent(), null, {'size': '177'});
      final large = buildCartItemKey(parent(), null, {'size': '178'});

      expect(small, isNot(large));
    });

    test('attribute order does not change the key', () {
      final a = buildCartItemKey(parent(), null, {'size': '177', 'color': '9'});
      final b = buildCartItemKey(parent(), null, {'color': '9', 'size': '177'});

      expect(a, b);
    });

    test('a line with no options keeps the plain sku key', () {
      expect(buildCartItemKey(parent(), null, null), 'PARENT-SKU');
      expect(buildCartItemKey(parent(), null, const {}), 'PARENT-SKU');
    });

    test('a variation with no options still keys on the child sku', () {
      final key = buildCartItemKey(
        parent(),
        ProductVariation()..sku = 'CHILD-SKU-177',
        null,
      );

      expect(key, 'CHILD-SKU-177');
    });

    test('falls back to the id when the product has no sku', () {
      final key = buildCartItemKey(Product()..id = '10', null, null);

      expect(key, '10');
    });
  });
}
