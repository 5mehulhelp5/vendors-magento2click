import 'dart:async';

import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart' show CartModel, Order;
import '../../services/index.dart';
import '../../widgets/product/product_bottom_sheet.dart';
import '../base_screen.dart';
import 'review_screen.dart';
import 'widgets/payment_methods.dart';
import 'widgets/shipping_address.dart';
import 'widgets/success.dart';

class CheckoutArgument {
  final bool? isModal;

  const CheckoutArgument({this.isModal});
}

class Checkout extends StatefulWidget {
  final bool? isModal;

  const Checkout({super.key, this.isModal});

  @override
  BaseScreen<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends BaseScreen<Checkout> {
  int tabIndex = 0;
  Order? newOrder;
  bool isPayment = false;
  bool isLoading = false;
  bool enabledShipping = kPaymentConfig.enableShipping;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final cartModel = Provider.of<CartModel>(context, listen: false);

      setState(() {
        enabledShipping = cartModel.isEnabledShipping();
      });
    });
  }

  void setLoading(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (!kPaymentConfig.enableAddress) {
      setState(() {
        tabIndex = 1;
      });
      if (!enabledShipping) {
        setState(() {
          tabIndex = 2;
        });
        if (!kPaymentConfig.enableReview) {
          setState(() {
            tabIndex = 3;
            isPayment = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget progressBar = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        kPaymentConfig.enableAddress
            ? Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      tabIndex = 0;
                    });
                  },
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          S.of(context).address.toUpperCase(),
                          style: TextStyle(
                              color: tabIndex == 0
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      tabIndex >= 0
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(2.0),
                                  bottomLeft: Radius.circular(2.0)),
                              child: Container(
                                  height: 3.0,
                                  color: Theme.of(context).primaryColor),
                            )
                          : Divider(
                              height: 2,
                              color: Theme.of(context).colorScheme.secondary)
                    ],
                  ),
                ),
              )
            : const SizedBox(),
        enabledShipping
            ? Expanded(
                child: GestureDetector(
                  onTap: () {
                    // if (cartModel.address != null &&
                    //     cartModel.address!.isValid()) {
                    //   setState(() {
                    //     tabIndex = 1;
                    //   });
                    // }
                  },
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          S.of(context).shipping.toUpperCase(),
                          style: TextStyle(
                              color: tabIndex == 1
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      tabIndex >= 1
                          ? Container(
                              height: 3.0,
                              color: Theme.of(context).primaryColor)
                          : Divider(
                              height: 2,
                              color: Theme.of(context).colorScheme.secondary)
                    ],
                  ),
                ),
              )
            : const SizedBox(),
        kPaymentConfig.enableReview
            ? Expanded(
                child: GestureDetector(
                  onTap: () {
                    // if (cartModel.shippingMethod != null) {
                    //   setState(() {
                    //     tabIndex = 2;
                    //   });
                    // }
                  },
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          S.of(context).review.toUpperCase(),
                          style: TextStyle(
                            color: tabIndex == 2
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).colorScheme.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      tabIndex >= 2
                          ? Container(
                              height: 3.0,
                              color: Theme.of(context).primaryColor)
                          : Divider(
                              height: 2,
                              color: Theme.of(context).colorScheme.secondary)
                    ],
                  ),
                ),
              )
            : const SizedBox(),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // if (cartModel.shippingMethod != null) {
              //   setState(() {
              //     tabIndex = 3;
              //   });
              // }
            },
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    S.of(context).payment.toUpperCase(),
                    style: TextStyle(
                      color: tabIndex == 3
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                tabIndex >= 3
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(2.0),
                            bottomRight: Radius.circular(2.0)),
                        child: Container(
                            height: 3.0, color: Theme.of(context).primaryColor),
                      )
                    : Divider(
                        height: 2,
                        color: Theme.of(context).colorScheme.secondary)
              ],
            ),
          ),
        )
      ],
    );

    return Stack(
      children: <Widget>[
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            centerTitle: true,
            elevation: 1,
            backgroundColor: Theme.of(context).colorScheme.background,
            title: Text(
              S.of(context).checkout,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            actions: <Widget>[
              if (widget.isModal != null && widget.isModal == true)
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.popUntil(
                          context, (Route<dynamic> route) => route.isFirst);
                    } else {
                      ExpandingBottomSheet.of(context, isNullOk: true)?.close();
                    }
                  },
                ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: newOrder != null
                ? OrderedSuccess(order: newOrder)
                : Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              getTabTitle(tabIndex),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                              style: AppStyle.txtArchivoSemiBold18Black900,
                            ),
                            Container(
                              margin: getMargin(
                                top: 21,
                                bottom: 3,
                                left: 25,
                                right: 25,
                              ),
                              child: Row(
                                children: [
                                  CircleWidget(
                                    size: 12,
                                    color: tabIndex >= 0
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  DashedBorderDivider(
                                    color: tabIndex >= 1
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  CircleWidget(
                                    size: 12,
                                    color: tabIndex >= 1
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  DashedBorderDivider(
                                    color: tabIndex >= 2
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  CircleWidget(
                                    size: 12,
                                    color: tabIndex >= 2
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  DashedBorderDivider(
                                    color: tabIndex >= 3
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                  CircleWidget(
                                    size: 12,
                                    color: tabIndex >= 3
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).dividerColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      !isPayment ? progressBar : const SizedBox(),
                      Expanded(
                        /// Will render with animation, fix later
                        // child: AnimatedSwitcher(
                        //   duration: const Duration(milliseconds: 250),
                        //   reverseDuration: const Duration(milliseconds: 250),
                        //   transitionBuilder:
                        //       (Widget child, Animation<double> animation) {
                        //     final inAnimation = Tween<Offset>(
                        //         begin: Offset(1.0, 0.0),
                        //         end: Offset(0.0, 0.0))
                        //         .animate(animation);
                        //     final outAnimation = Tween<Offset>(
                        //         begin: Offset(-1.0, 0.0),
                        //         end: Offset(0.0, 0.0))
                        //         .animate(animation);
                        //     if (true) {
                        //       return SlideTransition(
                        //         position: inAnimation,
                        //         child: child,
                        //       );
                        //     } else {
                        //       return SlideTransition(
                        //         position: outAnimation,
                        //         child: child,
                        //       );
                        //     }
                        //   },
                        //   child: renderContent(),
                        // ),
                        child: renderContent(),
                      )
                    ],
                  ),
          ),
        ),
        isLoading
            ? Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.white.withOpacity(0.36),
                child: kLoadingWidget(context),
              )
            : const SizedBox()
      ],
    );
  }

  String getTabTitle(int tabIndex) {
    //'1.Personal Info';

    switch (tabIndex) {
      case 0:
        return S.of(context).selectAddress.toUpperCase();
      case 1:
        return S.of(context).shipping.toUpperCase();
      case 2:
        return S.of(context).shipping.toUpperCase();
      case 3:
        return S.of(context).payment.toUpperCase();
      default:
        return '';
    }
  }

  Widget renderContent() {
    switch (tabIndex) {
      case 0:
        isPickerEnabled = true;
        return SizedBox(
          key: const ValueKey(0),
          child: ShippingAddress(onNext: () {
            Future.delayed(Duration.zero, goToShippingTab);
          }, isFromAddrssHistory: false,isFromCheckout: true),
        );
      case 1:
        return SizedBox(
          key: const ValueKey(1),
          child: Services().widget.renderShippingMethods(context, onBack: () {
            goToAddressTab(true);
          }, onNext: () {
            goToReviewTab();
          }),
        );
      case 2:
        return SizedBox(
          key: const ValueKey(2),
          child: ReviewScreen(onBack: () {
            goToShippingTab(true);
          }, onNext: () {
            goToPaymentTab();
          }),
        );
      case 3:
      default:
        return SizedBox(
          key: const ValueKey(3),
          child: PaymentMethods(
              onBack: () {
                goToReviewTab(true);
              },
              onFinish: (order) async {
                final cartModel =
                    Provider.of<CartModel>(context, listen: false);

                setState(() {
                  newOrder = order;
                });
                // Not clearCart: a guest's saved address must be dropped too,
                // or the next guest checkout pre-fills this order's address
                // (86d3g53f8 #8).
                cartModel.clearAfterOrder();
                await Services()
                    .widget
                    .updateOrderAfterCheckout(context, order);
              },
              onLoading: setLoading),
        );
    }
  }

  /// tabIndex: 0
  void goToAddressTab([bool isGoingBack = false]) {
    if (kPaymentConfig.enableAddress) {
      setState(() {
        tabIndex = 0;
      });
    } else {
      if (!isGoingBack) {
        goToShippingTab(isGoingBack);
      }
    }
  }

  /// tabIndex: 1
  void goToShippingTab([bool isGoingBack = false]) {
    if (enabledShipping) {
      setState(() {
        tabIndex = 1;
      });
    } else {
      if (isGoingBack) {
        goToAddressTab(isGoingBack);
      } else {
        goToReviewTab(isGoingBack);
      }
    }
  }

  /// tabIndex: 2
  void goToReviewTab([bool isGoingBack = false]) {
    if (kPaymentConfig.enableReview) {
      setState(() {
        tabIndex = 2;
      });
    } else {
      if (isGoingBack) {
        goToShippingTab(isGoingBack);
      } else {
        goToPaymentTab(isGoingBack);
      }
    }
  }

  /// tabIndex: 3
  void goToPaymentTab([bool isGoingBack = false]) {
    if (!isGoingBack) {
      setState(() {
        tabIndex = 3;
      });
    }
  }
}

class CheckOutStatus extends StatelessWidget {
  const CheckOutStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class CircleWidget extends StatelessWidget {
  final double size;
  final Color color;

  const CircleWidget({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2.0,
        ),
      ),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class DashedBorderDivider extends StatelessWidget {
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  const DashedBorderDivider({
    super.key,
    this.strokeWidth = 1.0,
    this.dashWidth = 2.0,
    this.dashSpace = 2.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final dividerWidth = constraints.maxWidth;
            final dashCount =
                (dividerWidth / (dashWidth + dashSpace)).floorToDouble();

            return CustomPaint(
              painter: DashedBorderPainter(
                strokeWidth: strokeWidth,
                dashWidth: dashWidth,
                dashSpace: dashSpace,
                dashCount: dashCount,
                color: color,
              ),
              child: SizedBox(
                width: double.infinity,
                height: strokeWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double dashCount;
  final Color color;

  DashedBorderPainter({
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.dashCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    var startX = 0.0;
    var startY = size.height / 2;
    //var endX = size.width;
    var endY = size.height / 2;

    final path = Path();
    for (var i = 0; i < dashCount; i++) {
      path.moveTo(startX, startY);
      path.lineTo(startX + dashWidth, endY);
      startX += dashWidth + dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.dashCount != dashCount ||
        oldDelegate.color != color;
  }
}
