// Regression test for ClickUp 86d3rytm0: rating a product from Order Details
// showed a "Not Found" toast.
//
// Magento keys its review and product-lookup routes off the SKU, but order line
// items were parsed for the numeric `product_id` only, and Order Details passed
// that to the Reviews widget. Verified against testing.locafy.market with order
// #7000003367:
//
//   GET /rest/V1/products/40552    -> 404   (the id the app was sending)
//   GET /rest/V1/products/test%2012 -> 200  (the sku it should send)
//
// That 404 is what surfaced as "Not Found". The same mismatch also meant the
// review list never loaded, since getReviews filters by sku too.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/order/product_item.dart';

void main() {
  group('ProductItem.fromMagentoJson', () {
    // Copied from GET /V1/orders -> items[0].items[0] for order #7000003367.
    // Note the SKU contains a space, so it has to survive URL encoding at the
    // call site.
    Map<String, dynamic> lineItem() => jsonDecode('''
      {"product_id": 40552, "sku": "test 12", "name": "test 12",
       "qty_ordered": 1, "base_row_total": 5000, "product_type": "simple"}
    ''');

    test('captures the sku the review route needs', () {
      final item = ProductItem.fromMagentoJson(lineItem());
      expect(item.sku, 'test 12');
      // The entity id is still read — it is what the rest of the screen uses.
      expect(item.productId, '40552');
    });

    test('sku survives the local cache round-trip', () {
      // Order History is cached, so a rehydrated item must still be reviewable.
      final cached = ProductItem.fromLocalJson(
          ProductItem.fromMagentoJson(lineItem()).toJson());
      expect(cached.sku, 'test 12');
    });

    test('sku is null when the payload has none, so callers can fall back', () {
      // Order Details passes `sku ?? productId`, so backends whose order
      // payload carries no sku keep their previous behaviour.
      final item = ProductItem.fromMagentoJson(
          jsonDecode('{"product_id": 40552, "name": "test 12"}'));
      expect(item.sku, isNull);
      expect(item.productId, '40552');
    });
  });
}
