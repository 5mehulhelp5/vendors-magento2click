// Regression test for the wrong photo on a product card (86d3x5ex6).
//
// Magento marks one gallery image as *the* product image via `types`
// (image / small_image / thumbnail). It does not return the gallery in that
// order, so `media_gallery_entries[0]` is simply whichever row came back
// first. The app used that first row, and on this catalogue the two disagree:
// "test image product" (id 40554) carries a stray logo at position 1 with
// `types: []` and its real photo at position 2 with all four roles. Every grid
// showed the logo, while the website and the search suggestions — which read
// the role — showed the photo.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_helper.dart';
import 'package:magentoegypt/models/entities/product.dart';

void main() {
  group('orderedGalleryFiles', () {
    test('the roled image comes first, not the first row', () {
      // Exactly the shape the API returns for product 40554.
      final files = MagentoHelper.orderedGalleryFiles([
        {
          'position': 1,
          'types': <String>[],
          'file': '/g/u/gucci-logo-png_seeklogo-64069.png',
        },
        {
          'position': 2,
          'types': ['image', 'small_image', 'thumbnail', 'swatch_image'],
          'file': '/6/1/61c6x6flv4l._ac_sl1000_.jpg',
        },
      ]);

      expect(files.first, '/6/1/61c6x6flv4l._ac_sl1000_.jpg');
      expect(files, hasLength(2));
    });

    test('any one of the three roles is enough to win', () {
      for (final role in ['image', 'small_image', 'thumbnail']) {
        final files = MagentoHelper.orderedGalleryFiles([
          {'position': 1, 'types': <String>[], 'file': '/a/first.jpg'},
          {'position': 2, 'types': [role], 'file': '/b/roled.jpg'},
        ]);

        expect(files.first, '/b/roled.jpg', reason: 'role $role should win');
      }
    });

    // swatch_image alone does not make a photo the product image — Magento
    // uses it for the colour chip, which is often a crop or a flat colour.
    test('a swatch-only image does not outrank position order', () {
      final files = MagentoHelper.orderedGalleryFiles([
        {'position': 1, 'types': <String>[], 'file': '/a/first.jpg'},
        {'position': 2, 'types': ['swatch_image'], 'file': '/b/swatch.jpg'},
      ]);

      expect(files.first, '/a/first.jpg');
    });

    test('with no roles at all it falls back to position order', () {
      final files = MagentoHelper.orderedGalleryFiles([
        {'position': 3, 'types': <String>[], 'file': '/c/third.jpg'},
        {'position': 1, 'types': <String>[], 'file': '/a/first.jpg'},
        {'position': 2, 'types': <String>[], 'file': '/b/second.jpg'},
      ]);

      expect(files, ['/a/first.jpg', '/b/second.jpg', '/c/third.jpg']);
    });

    test('the other images are kept, in position order behind the roled one',
        () {
      final files = MagentoHelper.orderedGalleryFiles([
        {'position': 3, 'types': <String>[], 'file': '/c/third.jpg'},
        {'position': 1, 'types': ['thumbnail'], 'file': '/a/roled.jpg'},
        {'position': 2, 'types': <String>[], 'file': '/b/second.jpg'},
      ]);

      expect(files, ['/a/roled.jpg', '/b/second.jpg', '/c/third.jpg']);
    });

    test('junk in, empty out rather than a throw', () {
      expect(MagentoHelper.orderedGalleryFiles(null), isEmpty);
      expect(MagentoHelper.orderedGalleryFiles('not a list'), isEmpty);
      expect(MagentoHelper.orderedGalleryFiles([]), isEmpty);
      // A row with no file is dropped instead of becoming a "null" URL.
      expect(
        MagentoHelper.orderedGalleryFiles([
          {'position': 1, 'types': <String>[]}
        ]),
        isEmpty,
      );
    });

    test('a missing position sorts last instead of crashing', () {
      final files = MagentoHelper.orderedGalleryFiles([
        {'types': <String>[], 'file': '/z/no-position.jpg'},
        {'position': 1, 'types': <String>[], 'file': '/a/first.jpg'},
      ]);

      expect(files, ['/a/first.jpg', '/z/no-position.jpg']);
    });
  });

  group('cart lines use the roled image too', () {
    test('the row shows the product photo, not the first gallery entry', () {
      // Shape taken from a live quote: the roled photo sits third.
      final product = Product.fromShopJson({
        'item_id': 95720,
        'sku': 'CHILD-SKU',
        'name': 'Cozy High-Neck Knit Pullover',
        'price': 655.8,
        'qty': 1,
        'extension_attributes': {
          'media_gallery_entries': [
            {'position': 1, 'types': <String>[], 'file': '/c/o/edit3.jpg'},
            {'position': 2, 'types': <String>[], 'file': '/c/o/edit2.jpg'},
            {
              'position': 3,
              'types': ['image', 'small_image', 'thumbnail'],
              'file': '/c/o/edit1.jpg',
            },
          ],
        },
      }, 'https://testing.locafy.market');

      expect(product.imageFeature, contains('/c/o/edit1.jpg'));
      expect(product.images, hasLength(3));
    });
  });
}
