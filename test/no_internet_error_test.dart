// Tests for StringExtensions.isNoInternetError in
// packages/inspireui/lib/extensions/string_extension.dart.
//
// The getter decides whether lib/widgets/product/product_list.dart shows
// NoInternetConnection instead of the generic error text. It used to match only
// 'SocketException: Failed host lookup', which nothing in the app ever throws:
// `makeRequest` in packages/inspireui/lib/utils/http_client.dart catches that
// exact SocketException and rethrows the literal 'No Internet Connection', and
// every network call in the app goes through those helpers (no caller passes
// enableDio: true). So the offline screen was unreachable and an offline
// shopper got "There is an issue with the app during request the data, please
// contact admin for fixing the issues" instead.
//
// The literals asserted below are the contract between those two files. If
// http_client stops throwing 'No Internet Connection', this test is what should
// fail rather than the offline screen silently going dark again.

import 'package:flutter_test/flutter_test.dart';
import 'package:inspireui/extensions/string_extension.dart';

void main() {
  group('isNoInternetError', () {
    test('matches what the http helpers actually throw', () {
      // http_client.dart `makeRequest`, the path every network call takes.
      expect('No Internet Connection'.isNoInternetError, isTrue);
    });

    test('still matches a raw SocketException', () {
      // The other path: an exception that reaches a caller unwrapped, so the
      // message is the exception's own toString().
      expect(
        "SocketException: Failed host lookup: 'testing.locafy.market' "
                '(OS Error: No address associated with hostname, errno = 7)'
            .isNoInternetError,
        isTrue,
      );
    });

    test('matches once the models have wrapped it in their own sentence', () {
      // How the string actually arrives at ProductList.errMsg. Neither model
      // rethrows the bare error, so a whole-string comparison would never hit.
      expect(
        'There is an issue with the app during request the data, please '
                'contact admin for fixing the issues No Internet Connection'
            .isNoInternetError,
        isTrue,
      );
      // SearchModel's shorter wrapper.
      expect('⚠️ No Internet Connection'.isNoInternetError, isTrue);
    });

    test('leaves real backend errors to the generic error text', () {
      // A reachable server that answered with a problem is not an offline
      // device: showing "No Internet Connection" here would send a shopper off
      // to check their wifi over a 404 or an expired session.
      expect(''.isNoInternetError, isFalse);
      expect('Not Found'.isNoInternetError, isFalse);
      expect(
          "The product that was requested doesn't exist.".isNoInternetError,
          isFalse);
      expect(
          'The consumer isn\'t authorized to access resources.'.isNoInternetError,
          isFalse);
    });
  });
}
