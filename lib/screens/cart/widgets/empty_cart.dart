import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:magentoegypt/generated/l10n.dart';

class EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      child: SingleChildScrollView(
        padding: getPadding(
          top: 150,
          bottom: 150,
        ),
        child: Padding(
          padding: getPadding(
            right: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                S.of(context).yourBagIsEmpty,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: AppStyle.txtBarlowSemiBold20Black900,
              ),
              Container(
                margin: getMargin(
                  left: 63,
                  top: 9,
                  right: 31,
                ),
                child: Text(
                  S.of(context).emptyCartSubtitle,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: AppStyle.txtBarlowRegular16,
                ),
              ),
              // CustomButton(
              //   height: getVerticalSize(
              //     40,
              //   ),
              //   text: S.of(context).startShopping,
              //   margin: getMargin(
              //     left: 57,
              //     top: 27,
              //     right: 25,
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );

    // SizedBox(
    //   width: screenSize.width,
    //   child: FittedBox(
    //     fit: BoxFit.cover,
    //     child: SizedBox(
    //       width:
    //           screenSize.width / (2 / (screenSize.height / screenSize.width)),
    //       child: Stack(
    //         children: <Widget>[
    //           Column(
    //             children: <Widget>[
    //               const SizedBox(height: 60),
    //               Text(S.of(context).yourBagIsEmpty,
    //                   style: Theme.of(context).textTheme.titleMedium,
    //                   textAlign: TextAlign.center),
    //               const SizedBox(height: 20),
    //               Padding(
    //                 padding: const EdgeInsets.symmetric(horizontal: 30),
    //                 child: Text(S.of(context).emptyCartSubtitle,
    //                     style: Theme.of(context).textTheme.bodyMedium,
    //                     textAlign: TextAlign.center),
    //               ),
    //               const SizedBox(height: 50)
    //             ],
    //           )
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }
}
