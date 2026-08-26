// Regression test for the logged-in checkout hang (ClickUp 86d3r3gpd).
//
// Magento omits `default_billing` / `default_shipping` from any address that
// isn't the default — verified against the live store, where a customer's
// non-default addresses carry neither key. The old predicate in
// User.fromMagentoJson was:
//
//     (item) => item['default_billing'] || item['default_shipping']
//
// which evaluates `null || null` on such an address and throws a TypeError.
// Because `firstWhere` short-circuits, it only threw when a NON-DEFAULT address
// came first in the list — which is why the bug looked intermittent, and why an
// account whose default happens to be first will never reproduce it.
//
// The throw was swallowed by the constructor's own catch, leaving `billing`
// null; getShippingAddress then hit the force-unwrapped getCustomerInfo and
// returned a null address, and checkout span forever waiting on shipping
// methods.
//
// Payloads are built with jsonDecode rather than Dart map literals on purpose:
// getUserInfo feeds this constructor the output of jsonDecode, so every value
// is `dynamic`. Typed literals give the list a non-nullable element type and
// change how firstWhere/orElse behave, which would test something the app
// never actually does.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/user.dart';

/// Address that is NOT the default: Magento omits both `default_*` keys
/// entirely rather than sending them as false.
String _nonDefault(int id) => '''
{
  "id": $id,
  "customer_id": 388706,
  "region": {"region": "Al Beheira", "region_id": 0},
  "country_id": "EG",
  "street": ["test"],
  "city": "Abou Al Matamer",
  "telephone": "201002007878",
  "firstname": "Test",
  "lastname": "test"
}''';

String _default(int id) => '''
{
  "id": $id,
  "customer_id": 388706,
  "default_billing": true,
  "default_shipping": true,
  "region": {"region": "Al Beheira", "region_id": 0},
  "country_id": "EG",
  "street": ["test"],
  "city": "Abou Al Matamer",
  "telephone": "201002007878",
  "firstname": "Test",
  "lastname": "test"
}''';

Map customer(List<String> addresses) => jsonDecode('''
{
  "id": 388706,
  "firstname": "Test",
  "lastname": "test",
  "email": "magento1team@gmail.com",
  "addresses": [${addresses.join(',')}],
  "custom_attributes": [
    {"attribute_code": "mobile", "value": "201002007878"}
  ]
}''') as Map;

void main() {
  group('the bug mechanism', () {
    // Replica of the OLD predicate, kept so the failure mode stays
    // demonstrable after the fix.
    bool oldPredicate(dynamic item) =>
        item['default_billing'] || item['default_shipping'];

    test('old predicate throws when the address is not the default', () {
      final addr = jsonDecode(_nonDefault(583));
      expect(() => oldPredicate(addr), throwsA(isA<TypeError>()));
    });

    test('old predicate survives when the address IS the default', () {
      // Short-circuits on the first operand — this is why accounts whose
      // default address sorts first never reproduced the hang.
      final addr = jsonDecode(_default(583));
      expect(oldPredicate(addr), isTrue);
    });
  });

  group('User.fromMagentoJson (fixed)', () {
    test('resolves billing when a NON-DEFAULT address comes first', () {
      // The exact shape that used to break checkout.
      final user =
          User.fromMagentoJson(customer([_nonDefault(583), _default(647)]), 't');

      expect(user.billing, isNotNull,
          reason: 'billing must resolve, or checkout gets a null address '
              'and hangs waiting for shipping methods');
      expect(user.shipping, isNotNull);
    });

    test('still resolves billing when the default comes first', () {
      final user =
          User.fromMagentoJson(customer([_default(583), _nonDefault(647)]), 't');

      expect(user.billing, isNotNull);
    });

    test('leaves billing null when the customer has no default at all', () {
      // firstWhere finds nothing and returns null via orElse. Must not throw —
      // the address step renders an empty form in that case.
      final user = User.fromMagentoJson(
          customer([_nonDefault(583), _nonDefault(584)]), 't');

      expect(user.billing, isNull);
    });

    test('handles a customer with no addresses', () {
      final user = User.fromMagentoJson(customer([]), 't');
      expect(user.billing, isNull);
    });
  });
}
