import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart' show AppModel, CartModel, Product, TaxModel;
import '../../services/index.dart';
import '../../widgets/common/common_safe_area.dart';
import '../../widgets/common/expansion_info.dart';
import '../../widgets/product/cart_item.dart';
import '../base_screen.dart';
import '../cart/widgets/shopping_cart_sumary.dart';

class ReviewScreen extends StatefulWidget {
  final Function? onBack;
  final Function? onNext;

  const ReviewScreen({this.onBack, this.onNext});

  @override
  BaseScreen<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends BaseScreen<ReviewScreen> {
  TextEditingController note = TextEditingController();
  bool enabledShipping = kPaymentConfig.enableShipping;

  @override
  void initState() {
    var notes = Provider.of<CartModel>(context, listen: false).notes;
    note.text = notes ?? '';
    super.initState();
    Future.delayed(Duration.zero, () {
      final cartModel = Provider.of<CartModel>(context, listen: false);
      setState(() {
        enabledShipping = cartModel.isEnabledShipping();
      });
    });
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (kPaymentConfig.enableTax) {
      Provider.of<TaxModel>(context, listen: false).getTaxes(
          Provider.of<CartModel>(context, listen: false), (taxesTotal, taxes) {
        Provider.of<CartModel>(context, listen: false).taxesTotal = taxesTotal;
        Provider.of<CartModel>(context, listen: false).taxes = taxes;
        setState(() {});
      });
    } else {
      Provider.of<CartModel>(context, listen: false).taxesTotal = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyRate = Provider.of<AppModel>(context).currencyRate;
    final taxModel = Provider.of<TaxModel>(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Consumer<CartModel>(
              builder: (context, model, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      enabledShipping
                          ? ExpansionInfo(
                              title: S.of(context).shippingAddress,
                              children: <Widget>[
                                ShippingAddressInfo(),
                              ],
                            )
                          : const SizedBox(),
                      Container(
                        height: 1,
                        decoration: const BoxDecoration(color: kGrey200),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(S.of(context).orderDetail,
                            style: const TextStyle(fontSize: 18)),
                      ),

                      // TODO check issue with Products
                       if (model.productsInCart.isNotEmpty)
                         ...getProducts(model, context),

                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color:  Theme.of(context).primaryColor),),
                        child: IntrinsicHeight(child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 1,
                              child: Container(
                               // alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Text(
                                  S.of(context).subtotal,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ),
                            VerticalDivider(
                              width: 10,
                              thickness: 0.8,
                              color: Theme.of(context).primaryColor,
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child:Text(
                                    PriceTools.getCurrencyFormatted(
                                        model.getSubTotal(), currencyRate,
                                        currency: model.currencyCode)!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                      fontSize: 14,
                                      color:
                                      Theme.of(context).colorScheme.secondary,
                                    ),
                                  )
                              ),
                            )
                          ],
                        ),),
                      ),
                      Services().widget.renderShippingMethodInfo(context),
                      if (model.getCoupon() != '')
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color:  Theme.of(context).primaryColor),
                                left: BorderSide(color:  Theme.of(context).primaryColor),
                                right: BorderSide(color:  Theme.of(context).primaryColor)
                            ),),
                          child: IntrinsicHeight(child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Expanded(
                                flex: 1,
                                child: Container(
                                 // alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child:  Text(
                                    S.of(context).discount,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 10,
                                thickness: 0.8,
                                color: Theme.of(context).primaryColor,
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child:Text(
                                      model.getCoupon(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                ),
                              )
                            ],
                          ),),
                        ),
                      Services().widget.renderTaxes(taxModel, context),
                      Services().widget.renderRewardInfo(context),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color:  Theme.of(context).primaryColor),
                              left: BorderSide(color:  Theme.of(context).primaryColor),
                              right: BorderSide(color:  Theme.of(context).primaryColor)
                          ),),
                        child: IntrinsicHeight(child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 1,
                              child: Container(
                               // alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Text(
                                  S.of(context).total,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ),
                            VerticalDivider(
                              width: 10,
                              thickness: 0.8,
                              color: Theme.of(context).primaryColor,
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child:Text(
                                    PriceTools.getCurrencyFormatted(
                                        model.getTotal(), currencyRate,
                                        currency: model.currencyCode)!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                      fontSize: 20,
                                      color:
                                      Theme.of(context).colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  )
                              ),
                            )
                          ],
                        ),),
                      ),
                      Services().widget.renderRecurringTotals(context),
                      if (kEnableCustomerNote) ...[
                        const SizedBox(height: 20),
                        Text(
                          S.of(context).yourNote,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                              width: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: TextField(
                            maxLines: 5,
                            controller: note,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                                hintText: S.of(context).writeYourNote,
                                hintStyle: const TextStyle(fontSize: 12),
                                border: InputBorder.none),
                          ),
                        ),
                      ],
                      const ShoppingCartSummary(showPrice: false),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _buildBottom(),
      ],
    );
  }



  Widget _buildBottom() {
    return CommonSafeArea(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabledShipping || kPaymentConfig.enableAddress) ...[
            GestureDetector(
              onTap: () {
                widget.onBack!();
              },
              child: Container(
                width: 130,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red,
                  ), // Customize the border color here
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Text(
                    S.of(context).goBack.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ButtonTheme(
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                ),
                onPressed: () {
                  widget.onNext!();
                  if (note.text.isNotEmpty) {
                    Provider.of<CartModel>(context, listen: false)
                        .setOrderNotes(note.text);
                  }
                },
                icon: const Icon(
                  CupertinoIcons.creditcard,
                  size: 18,
                ),
                label: Text(S.of(context).continueToPayment.toUpperCase()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> getProducts(CartModel model, BuildContext context) {
    return model.productsInCart.keys.map(
      (key) {
       // var productId = Product.cleanProductID(key);
       //  return ShoppingCartRow(
       //    addonsOptions: model.productAddonsOptionsInCart[key],
       //    product: model.getProductById(key),
       //    variation: model.getProductVariationById(key),
       //    quantity: model.productsInCart[key],
       //    options: model.productsMetaDataInCart[key],
       //  );
        var product = model.getProductById(key);

        if (product != null) {

          return ShoppingCartRow(
            product: product,
            addonsOptions: model.productAddonsOptionsInCart[key],
            variation: model.getProductVariationById(key),
            quantity: model.productsInCart[key],
            options: model.productsMetaDataInCart[key],
            onRemove: () {
              model.removeItemFromCart(key);
            },
            onChangeQuantity: (val) async {
              var message = await model.updateQuantity(product, key, val);
              if (message.isNotEmpty) {
                final snackBar = SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 1),
                );
                Future.delayed(
                  const Duration(milliseconds: 300),
                      () => ScaffoldMessenger.of(context).showSnackBar(snackBar),
                );
              }
            },
          );
        }
        return const SizedBox();
      },
    ).toList();
  }
}

class ShippingAddressInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cartModel = Provider.of<CartModel>(context);
    final address = cartModel.address!;

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).firstName} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.firstName!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).lastName} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.lastName!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),
          // Email is optional at checkout — only show the row when the
          // shopper actually entered one.
          if ((address.email ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 160,
                    child: Text(
                      '${S.of(context).email} :',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      address.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  )
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).streetName} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.street!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),

          // Match the form's wording: "City" is the governorate (Magento
          // region, held in address.state) and "Zone" is the district
          // (address.city) — same labels the website uses.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).city} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.state ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).zone} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.city ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),
          FutureBuilder(
            future: Services().widget.getCountryName(context, address.country),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 160,
                        child: Text(
                          '${S.of(context).country} :',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          snapshot.data as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      )
                    ],
                  ),
                );
              } else {
                return const SizedBox();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    '${S.of(context).phoneNumber} :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    address.phoneNumber!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

}
