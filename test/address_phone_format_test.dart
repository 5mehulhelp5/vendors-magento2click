// Regression test for ClickUp 86d3rrpqr: the address book could not add, edit
// or delete an address.
//
// The form's phone widget returns the dial code joined to the national number
// (`+201020104267`), and nothing between there and the API converted it, so
// Magento rejected the save with "Please enter a valid mobile number for Egypt
// (for example 01012345678)". That message is server-side — the app's own
// wording is different ("a 10-digit phone number with no spaces and no leading
// 0"), so it could only have come from Magento.
//
// Because `saveUserInfo` PUTs the customer's ENTIRE address book, one stored
// address in the wrong shape failed every save — which is why deleting broke
// too, and why normalisation is applied to every address in the payload.
//
// Scope note, checked against testing.locafy.market: the 15 most recent orders
// carry billing phones in `+20…`, `20…`, `01…` and even 1-character junk, so
// checkout applies no phone validation at all. The validator is specific to the
// `customers/me` save, which is why Address.toMagentoJson is left alone.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_helper.dart';

void main() {
  group('MagentoHelper.normalizePhoneForMagento', () {
    test('converts the widget\'s +20 form to the local 0 form', () {
      // Exactly what QA had on screen when the save was rejected.
      expect(MagentoHelper.normalizePhoneForMagento('+201020104267'),
          '01020104267');
    });

    test('accepts the same number however it was stored', () {
      // All four are the same subscriber, and all must reach Magento
      // identically, because the whole address book is re-sent on every save.
      for (final stored in [
        '+201020104267',
        '201020104267',
        '1020104267',
        '01020104267',
      ]) {
        expect(MagentoHelper.normalizePhoneForMagento(stored), '01020104267',
            reason: '$stored should normalise to the local form');
      }
    });

    test('tolerates the separators a pasted number arrives with', () {
      expect(MagentoHelper.normalizePhoneForMagento('+20 102 010 4267'),
          '01020104267');
      expect(
          MagentoHelper.normalizePhoneForMagento('(+20) 102-010-4267'),
          '01020104267');
    });

    test('does not mistake a leading 20 in a 10-digit number for the dial code',
        () {
      // The dial code is only stripped when what remains is still a full
      // national number, so this keeps all ten digits and just gains the
      // leading zero — it must not be truncated to 0 + 8 digits.
      expect(MagentoHelper.normalizePhoneForMagento('2012345678'),
          '02012345678');
    });

    test('hands back anything it cannot recognise, unchanged', () {
      // Normalising formatting is in scope; inventing digits is not.
      expect(MagentoHelper.normalizePhoneForMagento('12345'), '12345');
      expect(MagentoHelper.normalizePhoneForMagento(''), '');
      expect(MagentoHelper.normalizePhoneForMagento(null), null);
      expect(MagentoHelper.normalizePhoneForMagento('not a number'),
          'not a number');
    });
  });

  // Regression test for ClickUp 86d3tmxra item 2: the checkout phone check
  // rejected valid numbers stored in the local `01…` form (that's how a saved
  // address arrives), showing "enter a 10-digit number with no leading 0" and
  // blocking checkout. egyptianNationalNumber must treat every stored form as
  // the same 10-digit subscriber so the check passes.
  group('MagentoHelper.egyptianNationalNumber', () {
    test('collapses every stored form to the same 10-digit national number',
        () {
      for (final input in [
        '+201147375697',
        '201147375697',
        '01147375697', // the local form a saved address stores — was rejected
        '1147375697',
        '+20 114 737 5697',
        '(+20) 114-737-5697',
      ]) {
        expect(MagentoHelper.egyptianNationalNumber(input), '1147375697',
            reason: '$input should map to the national number');
      }
    });

    test('keeps a 10-digit number that merely starts with 20', () {
      // Only 10 digits remain, so "20" is data here, not the dial code.
      expect(MagentoHelper.egyptianNationalNumber('2012345678'), '2012345678');
    });

    test('returns the bare digits for empty/unrecognised input', () {
      // The caller still length-checks; this only normalises formatting.
      expect(MagentoHelper.egyptianNationalNumber(''), '');
      expect(MagentoHelper.egyptianNationalNumber(null), '');
      expect(MagentoHelper.egyptianNationalNumber('12345'), '12345');
    });
  });
}
