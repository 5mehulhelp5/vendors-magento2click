// Regression test for product photos silently turning into the store
// placeholder (86d3x5ex6).
//
// With kIsResizeImage on, the app asks for a "-small"/"-medium"/"-large"
// sibling of the media file. That is right for a raw catalog path
// (/media/catalog/product/s/e/foo.jpg), which really does have those siblings,
// but wrong for a URL that is already a Magento rendition
// (/media/catalog/product/cache/<hash>/s/e/foo.jpg): renditions have no
// siblings, so the request lands on a file that does not exist.
//
// What makes this worth pinning is the failure mode. This install answers a
// missing media file with HTTP 200 and the LOCAFY placeholder PNG rather than a
// 404, so nothing errors — the card just quietly shows the placeholder, and no
// error handler anywhere in the app can tell the difference. Verified against
// testing.locafy.market: appending "-medium" to a cache URL returns the exact
// same 15,529-byte placeholder as a deliberately bogus filename does.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/common/tools/image_tools.dart';
import 'package:magentoegypt/services/index.dart' show ServerConfig;

void main() {
  const media = 'https://testing.locafy.market/media/catalog/product';
  const cachePrefix = '$media/cache/ea90a1623f3f2944c5341ae0c5790169';

  group('formatImage', () {
    setUpAll(() => ServerConfig().setConfig({'type': 'magento'}));

    test('leaves an already-resized Magento rendition untouched', () {
      const url = '$cachePrefix/g/u/gucci-logo.png';

      expect(ImageTools.formatImage(url, kSize.medium), url);
      expect(ImageTools.formatImage(url, kSize.small), url);
      expect(ImageTools.formatImage(url, kSize.large), url);
    });

    test('still asks for the sibling of a raw catalog path', () {
      const url = '$media/s/e/set213213213_1_1.jpg';

      // Only assert the suffix so the test does not depend on whether the
      // resize flag happens to be on in this build's config.
      final medium = ImageTools.formatImage(url, kSize.medium)!;
      expect(
        medium == url || medium == '$media/s/e/set213213213_1_1-medium.jpg',
        isTrue,
        reason: 'raw paths keep the -medium rewrite: got $medium',
      );
    });

    test('a rendition is left alone whatever the file extension', () {
      for (final url in [
        '$cachePrefix/s/c/screenshot.png',
        '$cachePrefix/p/e/pexels.jpg',
        '$cachePrefix/a/b/photo.jpeg',
      ]) {
        expect(ImageTools.formatImage(url, kSize.medium), url);
      }
    });

    test('a null url stays null rather than throwing', () {
      expect(ImageTools.formatImage(null, kSize.medium), isNull);
    });
  });

  // Pull-to-refresh feeds this the product list, which arrives from a
  // CancelableOperation declared without a type argument — so the call is
  // statically dynamic and no cast is checked until runtime. An
  // Iterable<String?> parameter compiled cleanly and then threw
  // "MappedListIterable<Product, dynamic> is not a subtype of
  // Iterable<String?>" on device, inside the try block that loads products, so
  // the list came back empty and every search rendered "No Product".
  group('evictProductImages accepts what the callers actually pass', () {
    setUpAll(() {
      // clearMemoryImageCache() reaches PaintingBinding.instance.
      TestWidgetsFlutterBinding.ensureInitialized();
      ServerConfig().setConfig({'type': 'magento'});
    });

    test('a dynamic iterable of urls does not throw', () async {
      final dynamic urls = <Object?>[
        '$media/s/e/one.jpg',
        '$cachePrefix/s/e/two.jpg',
      ].map((e) => e);

      await expectLater(ImageTools.evictProductImages(urls), completes);
    });

    test('nulls and non-strings are skipped rather than throwing', () async {
      await expectLater(
        ImageTools.evictProductImages(<dynamic>[null, 42, '', 'not-a-url']),
        completes,
      );
    });

    test('an empty list is a no-op', () async {
      await expectLater(
          ImageTools.evictProductImages(const <dynamic>[]), completes);
    });

    // Emptying the caches alone left the old photo on screen: the URL is
    // unchanged, so the rebuilt widget's provider compares equal and Flutter
    // keeps the stream it already resolved. ImageResize mixes this counter
    // into each image's key so a refresh produces a fresh element.
    test('a refresh advances the generation the image keys are built from',
        () async {
      final before = ImageTools.refreshGeneration;

      await ImageTools.evictProductImages(
          <dynamic>['$media/s/e/one.jpg']);

      expect(ImageTools.refreshGeneration, greaterThan(before));
    });
  });
}
