import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart';
import '../../common/constants.dart';
import '../../generated/l10n.dart';

enum StatusOrder {
  pendding,
  onHold,
  failed,
  cancelled,
  processing,
  shipping,
  completed,
  refunded
}

// Shipping sits between Processing and Completed: an order that has left the
// warehouse but is not yet finalised used to have no step to land on, so it
// rendered as "unknown" (86d3rrauf #5).
const kStatusOrderSuccessNotFail = [
  StatusOrder.pendding,
  StatusOrder.onHold,
  StatusOrder.processing,
  StatusOrder.shipping,
  StatusOrder.completed
];

const kStatusOrderSuccessIsFail = [
  StatusOrder.pendding,
  StatusOrder.failed,
  StatusOrder.processing,
  StatusOrder.shipping,
  StatusOrder.completed
];

const kStatusOrderSuccessRefunded = [
  StatusOrder.pendding,
  StatusOrder.onHold,
  StatusOrder.processing,
  StatusOrder.shipping,
  StatusOrder.completed,
  StatusOrder.refunded
];

const kStatusOrderCancel = [
  StatusOrder.pendding,
  StatusOrder.failed,
  StatusOrder.cancelled
];

/// The step the timeline stops at, and the flow of steps it belongs to.
class TimelineFlow {
  final StatusOrder current;
  final List<StatusOrder> steps;

  const TimelineFlow(this.current, this.steps);
}

/// Maps an order status onto the step the timeline should highlight.
///
/// The argument is `OrderStatus.content` — an enum *name* from `describeEnum`,
/// not a raw backend status string, because that is what the only caller
/// (`renderOrderTimelineTracking`) passes. A case label spelled any other way
/// simply never matches: `on-hold` never saw `onHold`, so every held order fell
/// through to `default` and the timeline stalled on Pending Payment with the
/// On-hold step still grey (86d3rrauf). Enum names come first below; the
/// hyphenated spellings are kept as aliases for any caller passing a raw
/// status.
TimelineFlow resolveTimelineFlow(String? status) {
  switch (status) {
    case 'onHold': // Pendding(active) -> On-Hold(active) -> Processing -> Completed
    case 'on-hold':
      return const TimelineFlow(StatusOrder.onHold, kStatusOrderSuccessNotFail);

    case 'pending': // Pendding(active) -> On-Hold -> Processing -> Completed
    case 'pendding':
      return const TimelineFlow(
          StatusOrder.pendding, kStatusOrderSuccessNotFail);

    case 'processing': // Pendding(active) -> On-Hold(active) -> Processing(active) -> Completed
      return const TimelineFlow(
          StatusOrder.processing, kStatusOrderSuccessNotFail);

    // Both spellings: OrderStatus has a `canceled` value as well as
    // `cancelled`, and Magento's status string is the one-L spelling — so
    // cancelled orders were falling through to default and drawing the
    // *pending* timeline instead (86d3rrauf #5).
    case 'canceled':
    case 'cancelled': // Pendding(active) -> Failed(active) -> Cancelled(active)
      return const TimelineFlow(StatusOrder.cancelled, kStatusOrderCancel);

    case 'refunded': // Pendding(active) -> On-Hold(active) -> Processing(active) -> Completed(active) -> Refunded(active)
      return const TimelineFlow(
          StatusOrder.refunded, kStatusOrderSuccessRefunded);

    // Anything that means "on its way" lands on the Shipping step.
    case 'shipped':
    case 'delivered':
    case 'outForDelivery':
    case 'driverAssigned':
      return const TimelineFlow(
          StatusOrder.shipping, kStatusOrderSuccessNotFail);

    case 'completed': // Pendding(active) -> On-Hold(active) -> Processing(active) -> Completed(active)
      return const TimelineFlow(
          StatusOrder.completed, kStatusOrderSuccessNotFail);

    case 'failed': // Pendding(active) -> Failed(active) -> Processing -> Completed
      return const TimelineFlow(StatusOrder.failed, kStatusOrderSuccessIsFail);

    default:
      return const TimelineFlow(
          StatusOrder.pendding, kStatusOrderSuccessNotFail);
  }
}

class TimelineTracking extends StatefulWidget {
  final Axis axisTimeLine;
  final String? status;
  final DateTime? createdAt;
  final DateTime? dateModified;

  const TimelineTracking(
      {Key? key,
      this.axisTimeLine = Axis.vertical,
      this.status,
      this.createdAt,
      this.dateModified})
      : super(key: key);
  @override
  State<TimelineTracking> createState() => _TimelineTrackingState();
}

