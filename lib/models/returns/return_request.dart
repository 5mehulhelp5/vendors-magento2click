import 'package:inspireui/inspireui.dart';

import 'return_parse.dart';
import 'return_policy.dart';

/// One line on a return: what was requested, approved and received.
class ReturnItem {
  String? sku;
  String? name;
  num? qtyRequested;
  num? qtyApproved;
  num? qtyReceived;
  String? reasonLabel;
  num? price;
  num? rowTotal;

  ReturnItem.fromJson(Map json) {
    sku = json['sku']?.toString();
    name = json['name']?.toString();
    qtyRequested = parseReturnNum(json['qty_requested']);
    qtyApproved = parseReturnNum(json['qty_approved']);
    qtyReceived = parseReturnNum(json['qty_received']);
    reasonLabel = json['reason_label']?.toString();
    price = parseReturnNum(json['price']);
    rowTotal = parseReturnNum(json['row_total']);
  }
}

/// A shipment-tracking row attached to a return (usually inbound).
class ReturnTrack {
  String? carrierCode;
  String? carrierTitle;
  String? trackNumber;
  String? direction; // 'inbound' | 'outbound'
  DateTime? createdAt;

  ReturnTrack.fromJson(Map json) {
    carrierCode = json['carrier_code']?.toString();
    carrierTitle = json['carrier_title']?.toString();
    trackNumber = json['track_number']?.toString();
    direction = json['direction']?.toString();
    createdAt = parseReturnDate(json['created_at']);
  }
}

/// A single entry in the return's status / message history.
class ReturnTimelineEntry {
  String? status;
  String? statusLabel;
  String? comment;
  String? authorType; // 'system' | 'customer' | 'admin'
  DateTime? createdAt;

  ReturnTimelineEntry.fromJson(Map json) {
    status = json['status']?.toString();
    statusLabel = json['status_label']?.toString();
    comment = json['comment']?.toString();
    authorType = json['author_type']?.toString();
    createdAt = parseReturnDate(json['created_at']);
  }

  bool get isFromCustomer => authorType == 'customer';
}

/// A customer return (RMA). One class serves the list summary, the full detail
/// and the create response — fields absent from a given payload simply stay
/// null / empty.
///
/// Render action buttons from the [canCancel] / [canAddTracking] /
/// [needsCustomerReply] flags, never by guessing from [status].
class ReturnRequest {
  int? entityId;
  String? incrementId;
  String? orderIncrementId;
  String? status;
  String? statusLabel;
  String? resolution;
  String? resolutionLabel;
  String? customerComment;
  String? returnAddress;
  num? refundAmount;
  DateTime? createdAt;
  int? itemCount;
  List<ReturnItem> items = [];
  List<ReturnTrack> tracks = [];
  List<ReturnTimelineEntry> timeline = [];
  List<ReturnOption> carriers = [];
  bool canCancel = false;
  bool canAddTracking = false;
  bool needsCustomerReply = false;

  ReturnRequest.fromJson(Map json) {
    try {
      entityId = parseReturnInt(json['entity_id']);
      incrementId = json['increment_id']?.toString();
      orderIncrementId = json['order_increment_id']?.toString();
      status = json['status']?.toString();
      statusLabel = json['status_label']?.toString();
      resolution = json['resolution']?.toString();
      resolutionLabel = json['resolution_label']?.toString();
      customerComment = json['customer_comment']?.toString();
      returnAddress = json['return_address']?.toString();
      refundAmount = parseReturnNum(json['refund_amount']);
      createdAt = parseReturnDate(json['created_at']);
      itemCount = parseReturnInt(json['item_count']);
      items = parseReturnList(json['items'], ReturnItem.fromJson);
      tracks = parseReturnList(json['tracks'], ReturnTrack.fromJson);
      timeline = parseReturnList(json['timeline'], ReturnTimelineEntry.fromJson);
      carriers = parseReturnList(json['carriers'], ReturnOption.fromJson);
      canCancel = json['can_cancel'] == true;
      canAddTracking = json['can_add_tracking'] == true;
      needsCustomerReply = json['needs_customer_reply'] == true;
      itemCount ??= items.isNotEmpty ? items.length : null;
    } catch (e) {
      printLog('ReturnRequest.fromJson $e');
    }
  }

  /// Item count for a list summary, falling back to the parsed [items] length
  /// when the summary payload omits `item_count`.
  int get displayItemCount => itemCount ?? items.length;
}
