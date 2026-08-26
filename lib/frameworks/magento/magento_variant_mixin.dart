import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../models/entities/ProdcutOptionAttribute.dart'
    show ConfigurableSwatch, SwatchOption;
import '../../models/index.dart'
    show Product, ProductAttribute, ProductModel, ProductVariation;
import '../../services/index.dart';
import '../../widgets/product/product_variant.dart';
import '../product_variant_mixin.dart';

mixin MagentoVariantMixin on ProductVariantMixin {
  Future<void> getProductVariations({
    BuildContext? context,
    Product? product,
    void Function({
      Product? productInfo,
      List<ProductVariation>? variations,
      Map<String?, String?> mapAttribute,
      ProductVariation? variation,
    })?
        onLoad,
  }) async {
    if (product!.attributes!.isEmpty) {
      return;
    }

    Map<String?, String?> mapAttribute = HashMap();
    var variations = <ProductVariation>[];
    Product? productInfo;

    await Services().api.getProductVariations(product)!.then((value) {
      variations = value!.toList();
    });

    if (variations.isEmpty) {
      for (var attr in product.attributes!) {
        mapAttribute.update(attr.name!, (value) => attr.options![0],
            ifAbsent: () => attr.options![0]);
      }
    } else {
      /// Seed the default selection with the first valid option of each
      /// configurable attribute (AutoSelectFirstAttribute behaviour).
      /// Option lists can contain junk entries whose label is not a String.
      for (var attribute in product.attributes!) {
        final option = (attribute.options ?? []).firstWhere(
            (o) => o is Map && o['label'] is String && o['value'] != null,
            orElse: () => null);
        if (option != null) {
          mapAttribute[attribute.name] = option['value'].toString();
        }
      }
    }
    var productVariation = updateVariation(variations, mapAttribute);

    /// The seeded first-option combination may not exist as a child product;
    /// fall back to the first child's own attribute values.
    if (productVariation == null && variations.isNotEmpty) {
      for (var attr in variations.first.attributes) {
        if (attr.name != null && attr.option != null) {
          mapAttribute[attr.name] = attr.option;
        }
      }
      productVariation = updateVariation(variations, mapAttribute);
    }
    final model = context?.read<ProductModel>();
    model?.changeProductVariations(variations);
    // Two widgets (body + bottom bar) each run this flow on load. Only seed
    // the default when nothing is selected yet, so a late-finishing second
    // run can't reset a variant the user already picked.
    if (productVariation != null && model?.selectedVariation == null) {
      model?.changeSelectedVariation(productVariation);
    }
    onLoad!(
        productInfo: productInfo,
        variations: variations,
        mapAttribute: mapAttribute,
        variation: productVariation);
    return;
  }

  bool couldBePurchased(
    List<ProductVariation>? variations,
    ProductVariation? productVariation,
    Product product,
    Map<String?, String?>? mapAttribute,
  ) {
    final isAvailable =
        productVariation != null ? productVariation.sku != null : true;
    return isPurchased(productVariation!, product, mapAttribute!, isAvailable);
  }

  void onSelectProductVariant({
    required ProductAttribute attr,
    String? val,
    required List<ProductVariation> variations,
    required Map<String?, String?> mapAttribute,
    required Function onFinish,
  }) {
    mapAttribute.update(attr.name, (value) {
      final option = attr.options!
          .firstWhere((o) => o['label'] == val.toString(), orElse: () => null);
      if (option != null) {
        return option['value'].toString();
      }
      return val.toString();
    }, ifAbsent: () => val.toString());
    final productVariation = updateVariation(variations, mapAttribute);
    onFinish(mapAttribute, productVariation);
  }

  List<Widget> getProductAttributeWidget(
    String lang,
    Product product,
    Map<String?, String?>? mapAttribute,
    Function onSelectProductVariant,
    List<ProductVariation> variations,
  ) {
    var listWidget = <Widget>[];

    final checkProductAttribute =
        product.attributes != null && product.attributes!.isNotEmpty;
    if (checkProductAttribute) {
      for (var attr in product.attributes!) {
        if (attr.name != null && attr.name!.isNotEmpty) {
          var options = <String?>[];
          for (var i = 0; i < attr.options!.length; i++) {
            var label = attr.options![i]['label'];
            if (label is String) {
              options.add(attr.options![i]['label']);
            }
          }

          String? selectedValue = mapAttribute![attr.name!] ?? '';

          final o = attr.options!.firstWhere(
              (f) =>
                  f is Map &&
                  '${f['value']}' == selectedValue &&
                  f['label'] is String,
              orElse: () => null);
          if (o != null) {
            selectedValue = o['label'];
          }

          /// The store's attribute codes are technical (all_color, top_size…)
          /// — resolve the human label from the options/list response, then
          /// translate it via the config map when possible.
          final labelKey = (attr.label ?? attr.name!).toLowerCase();
          final nameKey = attr.name!.toLowerCase();
          final langMap = kProductVariantLanguage[lang];
          final title = langMap?[labelKey] ??
              langMap?[nameKey] ??
              attr.label ??
              attr.name!;
          final type = kProductVariantLayout[labelKey] ??
              kProductVariantLayout[nameKey] ??
              'box';

          /// Swatch hex codes shipped in the options/list payload.
          final swatchCodes = <String, String>{};
          for (var option in attr.options!) {
            if (option is Map &&
                option['label'] is String &&
                option['swatch'] is Map &&
                option['swatch']['value'] is String) {
              swatchCodes[option['label']] = option['swatch']['value'];
            }
          }

          /// Richer swatches from extension_attributes.swatches (product image
          /// per option, so color swatches show the variant photo like the
          /// website). Matched to this attribute by attribute_code.
          ///
          /// The join runs on the option *value id*, never the label: these
          /// options come from configurable-products/<sku>/options/list, which
          /// is always fetched on the default English store view, while the
          /// swatches ride on a product payload fetched in the app's language.
          /// Keying by label therefore missed on every translated colour in
          /// Arabic ("Black" vs "أسود"), which dropped the product photos back
          /// to plain hex circles (86d3g53dk #7).
          final swatchByValue = <String, SwatchOption>{};
          final swatchAttr = product.swatches?.firstWhere(
            (s) => s.attributeCode == attr.name,
            orElse: () => ConfigurableSwatch(),
          );
          for (final opt in swatchAttr?.options ?? <SwatchOption>[]) {
            if (opt.value != null) {
              swatchByValue[opt.value!] = opt;
            }
          }

          /// Fallback option photo: the child product's own image, taken from
          /// the first variation carrying that option. Keeps the web-parity
          /// tile working on products whose payload ships no swatches at all.
          final variationImages = <String, String>{};
          for (final variation in variations) {
            final option = variation.attributeMap[attr.name]?.option;
            final image = variation.imageFeature;
            if (option != null && (image?.isNotEmpty ?? false)) {
              variationImages.putIfAbsent(option, () => image!);
            }
          }

          final swatchOptions = <String, SwatchOption>{};
          final optionImages = <String?, String?>{};
          for (final option in attr.options!) {
            if (option is! Map || option['label'] is! String) {
              continue;
            }
            final label = option['label'] as String;
            final value = '${option['value']}';
            final swatch = swatchByValue[value];
            if (swatch != null) {
              swatchOptions[label] = swatch;
            }
            final image = (swatch?.hasImage ?? false)
                ? swatch!.productImage
                : variationImages[value];
            if (image?.isNotEmpty ?? false) {
              optionImages[label] = image;
            }
          }

          listWidget.add(
            BasicSelection(
              product: product,
              options: options,
              swatchCodes: swatchCodes,
              swatchOptions: swatchOptions,
              imageUrls: optionImages,
              title: title,
              type: type,
              value: selectedValue,
              onChanged: (val) => onSelectProductVariant(
                  attr: attr,
                  val: val,
                  mapAttribute: mapAttribute,
                  variations: variations),
            ),
          );
          listWidget.add(
            const SizedBox(height: 20.0),
          );
        }
      }
    }
    return listWidget;
  }

  List<Widget> getProductTitleWidget(BuildContext context,
      ProductVariation? productVariation, Product product) {
    final isAvailable =
        // ignore: unnecessary_null_comparison
        productVariation != null ? productVariation.sku != null : true;
    return makeProductTitleWidget(
        context, productVariation, product, isAvailable);
  }

  List<Widget> getBuyButtonWidget(
    BuildContext context,
    ProductVariation? productVariation,
    Product product,
    Map<String?, String?>? mapAttribute,
    int maxQuantity,
    int quantity,
    Function addToCart,
    Function onChangeQuantity,
    List<ProductVariation>? variations,
    bool isInAppPurchaseChecking,
    bool  isBuyNow
  ) {
    final isAvailable =
        productVariation != null ? productVariation.sku != null : true;
    return makeBuyButtonWidget(
        context,
        productVariation,
        product,
        mapAttribute,
        maxQuantity,
        quantity,
        addToCart,
        onChangeQuantity,
        isAvailable,
        isInAppPurchaseChecking,isBuyNow: isBuyNow);
  }
}