class _TimelineTrackingState extends State<TimelineTracking> {
  bool get isAxisVertical => widget.axisTimeLine == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    Widget renderMain;
    if (isAxisVertical) {
      renderMain = Column(children: _renderStatus(widget.status));
    } else {
      renderMain = Row(children: _renderStatus(widget.status));
    }

    return Center(
      child: Container(
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            color: Theme.of(context).primaryColorLight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
          child: SingleChildScrollView(
            scrollDirection: isAxisVertical ? Axis.vertical : Axis.horizontal,
            child: renderMain,
          )),
    );
  }

  String converTime(DateTime datetime) {
    var month =
        datetime.month < 10 ? '0${datetime.month}' : '${datetime.month}';
    return '${datetime.day}.$month.${datetime.year}';
  }

  Widget _renderItem(
      {required int index,
      DateTime? time,
      required String title,
      required String description,
      StatusOrder? status,
      StatusOrder? statusCurrent,
      required bool isActive,
      bool showLine = true}) {
    Widget date = SizedBox(
      width: isAxisVertical ? MediaQuery.of(context).size.width * 0.2 : null,
      height: 25.0,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          time != null ? converTime(time) : '',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );

    var contentInLine = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Center(
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
                color:
                    isActive ? Theme.of(context).primaryColor : Colors.black54,
                borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      showLine
          ? _buildLine(true, isActive && status != statusCurrent)
          : const SizedBox()
    ];

    Widget content = SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        height: description.isEmpty ? 25.0 : null,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              description.isEmpty
                  ? const SizedBox(
                      width: 0.0,
                      height: 0.0,
                    )
                  : Text(
                      description,
                      style: const TextStyle(fontSize: 10),
                    )
            ],
          ),
        ));

    if (isAxisVertical) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          date,
          Column(
            children: contentInLine,
          ),
          const SizedBox(width: 4),
          content
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: content,
          ),
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: contentInLine)),
          date
        ],
      );
    }
  }

  Widget _buildLine(bool visible, bool isActive) {
    return Container(
      width: isAxisVertical ? (visible ? 2.0 : 0.0) : double.infinity,
      height: isAxisVertical ? 30 : (visible ? 2.0 : 0.0),
      color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade400,
    );
  }

  List<Widget> _renderStatus(String? status) {
    var listStatus = <Widget>[];
    final flow = resolveTimelineFlow(status);
    final statusOrder = flow.current;
    final flowHandleStatus = flow.steps;

    for (var i = 0; i < flowHandleStatus.length; i++) {
      listStatus.add(_renderItem(
          index: i,
          statusCurrent: statusOrder,
          isActive: i <= flowHandleStatus.indexOf(statusOrder),
          title: getTitleStatus(flowHandleStatus[i]),
          showLine: i < (flowHandleStatus.length - 1),
          status: flowHandleStatus[i],
          time: i == 0
              ? widget.createdAt
              : (i == flowHandleStatus.indexOf(statusOrder)
                  ? widget.dateModified
                  : null),
          description: ''));
    }
    return listStatus;
  }

  Color getColor(StatusOrder status) {
    switch (status) {
      case StatusOrder.onHold:
        return HexColor(kOrderStatusColor['on-hold']!);
      case StatusOrder.pendding:
        return HexColor(kOrderStatusColor['pendding']!);
      case StatusOrder.failed:
        return HexColor(kOrderStatusColor['failed']!);
      case StatusOrder.completed:
        return HexColor(kOrderStatusColor['completed']!);
      case StatusOrder.cancelled:
        return HexColor(kOrderStatusColor['cancelled']!);
      case StatusOrder.refunded:
        return HexColor(kOrderStatusColor['refunded']!);
      case StatusOrder.processing:
        return HexColor(kOrderStatusColor['processing']!);
      case StatusOrder.shipping:
        return HexColor(kOrderStatusColor['shipping']!);
      default:
        return Colors.white;
    }
  }

  String getTitleStatus(StatusOrder status) {
    switch (status) {
      case StatusOrder.onHold:
        return S.of(context).orderStatusOnHold;
      case StatusOrder.pendding:
        return S.of(context).orderStatusPendingPayment;
      case StatusOrder.failed:
        return S.of(context).orderStatusFailed;
      case StatusOrder.processing:
        return S.of(context).orderStatusProcessing;
      case StatusOrder.shipping:
        return S.of(context).orderStatusShipped;
      case StatusOrder.completed:
        return S.of(context).orderStatusCompleted;
      case StatusOrder.cancelled:
        return S.of(context).orderStatusCancelled;
      case StatusOrder.refunded:
        return S.of(context).orderStatusRefunded;
      default:
        return '';
    }
  }
}
