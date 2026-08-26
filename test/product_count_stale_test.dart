// The product model is shared by every product page, so its `totalCount`
// outlived the category it was counted for: opening a category showed the
// previous one's number beside the new title until the fetch landed —
// "28 items" under BOYS right after coming from Shoes, and the mirror of it
// (a new title over the old count) in a screenshot taken mid-navigation.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/product_model.dart';

void main() {
  group('product count does not outlive its category', () {
    test('switching category drops the previous total', () {
      final model = ProductModel()..totalCount = 202;

      model.fetchProductsByCategory(
        categoryId: '286',
        categoryName: 'Shoes',
        notify: false,
      );

      expect(model.totalCount, isNull);
      expect(model.categoryName, 'Shoes');
    });

    test('a listing location switch drops it too', () {
      final model = ProductModel()..totalCount = 202;

      model.fetchProductsByCategory(listingLocationId: '7', notify: false);

      expect(model.totalCount, isNull);
    });
  });
}
