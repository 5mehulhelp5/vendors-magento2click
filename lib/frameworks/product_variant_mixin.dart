import 'dart:async';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:inspireui/inspireui.dart';
import '../common/config.dart';
import '../common/constants.dart';
import '../common/tools/flash.dart';
import '../common/tools/tools.dart';
import '../generated/l10n.dart';
import '../models/app_model.dart';
import '../models/index.dart'
    show CartModel, Product, ProductModel, ProductVariation;
import '../routes/flux_navigate.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/detail/widgets/index.dart' show ProductShortDescription;
import '../services/services.dart';
import '../widgets/common/webview.dart';
import '../widgets/product/widgets/quantity_selection.dart';

mixin ProductVariantMixin {
  ProductVariation? updateVariation(
    List<ProductVariation> variations,
    Map<String?, String?> mapAttribute,
  ) {
    final templateVariation =
        variations.isNotEmpty ? variations.first.attributes : null;
    ProductVariation productVariation;
    var attributeString = '';

    /// Flat attribute
    /// Example attribute = { "color": "RED", "SIZE" : "S", "Height": "Short" }
    /// => "colorRedsizeSHeightShort"
    templateVariation?.forEach((element) {
      final key = element.name;
      final value = mapAttribute[key];
      attributeString += value != null ? '$key$value' : '';
    });
    if(attributeString.isEmpty){
      // int index = 0;
      // for (var i = 0; i < variations.first.configurable_product_options.length; i++) {
      //   final option = variations.first.configurable_product_options[i];
      //   List values = option['values'];
      //   for (var j = 0; j < values.length; j++) {
      //     final item = values[j];
      //     if(item['value_index'].toString() == mapAttribute.values.first.toString()){
      //       index = j;
      //     }
      //   }
      // }
      if(mapAttribute.values.isNotEmpty && variations.firstWhereOrNull((element) => element.materialcolor.toString() == mapAttribute.values.first.toString()) != null){
        productVariation = variations.firstWhere((element) => element.materialcolor.toString() == mapAttribute.values.first.toString());
      }else{
        productVariation = variations[0];
      }
    }else{
      /// Find the variation whose attributes all agree with the selection.
      /// Exact per-attribute matching — a substring match over joined
      /// "nameValue" strings can pick a wrong sibling when one option id is
      /// a prefix of another (e.g. size ids 77/773/777).
      final validVariation = variations.lastWhereOrNull(
        (variation) =>
            variation.attributes.isNotEmpty &&
            variation.attributes.every((attr) {
              final selected = mapAttribute[attr.name];
              if (selected == null) return true;
              final option = attr.option;
              if (option == null || option.isEmpty) return true;
              return option.toString() == selected.toString();
            }),
      );

      if (validVariation == null) return null;
      productVariation = validVariation;

      for (var element in productVariation.attributes) {
        if (!mapAttribute.containsKey(element.name)) {
          mapAttribute[element.name!] = element.option!;
        }
      }
    }

    return productVariation;
  }

  bool isPurchased(
    ProductVariation? productVariation,
    Product product,
    Map<String?, String?> mapAttribute,
    bool isAvailable,
  ) {
    var inStock;
    // ignore: unnecessary_null_comparison
    if (productVariation != null) {
      inStock = productVariation.inStock!;
    } else {
      inStock = product.inStock!;
    }

    var allowBackorder = productVariation != null
        ? (productVariation.backordersAllowed ?? false)
        : product.backordersAllowed;

    var isValidAttribute = false;
    try {
      if (product.type == 'simple') {
        isValidAttribute = true;
      }
      if (product.attributes!.length == mapAttribute.length &&
          (product.attributes!.length == mapAttribute.length ||
              product.type != 'variable')) {
        isValidAttribute = true;
      }
    } catch (_) {}

    return (inStock || allowBackorder) && isValidAttribute && isAvailable;
  }

  List<Widget> makeProductTitleWidget(BuildContext context,
      ProductVariation? productVariation, Product product, bool isAvailable) {
    var listWidget = <Widget>[];

    // ignore: unnecessary_null_comparison
    var inStock = (productVariation != null
            ? productVariation.inStock
            : product.inStock) ??
        false;

    var stockQuantity =
        (kProductDetail.showStockQuantity) && product.stockQuantity != null
            ? '  (${product.stockQuantity}) '
            : '';
    if (Provider.of<ProductModel>(context, listen: false).selectedVariation !=
        null) {
      stockQuantity = (kProductDetail.showStockQuantity) &&
              Provider.of<ProductModel>(context, listen: false)
                      .selectedVariation!
                      .stockQuantity !=
                  null
          ? '  (${Provider.of<ProductModel>(context, listen: false).selectedVariation!.stockQuantity}) '
          : '';
    }

    if (isAvailable) {
      listWidget.add(
        const SizedBox(height: 5.0),
      );

      final sku = productVariation != null ? productVariation.sku : product.sku;

      listWidget.add(
        Row(
          children: <Widget>[
            if ((kProductDetail.showSku) && (sku?.isNotEmpty ?? false)) ...[
              Text(
                '${S.of(context).sku}: ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                sku ?? '',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: inStock
                          ? Theme.of(context).primaryColor
                          : const Color(0xFFe74c3c),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      );

      listWidget.add(
        const SizedBox(height: 5.0),
      );

      listWidget.add(
        Row(
          children: <Widget>[
            if (kAdvanceConfig.showStockStatus) ...[
              Text(
                '${S.of(context).availability}: ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              (productVariation != null
                      ? (productVariation.backordersAllowed ?? false)
                      : product.backordersAllowed)
                  ? Text(
                      S.of(context).backOrder,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            color: kStockColor.backorder,
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  : Text(
                      inStock
                          ? '${S.of(context).inStock}$stockQuantity'
                          : S.of(context).outOfStock,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            color: inStock
                                ? kStockColor.inStock
                                : kStockColor.outOfStock,
                            fontWeight: FontWeight.w600,
                          ),
                    )
            ],
          ],
        ),
      );
      if (productVariation?.description?.isNotEmpty ?? false) {
        listWidget.add(Services()
            .widget
            .renderProductDescription(context, productVariation!.description!));
      }
      if (product.shortDescription != null &&
          product.shortDescription!.isNotEmpty) {
        listWidget.add(
          ProductShortDescription(product),
        );
      }

      listWidget.add(
        const SizedBox(height: 15.0),
      );
    }

    return listWidget;
  }

  List<Widget> makeBuyButtonWidget(
      BuildContext context,
      ProductVariation? productVariation,
      Product product,
      Map<String?, String?>? mapAttribute,
      int maxQuantity,
      int quantity,
      Function addToCart,
      Function onChangeQuantity,
      bool isAvailable,
      bool isInAppPurchaseChecking,
      {bool isBuyNow = false,bool ignoreBuyOrOutOfStockButton = false}) {
    final theme = Theme.of(context);

    // ignore: unnecessary_null_comparison
    var inStock = (productVariation != null
            ? productVariation.inStock
            : product.inStock) ??
        false;
    var allowBackorder = productVariation != null
        ? (productVariation.backordersAllowed ?? false)
        : product.backordersAllowed;

    final isExternal = product.type == 'external' ? true : false;
    final isVariationLoading =
        // ignore: unnecessary_null_comparison
        (product.isVariableProduct || product.type == 'configurable') &&
            productVariation == null &&
            mapAttribute == null;

    final buyOrOutOfStockButton = Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: isExternal
            ? ((inStock || allowBackorder) &&
                    mapAttribute != null &&
                    (product.attributes!.length == mapAttribute.length) &&
                    isAvailable)
                ? theme.primaryColor
                : theme.disabledColor
            : theme.primaryColor,
      ),
      child: Center(
        child: Text(
          ((((inStock || allowBackorder) && isAvailable) || isExternal) &&
                  !isVariationLoading &&
                  !isInAppPurchaseChecking
              ? S.of(context).buyNow
              : (isAvailable && !isVariationLoading && !isInAppPurchaseChecking
                      ? S.of(context).outOfStock
                      : isInAppPurchaseChecking
                          ? S.of(context).checking
                          : isVariationLoading
                              ? S.of(context).loading
                              : S.of(context).unavailable)
                  .toUpperCase()),
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    );


      final buyNowButton = Container(
        height: 40,
        width: 100,
        margin: EdgeInsets.only(left: 10,right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: isExternal
              ? ((inStock || allowBackorder) &&
              mapAttribute != null &&
              (product.attributes!.length == mapAttribute.length) &&
              isAvailable)
              ? theme.primaryColor
              : theme.disabledColor
              : theme.primaryColor,
        ),
        child: Center(
          child: Text(S.of(context).buyNow
                .toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      );
    if (!inStock && !isExternal && !allowBackorder) {
      return [
        ignoreBuyOrOutOfStockButton ? const SizedBox() : buyOrOutOfStockButton,
      ];
    }

    if ((product.isPurchased) && (product.isDownloadable ?? false)) {
      return [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async => await Tools.launchURL(product.files![0]!),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                      child: Text(
                    S.of(context).download,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: Colors.white,
                        ),
                  )),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    return [
      if (!isExternal && kProductDetail.showStockQuantity) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            // Expanded(
            //   child: Text(
            //     '${S.of(context).selectTheQuantity}:',
            //     style: Theme.of(context).textTheme.titleMedium,
            //   ),
            // ),
            Container(
              width: 140,
              height: 40.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
              ),
              child: QuantitySelection(
                height: 40.0,
                expanded: false,
                value: quantity,
                color: theme.colorScheme.secondary,
                limitSelectQuantity: maxQuantity,
                onChanged: onChangeQuantity,
              ),
            ),

            // /// Action Buttons: Buy Now, Add To Cart
            // Expanded(
            //   child: actionButton(
            //     ignoreBuyOrOutOfStockButton,
            //     isAvailable,
            //     addToCart,
            //     inStock,
            //     allowBackorder,
            //     buyOrOutOfStockButton,
            //     isExternal,
            //     isVariationLoading,
            //     isInAppPurchaseChecking,
            //     context,
            //   ),
            // ),
            if(isBuyNow)
              GestureDetector(
                onTap: (){
                  addToCart(true, inStock || allowBackorder);
                },
                child: buyNowButton,
              ),
            Expanded(
              child: GestureDetector(
                onTap: () => addToCart(false, inStock || allowBackorder),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Center(
                    child: Text(
                      S.of(context).addToCart.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 9),
    ];
  }

  /// Add to Cart & Buy Now function
  /// Returns true when the product was actually added to the cart.
  Future<bool> addToCart(BuildContext context, Product product, int quantity,
      ProductVariation? productVariation, Map<String?, String?> mapAttribute,
      [bool buyNow = false, bool inStock = false, bool inBackground = false]) async {
    /// Out of stock || Variable product but not select any variant.
    if (!inStock || (product.isVariableProduct && mapAttribute.isEmpty)) {
      return false;
    }

    final cartModel = Provider.of<CartModel>(context, listen: false);
    if (product.type == 'external') {
      openExternal(context, product);
      return false;
    }

    productVariation =
        Provider.of<ProductModel>(context, listen: false).selectedVariation;

    // The selected variation is the source of truth for what the customer
    // picked — it is what decides the child sku. The caller's mapAttribute can
    // be stale or empty: each of the two widgets running this flow keeps its
    // own copy, and getProductVariations returns early without calling onLoad
    // when the attributes have not loaded yet, leaving it null. Deriving the
    // options from the variation keeps the cart payload correct either way;
    // without this the configurable silently degrades to a child-sku simple
    // line and the variant is lost on the other platforms (86d3g2npa #7/#9).
    final mapAttr = <String, String>{};
    for (final attr in productVariation?.attributes ?? const []) {
      if (attr.name != null && attr.option != null) {
        mapAttr[attr.name!] = attr.option!;
      }
    }
    if (mapAttr.isEmpty) {
      for (var entry in mapAttribute.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key != null && value != null) {
          mapAttr[key] = value;
        }
      }
    }

    String message;
    try {
      message = await cartModel.addProductToCart(
          context: context,
          product: product,
          quantity: quantity,
          variation: productVariation,
          options: mapAttr);
    } catch (e, trace) {
      // Network errors / unexpected payloads must not die unhandled.
      printError(e, trace);
      message = S.of(context).somethingWrong;
    }

    if (message.isNotEmpty) {
      FlashHelper.errorMessage(context, message: message);
      return false;
    }

    if (buyNow) {
      FluxNavigate.pushNamed(
        RouteList.cart,
        arguments: CartScreenArgument(isModal: true, isBuyNow: true),
      );
    }
    FlashHelper.message(
      context,
      title: product.name,
      message: S.of(context).addToCartSucessfully,
    );
    return true;
  }

  /// Support Affiliate product
  Future<void> openExternal(BuildContext context, Product product) async {
    final url = Tools.prepareURL(product.affiliateUrl);

    if (url != null) {
      try {
        if (Tools.needToOpenExternalApp(url)) {
          await Tools.launchURL(url);
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebView(
                url: product.affiliateUrl,
                title: product.name,
              ),
            ),
          );
        }
        return;
      } catch (e) {
        printError(e);
      }
    }
    await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          leading: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios),
          ),
        ),
        body: Center(
          child: Text(S.of(context).notFound),
        ),
      );
    }));
  }
}
