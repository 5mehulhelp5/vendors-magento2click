// Regression test for ClickUp 86d3g53f8 (retest): the checkout payment method
// names stayed in Arabic after switching the app to English.
//
// Magento returns each method's `title` in the language of the CART's store
// view, not the app's. A registered customer's quote keeps whatever store it
// was created on, so switching the app language never changed the names, while
// guests were fine (their cart is created fresh on the current store view).
// Verified against testing.locafy.market: the SAME quote returns Arabic titles
// over BOTH the eg-en and the eg-ar REST path, so the store view in the request
// URL cannot fix it -- the name has to be resolved app-side, which is what
// PaymentMethodItem._localizedTitle does.
//
// This test pins the strings that mapping depends on. It matters more than a
// usual l10n check because this project hand-edits the generated l10n files
// (no intl_utils run): a missing entry in messages_ar.dart does NOT fail the
// build, it silently falls back to English -- i.e. exactly the bug we are
// fixing would come back unnoticed.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/generated/l10n.dart';

void main() {
  group('payment method names follow the app language', () {
    test('Arabic resolves to the store\'s Arabic titles', () async {
      await S.load(const Locale('ar'));

      expect(S.current.paymentMethodCashOnDelivery, 'دفع عند الاستلام');
      expect(S.current.paymentMethodOnlineCard, 'دفع إلكتروني (فيزا-ماستر كارد)');
      expect(S.current.paymentMethodSympl, 'سيمبل');
    });

    test('English resolves to the store\'s English titles', () async {
      await S.load(const Locale('en'));

      expect(S.current.paymentMethodCashOnDelivery, 'Cash On Delivery (COD)');
      expect(S.current.paymentMethodOnlineCard,
          'Secure online payment by Visa / MasterCard');
      expect(S.current.paymentMethodSympl,
          'Pay later in 3 installments with Sympl');
    });

    test('switching locale actually changes the resolved name', () async {
      // The bug was that the name did NOT change when the language did, so pin
      // the transition rather than only the two end states.
      await S.load(const Locale('ar'));
      final arabic = S.current.paymentMethodCashOnDelivery;

      await S.load(const Locale('en'));
      final english = S.current.paymentMethodCashOnDelivery;

      expect(arabic, isNot(equals(english)),
          reason: 'the name must follow the app language, not the cart store');
    });
  });
}
