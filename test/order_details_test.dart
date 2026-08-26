// Regression tests for the order-details defects in ClickUp 86d3rrauf.
//
// Two of them were wrong-field bugs against the Magento REST shape, and one was
// a status the app had no name for. All three payload shapes below are copied
// from real responses on testing.locafy.market (customer PII replaced):
//
//   * billing_address carries `telephone` and `country_id`. The app was reading
//     'mobile' and 'country' / 'countryId', which do not exist in a Magento
//     address — so the phone rendered as the literal word "null" and the
//     country came out blank (#4).
//   * A merchant can define any `status` string in the Magento admin. This
//     store uses `Delivered_to_be_invioced` (its own typo), `order_confirmed_cod`
//     and `approved`, none of which the OrderStatus enum names — they all
//     rendered as "Unknown" (#5). `state` is a fixed Magento vocabulary, so it
//     resolves them without the app having to know each store's status list.
//
// Payloads are built with jsonDecode rather than Dart map literals so the values
// are `dynamic`, matching what the parsers actually receive from the API.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/address.dart';
import 'package:magentoegypt/models/order/order.dart';
import 'package:magentoegypt/widgets/orders/tracking.dart';

void main() {
  group('Address.fromMagentoJson', () {
    // Shape taken from GET /V1/orders -> items[0].billing_address.
    Map<String, dynamic> billing() => jsonDecode('''
      {"firstname": "QA", "lastname": "Tester", "street": ["1 Test Street"],
       "city": "Abou Al Matamer", "region": "Al Beheira", "country_id": "EG",
       "telephone": "201002007878", "postcode": null}
    ''');

    test('reads the phone from `telephone`, not `mobile`', () {
      final address = Address.fromMagentoJson(billing());
      expect(address.phoneNumber, '201002007878');
    });

    test('reads the country from `country_id`', () {
      final address = Address.fromMagentoJson(billing());
      // The ISO-2 code, not a display name: toMagentoJson sends it back as
      // country_id and getCountryName renders it as "Egypt".
      expect(address.country, 'EG');
      expect(address.countryId, 'EG');
    });

    test('still parses the non-Magento key shapes it used to accept', () {
      // The `?? ` fallbacks must keep working for any caller passing the old
      // shape, so fixing the Magento path cannot regress them.
      final legacy = Address.fromMagentoJson(jsonDecode(
          '{"mobile": "01000000000", "country": "EG", "countryId": "EG"}'));
      expect(legacy.phoneNumber, '01000000000');
      expect(legacy.country, 'EG');
    });
  });

  group('parseOrderStatus', () {
    final order = Order();

    test('resolves a merchant-defined status through its state', () {
      // Statuses with no explicit case fall back to their state. (The store's
      // Delivered_to_be_invioced is NOT one of these — it has an explicit case
      // so it can light up the Shipping step; see the shipping test below.)
      expect(
        order.parseOrderStatus('order_confirmed_cod', state: 'new'),
        OrderStatus.pending,
      );
      expect(
        order.parseOrderStatus('approved', state: 'processing'),
        OrderStatus.processing,
      );
    });

    test('covers the rest of the fixed Magento state vocabulary', () {
      expect(order.parseOrderStatus('whatever', state: 'pending_payment'),
          OrderStatus.pending);
      expect(order.parseOrderStatus('whatever', state: 'payment_review'),
          OrderStatus.pending);
      expect(order.parseOrderStatus('whatever', state: 'closed'),
          OrderStatus.refunded);
      expect(order.parseOrderStatus('whatever', state: 'canceled'),
          OrderStatus.canceled);
      expect(order.parseOrderStatus('whatever', state: 'holded'),
          OrderStatus.onHold);
    });

    test('an explicitly known status still wins over the state fallback', () {
      // 'complete' is matched by the switch before the fallback is reached.
      expect(order.parseOrderStatus('complete', state: 'complete'),
          OrderStatus.completed);
      expect(order.parseOrderStatus('holded', state: 'holded'),
          OrderStatus.onHold);
      expect(order.parseOrderStatus('pending', state: 'new'),
          OrderStatus.pending);
    });

    test("a shipping-stage status reaches the timeline's Shipping step", () {
      // QA re-opened #5: the order is "in shipping" but showed no such step.
      // This store spells that stage Delivered_to_be_invioced (its own typo)
      // and files it under state `complete`, so it must be matched explicitly —
      // the state fallback would otherwise collapse it into Completed and the
      // shipping step would never light up.
      expect(
        order.parseOrderStatus('Delivered_to_be_invioced', state: 'complete'),
        OrderStatus.shipped,
      );
      // TimelineTracking switches on OrderStatus.content, so the enum name is
      // the contract between the parser and the Shipping step.
      expect(OrderStatus.shipped.content, 'shipped');
    });

    test('other backends calling without a state are unaffected', () {
      expect(order.parseOrderStatus('on-hold'), OrderStatus.onHold);
      expect(order.parseOrderStatus('refunded'), OrderStatus.refunded);
      expect(order.parseOrderStatus('out-for-delivery'),
          OrderStatus.outForDelivery);
      // Still Unknown when there is nothing at all to go on — the fallback adds
      // a route out, it does not invent one.
      expect(order.parseOrderStatus('some_custom_status'), OrderStatus.unknown);
      expect(order.parseOrderStatus('some_custom_status', state: 'bogus'),
          OrderStatus.unknown);
    });
  });

  group('resolveTimelineFlow', () {
    // The timeline is handed `OrderStatus.content` — an enum *name* — so every
    // case label has to be spelled the way describeEnum spells it. Twice now a
    // label was not: `on-hold` never matched `onHold`, so a held order fell
    // through to the default and stalled on Pending Payment with the On-hold
    // step still grey (86d3rrauf). Asserting the whole map, rather than the one
    // status that was reported, is what stops the next one slipping through.
    test('every status the timeline handles lands on its own step', () {
      const expected = {
        OrderStatus.pending: StatusOrder.pendding,
        OrderStatus.onHold: StatusOrder.onHold,
        OrderStatus.processing: StatusOrder.processing,
        OrderStatus.shipped: StatusOrder.shipping,
        OrderStatus.delivered: StatusOrder.shipping,
        OrderStatus.outForDelivery: StatusOrder.shipping,
        OrderStatus.driverAssigned: StatusOrder.shipping,
        OrderStatus.completed: StatusOrder.completed,
        OrderStatus.cancelled: StatusOrder.cancelled,
        OrderStatus.canceled: StatusOrder.cancelled,
        OrderStatus.refunded: StatusOrder.refunded,
        OrderStatus.failed: StatusOrder.failed,
      };

      expected.forEach((orderStatus, step) {
        expect(
          resolveTimelineFlow(orderStatus.content).current,
          step,
          reason: '${orderStatus.content} should stop on $step',
        );
      });
    });

    test('a held order marks Pending Payment and On-hold, nothing beyond', () {
      final flow = resolveTimelineFlow(OrderStatus.onHold.content);
      // _renderStatus activates every step up to and including this index.
      expect(flow.steps.indexOf(flow.current), 1);
      expect(flow.steps, kStatusOrderSuccessNotFail);
    });

    test('an unrecognised status still draws the pending flow', () {
      final flow = resolveTimelineFlow(OrderStatus.unknown.content);
      expect(flow.current, StatusOrder.pendding);
      expect(flow.steps, kStatusOrderSuccessNotFail);
    });
  });
}
