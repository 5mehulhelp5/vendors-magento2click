import 'package:flutter/material.dart';

import '../../../common/config.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart' show PaymentMethod;
import '../../../services/index.dart';
import '../../../widgets/common/flux_image.dart';

class PaymentMethodItem extends StatelessWidget {
  const PaymentMethodItem(
      {Key? key,
      required this.paymentMethod,
      this.onSelected,
      this.selectedId,
      this.descWidget})
      : super(key: key);
  final PaymentMethod paymentMethod;
  final Function(String?)? onSelected;
  final String? selectedId;
  final Widget? descWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: () {
            if (onSelected != null) onSelected!(paymentMethod.id);
          },
          child: Container(
            decoration: BoxDecoration(
                color: paymentMethod.id == selectedId
                    ? Theme.of(context).primaryColorLight
                    : Colors.transparent),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: Column(
                children: [
                  Row(
                    children: <Widget>[
                      Radio<String?>(
                          value: paymentMethod.id,
                          groupValue: selectedId,
                          onChanged: onSelected),
                      const SizedBox(width: 10),
                      Expanded(
                        child: kPayments[paymentMethod.id] != null
                            ? Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FluxImage(
                                  imageUrl: kPayments[paymentMethod.id],
                                  height: 30,
                                ),
                              )
                            : Row(
                                children: <Widget>[
                                  // Leading brand mark so each option reads as
                                  // "logo + name" in checkout. Unmapped codes
                                  // fall back to name only.
                                  ..._buildBrandMark(context, paymentMethod.id),
                                  Expanded(
                                    child: Services()
                                        .widget
                                        .renderShippingPaymentTitle(
                                          context,
                                          _localizedTitle(context),
                                        ),
                                  ),
                                ],
                              ),
                      )
                    ],
                  ),
                  if (descWidget != null) descWidget!
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1)
      ],
    );
  }

  /// The method name to show, in the APP's language.
  ///
  /// Magento returns `title` in the language of the CART's store view, not the
  /// app's. A registered customer's quote keeps whatever store it was created
  /// on, so switching the app to English left the names in Arabic, while guests
  /// were fine because their cart is created fresh on the current store view
  /// (86d3g53f8, retest). Verified against testing.locafy.market: the SAME
  /// quote returns Arabic titles over both the eg-en and the eg-ar REST path,
  /// so the store view in the request URL cannot fix this — the name has to be
  /// resolved app-side.
  ///
  /// Only the store's known codes are mapped; anything else falls back to the
  /// title the API sent (and then to the code), so a newly enabled method still
  /// shows up rather than rendering blank.
  String _localizedTitle(BuildContext context) {
    switch (paymentMethod.id) {
      case 'cashondelivery':
        return S.of(context).paymentMethodCashOnDelivery;
      case 'online':
        return S.of(context).paymentMethodOnlineCard;
      case 'sympl':
        return S.of(context).paymentMethodSympl;
    }
    return paymentMethod.title ?? paymentMethod.id ?? '';
  }

  /// Leading brand mark(s) for a payment method, shown before its name so each
  /// checkout row reads as "logo + name". Keyed by the Magento payment code.
  /// Real card art (Visa/Mastercard) is bundled; COD/BNPL use a representative
  /// glyph until brand logos are supplied. Unknown codes get no mark (name
  /// only), so a new backend method can never break the row.
  List<Widget> _buildBrandMark(BuildContext context, String? id) {
    final color = Theme.of(context).colorScheme.secondary;
    const gap = SizedBox(width: 10);
    switch (id) {
      case 'online': // Secure online payment by Visa / MasterCard
        return [
          Image.asset('assets/icons/payment/visa-master.png', height: 24),
          gap,
        ];
      case 'sympl': // Pay later in installments with Sympl
        return [
          Image.asset('assets/icons/payment/sympl.png', height: 22),
          gap,
        ];
      case 'cashondelivery':
        return [Icon(Icons.payments_outlined, size: 24, color: color), gap];
      case 'aman':
        return [
          Icon(Icons.account_balance_wallet_outlined, size: 24, color: color),
          gap
        ];
      default:
        return const [];
    }
  }
}
