// Regression tests for the wishlist showing EGP0.00 / the undiscounted price
// (follow-up to the 86d3rtbnp layout fix).
//
// The wishlist is re-fetched from POST mobiconnect/wishlist/getwishlist on every
// app launch — ProductWishListModel.getLocalWishlist does not read the local box
// — and that endpoint returns prices as PREFORMATTED DISPLAY STRINGS rather than
// numbers. A real response body for this store:
//
//   {"product_name":"Modern Edge Tracksuit","product_type":"configurable",
//    "regular_price":"EGP 950.00","special_price":"EGP 760.00",
//    "min_price":null,"max_price":null,"final_price":null,"price":null}
//
// Note the U+00A0 non-breaking space between the currency and the amount, and
// the thousands separator on larger values ("EGP 1,100.00"). Every price
// field on Product holds a plain numeric string that PriceTools parses with
// double.tryParse, so the raw string parsed as 0 and the tile rendered EGP0.00.
//
// The strings below are copied verbatim from the live staging response.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/product.dart';

void main() {
  // Only the price-bearing keys matter here; the constructor tolerates the rest
  // being absent.
  Product wishlistProduct({
    required String regular,
    required String special,
  }) {
    final json = jsonDecode('''
      {"product_id": "35366", "wishlist_item_id": "2661", "product_name": "Test",
       "product_type": "configurable",
       "regular_price": "$regular", "special_price": "$special"}
    ''') as Map<String, dynamic>;
    return Product.fromWislitJson(json, 'https://example.com');
  }

  group('Product.fromWislitJson pricing', () {
    test('parses a discounted product from the display strings', () {
      //   is the non-breaking space the API actually sends.
      final product =
          wishlistProduct(regular: 'EGP 950.00', special: 'EGP 760.00');

      expect(product.price, '760.0', reason: 'shopper pays the special price');
      expect(product.salePrice, '760.0');
      expect(product.original_price, '950.0',
          reason: 'drives the struck-through original in ProductPricing');
      expect(product.regularPrice, '950.0');
    });

    test('strips thousands separators', () {
      final product = wishlistProduct(
          regular: 'EGP 1,100.00', special: 'EGP 880.00');

      expect(product.regularPrice, '1100.0');
      expect(product.price, '880.0');
    });

    test('a product with no discount falls back to the regular price', () {
      // "no_special" is Magento's sentinel for "no special price set".
      final product =
          wishlistProduct(regular: 'EGP 700.00', special: 'no_special');

      expect(product.price, '700.0');
      expect(product.salePrice, isNull);
      expect(product.minimalPrice, isNull);
      // original_price still set, but equal to price — ProductPricing's
      // strike-through branch compares the two numerically and stays hidden.
      expect(product.original_price, '700.0');
    });

    test('leaves prices null rather than zero when the amount is unusable', () {
      // Null/blank must not become "0.0": that would render a real EGP0.00
      // instead of simply omitting the price, which is the bug being fixed.
      final json = jsonDecode(
              '{"product_id": "1", "product_name": "T", "regular_price": null,'
              ' "special_price": ""}')
          as Map<String, dynamic>;
      final product = Product.fromWislitJson(json, 'https://example.com');

      expect(product.price, isNull);
      expect(product.regularPrice, isNull);
      expect(product.original_price, isNull);
      expect(product.salePrice, isNull);
    });

    test('marks the product as a stub for the detail page to replace', () {
      // The feed carries no description, no configurable options and image
      // names that don't resolve, so ProductDetailScreen re-fetches the catalog
      // record by id before rendering (86d3uqvmx #2). Without this flag the
      // page showed a placeholder image, "out of stock" and a buy button stuck
      // on LOADING.
      final product =
          wishlistProduct(regular: 'EGP 950.00', special: 'EGP 760.00');

      expect(product.isPartial, isTrue);
      // Empty, never null: the variant widgets dereference both with `!`.
      expect(product.attributes, isEmpty);
      expect(product.configurable_product_options, isEmpty);
    });

    test('builds usable image URLs and drops the unusable references', () {
      // `product_image` is absolute; the image-role names are media-relative
      // and may come without the leading slash, as 'no_selection', or absent.
      // Concatenating them blind gave `…/catalog/productnull`, which 404s.
      final json = jsonDecode('''
        {"product_id": "1", "product_name": "T",
         "product_image": "https://cdn.example.com/media/catalog/product/a/b/x.jpg",
         "thumbnail": "a/b/x.jpg",
         "small_image": "/c/d/y.jpg",
         "swatch_image": "no_selection"}
      ''') as Map<String, dynamic>;
      final product = Product.fromWislitJson(json, 'https://example.com');

      expect(product.imageFeature,
          'https://cdn.example.com/media/catalog/product/a/b/x.jpg');
      // The media host comes from the active server config (kMediaDomain), not
      // from the domain argument, so assert on the paths.
      expect(product.images, hasLength(3), reason: 'no_selection is dropped');
      expect(product.images.first,
          'https://cdn.example.com/media/catalog/product/a/b/x.jpg');
      expect(product.images[1], endsWith('/media/catalog/product/a/b/x.jpg'),
          reason: 'a name with no leading slash still resolves');
      expect(product.images[2], endsWith('/media/catalog/product/c/d/y.jpg'));
    });

    test('leaves the image fields empty when the feed sends none', () {
      final json =
          jsonDecode('{"product_id": "1", "product_name": "T"}') as Map<String, dynamic>;
      final product = Product.fromWislitJson(json, 'https://example.com');

      // Null, not '': ActionButtonMixin treats an empty string as "no image,
      // don't open this product".
      expect(product.imageFeature, isNull);
      expect(product.images, isEmpty);
    });

    test('does not set onSale, so the original price renders only once', () {
      // ProductPricing has two strike-through routes: one above the price keyed
      // on original_price, one inline keyed on onSale. Enabling both would show
      // the original price twice in the same tile.
      final product =
          wishlistProduct(regular: 'EGP 950.00', special: 'EGP 760.00');

      expect(product.onSale ?? false, isFalse);
    });
  });
}
