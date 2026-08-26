// Regression tests for ClickUp 86d3tkhgz #3: an order placed with a
// configurable product showed only the base name, never the variant that was
// bought.
//
// A Magento configurable order line comes back as the visible parent plus a
// hidden child (parent_item_id set) whose name is the parent name with the
// ordered options appended — e.g. "Boys Panel Detail Wide Leg Jeans-10 yrs" for
// parent "Boys Panel Detail Wide Leg Jeans". product_option only carries option
// IDs, so the variant text is recovered from that child name. Payload shapes
// below are trimmed from GET /V1/orders on testing.locafy.market (order
// #3000000604 is the one in the ticket screenshots).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/order/order.dart';
import 'package:magentoegypt/services/service_config.dart';

void main() {
  group('ProductItem.deriveVariantFromChildName', () {
    ProductItem parent(String name) => ProductItem.fromMagentoJson(
        jsonDecode('{"product_id": 1, "sku": "s", "name": ${jsonEncode(name)},'
            ' "qty_ordered": 1, "base_row_total": 0}'));

    test('strips the parent prefix to leave the ordered option', () {
      final p = parent('Boys Panel Detail Wide Leg Jeans');
      p.deriveVariantFromChildName('Boys Panel Detail Wide Leg Jeans-10 yrs');
      expect(p.variant, '10 yrs');
    });

    test('keeps every option when more than one was chosen', () {
      final p = parent('Ruffle pants Set');
      p.deriveVariantFromChildName('Ruffle pants Set-Green-3 yrs');
      expect(p.variant, 'Green-3 yrs');
    });

    test('single-attribute colour variant', () {
      final p = parent('Petit Bebe Baby Car seat Z8');
      p.deriveVariantFromChildName('Petit Bebe Baby Car seat Z8-Red');
      expect(p.variant, 'Red');
    });

    test('no variant when the child name is in another language', () {
      // A simple product missing its Arabic name falls back to English, so the
      // child does not start with the Arabic parent name. Better to show no
      // variant than text in the wrong language.
      final p = parent('جاكيت جلد للأطفال هارلي');
      p.deriveVariantFromChildName('Harley kids leather jacket-5 yrs');
      expect(p.variant, isNull);
    });

    test('no variant when parent and child names are identical', () {
      final p = parent('Simple Tee');
      p.deriveVariantFromChildName('Simple Tee');
      expect(p.variant, isNull);
    });

    test('a parent that is only a prefix of a longer word is not a variant', () {
      final p = parent('Top');
      p.deriveVariantFromChildName('Topaz');
      expect(p.variant, isNull);
    });

    test('null / empty child leaves the variant unset', () {
      final p = parent('Anything');
      p.deriveVariantFromChildName(null);
      p.deriveVariantFromChildName('');
      expect(p.variant, isNull);
    });
  });

  group('ProductItem.fromMagentoJson configurable option ids', () {
    test('captures attribute_id + option_value_id pairs', () {
      final item = ProductItem.fromMagentoJson(jsonDecode('''
        {"product_id": 40000, "sku": "s", "name": "Ruffle pants Set",
         "qty_ordered": 1, "base_row_total": 975, "product_type": "configurable",
         "product_option": {"extension_attributes": {"configurable_item_options":
           [{"option_id": "476", "option_value": 754},
            {"option_id": "479", "option_value": 845}]}}}
      '''));
      expect(item.configurableOptionIds, [
        {'attr': '476', 'value': 754},
        {'attr': '479', 'value': 845},
      ]);
    });

    test('is empty for a simple line with no product_option', () {
      final item = ProductItem.fromMagentoJson(jsonDecode(
          '{"product_id": 5, "sku": "5555", "name": "x", "qty_ordered": 1, "base_row_total": 10}'));
      expect(item.configurableOptionIds, isEmpty);
    });
  });

  group('Order.fromJson (magento) configurable line', () {
    setUpAll(() => ServerConfig().setConfig({'type': 'magento'}));

    // Order #3000000604: one configurable product, one unit ordered.
    Map<String, dynamic> order(List items) => {
          'entity_id': 7046,
          'increment_id': '3000000604',
          'state': 'new',
          'status': 'pending',
          'created_at': '2026-07-23 10:00:00',
          'base_grand_total': 1060,
          'payment': {
            'additional_information': ['Cash on Delivery']
          },
          'shipping_description': 'Flat Rate',
          'shipping_incl_tax': 85,
          'tax_amount': 0,
          'billing_address': {
            'firstname': 'Amira',
            'lastname': 'Ahmed',
            'street': ['6 Moustafa Fahmy St'],
            'city': 'جليم',
            'region': 'الإسكندرية',
            'country_id': 'EG',
            'telephone': '201029431824'
          },
          'items': items,
        };

    List configurableItems() => jsonDecode('''
      [
        {"item_id": 18636, "product_id": 40000, "sku": "junior-store_260426_3385",
         "name": "Boys Panel Detail Wide Leg Jeans", "qty_ordered": 1,
         "base_row_total": 975, "product_type": "configurable"},
        {"item_id": 18637, "parent_item_id": 18636, "product_id": 40001,
         "sku": "junior-store_260426_3385",
         "name": "Boys Panel Detail Wide Leg Jeans-10 yrs", "qty_ordered": 1,
         "base_row_total": 0, "product_type": "simple"}
      ]
    ''');

    test('surfaces the ordered variant on the single visible line', () {
      final o = Order.fromJson(order(configurableItems()));
      // The child line is skipped: one card, not two.
      expect(o.lineItems.length, 1);
      // ...and the ordered unit is counted once, not twice (86d3rrauf #2).
      expect(o.quantity, 1);
      final line = o.lineItems.first;
      expect(line.name, 'Boys Panel Detail Wide Leg Jeans');
      expect(line.variant, '10 yrs');
    });

    test('the parent line keeps the sku the order carries (86d3tkhgz #4)', () {
      final o = Order.fromJson(order(configurableItems()));
      expect(o.lineItems.first.sku, 'junior-store_260426_3385');
    });

    test('city/region map to the Magento fields the detail screen reads', () {
      // #2: the detail screen shows billing.state as City (governorate) and
      // billing.city as Zone (district).
      final o = Order.fromJson(order(configurableItems()));
      expect(o.billing!.state, 'الإسكندرية'); // governorate -> "City"
      expect(o.billing!.city, 'جليم'); // district -> "Zone"
    });

    test('a simple product carries no variant', () {
      final simple = jsonDecode('''
        [{"item_id": 1, "product_id": 5, "sku": "5555", "name": "test Simple Product",
          "qty_ordered": 2, "base_row_total": 100, "product_type": "simple"}]
      ''');
      final o = Order.fromJson(order(simple));
      expect(o.lineItems.length, 1);
      expect(o.lineItems.first.variant, isNull);
      expect(o.quantity, 2);
    });
  });
}
