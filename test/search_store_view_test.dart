// The search preview has to run against the same store view as the results
// page it leads to (86d3xea48).
//
// The catalogue differs per store view, so the counts legitimately differ:
// on testing.locafy.market "shirt" is 208 products on eg-en and 193 on eg-ar,
// and both the MageWorx autocomplete and V1/search agree with the storefront
// within each view. The app used to pin the autocomplete URL to eg-en while
// the results page honoured the app language, so an Arabic shopper was shown
// an English preview of 208 and then a page of 193.
//
// This pins the URL builder the preview now uses, since that mismatch is
// invisible in English — the language most testing happens in.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/common/config.dart';
import 'package:magentoegypt/env.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_helper.dart';

void main() {
  const domain = 'https://testing.locafy.market';
  const path = 'mageworx_searchsuiteautocomplete/ajax/index/?q=shirt';

  group('storefrontUrl follows the app language', () {
    // The mapping lives in the app config (env `languagesInfo`), not in code,
    // so load the real one rather than asserting against a fixture.
    setUpAll(() => Configurations().setConfigurationValues(environment));

    test('Arabic resolves to the Arabic store view', () {
      expect(
        MagentoHelper.storefrontUrl(domain, path, 'ar'),
        '$domain/eg-ar/$path',
      );
    });

    test('English resolves to the English store view', () {
      expect(
        MagentoHelper.storefrontUrl(domain, path, 'en'),
        '$domain/eg-en/$path',
      );
    });

    test('an unset or unknown language falls back to eg-en', () {
      for (final locale in [null, '', 'fr', 'zz']) {
        expect(
          MagentoHelper.storefrontUrl(domain, path, locale),
          '$domain/eg-en/$path',
          reason: 'locale $locale should fall back',
        );
      }
    });

    test('the REST builder maps the same way, so preview and results agree',
        () {
      expect(
        MagentoHelper.buildUrl(domain, 'search', 'ar').toString(),
        '$domain/eg-ar/rest/V1/search',
      );
      expect(
        MagentoHelper.buildUrl(domain, 'search', 'en').toString(),
        '$domain/eg-en/rest/V1/search',
      );
    });
  });
}
