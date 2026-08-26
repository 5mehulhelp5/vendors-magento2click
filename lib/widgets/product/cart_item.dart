// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:inspireui/extensions/build_context_ext.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:magentoegypt/widgets/product/widgets/quantity_selection.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/tools.dart';
import '../../models/entities/index.dart' show AddonsOption;
import '../../models/index.dart' show AppModel, Product, ProductVariation;
import '../../services/index.dart';
import 'action_button_mixin.dart';

class ShoppingCartRow extends StatelessWidget with ActionButtonMixin {
   ShoppingCartRow({
    super.key,
    required this.product,
    required this.quantity,
    this.onRemove,
    this.onChangeQuantity,
    this.variation,
    this.options,
    this.isEdit,
    this.addonsOptions,
  });

  final Product? product;
  final List<AddonsOption>? addonsOptions;
  final ProductVariation? variation;
  final Map? options;
  final int? quantity;
  bool? isEdit = true;
  final Function? onChangeQuantity;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    var currency = Provider.of<AppModel>(context).currency;
    final currencyRate = Provider.of<AppModel>(context).currencyRate;


    final price = Services().widget.getPriceItemInCart(
        product!, variation, currencyRate, currency,
        selectedOptions: addonsOptions);
    final imageFeature = (variation?.imageFeature?.isNotEmpty ?? false)
        ? variation!.imageFeature
        : product!.imageFeature;
    var maxQuantity = kCartDetail['maxAllowQuantity'] ?? 100;
    var totalQuantity = variation != null
        ? (variation!.stockQuantity ?? maxQuantity)
        : (product!.stockQuantity ?? maxQuantity);
    var limitQuantity =
        totalQuantity > maxQuantity ? maxQuantity : totalQuantity;

    var theme = Theme.of(context);
    late List<int> quantities;

