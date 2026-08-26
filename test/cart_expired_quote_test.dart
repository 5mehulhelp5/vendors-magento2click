// Pins the condition that triggers the cart recreate-and-retry in
// MagentoService.addUpdateItemsToCart.
//
// That recovery was unreachable dead code: it branches on `res.statusCode ==
// 404`, but makeRequest throws on a 404 before the caller sees a response, so
// the outer `catch (err) { rethrow; }` fired instead and a stale quote produced
// a hard cart failure. _sendCartItemRequest now passes `allowNotFound: true`
// (the reachability half is covered in http_error_message_test.dart).
//
// This file covers the other half: that the body Magento actually sends still
// satisfies the `No such entity` guard once getErrorMessage has substituted the
// placeholders. The bodies below were captured from testing.locafy.market.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_helper.dart';

void main() {
  group('expired-quote 404 recognition', () {
    test('the real Magento body satisfies the recreate guard', () {
      // GET /eg-en/rest/V1/carts/999999999 -> 404. Identical on the default
      // (Arabic) store view: this string is untranslated on both, which is what
      // makes matching prose tolerable here.
      final body = {
        'message': 'No such entity with %fieldName = %fieldValue',
        'parameters': {'fieldName': 'cartId', 'fieldValue': 999999999},
      };

      final message = MagentoHelper.getErrorMessage(body);

      expect(message, 'No such entity with cartId = 999999999');
      // The guard addUpdateItemsToCart applies.
      expect(message!.contains('No such entity'), isTrue);
    });

    test('a quoteId-keyed variant is recognised too', () {
      // Magento names the field after the repository that raised it, so the
      // field is not something to key off. Only the cartId form above was
      // observed on the backend; this pins that the guard matches on the
      // invariant prefix rather than the field name, so a quoteId-keyed 404
      // from the cart-item route would recover the same way.
      final message = MagentoHelper.getErrorMessage({
        'message': 'No such entity with %fieldName = %fieldValue',
        'parameters': {'fieldName': 'quoteId', 'fieldValue': '4321'},
      });

      expect(message, 'No such entity with quoteId = 4321');
      expect(message!.contains('No such entity'), isTrue);
    });

    test('an unrelated 404 does not trigger the recreate', () {
      // A 404 also covers "this SKU does not exist". Recreating the cart cannot
      // help there, and the shopper should get Magento's own explanation.
      final message = MagentoHelper.getErrorMessage({
        'message':
            "The product that was requested doesn't exist. Verify the product "
                'and try again.',
      });

      expect(message!.contains('No such entity'), isFalse);
    });
  });
}
