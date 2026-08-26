import 'package:flutter/material.dart';

import '../entities/product.dart';
import '../entities/product_variation.dart';
import '../entities/tax.dart';
import 'mixin/index.dart';

abstract class CartModel
    with
        CartMixin,
        AddressMixin,
        LocalMixin,
        CouponMixin,
        CurrencyMixin,
        MagentoMixin,
        OpencartMixin,
        VendorMixin,
        OrderDeliveryMixin,
        ChangeNotifier {
  @override
  double? getSubTotal();

  double getItemTotal(
      {ProductVariation? productVariation, Product? product, int quantity = 1});

  double? getTotal();

  Future<String> updateQuantity(Product product, String key, int quantity);

  void removeItemFromCart(String key);

  // @override
  // Product? getProductById1(String id);

  @override
  ProductVariation? getProductVariationById(String key);

  void clearCart(bool isFromCartScreen);

  /// Full reset once an order has been placed.
  ///
  /// [clearCart] deliberately keeps the address — it also runs when the shopper
  /// merely empties the basket and on every app start, and discarding their
  /// details there would be hostile. But after an order completes a guest's
  /// address has to go too, or the next guest checkout pre-fills the previous
  /// order's address (86d3g53f8 #8). Signed-in customers keep theirs: it's tied
  /// to their account and re-fetched anyway.
  ///
  /// Call this from order-completion paths instead of [clearCart].
  void clearAfterOrder();

  /// Re-fetch the cart from the server so changes made on another platform
  /// (web / other app) are reflected without re-login. Overridden by
  /// frameworks that support a server cart (Magento); no-op by default.
  Future<void> reloadCartFromServer() async {}

  void setOrderNotes(String note);

  void initData();

  @override
  Future<String> addProductToCart({
    context,
    Product? product,
    int? quantity = 1,
    ProductVariation? variation,
    Function? notify,
    isSaveLocal = true,
    isFromApi = false,
    Map? options,
  });

  void setRewardTotal(double total);

  @override
  void loadSavedCoupon();

  @override
  void setWalletAmount(double total);

  @override
  bool isWalletCart();

  @override
  void setTaxInfo(List<Tax> taxes, double taxesTotal);
}