    return LayoutBuilder(
      builder: (context, constraints) {
        quantities = List.generate(limitQuantity, (index) => index + 1);
        return Container(
          margin: getMargin(top: 13, left: 16, right: 16),
          padding: getPadding(top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadiusStyle.roundedBorder8,
            boxShadow: [
              BoxShadow(
                color: ColorConstant.blueGray50019,
                spreadRadius: getHorizontalSize(2),
                blurRadius: getHorizontalSize(2),
                offset: const Offset(1, 1),
              ),
            ],
          ),

          // AppDecoration.outlineBluegray50019.copyWith(
          //   borderRadius: BorderRadiusStyle.roundedBorder8,
          // ),
          child: Column(
            children: [
              Stack(
                children: [
                  Row(
                    key: ValueKey(product!.id),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onRemove != null)
                        Expanded(
                          child: GestureDetector(
                            // The line stores the *parent* configurable, so
                            // this opens the parent PDP; carry the selected
                            // options over so it opens on that variant rather
                            // than the default one (86d3g2npa #7).
                            onTap: () => onTapProduct(
                              context,
                              product: product!,
                              preselectedOptions: options?.map((k, v) =>
                                  MapEntry(k?.toString(), v?.toString())),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: constraints.maxWidth * 0.25,
                                  height: constraints.maxWidth * 0.27,
                                  child: ImageResize(url: imageFeature),
                                ),
                                const SizedBox(width: 16.0),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: context.isRtl
                                              ? const EdgeInsets.only(left: 5.0)
                                              : const EdgeInsets.only(
                                                  right: 5.0),
                                          child: Text(
                                            product!.name!,
                                            style: TextStyle(
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // const SizedBox(height: 7),
                                        // Row(
                                        //   children: [
                                        //     CustomImageView(
                                        //       svgPath: ImageConstant
                                        //           .imgStar2Amber500,
                                        //       height: getSize(
                                        //         18,
                                        //       ),
                                        //       width: getSize(
                                        //         18,
                                        //       ),
                                        //     ),
                                        //     Padding(
                                        //       padding: getPadding(
                                        //         left: 6,
                                        //         top: 1,
                                        //       ),
                                        //       child: Text(
                                        //         '4.8/5',
                                        //         overflow: TextOverflow.ellipsis,
                                        //         textAlign: TextAlign.left,
                                        //         style: AppStyle
                                        //             .txtArchivoRomanLight14Black9007f
                                        //             .copyWith(
                                        //           color: theme
                                        //               .colorScheme.onPrimary,
                                        //         ),
                                        //       ),
                                        //     ),
                                        //   ],
                                        // ),
                                        if(product?.original_price != null &&
                                            !isEqual(product?.price ?? '',product?.original_price ?? ''))
                                        const SizedBox(height: 12),
                                        if(product?.original_price != null &&
                                            !isEqual(product?.price ?? '',product?.original_price ?? ''))
                                          Text(
                                            '${ PriceTools.getOriginalPriceProduct(
                                                product, currencyRate, currency,
                                                onSale: true)!}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade500,
                                              decoration: TextDecoration.combine(
                                                  [TextDecoration.lineThrough]),
                                            )
                                                .apply(fontSizeFactor: 0.8),
                                          ),
                                        const SizedBox(height: 12),
                                        Text(
                                          price!,
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (product!.options != null &&
                                            options != null)
                                          Services()
                                              .widget
                                              .renderOptionsCartItem(
                                                  product!, options),
                                        // A cart line rebuilt from the server
                                        // has no variation object — only the
                                        // selected options — so gating on
                                        // `variation != null` hid the variant
                                        // for carts filled on another platform
                                        // (86d3g2npa #9).
                                        if (variation != null ||
                                            (options?.isNotEmpty ?? false))
                                          Services()
                                              .widget
                                              .renderVariantCartItem(context,
                                                  product, variation, options),
                                        if (addonsOptions?.isNotEmpty ?? false)
                                          Services()
                                              .widget
                                              .renderAddonsOptionsCartItem(
                                                  context, addonsOptions),
                                        if (product?.store != null &&
                                            (product?.store?.name != null &&
                                                product!.store!.name!
                                                    .trim()
                                                    .isNotEmpty))
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5.0),
                                            child: Text(
                                              product!.store!.name!,
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.secondary,
                                                  fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 16.0),
                    ],
                  ),
                  if(isEdit ?? true)
                  context.isRtl
                      ? Positioned(
                          left: 0,
                          top: 0,
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: onRemove,
                          ),
                        )
                      : Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: onRemove,
                          ),
                        ),
                  if(isEdit ?? true)
                    // Always show the quantity selector in the cart so shoppers
                    // (including guests) can adjust amounts like on the website.
                    // Previously gated behind kProductDetail.showStockQuantity,
                    // which hid it entirely when that config was off.
                    context.isRtl
                        ? Positioned(
                            left: 5,
                            bottom: 0,
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400, width: 1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: quantity,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  style: const TextStyle(fontSize: 14, color: Colors.black),
                                  items: quantities.map((qty) {
                                    return DropdownMenuItem<int>(
                                      value: qty,
                                      child: Text('   $qty'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    onChangeQuantity?.call(value);
                                     // quantity = value!;
                                  },
                                ),
                              ),
                            ),
                            // QuantitySelection(
                            //   height: 32.0,
                            //   expanded: false,
                            //   value: quantity,
                            //   color: theme.colorScheme.secondary,
                            //   limitSelectQuantity: maxQuantity,
                            //   onChanged: onChangeQuantity,
                            // ),
                          )
                        : Positioned(
                            right: 5,
                            bottom: 0,
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400, width: 1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: quantity,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  style: const TextStyle(fontSize: 14, color: Colors.black),
                                  items: quantities.map((qty) {
                                    return DropdownMenuItem<int>(
                                      value: qty,
                                      child: Text('   $qty'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    onChangeQuantity?.call(value);
                                    // quantity = value!;
                                  },
                                ),
                              ),
                            ),
                            // QuantitySelection(
                            //   height: 32.0,
                            //   expanded: false,
                            //   value: quantity,
                            //   color: theme.colorScheme.secondary,
                            //   limitSelectQuantity: maxQuantity,
                            //   onChanged: onChangeQuantity,
                            // ),
                          ),
                ],
              ),
              //const SizedBox(height: 10.0),
              // const Divider(color: kGrey200, height: 1),
              // const SizedBox(height: 10.0),
            ],
          ),
        );
      },
    );
  }

  bool isEqual(String price,String original_price){
    try{
      var priceDouble = double.parse(price);
      var original_priceDouble = double.parse(original_price);
      return priceDouble == original_priceDouble;
    }on Exception catch (_) {
      return false;
    };
  }
}
