import 'package:inspireui/inspireui.dart';

import 'return_parse.dart';

/// A single line item that is still eligible to be returned from an order.
/// Use [orderItemId] (not product id or sku) as the key when building the
/// create payload; [returnableQty] is the max you may request for this line.
class ReturnableItem {
  int? orderItemId;
  String? sku;
  String? name;
  num returnableQty = 0;
  num? price;

  ReturnableItem.fromJson(Map json) {
    orderItemId = parseReturnInt(json['order_item_id']);
    sku = json['sku']?.toString();
    name = json['name']?.toString();
    returnableQty = parseReturnNum(json['returnable_qty']) ?? 0;
    price = parseReturnNum(json['price']);
  }
}

/// An order that has at least one returnable line, with the specific items and
/// their remaining returnable quantities.
class ReturnableOrder {
  int? orderId;
  String? orderIncrementId;
  DateTime? createdAt;
  List<ReturnableItem> items = [];

  ReturnableOrder.fromJson(Map json) {
    try {
      orderId = parseReturnInt(json['order_id']);
      orderIncrementId = json['order_increment_id']?.toString();
      createdAt = parseReturnDate(json['created_at']);
      items = parseReturnList(json['items'], ReturnableItem.fromJson);
    } catch (e) {
      printLog('ReturnableOrder.fromJson $e');
    }
  }
}

/// One line the customer has chosen to return — the typed input for
/// `createReturn`. Serializes to camelCase `{orderItemId, qty, reason}`, which
/// is how the endpoint receives its typed parameter.
class ReturnLineInput {
  ReturnLineInput({
    required this.orderItemId,
    required this.qty,
    required this.reason,
  });

  final int orderItemId; // from ReturnableItem.orderItemId
  final num qty; // 1 <= qty <= ReturnableItem.returnableQty
  final String reason; // a code from ReturnPolicy.reasons

  Map<String, dynamic> toJson() => {
        'orderItemId': orderItemId,
        'qty': qty,
        'reason': reason,
      };
}
