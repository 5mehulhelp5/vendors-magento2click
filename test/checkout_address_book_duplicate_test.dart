// Regression test for ClickUp 86d3tkj56 #1: a newly created customer's first
// order left TWO identical entries in the address book.
//
// On order placement Magento copies BOTH the quote's billing address and its
// shipping address into the customer's address book (one becomes
// default_billing, the other default_shipping). The checkout posts the SAME
// Address object as both -- see the addressInformation payload in
// MagentoService.getPaymentMethods -- and `toMagentoJson` carried no
// `save_in_address_book` flag, so Magento stored the address twice.
//
// The fix flags exactly ONE of the pair (the shipping address) and leaves every
// other caller unflagged: the shipping estimate, the tax lookup and the order's
// own billing_address are all read-only and must never write the address book.
// These tests pin that contract, because it lives in a payload map where a
// regression is silent until QA counts the entries again.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/address.dart';

void main() {
  Address buildAddress() => Address(
        firstName: 'Test',
        lastName: 'Guest',
        country: 'EG',
        // state = governorate (Magento region), city = district.
        state: 'القاهرة',
        city: 'البساتين',
        street: '50 شارع محمد حلمي',
        phoneNumber: '1147375697',
      );

  Map addressPayload(Address address, {bool saveInAddressBook = false}) =>
      address.toMagentoJson(saveInAddressBook: saveInAddressBook)['address']
          as Map;

  group('Address.toMagentoJson save_in_address_book', () {
    test('is off by default so read-only callers never write the book', () {
      expect(addressPayload(buildAddress())['save_in_address_book'], 0);
    });

    test('turns on only when the caller explicitly opts in', () {
      expect(
        addressPayload(buildAddress(), saveInAddressBook: true)[
            'save_in_address_book'],
        1,
      );
    });

    test('the checkout pair flags exactly one of the two addresses', () {
      // Mirrors the addressInformation payload the checkout posts: the same
      // address object sent as both shipping and billing.
      final source = buildAddress();
      final shipping = addressPayload(source, saveInAddressBook: true);
      final billing = addressPayload(source);

      final flagged = [shipping, billing]
          .where((a) => a['save_in_address_book'] == 1)
          .length;

      expect(flagged, 1,
          reason: 'flagging both is exactly what saved the address twice');
    });

    test('flagging does not disturb the rest of the address payload', () {
      // The flag is additive: region/city/street still carry the same values,
      // so the order itself is unaffected by which copy is flagged.
      final flagged = addressPayload(buildAddress(), saveInAddressBook: true);
      final plain = addressPayload(buildAddress());

      for (final key in ['country_id', 'region', 'city', 'telephone']) {
        expect(flagged[key], plain[key], reason: '$key must not change');
      }
    });
  });
}
