// Tests for the 404 message handling in packages/inspireui/lib/utils/http_client.dart.
//
// `makeRequest` used to replace every 404 with the bare HTTP reason phrase
// ("Not Found"), discarding the response body. That is what hid ClickUp
// 86d3rytm0: the app requested a product by entity id instead of SKU, and
// Magento's actual explanation never reached the user.
//
// The bodies below are real responses from testing.locafy.market, captured with
// curl (PowerShell's error-stream handling silently reports these as empty):
//
//   GET /eg-en/rest/V1/products/40552
//     404 {"message":"The product that was requested doesn't exist. Verify the product and try again."}
//   GET /eg-en/rest/V1/products/test%2012/reviews
//     404 {"message":"Request does not match any route."}
//
// A 404 still throws by default — most callers of these helpers read the body
// without checking the status, so returning it would have them parse an error
// as data. Only the message carried by the throw changed.
//
// A call site that does branch on statusCode can opt out with
// `allowNotFound: true` and receive the 404 Response instead; the cart calls in
// magento_service use it to recreate an expired quote and retry. The
// makeRequest group below pins both halves of that contract.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:inspireui/utils/http_client.dart';

void main() {
  group('parseBackendErrorMessage', () {
    test('extracts the message Magento sends with a 404', () {
      // The exact body behind the "Not Found" toast in 86d3rytm0.
      expect(
        parseBackendErrorMessage(
            '{"message":"The product that was requested doesn\'t exist. Verify the product and try again."}'),
        "The product that was requested doesn't exist. Verify the product and try again.",
      );
      expect(
        parseBackendErrorMessage('{"message":"Request does not match any route."}'),
        'Request does not match any route.',
      );
    });

    test('fills Magento\'s positional %1 placeholders', () {
      expect(
        parseBackendErrorMessage(
            '{"message":"No such entity with %1 = %2","parameters":["cartId","4321"]}'),
        'No such entity with cartId = 4321',
      );
    });

    test('fills Magento\'s named %fieldName placeholders', () {
      // The shape behind the "No such entity" cart 404 that magento_service
      // documents at addUpdateItemsToCart.
      expect(
        parseBackendErrorMessage(
            '{"message":"No such entity with %fieldName = %fieldValue",'
            '"parameters":{"fieldName":"quoteId","fieldValue":"4321"}}'),
        'No such entity with quoteId = 4321',
      );
    });

    test('returns null for an HTML error page rather than a parser dump', () {
      // A store behind a WAF answers with HTML; showing a shopper a
      // FormatException dump would be worse than the reason phrase.
      expect(
          parseBackendErrorMessage('<html><head><title>404</title></head></html>'),
          isNull);
      expect(parseBackendErrorMessage('Not JSON at all'), isNull);
    });

    test('returns null when there is no usable message', () {
      expect(parseBackendErrorMessage(null), isNull);
      expect(parseBackendErrorMessage(''), isNull);
      expect(parseBackendErrorMessage('   '), isNull);
      expect(parseBackendErrorMessage('{}'), isNull);
      expect(parseBackendErrorMessage('{"message":""}'), isNull);
      expect(parseBackendErrorMessage('{"message":"   "}'), isNull);
      expect(parseBackendErrorMessage('{"message":null}'), isNull);
      // A JSON array is valid JSON but carries no message field.
      expect(parseBackendErrorMessage('[{"message":"nope"}]'), isNull);
      // Non-string message must not be coerced into "42".
      expect(parseBackendErrorMessage('{"message":42}'), isNull);
    });

    test('leaves a message alone when parameters are absent or unusable', () {
      expect(parseBackendErrorMessage('{"message":"Plain message"}'),
          'Plain message');
      expect(
          parseBackendErrorMessage(
              '{"message":"Unsubstituted %1","parameters":[]}'),
          'Unsubstituted %1');
      expect(
          parseBackendErrorMessage(
              '{"message":"Unsubstituted %1","parameters":null}'),
          'Unsubstituted %1');
    });
  });

  group('notFoundError', () {
    test('prefers the backend message over the reason phrase', () {
      final response = http.Response(
        '{"message":"The product that was requested doesn\'t exist."}',
        404,
        reasonPhrase: 'Not Found',
      );
      expect(notFoundError(response),
          "The product that was requested doesn't exist.");
    });

    test('falls back to the reason phrase when the body is unusable', () {
      // The old behaviour, kept for bodies that carry nothing to show — an
      // HTML error page from a WAF, or an empty body.
      expect(
        notFoundError(http.Response('<html>404</html>', 404,
            reasonPhrase: 'Not Found')),
        'Not Found',
      );
      expect(
        notFoundError(http.Response('', 404, reasonPhrase: 'Missing')),
        'Missing',
      );
    });

    test('never reports an empty message', () {
      // http.Response leaves reasonPhrase null when the server omits it, and a
      // blank snackbar would be worse than a generic one.
      expect(notFoundError(http.Response('', 404)), 'Not Found');
    });
  });

  group('makeRequest', () {
    // The body Magento actually returns for a stale/expired quote, captured
    // from testing.locafy.market:
    //   GET /eg-en/rest/V1/carts/999999999   (and the same on the default
    //   store view, which is Arabic — this string is untranslated on both)
    const noSuchEntity = '{"message":"No such entity with %fieldName = '
        '%fieldValue","parameters":{"fieldName":"cartId",'
        '"fieldValue":999999999}}';

    test('throws the backend message on a 404 by default', () async {
      // The fail-closed default that keeps the unguarded `jsonDecode(res.body)`
      // callers in magento_service from parsing an error payload as data.
      await expectLater(
        makeRequest(Future.value(http.Response(noSuchEntity, 404))),
        throwsA('No such entity with cartId = 999999999'),
      );
    });

    test('returns the 404 response when the call site opts in', () async {
      // What makes the recreate-and-retry in addUpdateItemsToCart reachable.
      final res = await makeRequest(
        Future.value(http.Response(noSuchEntity, 404)),
        allowNotFound: true,
      );
      expect(res.statusCode, 404);
      // The body has to survive intact — getErrorMessage substitutes the
      // %fieldName placeholders out of it to decide whether to recreate.
      expect(res.body, noSuchEntity);
    });

    test('allowNotFound changes nothing for other statuses', () async {
      for (final allow in [false, true]) {
        for (final status in [200, 400, 401, 500]) {
          final res = await makeRequest(
            Future.value(http.Response('{"message":"body"}', status)),
            allowNotFound: allow,
          );
          expect(res.statusCode, status,
              reason: 'status $status with allowNotFound: $allow');
        }
      }
    });

    test('allowNotFound does not swallow transport failures', () async {
      // Opting in to 404s must not turn "the socket failed" into a response —
      // the offline screen keys off this exact string.
      await expectLater(
        makeRequest(
          Future.error(const SocketException('Failed host lookup: example.com')),
          allowNotFound: true,
        ),
        throwsA('No Internet Connection'),
      );
      await expectLater(
        makeRequest(
          Future.error(const SocketException('Connection reset by peer')),
          allowNotFound: true,
        ),
        throwsA('Connection reset by peer'),
      );
    });
  });
}
