import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../common/tools/flash.dart';
import '../../generated/l10n.dart';
import '../../models/app_model.dart';
import '../../models/cart/cart_base.dart';
import '../../models/entities/product.dart';
import '../../models/entities/product_variation.dart';
import '../../models/recent_product_model.dart';
import '../../modules/dynamic_layout/config/product_config.dart';
import '../../routes/flux_navigate.dart';
import '../../screens/detail/product_detail_screen.dart';
import '../../services/index.dart';

mixin ActionButtonMixin {
  void onTapProduct(
    context, {
    bool isFromSearchScreen = false,
    required Product product,
    ProductConfig? config,

    /// {attribute_code: option value id} to open the variant picker on. Set by
    /// the cart so a configurable line reopens on the variant that was added
    /// (86d3g2npa #7).
    Map<String?, String?>? preselectedOptions,
  }) {
    if (product.imageFeature == '') return;



    Provider.of<RecentModel>(context, listen: false).addRecentProduct(product);

    final arguments = (preselectedOptions?.isNotEmpty ?? false)
        ? ProductDetailArguments(product,
            preselectedOptions: preselectedOptions)
        : product;

    if (isFromSearchScreen) {
      Navigator.of(context).pushNamed(
        RouteList.productDetail,
        arguments: arguments,
      );
      return;
    }

    // FluxNavigate.pushNamed(
    //   RouteList.productDetail,
    //   arguments: product,
    // );
    Navigator.of(context).pushNamed(
      RouteList.productDetail,
      arguments: arguments,
    );
  }

  Future<void> addToCart(
    BuildContext context, {
    int quantity = 1,
    bool enableBottomAddToCart = false,
    required Product product,
  }) async {
    if (FocusScope.of(context).hasFocus) {
      FocusScope.of(context).unfocus();
    }

    final Future<String> Function({
      dynamic context,
      dynamic isSaveLocal,
      Function notify,
      Map<String, dynamic> options,
      Product? product,
      int quantity,
      ProductVariation variation,
    })  addProductToCart =
        Provider.of<CartModel>(context, listen: false).addProductToCart;
    // if (enableBottomAddToCart) {
    //   DialogAddToCart.show(context, product: product, quantity: quantity);
    // } else {
    Product? productCheck = await Services().api.getStockStatus(product.sku);

   if(!(productCheck?.inStock ?? false)){
     FlashHelper.message(
       context,
       title: product.name,
       message: S.of(context).outOfStock,
       isError: true,
     );
     return;
   }

    // Magento validates (in-cart qty + requested qty) <= salable qty; check it
    // here too so low-stock items fail fast with a clear message instead of a
    // raw server error.
    final salableQty = productCheck?.stockQuantity;
    if (salableQty != null) {
      final cartModel = Provider.of<CartModel>(context, listen: false);
      final cartKey = product.sku ?? product.id.toString();
      final inCartQty = cartModel.productsInCart[cartKey] ?? 0;
      if (inCartQty + quantity > salableQty) {
        FlashHelper.message(
          context,
          title: product.name,
          message:
              '${S.of(context).currentlyWeOnlyHave} $salableQty ${S.of(context).ofThisProduct}',
          isError: true,
        );
        return;
      }
    }
    var message = await addProductToCart(
      product: product,
      context: context,
      quantity: quantity,
    );

    FlashHelper.message(
      context,
      title: message.isEmpty ? product.name : null,
      message: message.isEmpty ? S.of(context).addToCartSucessfully : message,
      isError: message.isNotEmpty,
    );
    //}
  }

  void updateQuantity({
    required Product product,
    required int quantity,
    required BuildContext context,
  }) {
    final cartModel = Provider.of<CartModel>(context, listen: false);
    if (quantity == 0) {
      cartModel.removeItemFromCart(product.id);
      return;
    }
    cartModel.updateQuantity(product, product.id, quantity);
  }
}
