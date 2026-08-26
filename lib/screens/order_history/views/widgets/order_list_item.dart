import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inspireui/inspireui.dart';
import '../../../../common/constants.dart';
import '../../../../common/tools.dart';
import '../../../../generated/l10n.dart';
import '../../../../models/index.dart';
import '../../index.dart';

class OrderListItem extends StatelessWidget {
  const OrderListItem({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Center(
      child: Consumer<OrderHistoryDetailModel>(builder: (_, model, __) {
        final order = model.order;
        final currencyCode =
            order.currencyCode ?? Provider.of<AppModel>(context).currencyCode;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(
              RouteList.orderDetail,
              arguments: OrderDetailArguments(
                model: model,
              ),
            );
          },
          child: Container(
            width: size.width,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                )
              ],
            ),
            margin: const EdgeInsets.only(
              top: 12.0,
              left: 15.0,
              right: 15.0,
              bottom: 8.0,
            ),
            child: Column(
              children: [
                // Compact order-summary header: date and order number only.
                // The product image, product name and customer/address line
                // were removed (86d3tkhgz #5) — a summary card shouldn't pose as
                // a single product — and the card was shortened so the empty
                // space they used to occupy is gone. Every product is still
                // listed on the detail screen this card opens.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 8.0),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14.0),
                      topRight: Radius.circular(14.0),
                    ),
                    color: Theme.of(context).colorScheme.background,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.of(context).createdOn +
                              DateFormat('d MMM, HH:mm')
                                  .format(order.createdAt!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    fontSize: 12.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.8),
                                  ),
                        ),
                      ),
                      Text(
                        S.of(context).orderNo + order.number.toString(),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                // Divider(
                //   height: 1,
                //   color: Theme.of(context).primaryColorLight,
                // ),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14.0),
                        bottomRight: Radius.circular(14.0),
                      ),
                      color: Theme.of(context).colorScheme.background,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Theme.of(context).primaryColorLight,
                      ),
                      margin: const EdgeInsets.all(8),
                      padding: EdgeInsets.only(
                          right: Tools.isRTL(context) ? 0.0 : 8,
                          left: !Tools.isRTL(context) ? 0.0 : 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 10,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                          ),
                          // Total and Status hold the widest content
                          // (formatted price, status label), so they get more
                          // of the row than Tax/Qty (86d3tkhgz).
                          OrderStatusWidget(
                            title: S.of(context).total,
                            detail: PriceTools.getCurrencyFormatted(
                                order.total, null,
                                currency: currencyCode),
                            flex: 3,
                          ),
                          OrderStatusWidget(
                            title: S.of(context).tax,
                            detail: PriceTools.getCurrencyFormatted(
                                order.totalTax, null,
                                currency: currencyCode),
                            flex: 2,
                          ),
                          OrderStatusWidget(
                            title: S.of(context).qty,
                            detail: order.quantity.toString(),
                            flex: 1,
                          ),
                          if (order.status != null)
                            OrderStatusWidget(
                              title: S.of(context).status,
                              detail: order.status == OrderStatus.unknown &&
                                      order.orderStatus != null
                                  ? order.orderStatus
                                  : order.status!.content,
                              flex: 3,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class OrderStatusWidget extends StatelessWidget {
  final String? title;
  final String? detail;
  final int flex;

  const OrderStatusWidget({Key? key, this.title, this.detail, this.flex = 1})
      : super(key: key);

  String getTitleStatus(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'onhold':
        return S.of(context).orderStatusOnHold;
      case 'pending':
        return S.of(context).orderStatusPendingPayment;
      case 'failed':
        return S.of(context).orderStatusFailed;
      case 'processing':
        return S.of(context).orderStatusProcessing;
      case 'completed':
        return S.of(context).orderStatusCompleted;
      case 'cancelled':
        return S.of(context).orderStatusCancelled;
      case 'refunded':
        return S.of(context).orderStatusRefunded;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    late Color statusOrderColor = Colors.black;
    switch (detail!.toLowerCase()) {
      case 'pending':
        {
          statusOrderColor = Colors.red;
          break;
        }
      case 'processing':
        {
          statusOrderColor = Colors.orange;
          break;
        }
      case 'completed':
        {
          statusOrderColor = Colors.green;
          break;
        }
    }

    return Expanded(
      flex: flex,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            height: 10.0,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title.toString(),
                maxLines: 1,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(
                      fontSize: 14.0,
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    )
                    .apply(fontSizeFactor: 0.9),
              ),
            ),
          ),
          Expanded(
            // Scale the value to fit its column instead of ellipsizing —
            // "EGP5,730.00" and long status labels used to clip to "EGP940…" /
            // "Pending…" (86d3tkhgz).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                getTitleStatus(detail!, context).capitalize(),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: statusOrderColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
