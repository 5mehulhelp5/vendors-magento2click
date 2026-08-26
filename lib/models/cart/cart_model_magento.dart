import 'package:flutter/material.dart';

import '../../common/config.dart';
import '../../common/tools.dart';
import '../../data/boxes.dart';
import '../../generated/l10n.dart';
import '../../services/services.dart';
import '../entities/product.dart';
import '../entities/product_variation.dart';
import 'cart_base.dart';
import 'mixin/index.dart';

class CartModelMagento
    with
        ChangeNotifier,
        CartMixin,
        CouponMixin,
        CurrencyMixin,
        AddressMixin,
        LocalMixin,
        OpencartMixin,
        VendorMixin,
        MagentoMixin,
        OrderDeliveryMixin
    implements CartModel {
  static final CartModelMagento _instance = CartModelMagento._internal();

  factory CartModelMagento() => _instance;

  CartModelMagento._internal();

  @override
  Future<void> initData() async {
    await getShippingAddress();
   // getCartInLocal();
    getCurrency();
  }

  @override
  double getSubTotal() {
    return productsInCart.keys.fold(0.0, (sum, key) {
      if (productVariationInCart[key] != null &&
          productVariationInCart[key]!.price != null &&
          productVariationInCart[key]!.price!.isNotEmpty) {
        return sum +
            double.parse(productVariationInCart[key]!.price!) *
                productsInCart[key]!;
      } else {
       // var productId = Product.cleanProductID(key);

        var price =
            PriceTools.getPriceProductValue(item[key], onSale: true)!;
        if (price.isNotEmpty) {
          return sum + double.parse(price) * productsInCart[key]!;
        }
        return sum;
      }
    });
  }

  /// Magento: get item total
  @override
  double getItemTotal({
    ProductVariation? productVariation,
    Product? product,
    int quantity = 1,
  }) {
    var subtotal = double.parse(product!.price!) * quantity;
    if (discountAmount > 0) {
      return subtotal - discountAmount;
    } else {
      if (couponObj != null) {
        if (couponObj!.discountType == 'percent') {
          return subtotal - subtotal * couponObj!.amount! / 100;
        } else {
          return subtotal - (couponObj!.amount! * quantity);
        }
      } else {
        return subtotal;
      }
    }
  }

  /// Magento: get coupon
  @override
  String getCoupon() {
    if (discountAmount > 0) {
      return '-${PriceTools.getCurrencyFormatted(discountAmount, currencyRates, currency: currencyCode)!}';
    } else {
      if (couponObj != null) {
        if (couponObj!.discountType == 'percent') {
          return '-${couponObj!.amount}%';
        } else {
          return '-${PriceTools.getCurrencyFormatted(couponObj!.amount! * totalCartQuantity, currencyRates, currency: currencyCode)!}';
        }
      } else {
        return '';
      }
    }
  }

  /// Magento: get total
  @override
  double getTotal() {
    var subtotal = getSubTotal();

    if (discountAmount > 0) {
      subtotal -= discountAmount;
    } else {
      if (couponObj != null) {
        if (couponObj!.discountType == 'percent') {
          subtotal -= subtotal * couponObj!.amount! / 100;
        } else {
          subtotal -= (couponObj!.amount! * totalCartQuantity);
        }
      }
    }
    if (kPaymentConfig.enableShipping) {
      subtotal += getShippingCost()!;
    }
    if (taxes.isNotEmpty) {
      subtotal += taxesTotal;
    }
    subtotal += getCODExtraFee();
    return subtotal;
  }

  /// Magento: get coupon cost
  @override
  double getCouponCost() {
    if (discountAmount > 0) {
      return discountAmount;
    } else {
      var subtotal = getSubTotal();
      if (couponObj != null) {
        if (couponObj!.discountType == 'percent') {
          return subtotal * couponObj!.amount! / 100;
        } else {
          return couponObj!.amount! * totalCartQuantity;
        }
      } else {
        return 0.0;
      }
    }
  }

  @override
  Future<String> updateQuantity(Product product, String key, int quantity, {context}) async {
    var message = '';
    var total = quantity;
    ProductVariation? variation;

    if (key.contains('-')) {
      variation = getProductVariationById(key);
    }
    var stockQuantity =
        variation == null ? product.stockQuantity : variation.stockQuantity;

    if (!product.manageStock) {
      productsInCart[key] = total;
    } else if (total <= stockQuantity!) {
      if (product.minQuantity == null && product.maxQuantity == null) {
        productsInCart[key] = total;
      } else if (product.minQuantity != null && product.maxQuantity == null) {
        total < product.minQuantity!
            ? message = 'Minimum quantity is ${product.minQuantity}'
            : productsInCart[key] = total;
      } else if (product.minQuantity == null && product.maxQuantity != null) {
        total > product.maxQuantity!
            ? message =
                'You can only purchase ${product.maxQuantity} for this product'
            : productsInCart[key] = total;
      } else if (product.minQuantity != null && product.maxQuantity != null) {
        if (total >= product.minQuantity! && total <= product.maxQuantity!) {
          productsInCart[key] = total;
        } else {
          if (total < product.minQuantity!) {
            message = 'Minimum quantity is ${product.minQuantity}';
          }
          if (total > product.maxQuantity!) {
            message =
                'You can only purchase ${product.maxQuantity} for this product';
          }
        }
      }
    } else {
      message = 'Currently we only have $stockQuantity of this product';
    }
    // A qty update targets an existing line by item_id, but Magento still
    // revalidates the payload — send the same sku/options shape the line was
    // created with so a configurable is not silently rewritten to a simple.
    final options = productsMetaDataInCart[key];
    final hasOptions = options is Map && options.isNotEmpty;
    String? skuString =
        (variation != null && !hasOptions) ? variation.sku : product.sku;
    final messageBody = await Services().api.addUpdateItemsToCart(
        product, skuString ?? "", quantity, true,
        options: hasOptions ? options : null, fallbackSku: variation?.sku);
    if((messageBody ?? "").isNotEmpty){
      return (messageBody ?? "");
    }
    if (message.isEmpty) {
      updateQuantityCartLocal(key: key, quantity: quantity);
      notifyListeners();
    }
    return message;
  }

  @override
  // Removes an item from the cart.
  void removeItemFromCart(String key) {
    if (productsInCart.containsKey(key)) {
      // Resolve the server line through the cart key itself. Matching on
      // `element.sku == key` broke as soon as configurable lines became
      // "parentSku|attr=value" keys — the DELETE never fired and the item came
      // back on the next sync (86d3g2npa #3/#4).
      final itemId = item[key]?.itemID;
      if (itemId != null && itemId.isNotEmpty) {
        Services().api.deleteItemInCart(itemId);
      } else {
        shoppingList.forEach((element) {
          if (element.id == key || element.sku == key) {
            Services().api.deleteItemInCart(element.itemID ?? "");
          }
        });
      }
      productsInCart.remove(key);
      item.remove(key);
      productVariationInCart.remove(key);
      productsMetaDataInCart.remove(key);
      productSkuInCart.remove(key);
      removeProductLocal(key);
    }
    notifyListeners();
  }

  @override
  // Removes everything from the cart.
  void clearCart(bool isFromCartScreen) {
    if(isFromCartScreen){
      shoppingList.forEach((element){
        Services().api.deleteItemInCart(element.itemID ?? "");
      });
    }
    clearCartLocal();
    productsInCart.clear();
    item.clear();
    productVariationInCart.clear();
    productsMetaDataInCart.clear();
    productSkuInCart.clear();
    shippingMethod = null;
    paymentMethod = null;
    resetCoupon();
    notes = null;
    discountAmount = 0.0;
    // Totals from the finished order must not leak into the next (empty)
    // cart — without this the cart kept showing the previous order's tax.
    shoppingList = [];
    taxes = [];
    taxesTotal = 0.0;
    notifyListeners();
  }

  @override
  void clearAfterOrder() {
    clearCart(false);
    // Guests only: a signed-in customer's address belongs to their account and
    // is re-fetched anyway, so keeping the pre-fill is a convenience. For a
    // guest it's the previous order's address (86d3g53f8 #8).
    if (!UserBox().isLoggedIn) {
      clearSavedAddress();
    }
  }

  /// Re-fetch the cart from the server so items added, removed or updated on
  /// another platform (web / iOS) are reflected without having to log out and
  /// back in. Only the product lines are replaced (see getShoppingList);
  /// coupon, shipping, payment and notes are preserved. On network failure the
  /// current cart is kept. Guests keep their local cart and are skipped.
  @override
  Future<void> reloadCartFromServer() async {
    if (user?.loggedIn != true) return;
    // replace: true resets the product lines to the server's state (removing
    // items deleted elsewhere) only after a successful fetch — no flicker and
    // no data loss on network failure.
    await Services().api.getShoppingList(this, replace: true);
    // Ensure the UI updates even when the server cart is now empty (nothing
    // for getShoppingList to add back).
    notifyListeners();
  }

  @override
  void setOrderNotes(String note) {
    notes = note;
    notifyListeners();
  }

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
  }) async {
    if (product!.type == 'configurable' && variation == null) {
      return S.of(context).loading;
    }
    // Configurables go to Magento as the *parent* sku plus the selected super
    // attributes (see addUpdateItemsToCart) — posting the child sku made
    // Magento store a plain simple-product line, which is why the variant was
    // invisible on the website and the other app, and why opening the line
    // landed on the child instead of the parent (86d3g2npa #7/#9).
    final hasOptions = options != null && options.isNotEmpty;
    String? skuString =
        (variation != null && !hasOptions) ? variation.sku : product.sku;
    if(!isFromApi) {
      // Re-adding a SKU that is already in the server cart must be sent as an
      // update (absolute qty): POSTing the same SKU again makes Magento sum
      // the quantities server-side and reject the request with "The requested
      // qty is not available" whenever stock can't cover the sum.
      final cartKey = buildCartItemKey(product, variation, options);
      final existingQty = productsInCart[cartKey] ?? 0;
      final existingItemId = item[cartKey]?.itemID ?? product.itemID;

      // Fail fast when the combined quantity exceeds the salable stock —
      // the server would reject it with "The requested qty is not available".
      final stockQty = variation?.stockQuantity ?? product.stockQuantity;
      if (existingQty > 0 &&
          stockQty != null &&
          existingQty + (quantity ?? 1) > stockQty) {
        return '${S.current.currentlyWeOnlyHave} $stockQty ${S.current.ofThisProduct}';
      }

      String? messagebody;
      if (existingQty > 0 && (existingItemId?.isNotEmpty ?? false)) {
        product.itemID = existingItemId;
        messagebody = await Services().api.addUpdateItemsToCart(
            product, skuString ?? "", existingQty + (quantity ?? 1), true,
            options: options, fallbackSku: variation?.sku);
      } else {
        messagebody = await Services().api.addUpdateItemsToCart(
            product, skuString ?? "", quantity!, false,
            options: options, fallbackSku: variation?.sku);
      }
      if (!(messagebody ?? "").isEmpty) {
        return messagebody ?? "";
      }
    }
    // `options` was being dropped here, so productsMetaDataInCart stayed null
    // even for a locally added configurable and the cart row could not resolve
    // its "Size: …" label from the parent's attributes.
    var message = super.addProductToCart(
        product: product,
        quantity: quantity,
        variation: variation,
        options: options,
        isSaveLocal: isSaveLocal,
        notify: notifyListeners);

    productSkuInCart[buildCartItemKey(product, variation, options)] = skuString;
    return message;
  }

  @override
  void setRewardTotal(double total) {
    rewardTotal = total;
    notifyListeners();
  }
}
