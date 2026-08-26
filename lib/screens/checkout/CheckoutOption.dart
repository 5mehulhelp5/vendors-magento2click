import 'package:flutter/material.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools/price_tools.dart';
import '../../generated/l10n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/index.dart' show AppModel, CartModel, Coupons, Discount;
import '../../routes/flux_navigate.dart';
import '../../widgets/product/cart_item.dart';
import '../cart/widgets/shopping_cart_sumary.dart';
import 'checkout_screen.dart';

class CheckoutOption extends StatelessWidget {
   CheckoutOption({super.key});

  final defaultCurrency = kAdvanceConfig.defaultCurrency;

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<AppModel>(context).currency;
    final currencyRate = Provider.of<AppModel>(context).currencyRate;
    final largeAmountStyle = TextStyle(
      color: Theme.of(context).colorScheme.onPrimary,
      fontSize: 20,
    );
    return Consumer<CartModel>(builder: (context, cartModel, child) {
      var couponMsg = '';

      if (cartModel.productsInCart.isEmpty) {
        return const SizedBox();
      }
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 1,
          backgroundColor: Theme.of(context).colorScheme.background,
          title: Text(
            S.of(context).checkout,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Column(
          children: [

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  sectionItem(
                    context: context,
                    title: S.of(context).selectAddress.toUpperCase(),
                    // subText: S.of(context).addDeliveryAddress,
                    onTap: () {
                      FluxNavigate.pushNamed(
                        RouteList.checkout,
                        arguments: CheckoutArgument(isModal: true),
                        forceRootNavigator: true,
                      );
                    },
                  ),

                  sectionItem(
                    context: context,
                    title: S.of(context).shipping.toUpperCase(),
                    onTap: () {},
                  ),

                  sectionItem(
                    context: context,
                    title: S.of(context).orderSummary.toUpperCase(),
                    onTap: () {},
                  ),

                  sectionItem(
                    context: context,
                    title: S.of(context).checkout.toUpperCase(),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Bottom total area
            InkWell(
              onTap: (){
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => orderReviewBottomSheet(cartModel,context),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shipping cost line — shows the delivery fee that is
                    // included in the total below (previously the total hid the
                    // shipping cost by subtracting it, so shoppers never saw it).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).shipping,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          PriceTools.getCurrencyFormatted(
                              cartModel.getShippingCost() ?? 0,
                              currencyRate,
                              currency: cartModel.isWalletCart()
                                  ? defaultCurrency?.currencyCode
                                  : currency)!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children:  [
                        Text(
                          S.of(context).totalAmount,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        cartModel.calculatingDiscount
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                          ),
                        )
                            : Text(
                          PriceTools.getCurrencyFormatted(
                              cartModel.getTotal()!,
                              currencyRate,
                              currency: cartModel.isWalletCart()
                                  ? defaultCurrency
                                  ?.currencyCode
                                  : currency)!,
                          style: largeAmountStyle,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                  ],
                ),
              ),
            )
          ],
        ),
      );
    });
  }

  Widget sectionItem({
    required BuildContext context,
    required String title,
    String? subText,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: subText != null ? Text(subText, style:  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)) : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }

   Widget orderReviewBottomSheet(CartModel model, BuildContext context) {
     return Container(
       height: MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.height * 0.92,
       decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.background,
         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
       ),
       child: Column(
         children: [
           // Drag handle
           Container(
             width: 50,
             height: 6,
             margin: const EdgeInsets.only(top: 10, bottom: 10),
             decoration: BoxDecoration(
               color: Colors.grey.shade400,
               borderRadius: BorderRadius.circular(3),
             ),
           ),

           Expanded(
             child: ListView(
               padding: const EdgeInsets.all(16),
               children: [
                 const ShoppingCartSummary(enableCoupon: false,),
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 20.0),
                   child: Text(S.of(context).orderDetail,
                       style: const TextStyle(fontSize: 18)),
                 ),
                 // TODO check issue with Products
                 if (model.productsInCart.isNotEmpty)
                   ...getProducts(model, context),
               ],
             ),
           ),

         ],
       ),
     );
   }

   List<Widget> getProducts(CartModel model, BuildContext context) {
     return model.productsInCart.keys.map(
           (key) {
         var product = model.getProductById(key);
         if (product != null) {
           return ShoppingCartRow(
             product: product,
             addonsOptions: model.productAddonsOptionsInCart[key],
             variation: model.getProductVariationById(key),
             quantity: model.productsInCart[key],
             options: model.productsMetaDataInCart[key],
             isEdit: false,
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