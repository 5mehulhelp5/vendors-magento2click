// Regression test for the wiped default address (ClickUp 86d3rrpqr follow-up).
//
// PUT /customers/me replaces the customer's ENTIRE address book, so any field
// left out of the payload is cleared server-side. `Addresses` never modelled
// `default_billing` / `default_shipping`, so MagentoService.saveUserInfo — which
// rebuilds the whole array from UserBox().addresses on every add, edit and
// delete — silently dropped them, and Magento cleared the shopper's default
// address. Losing the default also breaks the checkout pre-fill.
//
// The fix carries the flags across, matched by address id, from the last server
// copy held in UserBox().userInfo. That only works if the flags survive the full
// round trip: server JSON -> Addresses -> local storage -> Addresses again. This
// test pins that round trip.
//
// Payloads are built with jsonDecode rather than Dart map literals on purpose,
// for the same reason as checkout_default_address_test.dart: the app feeds these
// constructors the output of jsonDecode, where every value is `dynamic`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/user.dart';

void main() {
  group('Addresses default flags', () {
    test('parses the flags Magento sends on the default address', () {
      final json = jsonDecode('''
        {"id": 583, "customer_id": 388706, "default_billing": true,
         "default_shipping": true, "street": ["test"], "city": "Abou Al Matamer"}
      ''');

      final address = Addresses.fromJson(json);

      expect(address.id, 583);
      expect(address.defaultBilling, isTrue);
      expect(address.defaultShipping, isTrue);
    });

    test('treats the omitted keys on a non-default address as false, not null',
        () {
      // Magento omits these keys entirely rather than sending false, which is
      // what made `json['default_billing'] || ...` throw elsewhere.
      final json = jsonDecode('''
        {"id": 584, "customer_id": 388706, "street": ["test"], "city": "Cairo"}
      ''');

      final address = Addresses.fromJson(json);

      expect(address.defaultBilling, isFalse);
      expect(address.defaultShipping, isFalse);
    });

    test('emits the flags only for the default address', () {
      final defaultAddress = Addresses.fromJson(jsonDecode(
          '{"id": 583, "street": ["1 Default Street"], "default_billing": true,'
          ' "default_shipping": true}'));
      final otherAddress = Addresses.fromJson(
          jsonDecode('{"id": 584, "street": ["2 Secondary Street"]}'));

      expect(defaultAddress.toJson()['default_billing'], isTrue);
      expect(defaultAddress.toJson()['default_shipping'], isTrue);

      // Sending `false` explicitly would be harmless, but omitting matches what
      // the store itself returns and keeps the payload diff-able against it.
      expect(otherAddress.toJson().containsKey('default_billing'), isFalse);
      expect(otherAddress.toJson().containsKey('default_shipping'), isFalse);
    });

    test('flags survive the local-storage round trip', () {
      // saveUserInfo reads the prior flags back out of UserBox().userInfo, which
      // is persisted via User.toJson and restored via User.fromLocalJson. If
      // either side drops the flags the restore is a no-op and the defaults are
      // wiped again on the next address change.
      final user = User.fromMagentoJson(
        jsonDecode('''
          {"id": 388706, "email": "qa@example.com", "firstname": "QA",
           "lastname": "Tester",
           "addresses": [
             {"id": 583, "default_billing": true, "default_shipping": true,
              "street": ["1 Default Street"], "city": "Cairo"},
             {"id": 584, "street": ["2 Secondary Street"], "city": "Cairo"}
           ]}
        '''),
        'token',
      );

      final restored = User.fromLocalJson(jsonDecode(jsonEncode(user.toJson())));

      final byId = {for (final a in restored.addresses!) a.id: a};
      expect(byId[583]!.defaultBilling, isTrue);
      expect(byId[583]!.defaultShipping, isTrue);
      expect(byId[584]!.defaultBilling, isFalse);
      expect(byId[584]!.defaultShipping, isFalse);
    });
  });
}
