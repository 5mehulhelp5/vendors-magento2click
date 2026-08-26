part of '../config.dart';

/// Everything Config about the Product Setting

Map get kProductVariantLayout => Configurations.productVariantLayout;

ProductDetailConfig get kProductDetail =>
    ProductDetailConfig.fromJson(Configurations.productDetail);

Map get kCartDetail => Configurations.cartDetail;

Map get kProductVariantLanguage => Configurations.productVariantLanguage;

SaleoffProductConfig get kSaleOffProduct => SaleoffProductConfig.fromJson(Configurations.saleOffProduct);

bool get kNotStrictVisibleVariant => Configurations.notStrictVisibleVariant;

ProductCardConfig get kProductCard => ProductCardConfig.fromJson(Configurations.productCard);

