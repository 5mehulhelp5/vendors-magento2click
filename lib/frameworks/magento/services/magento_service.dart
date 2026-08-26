import 'dart:async';
import 'dart:convert' as convert;
import 'package:country_pickers/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:inspireui/inspireui.dart';
import 'package:magentoegypt/common/logger.dart';
import 'package:magentoegypt/data/boxes.dart';
import 'package:magentoegypt/models/SearchResponse.dart';
import 'package:magentoegypt/models/banner_images_model.dart';
import 'package:magentoegypt/models/entities/index.dart';
import 'package:magentoegypt/models/entities/product_review.dart';
import 'package:quiver/strings.dart';
import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/events.dart';
import '../../../common/extensions.dart';
import '../../../generated/l10n.dart';
import '../../../models/entities/ProdcutOptionAttribute.dart';
import '../../../models/entities/home_section.dart';
import '../../../models/returns/index.dart';
import '../../../models/index.dart'
    show
        CartModel,
        Category,
        Coupons,
        Order,
        OrderStatus,
        PaymentMethod,
        Product,
        ProductAttribute,
        ProductVariation,
        Review,
        ShippingMethod,
        Store,
        Tax,
        User,
        UserModel;
import '../../../services/base_services.dart';
import '../../../services/https.dart';
import '../../../services/services.dart';
import 'magento_helper.dart';

const bool kEnableProductThumbnail = false;

class MagentoService extends BaseServices {
  final String accessToken;
  String? guestQuoteId;
  Map<String, ProductAttribute>? attributes;
  List<String> brandIds = [];
  Map<String, String>? _brandLabelsCache;
  Future<Map<String, String>>? _brandLabelsInFlight;

  /// Home banners are requested once per `DynamicLayout` section, so a single
  /// home load fires `getBannerImages` ~7x. Coalesce concurrent calls onto one
  /// in-flight request and reuse the result for a short window; a pull-to-
  /// refresh past the TTL fetches fresh. See [getBannerImages].
  List<BannerImagesModel>? _bannersCache;
  DateTime? _bannersCachedAt;
  Future<List<BannerImagesModel>?>? _bannersInFlight;
  static const _bannersTtl = Duration(minutes: 3);

  /// Per-sku caches for the PDP configurable flow. Two widgets (variant body +
  /// bottom bar) both request variations on open; coalescing the in-flight
  /// fetch collapses the duplicate children + per-variant-stock round-trips,
  /// and the attribute list is cached for the session (stable per sku).
  final Map<String, Future<List<ProductAttribute>>> _configAttributesCache = {};
  final Map<String, Future<List<ProductVariation>>> _variationsInFlight = {};

  /// The API's `total_count` from the last `fetchProductsByCategory` response,
  /// so the product-list header can show the real category/brand total instead
  /// of just the loaded page size (e.g. "100 items" for every list).
  int? lastCategoryProductsTotal;

  MagentoService({
    required String domain,
    String? blogDomain,
    required this.accessToken,
  })  : attributes = null,
        guestQuoteId = null,
        super(domain: domain, blogDomain: blogDomain);

  Product parseProductFromJson(productJson, {Map<String, String>? brandLabels}) {
    final dateSaleFrom = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'special_from_date');
    final dateSaleTo = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'special_to_date');
    var onSale = false;

    /// This store leaves the parent `price` at 0 on **configurable** products
    /// (the real pricing lives on the child SKUs), but the list — "before
    /// discount" — price is still exposed on the parent's `vendor_price`
    /// attribute. Fall back to it so configurables get the same discount
    /// detection as simple products; without it every configurable's "-XX%"
    /// badge and strikethrough was silently dropped, because a base price of 0
    /// can never be greater than the discounted price (86d3g4mna).
    ///
    /// `vendor_price` is merchant-entered, though, so it is simply absent on
    /// some configurables — and those show their discounted price alone, with
    /// no strikethrough and no badge, where the website shows both.
    ///
    /// `extension_attributes.minimal_regular_price` is the fix for that: the
    /// minimum *regular* price across the children, read from the price index,
    /// which is the number the website strikes through. It is preferred over
    /// `vendor_price` because it comes from the same index as the current price
    /// (`minimal_price`) below, so both sides of the discount are measured the
    /// same way; mixing an index price with a merchant-entered one is what
    /// produced percentages matching neither the app nor the website.
    ///
    /// Measured over 241 configurables: the two agree on 237, the index alone
    /// is present on 2, and on the 2 where they disagree the index matched the
    /// storefront and `vendor_price` was stale (666 listed 1500 against
    /// children priced 1400). `vendor_price` stays as the fallback for anything
    /// the index does not cover.
    final rawPrice = productJson['price'];
    final vendorPrice = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'vendor_price');
    final minimalRegularPrice =
        productJson['extension_attributes']?['minimal_regular_price'];
    final childRegularPrice =
        (double.tryParse('$minimalRegularPrice') ?? 0) > 0
            ? minimalRegularPrice
            : null;
    final basePrice = (double.tryParse('$rawPrice') ?? 0) > 0
        ? rawPrice
        : (childRegularPrice ?? vendorPrice ?? rawPrice);
    final basePriceValue = double.tryParse('$basePrice') ?? 0;

    var price = basePrice;
    var salePrice = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'special_price');
    var minimalPrice = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'minimal_price');

    /// A `special_price` is only a discount when it is actually LOWER than the
    /// list price. This catalogue contains rows where special_price is *higher*
    /// (e.g. 312 against a 240 list price); Magento and the website both ignore
    /// those, but the app used to apply them regardless — showing the inflated
    /// 312 where the website shows 240 (86d3g4mna).
    ///
    /// When there is no reliable list price at all (base 0 and no
    /// `vendor_price`) still fall back to special_price — showing 0 would be
    /// worse — and `hasReliableRegularPrice` below then keeps onSale off.
    final salePriceValue = double.tryParse('${salePrice ?? ''}');
    final isRealDiscount = salePriceValue != null &&
        (basePriceValue <= 0 || basePriceValue > salePriceValue);

    if (dateSaleFrom != null || dateSaleTo != null) {
      final now = DateTime.now();
      if (dateSaleFrom != null && dateSaleTo != null) {
        onSale = now.isAfter(DateTime.parse(dateSaleFrom)) &&
            now.isBefore(DateTime.parse(dateSaleTo));
      }
      if (dateSaleFrom != null && dateSaleTo == null) {
        onSale = now.isAfter(DateTime.parse(dateSaleFrom));
      }
      if (dateSaleFrom == null && dateSaleTo != null) {
        onSale = now.isBefore(DateTime.parse(dateSaleTo));
      }
      // An in-window sale still has to be a genuine price cut.
      onSale = onSale && isRealDiscount;
      if (onSale) {
        price = salePrice;
        minimalPrice = salePrice;
      }
    } else if (salePrice != null &&
        dateSaleFrom == null &&
        dateSaleTo == null) {
      onSale = isRealDiscount;
      // Only take special_price as the price when it actually undercuts the
      // list price — previously this ran unconditionally.
      if (onSale) {
        price = salePrice;
        minimalPrice = salePrice;
      }
    }


    final mediaGalleryEntries = productJson['media_gallery_entries'];
    var images = kEnableProductThumbnail
        ? [MagentoHelper.getProductImageUrl(domain, productJson, 'thumbnail')]
        : <String>[];
    // Role-first, so the card shows the photo Magento marks as the product
    // image rather than whatever happens to be first in the gallery
    // (86d3x5ex6). Also replaces an `&&`/`||` precedence bug here that
    // dereferenced mediaGalleryEntries.length even when it was null.
    images.addAll(MagentoHelper.orderedGalleryFiles(mediaGalleryEntries)
        .map((file) => MagentoHelper.getProductImageUrlByName(domain, file)));
    var product = Product.fromMagentoJson(productJson);
    final description = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'description');
    final shortDescription = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'short_description');
    product.description = description ?? shortDescription;
    // Only surface the short-description block when it isn't already the
    // sole content of the Details section (description fallback above).
    if (description != null) {
      product.shortDescription = shortDescription;
    }
    product.size_chart = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'size_chart');

    /// Configurable swatches (color/size options with product images +
    /// child product_ids), exposed on both list and single payloads.
    final rawSwatches = productJson['extension_attributes']?['swatches'];
    if (rawSwatches is List) {
      product.swatches = rawSwatches
          .whereType<Map>()
          .map((a) => ConfigurableSwatch.fromJson(a))
          .toList();
    }

    /// Marketplace seller ("Sold by …"), exposed by the backend as
    /// extension_attributes.seller_name (+ seller_shop_url). id is left null so
    /// the same-store related-products block stays off (no vendor API here).
    final sellerName = productJson['extension_attributes']?['seller_name'];
    if (sellerName is String && sellerName.isNotEmpty) {
      product.store = Store.fromLocalJson({
        'name': sellerName,
        'website': productJson['extension_attributes']?['seller_shop_url'],
      });
    }
    if (productJson['type_id'] == 'configurable') {
      // `product.price` (the entity field) is always null at this point —
      // Product.fromMagentoJson() never sets it — so this used to always
      // take the special_price/minimal_price branch below, then throw away
      // the onSale/regularPrice/salePrice already computed above and hard
      // -code onSale=false. That silently dropped every discount badge and
      // "before" price for configurable products (the common case for
      // clothing with size/color options), even when special_price made
      // them genuinely on sale. Check the raw `price` value from the
      // response instead, and reuse the onSale/salePrice already derived
      // from special_price/date range above, same as simple products.
      if (price == null) {
        if((MagentoHelper.getCustomAttribute(productJson['custom_attributes'], 'special_price') ?? "").isNotEmpty){
          product.price = MagentoHelper.getCustomAttribute(
              productJson['custom_attributes'], 'special_price');
        }else{
          product.price = MagentoHelper.getCustomAttribute(
              productJson['custom_attributes'], 'minimal_price');
        }
      } else {
        product.price = '$price';
      }
    } else {
      product.price = '$price';
    }
    // Only trust the base price as the "regular" (before discount) price when
    // it's actually greater than the current price — otherwise claiming
    // onSale=true with a bogus regularPrice shows a broken "0.00"
    // strikethrough/badge instead of just the plain price. `basePrice` already
    // falls back to `vendor_price` for configurables, whose parent `price` is 0.
    final currentPriceValue = double.tryParse(product.price ?? '') ?? 0;
    final hasReliableRegularPrice = basePriceValue > currentPriceValue;
    product.regularPrice =
        hasReliableRegularPrice ? "$basePrice" : product.price;
    product.salePrice = onSale ? salePrice : product.price;
    product.onSale = onSale && hasReliableRegularPrice;

    product.minimalPrice = minimalPrice;
    if (minimalPrice != null) {
      // Same reasoning as hasReliableRegularPrice above: only show
      // minimal_price's predecessor as the "before" price when it's an
      // actual, larger value.
      final minimalPriceValue = double.tryParse(minimalPrice) ?? 0;
      if (currentPriceValue > minimalPriceValue) {
        product.original_price = product.price;
        // This catalogue discounts through CATALOG PRICE RULES, which reach the
        // app as `minimal_price` alone — no `special_price`, no date window. So
        // `onSale` above is computed from special_price and stays false, and
        // every widget keyed on it went quiet: the "-XX%" badge on the PLP card
        // (ProductOnSale) and the percent label on the PDP (ProductTitle). The
        // strikethrough still rendered, because that route keys on
        // `original_price` instead — which is why the cards showed a cut price
        // with no badge next to it. A minimal_price that genuinely undercuts
        // the list price IS a sale, whatever produced it.
        product.onSale = true;
      }
      product.price = minimalPrice;
      product.salePrice = minimalPrice;
    }
    product.images = images;
    // Every card in the app — PLP grids, home carousels, search results —
    // shows the `small_image` role, the same one the website's listings use.
    // Take it from the attribute rather than inferring it from the gallery:
    // the gallery is not returned role-first, so the first entry is often not
    // the product photo at all ("test image product" leads with a stray logo
    // whose `types` is empty, which is what put the wrong image on every grid
    // — 86d3x5ex6). The ordered gallery is only the fallback.
    final smallImage =
        MagentoHelper.getProductImageUrl(domain, productJson, 'small_image');
    // Take Magento's own rendition of it where there is one. The `thumbnail`
    // attribute is a /media/catalog/product/cache/<hash>/… URL, and Magento
    // builds those on demand from the original, so they exist the moment an
    // image is uploaded. The -small/-medium/-large siblings do not: they are
    // written by the resize job, and until it runs they 404 — which renders as
    // an empty card, because a failed load draws nothing. Swapping a photo in
    // the admin used to leave that blank until the job caught up (86d3x5ex6);
    // measured on the 30 newest products, the -medium sibling was missing for
    // one and the rendition URL resolved for all 30.
    //
    // formatImage leaves cache URLs alone, so this is used as-is rather than
    // having a suffix appended to it.
    final thumbnail =
        MagentoHelper.getProductImageUrl(domain, productJson, 'thumbnail');
    // …but not when it is the store's stand-in for "no image at all", which
    // would hide a product that does have a usable gallery photo.
    final preferred =
        (thumbnail.isNotEmpty && !thumbnail.contains('/placeholder/'))
            ? thumbnail
            : smallImage;
    product.imageFeature = preferred.isNotEmpty
        ? preferred
        : (images.isNotEmpty ? images[0] : null);

    final brandId =
        MagentoHelper.getCustomAttribute(productJson['custom_attributes'], 'brand');
    if (brandId != null) {
      product.vendor = brandLabels?[brandId];
    }

    List<dynamic>? categoryIds;
    if (productJson['custom_attributes'] != null &&
        productJson['custom_attributes'].length > 0) {
      for (var item in productJson['custom_attributes']) {
        if (item['attribute_code'] == 'category_ids') {
          categoryIds = item['value'];
          break;
        }
      }
    }
    product.categoryId = categoryIds!.isNotEmpty ? '${categoryIds[0]}' : '0';
    // Shareable storefront link, built from the product's url_key.
    //
    // This was hardcoded to '', so every share entry point took its "url is
    // empty" branch and showed "Failed to generate link" — sharing could never
    // work for any Magento product, on any screen (86d3pq0t0). Nothing was
    // wrong with link *generation*; there was simply never a link.
    //
    // The short form is safe to share: Magento 301s /<store>/<url_key>.html to
    // the canonical category path (verified against the live storefront).
    final urlKey = MagentoHelper.getCustomAttribute(
        productJson['custom_attributes'], 'url_key');
    final trimmedUrlKey = urlKey?.trim() ?? '';
    product.permalink = trimmedUrlKey.isNotEmpty
        ? MagentoHelper.storefrontUrl(
            domain, '$trimmedUrlKey.html', SettingsBox().languageCode)
        : '';

    var attrs = <ProductAttribute>[];
    final options = productJson['extension_attributes'] != null &&
        productJson['extension_attributes']['configurable_product_options'] != null
        ? productJson['extension_attributes']['configurable_product_options']
        : [];
    final configurableProductLinks = productJson['extension_attributes'] != null &&
        productJson['extension_attributes']['configurable_product_links'] != null
        ? productJson['extension_attributes']['configurable_product_links']
        : [];
    product.configurable_product_links = configurableProductLinks;
    product.configurable_product_options = options;
    List? attrsList = kAdvanceConfig.enableAttributesConfigurableProduct;
    List? attrsLabelList =
        kAdvanceConfig.enableAttributesLabelConfigurableProduct;

    for (var i = 0; i < options.length; i++) {
      final option = options[i];

      for (var j = 0; j < attrsList.length; j++) {
        final item = attrsList[j];
        final itemLabel = attrsLabelList[j];
       // if (option['label'].toLowerCase() == itemLabel.toString().toLowerCase()) {
          List? values = option['values'];
          var optionAttr = [];
          if (attributes?[item] != null) {
            for (var f in attributes![item]!.options!) {
              final value = values!.firstWhere(
                  (o) => o['value_index'].toString() == f['value'],
                  orElse: () => null);
              if (value != null) {
                optionAttr.add(f);
              }
            }
            attrs.add(ProductAttribute.fromMagentoJson({
              'attribute_id': attributes![item]!.id,
              'attribute_code': attributes![item]!.name,
              'options': optionAttr
            }));
          }
      //  }
      }
    }
    product.attributes = attrs;
    product.type = productJson['type_id'];
    return product;
  }

  @override
  Future<Product?> getStockStatus(sku) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'stockStatuses/$sku')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      final body = convert.jsonDecode(response.body);

      if (response.statusCode == 200) {
        return Product.fromStockStatusJson(body, domain, sku);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> getStockStatusOld(sku) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'stockItems/$sku')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      final body = convert.jsonDecode(response.body);
      return body['is_in_stock'] ?? false;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProdcutOptionAttribute>> getProductAttributesWithOption(String attributeCode) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'products/attributes/$attributeCode/options')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      final body = convert.jsonDecode(response.body);
      final list = (body as List).map((i) => ProdcutOptionAttribute.fromJson(i)).toList();
      return list;
    } catch (e) {
      rethrow;
    }
  }

  /// Maps the `brand` attribute's numeric option ids (what
  /// `custom_attributes` gives us on a product) to their display label,
  /// fetched once and cached for the app session.
  Future<Map<String, String>> getBrandLabels() async {
    if (_brandLabelsCache != null) return _brandLabelsCache!;
    // Share a single in-flight fetch: profiling showed this ~1.3s brand-
    // attribute call, awaited inline in the product parse, was the biggest hit
    // on the first product list (the parse itself is ~12ms). It's primed at
    // startup (see main.dart); the guard means a product list opened before the
    // prime finishes awaits that same fetch instead of starting a second one.
    return _brandLabelsInFlight ??= _loadBrandLabels();
  }

  Future<Map<String, String>> _loadBrandLabels() async {
    try {
      final options = await getProductAttributesWithOption('brand');
      _brandLabelsCache = {
        for (final o in options)
          if (o.value != null) o.value!: o.label ?? '',
      };
    } catch (e) {
      _brandLabelsCache = {};
    }
    _brandLabelsInFlight = null;
    return _brandLabelsCache!;
  }

  List? _storeViewsCache;
  Future<int?> _storeViewIdForCode(String code) async {
    try {
      if (_storeViewsCache == null) {
        final res = await httpGet(
            MagentoHelper.buildUrl(domain, 'store/storeViews')!,
            headers: {'Authorization': 'Bearer $accessToken'});
        if (res.statusCode == 200) {
          final body = convert.jsonDecode(res.body);
          if (body is List) {
            _storeViewsCache = body;
          }
        }
      }
      final match = _storeViewsCache?.firstWhere(
          (s) => s is Map && s['code'] == code,
          orElse: () => null);
      return match?['id'];
    } catch (_) {
      return null;
    }
  }

  Map<String, Map<String, dynamic>>? _visibleAttributesCache;
  String? _visibleAttributesCacheLang;

  /// attribute_code -> {'label': localized label, 'options': value->label}
  /// for every attribute flagged visible-on-front, fetched once per language.
  /// Used to build the PDP "Product Details" table like the website's
  /// "More Information" tab.
  Future<Map<String, Map<String, dynamic>>> getVisibleFrontAttributes(
      {String? lang}) async {
    final langCode = (lang ?? SettingsBox().languageCode ?? 'en').toLowerCase();
    if (_visibleAttributesCache != null &&
        _visibleAttributesCacheLang == langCode) {
      return _visibleAttributesCache!;
    }
    final result = <String, Map<String, dynamic>>{};
    var succeeded = false;
    try {
      // Store-scoped path so option labels come localized.
      final storePath = langCode == 'ar' ? 'eg-ar' : 'eg-en';
      final storeId =
          await _storeViewIdForCode(storePath.replaceAll('-', '_'));
      final url = '$domain/$storePath/rest/V1/products/attributes?'
          'searchCriteria[filter_groups][0][filters][0][field]=is_visible_on_front'
          '&searchCriteria[filter_groups][0][filters][0][value]=1'
          '&searchCriteria[pageSize]=200'
          '&fields=items[attribute_code,default_frontend_label,frontend_labels,options]';
      final res = await httpGet(url.toUri()!,
          headers: {'Authorization': 'Bearer $accessToken'});
      final body = convert.jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map && body['items'] is List) {
        succeeded = true;
        for (final item in body['items']) {
          final code = item['attribute_code'];
          if (code is! String || code.isEmpty) {
            continue;
          }
          String? label;
          final storeLabels = item['frontend_labels'];
          if (storeId != null && storeLabels is List) {
            final match = storeLabels.firstWhere(
                (l) => l is Map && l['store_id'] == storeId,
                orElse: () => null);
            if (match != null && match['label'] is String) {
              label = match['label'];
            }
          }
          if (label == null && item['default_frontend_label'] is String) {
            label = item['default_frontend_label'];
          }
          if (label == null || label.trim().isEmpty) {
            continue;
          }
          final optionsMap = <String, String>{};
          if (item['options'] is List) {
            for (final option in item['options']) {
              final value = '${option['value'] ?? ''}'.trim();
              final optionLabel = option['label'];
              if (value.isEmpty ||
                  optionLabel is! String ||
                  optionLabel.trim().isEmpty) {
                continue;
              }
              optionsMap[value] = optionLabel.trim();
            }
          }
          result[code] = {'label': label.trim(), 'options': optionsMap};
        }
      }
    } catch (e) {
      printLog('getVisibleFrontAttributes error: $e');
    }
    // Only cache a successful fetch — otherwise a transient failure would
    // suppress the Product Details table for the whole app session.
    if (succeeded) {
      _visibleAttributesCache = result;
      _visibleAttributesCacheLang = langCode;
    }
    return result;
  }

  // attribute_id -> {'label': <store label>, 'options': {value_id: label}},
  // filled lazily as configurable order lines are resolved and cleared on a
  // language change so labels re-fetch localized (86d3tkhgz #3).
  final Map<int, Map<String, dynamic>> _configurableAttrById = {};
  String? _configurableAttrLang;

  @override
  Future<List<Map<String, dynamic>>> resolveConfigurableOptions(
      List<Map<String, dynamic>> options) async {
    if (options.isEmpty) return const [];
    final langCode = (SettingsBox().languageCode ?? 'en').toLowerCase();
    if (_configurableAttrLang != langCode) {
      _configurableAttrById.clear();
      _configurableAttrLang = langCode;
    }
    final missing = <int>{};
    for (final o in options) {
      final id = int.tryParse('${o['attr']}');
      if (id != null && !_configurableAttrById.containsKey(id)) missing.add(id);
    }
    if (missing.isNotEmpty) await _fetchConfigurableAttrs(missing, langCode);

    final result = <Map<String, dynamic>>[];
    for (final o in options) {
      final id = int.tryParse('${o['attr']}');
      final attr = id != null ? _configurableAttrById[id] : null;
      if (attr == null) continue;
      final name = (attr['label'] as String?)?.trim() ?? '';
      final value =
          (attr['options'] as Map?)?['${o['value']}']?.toString().trim() ?? '';
      if (name.isNotEmpty && value.isNotEmpty) {
        result.add({'name': name, 'value': value});
      }
    }
    return result;
  }

  Future<void> _fetchConfigurableAttrs(Set<int> ids, String langCode) async {
    try {
      // Store-scoped path so the option labels and the per-store attribute
      // label both come back localized.
      final storePath = langCode == 'ar' ? 'eg-ar' : 'eg-en';
      final storeId = await _storeViewIdForCode(storePath.replaceAll('-', '_'));
      final url = '$domain/$storePath/rest/V1/products/attributes?'
          'searchCriteria[filter_groups][0][filters][0][field]=attribute_id'
          '&searchCriteria[filter_groups][0][filters][0][value]=${ids.join(',')}'
          '&searchCriteria[filter_groups][0][filters][0][condition_type]=in'
          '&fields=items[attribute_id,default_frontend_label,frontend_labels,options[label,value]]';
      final res = await httpGet(url.toUri()!,
          headers: {'Authorization': 'Bearer $accessToken'});
      final body = convert.jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map && body['items'] is List) {
        for (final item in body['items']) {
          final id = int.tryParse('${item['attribute_id']}');
          if (id == null) continue;
          // Prefer the current store view's label ("Color"/"اللون") over the
          // raw default_frontend_label, which on this store is the admin code
          // (e.g. "all_color").
          String? label;
          final storeLabels = item['frontend_labels'];
          if (storeId != null && storeLabels is List) {
            final match = storeLabels.firstWhere(
                (l) => l is Map && l['store_id'] == storeId,
                orElse: () => null);
            if (match != null && match['label'] is String) {
              label = match['label'];
            }
          }
          if (label == null && item['default_frontend_label'] is String) {
            label = item['default_frontend_label'];
          }
          final optionsMap = <String, String>{};
          if (item['options'] is List) {
            for (final option in item['options']) {
              final value = '${option['value'] ?? ''}'.trim();
              final optionLabel = option['label'];
              if (value.isNotEmpty &&
                  optionLabel is String &&
                  optionLabel.trim().isNotEmpty) {
                optionsMap[value] = optionLabel.trim();
              }
            }
          }
          _configurableAttrById[id] = {
            'label': (label ?? '').trim(),
            'options': optionsMap,
          };
        }
      }
    } catch (e) {
      printLog('resolveConfigurableOptions error: $e');
    }
    // Cache negative lookups too so a missing/failed attribute is not refetched
    // on every rebuild.
    for (final id in ids) {
      _configurableAttrById.putIfAbsent(
          id, () => {'label': '', 'options': <String, String>{}});
    }
  }

  /// Fetch just the configurable swatches for a SKU. Used to backfill
  /// product.swatches on PDPs whose product came from a source that doesn't
  /// carry them (e.g. live-search results), so color swatches render there too.
  Future<List<ConfigurableSwatch>> getProductSwatches(String? sku) async {
    if (sku == null || sku.isEmpty) {
      return [];
    }
    try {
      final res = await httpGet(
          MagentoHelper.buildUrl(domain,
              'products/${Uri.encodeComponent(sku)}?fields=extension_attributes[swatches]')!,
          headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        final body = convert.jsonDecode(res.body);
        final ext = body is Map ? body['extension_attributes'] : null;
        final sw = ext is Map ? ext['swatches'] : null;
        if (sw is List) {
          return sw
              .whereType<Map>()
              .map((a) => ConfigurableSwatch.fromJson(a))
              .toList();
        }
      }
    } catch (e) {
      printLog('getProductSwatches error: $e');
    }
    return [];
  }

  /// Attributes shown elsewhere on the PDP — keep them out of the table.
  static const _kExcludedInforCodes = [
    'description',
    'short_description',
    'size_chart',
  ];

  /// Builds the localized "Product Details" rows (product.infors) from the
  /// product's visible-on-front custom attributes.
  Future<List<ProductAttribute>> getProductInfors(String? sku,
      {String? lang}) async {
    final infors = <ProductAttribute>[];
    if (sku == null || sku.isEmpty) {
      return infors;
    }
    try {
      final meta = await getVisibleFrontAttributes(lang: lang);
      if (meta.isEmpty) {
        return infors;
      }
      final res = await httpGet(
          MagentoHelper.buildUrl(domain,
              'products/${Uri.encodeComponent(sku)}?fields=custom_attributes')!,
          headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode != 200) {
        return infors;
      }
      final body = convert.jsonDecode(res.body);
      final customAttributes = body is Map ? body['custom_attributes'] : null;
      if (customAttributes is! List) {
        return infors;
      }
      for (final attr in customAttributes) {
        final code = attr['attribute_code'];
        final rawValue = attr['value'];
        final attrMeta = meta[code];
        if (attrMeta == null ||
            rawValue == null ||
            _kExcludedInforCodes.contains(code)) {
          continue;
        }
        final optionLabels = attrMeta['options'] as Map<String, String>;
        final values = <String>[];
        // Multiselect values arrive as comma-joined option ids.
        for (final part in '$rawValue'.split(',')) {
          final value = part.trim();
          if (value.isEmpty) {
            continue;
          }
          final resolved = optionLabels[value];
          if (resolved != null) {
            values.add(resolved);
          } else if (optionLabels.isEmpty) {
            // Text attribute — show the raw value.
            values.add(value);
          }
        }
        if (values.isEmpty) {
          continue;
        }
        infors.add(ProductAttribute(
          id: code,
          name: attrMeta['label'],
          label: attrMeta['label'],
          options: values,
        ));
      }
    } catch (e) {
      printLog('getProductInfors error: $e');
    }
    return infors;
  }

  Future getAllAttributes() async {
    try {
      attributes = <String, ProductAttribute>{};
      List attrs = kAdvanceConfig.enableAttributesConfigurableProduct;

      for (var item in attrs) {
        var attrsItem = await getProductAttributes(item);
        attributes![item] = attrsItem;
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<List<ProductAttribute>> getConfigurableproductsAttributes(String sku) {
    // Attributes are stable per sku for a session and are requested several
    // times per PDP open (detail seed + each variant widget), so cache them.
    final cached = _configAttributesCache[sku];
    if (cached != null) return cached;
    final future = _fetchConfigurableProductsAttributes(sku);
    _configAttributesCache[sku] = future;
    // Drop a failed fetch so a later attempt can retry.
    future.then((_) {}, onError: (_) => _configAttributesCache.remove(sku));
    return future;
  }

  Future<List<ProductAttribute>> _fetchConfigurableProductsAttributes(
      String sku) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'configurable-products/$sku/options/list')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      final body = convert.jsonDecode(response.body);
      if (body is List && body.isNotEmpty) {
        final attributes = body[0]['attributes'] as List;

        return attributes
            .map((attr) => ProductAttribute.fromConfigProductJson(attr))
            .toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Parent sku of a configurable cart line, keyed by the child sku.
  final Map<String, Future<String?>> _parentSkuCache = {};

  /// sku of the configurable with this entity id, or null when the id is
  /// missing/unknown or names a product that is not a configurable — a simple
  /// line must keep its own sku.
  final Map<String, Future<String?>> _skuByEntityIdCache = {};

  Future<String?> _configurableSkuByEntityId(String? entityId) {
    if (entityId == null || entityId.isEmpty || entityId == '0') {
      return Future.value(null);
    }
    final cached = _skuByEntityIdCache[entityId];
    if (cached != null) return cached;
    final future = () async {
      try {
        final url = MagentoHelper.buildUrl(domain, 'products')!.replace(
          queryParameters: {
            'searchCriteria[filterGroups][0][filters][0][field]': 'entity_id',
            'searchCriteria[filterGroups][0][filters][0][value]': entityId,
            'searchCriteria[filterGroups][0][filters][0][condition_type]': 'eq',
            'searchCriteria[pageSize]': '1',
          },
        );
        final response = await httpGet(url,
            headers: {'Authorization': 'Bearer $accessToken'});
        final body = convert.jsonDecode(response.body);
        final items = (body is Map) ? body['items'] : null;
        if (items is! List || items.isEmpty) return null;
        final item = items.first;
        if (item is! Map) return null;
        if (item['type_id']?.toString() != 'configurable') return null;
        return item['sku']?.toString();
      } catch (_) {
        return null;
      }
    }();
    _skuByEntityIdCache[entityId] = future;
    future.then((v) {
      if (v == null) _skuByEntityIdCache.remove(entityId);
    }, onError: (_) => _skuByEntityIdCache.remove(entityId));
    return future;
  }

  /// Finds the configurable parent for a cart line.
  ///
  /// `carts/mine/items` reports the *child* sku for a configurable line even
  /// though the line itself is configurable, so without this the cart row would
  /// open the child simple product (no variant picker) instead of the parent
  /// (86d3g2npa #7), and the rebuilt line would key on the child sku while a
  /// locally added one keys on the parent, so a refresh would not line up with
  /// the row it replaced.
  ///
  /// The line does say which parent it belongs to:
  /// `extension_attributes.entity_id` is the *configurable's* entity id, not
  /// the child's (verified on live quotes — child sku amari-store_221225_6 is
  /// catalog id 33985 while the line reports 33987, the configurable whose
  /// `configurable_product_links` contains 33985). [parentEntityId] is that
  /// value, and resolving through it is exact and language-independent.
  ///
  /// The previous implementation searched configurables by the line's *name*
  /// instead. That is what made this fail for a cart filled on the website:
  /// Magento snapshots the item name into the quote in the store view the
  /// shopper used, so a line added on the Arabic storefront carries the Arabic
  /// title, while this lookup runs against eg-en where the product is titled in
  /// English — no match, no parent, and the row opened the variant. (It also
  /// passed the parent's own id as `childEntityId`, so the
  /// `configurable_product_links` confirmation could never match either, and
  /// every resolution leaned on the "exactly one product has this name"
  /// fallback.) The name search is kept below only for lines that arrive
  /// without an entity id.
  Future<String?> getConfigurableParentSku(String childSku, String? parentName,
      {String? parentEntityId}) {
    final cached = _parentSkuCache[childSku];
    if (cached != null) return cached;
    final future = () async {
      final byId = await _configurableSkuByEntityId(parentEntityId);
      if (byId != null) return byId;
      if (parentName == null || parentName.isEmpty) return null;
      try {
        final url = MagentoHelper.buildUrl(domain, 'products')!.replace(
          queryParameters: {
            'searchCriteria[filterGroups][0][filters][0][field]': 'name',
            'searchCriteria[filterGroups][0][filters][0][value]': parentName,
            'searchCriteria[filterGroups][1][filters][0][field]': 'type_id',
            'searchCriteria[filterGroups][1][filters][0][value]': 'configurable',
            'searchCriteria[pageSize]': '10',
          },
        );
        final response = await httpGet(url,
            headers: {'Authorization': 'Bearer $accessToken'});
        final body = convert.jsonDecode(response.body);
        final items = (body is Map) ? body['items'] : null;
        if (items is! List || items.isEmpty) return null;
        // Exactly one configurable carries this name — anything ambiguous is
        // left unresolved rather than guessed at.
        return items.length == 1 ? items.first['sku']?.toString() : null;
      } catch (_) {
        return null;
      }
    }();
    _parentSkuCache[childSku] = future;
    future.then((v) {
      if (v == null) _parentSkuCache.remove(childSku);
    }, onError: (_) => _parentSkuCache.remove(childSku));
    return future;
  }

  /// Attribute lookups keyed by code *or* numeric id. Attributes are stable for
  /// a session and a cart can repeat the same ones across lines, so cache.
  final Map<String, Future<ProductAttribute?>> _attributeByKeyCache = {};

  /// Resolves a configurable attribute from the id Magento puts in a cart
  /// line's `configurable_item_options.option_id`.
  ///
  /// The cart line only ever gives the *child* sku, so the parent's
  /// `configurable-products/{sku}/options/list` cannot be used to name the
  /// selection — that endpoint returns nothing for a simple product. Going
  /// through the attribute itself works from the line alone, and Magento
  /// localizes the option labels per store view, so the value still reads
  /// "Green"/"12 yrs" (or the Arabic equivalents) (86d3g2npa #9).
  Future<ProductAttribute?> getAttributeByIdOrCode(String key) {
    final cached = _attributeByKeyCache[key];
    if (cached != null) return cached;
    final future = () async {
      try {
        final response = await httpGet(
            MagentoHelper.buildUrl(
                domain, 'products/attributes/$key', SettingsBox().languageCode)!,
            headers: {'Authorization': 'Bearer $accessToken'});
        final body = convert.jsonDecode(response.body);
        if (body is! Map || body['attribute_code'] == null) return null;
        final attr = ProductAttribute()
          ..id = body['attribute_id']?.toString()
          ..name = body['attribute_code']?.toString()
          ..options = body['options'] is List ? body['options'] : [];
        // default_frontend_label is often just the raw code (e.g. "all_color");
        // the per-store frontend_labels carry the human title ("Color").
        final defaultLabel = body['default_frontend_label']?.toString();
        String? label =
            (defaultLabel != null && defaultLabel != attr.name && defaultLabel.trim().isNotEmpty)
                ? defaultLabel
                : null;
        if (label == null && body['frontend_labels'] is List) {
          for (final l in body['frontend_labels']) {
            final candidate = (l is Map) ? l['label']?.toString() : null;
            if (candidate != null &&
                candidate.trim().isNotEmpty &&
                candidate != attr.name) {
              label = candidate;
              break;
            }
          }
        }
        attr.label = label ?? attr.name;
        return attr;
      } catch (_) {
        return null;
      }
    }();
    _attributeByKeyCache[key] = future;
    future.then((v) {
      if (v == null) _attributeByKeyCache.remove(key);
    }, onError: (_) => _attributeByKeyCache.remove(key));
    return future;
  }

  Future<ProductAttribute> getProductAttributes(String attributeCode) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'products/attributes/$attributeCode')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      final body = convert.jsonDecode(response.body);
      if (body['message'] != null) {
        throw Exception(MagentoHelper.getErrorMessage(body));
      } else {
        return ProductAttribute.fromMagentoJson(body);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Category>> getCategories({lang}) async {
    try {
      printLog(MagentoHelper.buildUrl(domain, 'mstore/categories', lang)!);
      // Brands and the category tree are independent fetches — kick them off
      // together so the category request isn't queued behind the brand one
      // (parsing below still needs brands, so we await both). Categories change
      // rarely; the standard (1h) disk cache also makes the tree load instantly
      // on re-entry and across app launches.
      final categoriesFuture = httpCache(
          MagentoHelper.buildUrl(domain, 'mstore/categories', lang)!,
          headers: {'Authorization': 'Bearer $accessToken'});
      final brands = await fetchBrands();
      brandIds.clear();
      for (var element in brands) {
        brandIds.add(element.value);
      }
      var response = await categoriesFuture;
      var list = <Category>[];
      if (response.statusCode == 200) {
        for (var item in convert.jsonDecode(response.body)['children_data']) {
          if (item['is_active'] == true && item['include_in_menu'] == true) {
            var category = Category.fromMagentoJson(item,domain);
            category.parent = '0';
            if (item['image'] != null) {
              category.image = item['image'].toString().contains('media/')
                  ? "$kMediaDomain/${item["image"]}"
                  : "$kMediaDomain/media/catalog/category/${item["image"]}";
            }
            list.add(category);
            if(category.brandIds.isNotEmpty){
              attachBrandsAtTopLevel(category,list, brands);
            }

            for (var item1 in item['children_data']) {
              if (item1['is_active'] == true && item1['include_in_menu'] == true) {
                list.add(Category.fromMagentoJson(item1,domain));

                for (var item2 in item1['children_data']) {
                  if (item2['is_active'] == true  && item2['include_in_menu'] == true) {
                    list.add(Category.fromMagentoJson(item2,domain));
                  }
                }
              }
            }
          }
        }
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Brand>> fetchBrands() async {
    var response = await httpGet(
      MagentoHelper.buildUrl(domain, 'mstore/brands', null)!,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = convert.jsonDecode(response.body) as List;
      return data.map((e) => Brand.fromJson(e)).toList();
    }
    return [];
  }

  List<ShopBrand>? _shopBrandsCache;
  bool _shopBrandsFetched = false;

  /// `GET mstore/shopbrands` — the Shop-by-Brand grid, each tile carrying the
  /// `option_id` (brand attribute option value) that keys the brand's product
  /// listing. Not present on every environment yet; returns [] when absent so
  /// callers fall back to the homepage `brands` section. Registers every
  /// option id in [brandIds] so `fetchProductsByCategory` filters by brand.
  Future<List<ShopBrand>> fetchShopBrands() async {
    if (_shopBrandsFetched) return _shopBrandsCache ?? const <ShopBrand>[];
    try {
      final response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mstore/shopbrands', null)!,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        if (data is List) {
          _shopBrandsCache =
              data.whereType<Map>().map(ShopBrand.fromJson).toList();
          for (final b in _shopBrandsCache!) {
            if ((b.optionId?.isNotEmpty ?? false) &&
                !brandIds.contains(b.optionId)) {
              brandIds.add(b.optionId!);
            }
          }
        }
      }
    } catch (_) {}
    _shopBrandsFetched = true;
    return _shopBrandsCache ?? const <ShopBrand>[];
  }

  static String _normalizeBrand(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The `shopbrand/<slug>-store.html` slug from a storefront brand url,
  /// normalized — used to join a homepage `brands` item to a shopbrands tile.
  static String? _brandSlug(String? url) {
    final m =
        RegExp(r'shopbrand/([^/]+?)(?:-store)?\.html').firstMatch(url ?? '');
    return m != null ? _normalizeBrand(m.group(1)) : null;
  }

  /// Resolve a featured brand (a homepage `brands` item, which only has a
  /// positional id) to its `brand` attribute option value, so the app can open
  /// a native product listing instead of the storefront WebView. Prefers the
  /// authoritative `mstore/shopbrands` join (shop-url slug, then name); falls
  /// back to a normalized name match against `mstore/brands`. Ensures the id is
  /// in [brandIds] so the products query filters by brand. Returns null when it
  /// can't be resolved (caller keeps the web fallback).
  Future<String?> resolveBrandOptionId({String? shopUrl, String? name}) async {
    void register(String? id) {
      if ((id?.isNotEmpty ?? false) && !brandIds.contains(id)) {
        brandIds.add(id!);
      }
    }

    // 1) Authoritative: mstore/shopbrands (carries option_id).
    final shop = await fetchShopBrands();
    if (shop.isNotEmpty) {
      final wantSlug = _brandSlug(shopUrl);
      final wantName = _normalizeBrand(name);
      for (final b in shop) {
        if (!(b.optionId?.isNotEmpty ?? false)) continue;
        if ((wantSlug != null && _brandSlug(b.url) == wantSlug) ||
            (wantName.isNotEmpty && _normalizeBrand(b.name) == wantName)) {
          register(b.optionId);
          return b.optionId;
        }
      }
    }

    // 2) Fallback: normalized name match against mstore/brands.
    final want = _normalizeBrand(name);
    if (want.isEmpty) return null;
    final brands = await fetchBrands();
    for (final b in brands) {
      if (_normalizeBrand(b.label) == want) {
        register(b.value);
        return b.value;
      }
    }
    // Unique containment match handles suffix/prefix differences
    // ("Zazu Kids" -> "Zazu", "Do Dress On" -> "Dress on"). Only resolve when
    // exactly one brand matches, so ambiguity safely falls through to the web.
    final contained = brands.where((b) {
      final l = _normalizeBrand(b.label);
      return l.length >= 4 && (want.contains(l) || l.contains(want));
    }).toList();
    if (contained.length == 1) {
      register(contained.first.value);
      return contained.first.value;
    }
    return null;
  }

  /// Backend-curated home / main-category sections
  /// (`GET mstore/homepage-sections`): a list of groups of typed sections
  /// (banner / category / brands). Rendered banner -> category -> brands; the
  /// brands section is shared by the home and main-category screens.
  Future<List<HomeSection>> fetchHomepageSections({String? lang}) async {
    try {
      final response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mstore/homepage-sections', lang)!,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return HomeSection.parseResponse(convert.jsonDecode(response.body));
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Cache for [resolveCategoryUrls], keyed by `lang|url path`. A null value
  /// records "asked, and this path is not a category" (a CMS page), so a
  /// second tap doesn't repeat the lookup.
  final Map<String, CategoryUrlTarget?> _categoryUrlCache = {};

  /// Resolve storefront category paths (`kidswear/boys/t-shirts-shirts`) to
  /// the categories behind them, so links authored in CMS copy can open the
  /// app's own category page instead of the website.
  ///
  /// One request for the whole set: `GET V1/categories/list` filtered by
  /// `url_path in (…)`. Paths that match nothing come back absent — the
  /// caller falls back to opening the page.
  Future<Map<String, CategoryUrlTarget>> resolveCategoryUrls(
    Iterable<String> paths, {
    String? lang,
    String? preferUnder,
  }) async {
    final resolved = <String, CategoryUrlTarget>{};
    final missing = <String>{};
    for (final path in paths.where((p) => p.isNotEmpty).toSet()) {
      final key = '$lang|$path';
      if (_categoryUrlCache.containsKey(key)) {
        final hit = _categoryUrlCache[key];
        if (hit != null) resolved[path] = hit;
      } else {
        missing.add(path);
      }
    }
    if (missing.isEmpty) return resolved;

    try {
      final byPath = await _fetchCategoriesBy('url_path', missing, lang);
      for (final path in missing.toList()) {
        final hit = byPath[path];
        if (hit == null) continue;
        resolved[path] = hit;
        _categoryUrlCache['$lang|$path'] = hit;
        missing.remove(path);
      }

      // Copy is authored by hand and its ancestors go stale
      // ("kidswear/kids-3-12-years/boys/t-shirts-shirts" for what is now
      // "kidswear/boys/t-shirts-shirts"), so fall back to the last segment.
      // That key is rarely unique — every section has a "pants" — which is
      // what [preferUnder] settles: a link in a category's own copy points at
      // that category's subtree.
      final keys = {for (final path in missing) path.split('/').last: path};
      if (keys.isNotEmpty) {
        final byKey = await _fetchCategoriesBy('url_key', keys.keys, lang,
            preferUnder: preferUnder);
        keys.forEach((key, path) {
          final hit = byKey[key];
          if (hit != null) resolved[path] = hit;
          _categoryUrlCache['$lang|$path'] = hit;
        });
      }
    } catch (_) {
      // Leave the unresolved paths out; they open on the web.
    }
    return resolved;
  }

  /// `categories/list` filtered by [field] `in` [values], keyed by that
  /// field's value.
  ///
  /// When a value matches several categories, the one inside [preferUnder]'s
  /// subtree wins (Magento's `path` is `1/2/192/270/287`, so containment is a
  /// substring test on the id). Still ambiguous after that means the value is
  /// left out — opening the page beats opening the wrong category.
  Future<Map<String, CategoryUrlTarget>> _fetchCategoriesBy(
    String field,
    Iterable<String> values,
    String? lang, {
    String? preferUnder,
  }) async {
    final url = MagentoHelper.buildUrl(domain, 'categories/list', lang)!
        .replace(queryParameters: {
      'searchCriteria[filter_groups][0][filters][0][field]': field,
      'searchCriteria[filter_groups][0][filters][0][value]': values.join(','),
      'searchCriteria[filter_groups][0][filters][0][condition_type]': 'in',
      'searchCriteria[pageSize]': '100',
      'fields': 'items[id,name,custom_attributes]',
    });
    final response =
        await httpCache(url, headers: {'Authorization': 'Bearer $accessToken'});
    if (response.statusCode != 200) return {};

    final body = convert.jsonDecode(response.body);
    final items = (body is Map ? body['items'] : null);
    if (items is! List) return {};

    final candidates = <String, List<Map>>{};
    for (final item in items.whereType<Map>()) {
      final value =
          MagentoHelper.getCustomAttribute(item['custom_attributes'], field);
      if (value == null || item['id'] == null) continue;
      candidates.putIfAbsent(value, () => []).add(item);
    }

    final found = <String, CategoryUrlTarget>{};
    candidates.forEach((value, matches) {
      var match = matches.length == 1 ? matches.first : null;
      if (match == null && preferUnder != null) {
        final inSubtree = matches.where((item) {
          final path =
              MagentoHelper.getCustomAttribute(item['custom_attributes'], 'path');
          return path != null && path.contains('/$preferUnder/');
        }).toList();
        if (inSubtree.length == 1) match = inSubtree.first;
      }
      if (match == null) return;
      found[value] = CategoryUrlTarget(
        id: match['id'].toString(),
        name: match['name']?.toString(),
      );
    });
    return found;
  }

  /// A category's own `description` — the SEO box the website renders right
  /// under the category title (e.g. loca-men/clothing/jackets.html). Locafy
  /// authors it on the deepest (L3) categories: a heading, a tagline, body
  /// copy and an FAQ. The value is store-view localized, so [lang] decides
  /// whether the Arabic or the English copy comes back.
  ///
  /// Cached on disk like the category tree — the copy changes rarely and the
  /// page shouldn't wait for it on every re-entry. Returns null when the
  /// category has no description.
  Future<String?> fetchCategoryDescription(
    String categoryId, {
    String? lang,
  }) async {
    try {
      final response = await httpCache(
        MagentoHelper.buildUrl(domain, 'categories/$categoryId', lang)!,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode != 200) return null;
      final body = convert.jsonDecode(response.body);
      if (body is! Map) return null;
      final description = MagentoHelper.getCustomAttribute(
          body['custom_attributes'], 'description');
      return (description?.isNotEmpty ?? false) ? description : null;
    } catch (_) {
      return null;
    }
  }

  /// Backend-curated sections for a MAIN category's landing page
  /// (86d3g36q4). `GET mstore/sections/{categoryId}` returns
  /// `[ { "sections": [ { "label": "...", "sub_category": "id" | "id,id,..." }, ... ] } ]`.
  /// A `sub_category` with several comma-separated ids is a "shop collection"
  /// (hero subcategory banners); a single id is a product carousel whose
  /// products are that category's curated set. Labels are merchant-defined and
  /// vary per category, so callers render whatever comes back. Returns an empty
  /// list when the category has no curation configured.
  Future<List<Map<String, dynamic>>> fetchMainCategorySections(
      String categoryId, {String? lang}) async {
    try {
      final response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mstore/sections/$categoryId', lang)!,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data.first is Map) {
          final sections = (data.first as Map)['sections'];
          if (sections is List) {
            return sections
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();
          }
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  void attachBrandsAtTopLevel(
      Category parentCategory,
      List<Category> categories,
      List<Brand> brands,
      ) {
    // 🔹 Collect all brand IDs from the full tree
    final brandIds = collectBrandIds(parentCategory);

    // 🔹 Match brands
    final matchedBrands = brands.where((brand) {
      final id = int.tryParse(brand.value);
      return id != null && brandIds.contains(id);
    }).toList();


    // 🔥 Create Brand Children
    final brandChildren = matchedBrands.map((b) {
      return Category(
        id: b.value,
        name: b.label,
        parent: "-${parentCategory.id}",
        subCategories: [],
        hasChildren: false,
      );
    }).toList();

    // 🔥 Create "Brands" node (5th item). This one is synthesized app-side
    // rather than coming from the store view, so it needs translating with
    // everything around it — a hard-coded label left "Brands" sitting in
    // English amongst the Arabic categories.
    final brandsNode = Category(
      id: "-${parentCategory.id}", // unique fake id
      name: S.current.brands,
      parent: parentCategory.id,
      subCategories: [],
      hasChildren: true,
    );
    categories.add(brandsNode);
    categories.addAll(brandChildren);
  }

  void attachBrandsAtTopLevel1(
      List<Category> categories,
      List<Brand> brands,
      ) {
    for (var topCategory in categories) {
      // 🔹 Collect all brand IDs from full tree
      final brandIds = collectBrandIds(topCategory);

      if (brandIds.isEmpty) continue;

      // 🔹 Match brands
      final matchedBrands = brands.where((brand) {
        final id = int.tryParse(brand.value);
        return id != null && brandIds.contains(id);
      }).toList();

      if (matchedBrands.isEmpty) continue;

      // 🔥 Create Brand Children
      final brandChildren = matchedBrands.map((b) {
        return Category(
          id: b.value,
          name: b.label,
          parent: topCategory.id,
          subCategories: [],
          hasChildren: false,
        );
      }).toList();

      // 🔥 Create "Brands" node (5th item)
      final brandsNode = Category(
        id: "-${topCategory.id}", // unique fake id
        name: "Brands",
        parent: topCategory.id,
        subCategories: brandChildren,
        hasChildren: true,
      );

      // ✅ Ensure it's always last (optional safe)
      topCategory.subCategories
          .removeWhere((c) => c.name == "Brands");

      topCategory.subCategories.add(brandsNode);
    }
  }

  Set<int> collectBrandIds(Category category) {
    final ids = <int>{};

    // 🔹 from current category
    if (category.brandIds != null) {
      ids.addAll(category.brandIds);
    }

    // 🔁 from children
    for (var child in category.subCategories) {
      ids.addAll(collectBrandIds(child));
    }

    return ids;
  }

  @override
  Future<SearchResponse?> searchProductsResult(String? search) async {
    try {
      // Follow the app language into the matching store view. This was pinned
      // to eg-en, so the Arabic app previewed the *English* catalogue: "shirt"
      // offered 208 products where the Arabic storefront — and the app's own
      // results page, which already honours the language — both say 193. The
      // preview and the page it leads to disagreed by 15 products purely
      // because of the store view (86d3xea48).
      final url = MagentoHelper.storefrontUrl(
          domain,
          'mageworx_searchsuiteautocomplete/ajax/index/'
              '?q=${Uri.encodeComponent(search ?? '')}',
          SettingsBox().languageCode);
      printLog(url);
      var response = await httpGet(Uri.parse(url),
          headers: {'Authorization': 'Bearer $accessToken'});
      if (response.statusCode == 200) {
        return SearchResponse.fromJson(convert.jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// One page of catalog-search hits, in the relevance order the website uses.
  ///
  /// The search *preview* already matches locafy.market because it calls the
  /// same MageWorx autocomplete the website's header uses. The results page
  /// behind "SEE ALL" did not: it ran a plain `name LIKE %keyword%` over the
  /// catalog, which is a different engine entirely — for "dress" that is 24
  /// products against the website's 158, and for "shirt" 108 against 208
  /// (86d3xea48). Anything matched on description, sku, attributes or by
  /// stemming/synonyms was simply invisible.
  ///
  /// `V1/search` with `quick_search_container` is the request the storefront
  /// itself runs, so its `total_count` and ordering match the website exactly
  /// (verified against /eg-en/catalogsearch/result on all three keywords).
  /// It returns ids only, so the caller hydrates them through `mstore/products`.
  ///
  /// NOTE `currentPage` is a 0-based offset here, unlike every other
  /// searchCriteria endpoint in this file: page 0 returns the website's first
  /// results and page 1 already skips [perPage] of them. Callers pass a
  /// 1-based page, so it is decremented below — without that the first
  /// [perPage] hits are never shown.
  ///
  /// [categoryId] narrows the search to one category. It has to be applied
  /// *here* rather than to the hydrating query: the ids are already one page,
  /// so filtering them afterwards drops rows out of that page — searching
  /// "shirt" inside a category returned 12 rows for a page of 20 while the
  /// header still claimed 208 — and the count would still be the unscoped one.
  Future<({List<String> ids, int total})?> searchProductIds(
    String keyword, {
    int page = 1,
    int perPage = 20,
    String? lang,
    String? categoryId,
  }) async {
    if (keyword.trim().isEmpty) return null;
    try {
      final url = MagentoHelper.buildUrl(domain, 'search', lang)!.replace(
        queryParameters: {
          'searchCriteria[requestName]': 'quick_search_container',
          'searchCriteria[filter_groups][0][filters][0][field]': 'search_term',
          'searchCriteria[filter_groups][0][filters][0][value]': keyword,
          if (categoryId != null && categoryId.isNotEmpty) ...{
            'searchCriteria[filter_groups][1][filters][0][field]':
                'category_ids',
            'searchCriteria[filter_groups][1][filters][0][value]': categoryId,
          },
          'searchCriteria[pageSize]': '$perPage',
          'searchCriteria[currentPage]': '${page > 0 ? page - 1 : 0}',
        },
      );
      final response =
          await httpGet(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (response.statusCode != 200) return null;
      final body = convert.jsonDecode(response.body);
      if (body is! Map) return null;
      final items = body['items'];
      if (items is! List) return null;
      final ids = <String>[];
      for (final item in items) {
        final id = (item is Map) ? item['id']?.toString() : null;
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      final rawTotal = body['total_count'];
      final total = rawTotal is int ? rawTotal : int.tryParse('$rawTotal') ?? 0;
      return (ids: ids, total: total);
    } catch (_) {
      // Never fail the whole listing over search: the caller falls back to the
      // old name-LIKE filter.
      return null;
    }
  }

  @override
  Future<List<Product>> getProducts({userId}) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(
              domain, 'mstore/products&searchCriteria[pageSize]=$apiPageSize')!,
          headers: {'Authorization': 'Bearer $accessToken'});
      var list = <Product>[];
      if (response.statusCode == 200) {
        // Resolve brand labels so cards show the seller/brand name
        // (product.vendor), matching the grid path. Cached — one cheap lookup.
        final brandLabels = await getBrandLabels();
        for (var item in convert.jsonDecode(response.body)['items']) {
          var product = parseProductFromJson(item, brandLabels: brandLabels);
          list.add(product);
        }
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Product>> fetchProductsLayout({required config, lang, userId, bool refreshCache = false}) async {
    try {
      var list = <Product>[];
      if (config['layout'] == 'imageBanner' ||
          config['layout'] == 'circleCategory') {
        return list;
      }

      var endPoint = '?';
      if (config.containsKey('category')) {
        endPoint +=
            "searchCriteria[filter_groups][0][filters][0][field]=category_id&searchCriteria[filter_groups][0][filters][0][value]=${config["category"]}&searchCriteria[filter_groups][0][filters][0][condition_type]=eq&searchCriteria[pageSize]=${config['limit'] ?? (config.containsKey('page') ? apiPageSize : kHomeCarouselLimit)}";
      }
      if (config.containsKey('page')) {
        endPoint += "&searchCriteria[currentPage]=${config["page"]}";
      }

      /// sort by
      if (config.containsKey('orderby') && config['orderby'] != null) {
        endPoint +=
            '&searchCriteria[sortOrders][1][field]=${getOrderByKey(config['orderBy'])}';
      }

      if (config.containsKey('order') && config['order'] != null) {
        endPoint +=
            '&searchCriteria[sortOrders][1][direction]=${getOrderDirection(config['order'])}';
      }

      endPoint +=
          '&searchCriteria[filter_groups][1][filters][0][field]=visibility&searchCriteria[filter_groups][1][filters][0][value]=4';

      'mstore/products$endPoint'.log();

      'URL:${MagentoHelper.buildUrl(domain, 'mstore/products$endPoint', lang)!}'
          .log();
      'admin token ${isBlank(accessToken) ? 'MISSING' : 'present'}'.log();

      var response = await httpCache(
        MagentoHelper.buildUrl(domain, 'mstore/products$endPoint', lang)!,
        headers: {'Authorization': 'Bearer $accessToken'},
        // Same catalog payload the grid fetches, so it belongs on the same
        // short TTL. Without this the home carousels sat in the 1h store while
        // the grid used 5m, so the identical product could show a stale price,
        // stock state or image URL for twelve times as long on the home screen
        // as it did one tap away — and a role/image change on the backend took
        // an hour to surface there.
        shortLived: true,
        refreshCache: refreshCache,
      );

      if (response.statusCode == 200) {
        // Resolve brand labels so cards show the seller/brand name
        // (product.vendor), matching the grid path. Cached — one cheap lookup.
        final brandLabels = await getBrandLabels();
        for (var item in convert.jsonDecode(response.body)['items']) {
          var product = parseProductFromJson(item, brandLabels: brandLabels);
          list.add(product);
        }
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  String getOrderByKey(orderBy) {
    switch (orderBy) {
      case 'price':
        return 'price';
      case 'title':
        return 'name';
      // Matches the website's default "Sort by Position" option.
      case 'menu_order':
        return 'position';
      case 'popularity':
      case 'rating':
      case 'date':
      default:
        return 'created_at';
    }
  }

  @override
  String getOrderDirection(order) {
    switch (order) {
      case 'asc':
        return 'ASC';
      case 'desc':
      default:
        return 'DESC';
    }
  }

  // called on details products
  @override
  Future<List<Product>?> fetchProductsByCategory(
      {categoryId,
      tagId,
      page,
      minPrice,
      maxPrice,
      lang,
      orderBy,
      order,
      featured,
      onSale,
      attribute,
      attributeTerm,
      listingLocation,
      userId,
      String? include,
      String? search,
        String? searchText,
      Map<String, List<String>>? attributeFilters,
      nextCursor,
      int? perPage,
      bool refreshCache = false}) async {
    try {
      var endPoint = '?';
      // The synthesized "Brands" menu node has no catalog category of its own
      // (see below), and a brand node filters on `brand` rather than
      // `category_id` — so resolve both up front, the search engine needs the
      // real category id before the query is built.
      final isBrandNode = categoryId != null && brandIds.contains(categoryId);
      String? resolvedCategoryId;
      if (categoryId != null) {
        resolvedCategoryId = '$categoryId';
        if (resolvedCategoryId.startsWith('-') &&
            int.tryParse(resolvedCategoryId.substring(1)) != null) {
          resolvedCategoryId = resolvedCategoryId.substring(1);
        }
      }

      // A keyword search resolves through the storefront's own search engine
      // first, so the results page returns what locafy.market returns instead
      // of a name-LIKE approximation (86d3xea48). The ids come back already
      // paged and in relevance order; `mstore/products` is then only used to
      // hydrate them, so its own paging and sorting must be left off below.
      //
      // Narrowing that cannot be pushed into the search engine is the one case
      // this must not be used for. The ids are already a single page, so a
      // filter applied while hydrating removes rows *from that page* and the
      // count still describes the unfiltered search — short pages under a
      // number that does not match them. The category is pushed into the
      // search itself; brand/price/attribute/on-sale narrowing is not
      // expressible there, so those fall back to the name match, which is less
      // faithful to the website but at least agrees with its own count.
      final hasUnpushableFilter = isBrandNode ||
          minPrice != null ||
          maxPrice != null ||
          onSale == true ||
          (attributeFilters != null && attributeFilters.isNotEmpty);
      final relevance = (isBlank(search) || hasUnpushableFilter)
          ? null
          : await searchProductIds(search!,
              page: (page is int && page > 0) ? page : 1,
              perPage: perPage ?? apiPageSize,
              lang: lang,
              categoryId: resolvedCategoryId);
      final useRelevance = relevance != null && relevance.ids.isNotEmpty;
      // No hits on this page means the end of the results (or a keyword that
      // matches nothing). Stop here rather than falling through to the
      // name-LIKE branch below, which would answer a *different* query and so
      // resurrect the list every time the shopper scrolled past the last page.
      // Only a failed lookup (relevance == null) is allowed to fall back.
      if (relevance != null && relevance.ids.isEmpty) {
        lastCategoryProductsTotal = relevance.total;
        return <Product>[];
      }
      // Skipped when the search engine already scoped the ids to this category
      // — re-applying it here could only ever remove rows from the page.
      if (categoryId != null && !useRelevance) {
        // The synthesized "Brands" menu node has no catalog category of its
        // own: attachBrandsAtTopLevel gives it the id "-<parentCategoryId>".
        // Querying that literally sent category_id=-192, which matches nothing,
        // so tapping Brands opened a "No Product" grid even though its brand
        // strip rendered fine. Resolve it back to the parent category and show
        // that category's products; the brand strip then narrows by brand.
        // (86d3qecbf / brands submenu blank.)
        if (isBrandNode) {
          endPoint +=
          'searchCriteria[filter_groups][0][filters][0][field]=brand&searchCriteria[filter_groups][0][filters][0][value]=$categoryId&searchCriteria[filter_groups][0][filters][0][condition_type]=eq';
        }else{
          endPoint +=
          'searchCriteria[filter_groups][0][filters][0][field]=category_id&searchCriteria[filter_groups][0][filters][0][value]=$resolvedCategoryId&searchCriteria[filter_groups][0][filters][0][condition_type]=eq';
        }

      }
      if (minPrice != null) {
        // Was filter_groups[0].filters[1] — the SAME group as category_id
        // above. Filters within one group are OR'd in Magento's
        // searchCriteria, so that made the query
        // "(category_id = X OR price >= minPrice) AND price <= maxPrice",
        // which let any category item through regardless of price (proven
        // on-device: a category item priced below minPrice still appeared).
        // Needs its own group, isolated from category_id/maxPrice/onSale/
        // search (groups 0/2/3/4), so it's a genuine AND condition.
        endPoint +=
            '&searchCriteria[filter_groups][5][filters][0][field]=price&searchCriteria[filter_groups][5][filters][0][value]=$minPrice&searchCriteria[filter_groups][5][filters][0][condition_type]=gteq';
      }
      if (maxPrice != null) {
        endPoint +=
            '&searchCriteria[filter_groups][2][filters][1][field]=price&searchCriteria[filter_groups][2][filters][1][value]=$maxPrice&searchCriteria[filter_groups][2][filters][1][condition_type]=lteq';
      }
      //Search by SKU
      // Uses filter_groups[4] (not [0], which category_id/minPrice already
      // occupy) so a text search performed inside a category doesn't
      // silently overwrite the category filter via a duplicate query key.
      if (search != null) {
        // This block used to be missing its leading '&', so whenever a
        // category/price filter had already been appended above, this
        // segment ran straight into it with no separator — corrupting the
        // whole query string and causing the backend to 404 on searches
        // performed from within a category.
        if (endPoint != '?') endPoint += '&';
        if (useRelevance) {
          // Hydrate exactly the hits the search engine returned for this page.
          endPoint +=
              'searchCriteria[filter_groups][4][filters][0][field]=entity_id'
              '&searchCriteria[filter_groups][4][filters][0][value]=${relevance.ids.join(',')}'
              '&searchCriteria[filter_groups][4][filters][0][condition_type]=in';
        } else if (kAdvanceConfig.enableSkuSearch) {
          endPoint +=
              'searchCriteria[filter_groups][4][filters][0][field]=name&searchCriteria[filter_groups][4][filters][0][value]=%$search%&searchCriteria[filter_groups][4][filters][0][condition_type]=like&searchCriteria[filter_groups][4][filters][1][field]=sku&searchCriteria[filter_groups][4][filters][1][value]=%$search%&searchCriteria[filter_groups][4][filters][1][condition_type]=like';
        } else {
          endPoint +=
              'searchCriteria[filter_groups][4][filters][0][field]=name&searchCriteria[filter_groups][4][filters][0][value]=%$search%&searchCriteria[filter_groups][4][filters][0][condition_type]=like';
        }
      }
      // Layered-navigation attribute filters (Brand, Colour, Size, Gender,
      // Material, …) selected from the filter panel. Each attribute gets its
      // OWN filter group (starting at index 6 — 0-5 are taken by
      // category/visibility/max-price/on-sale/search/min-price), so different
      // attributes are AND'd together. Multiple selected values for one
      // attribute go in a single `in` filter, so they are OR'd — exactly
      // Magento layered navigation and the website. The option ids are the
      // same EAV values `brand`/`category_id` already filter on above.
      if (attributeFilters != null && attributeFilters.isNotEmpty) {
        var groupIndex = 6;
        attributeFilters.forEach((field, values) {
          final clean =
              values.where((v) => v.trim().isNotEmpty).toList();
          if (field.trim().isEmpty || clean.isEmpty) return;
          if (endPoint != '?') endPoint += '&';
          final joined = clean.join(',');
          endPoint +=
              'searchCriteria[filter_groups][$groupIndex][filters][0][field]=$field'
              '&searchCriteria[filter_groups][$groupIndex][filters][0][value]=$joined'
              '&searchCriteria[filter_groups][$groupIndex][filters][0][condition_type]=in';
          groupIndex++;
        });
      }
      // The relevance path has already paged: the ids ARE this page, so asking
      // mstore/products for page N of them would return nothing.
      if (page != null && !useRelevance) {
        endPoint += '&searchCriteria[currentPage]=$page';
      }

      // Likewise, a sort would throw away the relevance ranking the website
      // orders search results by — only send one the shopper actually picked.
      if (!useRelevance || orderBy != null) {
        endPoint +=
            '&searchCriteria[sortOrders][1][field]=${getOrderByKey(orderBy)}';

        endPoint +=
            '&searchCriteria[sortOrders][1][direction]=${getOrderDirection(order)}';
      }

      if (onSale == true) {
        endPoint +=
            '&searchCriteria[filter_groups][3][filters][0][field]=special_price&searchCriteria[filter_groups][3][filters][0][condition_type]=notnull';
      }
      endPoint +=
          '&searchCriteria[pageSize]=${useRelevance ? relevance.ids.length : (perPage ?? apiPageSize)}';

      endPoint +=
          '&searchCriteria[filter_groups][1][filters][0][field]=visibility&searchCriteria[filter_groups][1][filters][0][value]=4';
      // `searchText` used to be appended here as mstore/products' full-text
      // `q=` parameter. That endpoint 500s as soon as `q` is combined with any
      // searchCriteria filter — including the visibility filter every call
      // above adds — so it could only ever blank the listing. Keyword search
      // now goes through searchProductIds above; the parameter is kept in the
      // signature because the shared BaseServices API declares it.
      // Short-TTL catalog cache: opening a product and coming back re-uses the
      // list instantly; a pull-to-refresh passes refreshCache to bypass it.
      var response = await httpCache(
          MagentoHelper.buildUrl(domain, 'mstore/products$endPoint', lang)!,
          headers: {'Authorization': 'Bearer $accessToken'},
          shortLived: true,
          refreshCache: refreshCache);

      var list = <Product>[];
      if (response.statusCode == 200) {
        final decoded = convert.jsonDecode(response.body);
        final total = decoded is Map ? decoded['total_count'] : null;
        lastCategoryProductsTotal =
            total is int ? total : int.tryParse('$total');
        final brandLabels = await getBrandLabels();
        for (var item
            in (decoded is Map ? decoded['items'] : null) ?? const []) {
          var product = parseProductFromJson(item, brandLabels: brandLabels);
          list.add(product);
        }
        if (useRelevance) {
          // `entity_id in (...)` comes back in id order, not the order it was
          // asked for, so put the search engine's ranking back — that ranking
          // is what makes the first screen match the website's first screen.
          final rank = <String, int>{
            for (var i = 0; i < relevance.ids.length; i++) relevance.ids[i]: i
          };
          list.sort((a, b) => (rank[a.id] ?? relevance.ids.length)
              .compareTo(rank[b.id] ?? relevance.ids.length));
          // The count beside the title has to be the number of hits, not the
          // size of this page — and it is what the preview shows too, so the
          // two finally agree (86d3xea48).
          lastCategoryProductsTotal = relevance.total;
        }
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch the web-parity filter attributes (Brand, Colour, Size, Gender,
  /// Material, Pattern, Sleeve length, Style, Product Type, …) for a category
  /// via the storefront GraphQL `aggregations` — the only surface on this
  /// install that exposes layered-navigation options/counts (the REST
  /// `mstore/products` endpoint has none). The *selected* values are then
  /// applied back through REST `fetchProductsByCategory` so the product list,
  /// prices and paging stay on the existing REST path. See docs/qa-followups.md
  /// item 3.
  /// [webParityOnly] restricts the panel to the attributes the website
  /// actually exposes on a subcategory page — Brand and Colour (the web's
  /// other two, Category and Price, are already rendered by the category tree
  /// and the price slider). Applied for Magento L2/L3 (main category and
  /// subcategory) so the app's filter list matches locafy.market, e.g.
  /// /eg-ar/kidswear/boys.html, which shows exactly
  /// فئة / الماركة / الألوان / السعر. L4 and deeper keep the full aggregation
  /// set. See ClickUp 86d3g3mea item 3.
  Future<List<CategoryFilterAttribute>> fetchCategoryFilters({
    required String categoryId,
    String? lang,
    bool webParityOnly = false,
  }) async {
    try {
      final langCode = (lang ?? SettingsBox().languageCode ?? 'en').toLowerCase();
      final store = langCode == 'ar' ? 'eg_ar' : 'eg_en';
      final query = '''
{
  products(filter: {category_id: {eq: "$categoryId"}}, pageSize: 1) {
    aggregations {
      attribute_code
      label
      options { label value count }
    }
  }
}''';
      final response = await httpPost(
        '$domain/graphql'.toUri()!,
        headers: {'content-type': 'application/json', 'Store': store},
        body: convert.jsonEncode({'query': query}),
      );
      if (response.statusCode != 200) return const [];
      final body = convert.jsonDecode(response.body);
      final aggs = body?['data']?['products']?['aggregations'];
      if (aggs is! List) return const [];

      // `category_id` and `price` are already covered by the category tree and
      // the price slider in the panel — don't duplicate them as chips.
      //
      // The category aggregation comes back as `category_uid`, NOT
      // `category_id`, so it used to slip past this set and render a
      // "Category" group whose option values are base64 ids (`Mjcw` = "270").
      // Those were then sent to REST as
      // `filter_groups[n][filters][0][field]=category_uid` — a field REST
      // doesn't have, and it doesn't decode base64 either — so every tap in
      // that group returned an empty list.
      const skip = {'category_id', 'category_uid', 'price'};

      // The attribute codes the website's layered navigation exposes.
      const webParityCodes = {'brand', 'all_color'};

      // Merge attributes that share a display label into one group (e.g. the
      // several category-specific `*_producttype` codes all show as "Product
      // Type" on the web). Each option keeps its own attribute_code so it
      // still filters the right field.
      final byLabel = <String, List<CategoryFilterOption>>{};
      final order = <String>[];
      for (final agg in aggs) {
        final code = '${agg['attribute_code'] ?? ''}'.trim();
        if (code.isEmpty || skip.contains(code)) continue;
        if (webParityOnly && !webParityCodes.contains(code)) continue;
        final label = '${agg['label'] ?? code}'.trim();
        if (label.isEmpty) continue;
        final options = agg['options'];
        if (options is! List) continue;
        final parsed = <CategoryFilterOption>[];
        for (final o in options) {
          final value = '${o['value'] ?? ''}'.trim();
          final optLabel = '${o['label'] ?? ''}'.trim();
          if (value.isEmpty || optLabel.isEmpty) continue;
          final rawCount = o['count'];
          final count = rawCount is num
              ? rawCount.toInt()
              : int.tryParse('${rawCount ?? ''}') ?? 0;
          parsed.add(CategoryFilterOption(
            code: code,
            label: optLabel,
            value: value,
            count: count,
          ));
        }
        if (parsed.isEmpty) continue;
        if (!byLabel.containsKey(label)) order.add(label);
        byLabel.putIfAbsent(label, () => []).addAll(parsed);
      }

      return [
        for (final label in order)
          CategoryFilterAttribute(label: label, options: byLabel[label]!),
      ];
    } catch (e) {
      printLog('fetchCategoryFilters error: $e');
      return const [];
    }
  }


  @override
  Future<PagingResponse<Review>>? getReviews(productId,
      {int page = 1, int perPage = 10}) async {
    final sku = '$productId';
    try {
      // Customer photos are only carried on the REST reviews feed (approved
      // reviews for the product), so it is the source of truth for the list.
      // GraphQL — which has no image field — stays as a fallback for when the
      // REST route is unavailable. `productId` must be the product SKU.
      final res = await httpGet(
        MagentoHelper.buildUrl(domain,
            'products/${Uri.encodeComponent(sku)}/reviews',
            SettingsBox().languageCode)!,
      );
      if (res.statusCode == 200) {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is List) {
          final list = <Review>[];
          for (final item in decoded) {
            if (item is Map) list.add(_reviewFromRest(item));
          }
          return PagingResponse(data: list);
        }
      }
      // Reachable but unexpected payload — try GraphQL before giving up.
      return PagingResponse(
          data: await _getReviewsViaGraphQL(sku, page, perPage));
    } catch (e) {
      printLog('getReviews REST error: $e');
      try {
        return PagingResponse(
            data: await _getReviewsViaGraphQL(sku, page, perPage));
      } catch (e2) {
        // Degrade to the widget's empty state rather than a stuck spinner.
        printLog('getReviews GraphQL fallback error: $e2');
        return PagingResponse(data: <Review>[]);
      }
    }
  }

  /// The signed-in customer's own reviews across all products (includes
  /// pending ones), from the `self`-scoped REST feed. Powers the "your
  /// reviews" surfaces (e.g. the review box on a completed order) that the
  /// public product feed can't serve — it carries no customer identity.
  @override
  Future<PagingResponse<Review>>? getMyReviews(
      {int page = 1, int perPage = 20, String? token}) async {
    try {
      final authToken = token ?? UserBox().userInfo?.cookie;
      if (authToken == null || authToken.isEmpty) {
        return PagingResponse(data: <Review>[]);
      }
      final res = await httpGet(
        MagentoHelper.buildUrl(domain,
            'customers/me/reviews?currentPage=$page&pageSize=$perPage',
            SettingsBox().languageCode)!,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (res.statusCode == 200) {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is List) {
          final list = <Review>[];
          for (final item in decoded) {
            if (item is Map) list.add(_reviewFromRest(item));
          }
          return PagingResponse(data: list);
        }
      }
      return PagingResponse(data: <Review>[]);
    } catch (e) {
      printLog('getMyReviews error: $e');
      return PagingResponse(data: <Review>[]);
    }
  }

  // ---------------------------------------------------------------------------
  // Customer Returns (RMA)
  //
  // Eight `self`-scoped REST endpoints under `customers/me/...`, authed with the
  // customer's own bearer token (from UserBox) — never the app's integration
  // token. URLs carry the store-view code so labels come localized. Passive
  // fetches degrade to null/empty so the feature self-hides when the backend
  // module is off or a store-view rejects the token; explicit actions throw the
  // server's shopper-ready `message` (via getErrorMessage).
  // ---------------------------------------------------------------------------

  @override
  Future<ReturnPolicy?> getReturnPolicy() async {
    try {
      final authToken = UserBox().userInfo?.cookie;
      if (authToken == null || authToken.isEmpty) return null;
      final res = await httpGet(
        MagentoHelper.buildUrl(
            domain, 'customers/me/return-policy', SettingsBox().languageCode)!,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      final body = res.body.isNotEmpty ? convert.jsonDecode(res.body) : null;
      // 401 / disabled / unexpected → treat as unavailable so the UI hides it.
      if (body is Map && body['message'] != null) return null;
      if (res.statusCode == 200 && body is Map) {
        return ReturnPolicy.fromJson(body);
      }
      return null;
    } catch (e) {
      // A 404 (module not installed) throws from the transport layer — swallow
      // it: returns simply isn't available on this store.
      printLog('getReturnPolicy error: $e');
      return null;
    }
  }

  @override
  Future<List<ReturnableOrder>> getReturnableOrders() async {
    try {
      final authToken = UserBox().userInfo?.cookie;
      if (authToken == null || authToken.isEmpty) {
        return const <ReturnableOrder>[];
      }
      final res = await httpGet(
        MagentoHelper.buildUrl(domain, 'customers/me/returnable-orders',
            SettingsBox().languageCode)!,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (res.statusCode == 200) {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => ReturnableOrder.fromJson(e))
              .toList();
        }
      }
      return const <ReturnableOrder>[];
    } catch (e) {
      printLog('getReturnableOrders error: $e');
      return const <ReturnableOrder>[];
    }
  }

  @override
  Future<ReturnRequest> createReturn({
    required int orderId,
    required List<ReturnLineInput> items,
    required String resolution,
    String? comment,
  }) async {
    final authToken = UserBox().userInfo?.cookie;
    if (authToken == null || authToken.isEmpty) {
      throw Exception(S.current.somethingWrong);
    }
    // The typed parameter is wrapped in `request`; inner keys are camelCase.
    final payload = {
      'request': {
        'orderId': orderId,
        'items': [for (final it in items) it.toJson()],
        'resolution': resolution,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    };
    final res = await httpPost(
      MagentoHelper.buildUrl(
          domain, 'customers/me/returns', SettingsBox().languageCode)!,
      headers: {
        'Authorization': 'Bearer $authToken',
        'content-type': 'application/json',
      },
      body: convert.jsonEncode(payload),
    );
    final body = res.body.isNotEmpty ? convert.jsonDecode(res.body) : null;
    if (body is Map && body['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(body));
    }
    if (res.statusCode == 200 && body is Map) {
      return ReturnRequest.fromJson(body);
    }
    throw Exception(S.current.somethingWrong);
  }

  @override
  Future<PagingResponse<ReturnRequest>> getMyReturns({
    User? user,
    dynamic cursor,
  }) async {
    // The returns list endpoint returns the whole list in one response, so only
    // serve it on the first page; later pages return empty to end pagination
    // (mirrors ListOrderRepository.getLocalOrders).
    if (cursor != null && cursor != 1) {
      return const PagingResponse(data: <ReturnRequest>[]);
    }
    try {
      final authToken = user?.cookie ?? UserBox().userInfo?.cookie;
      if (authToken == null || authToken.isEmpty) {
        return const PagingResponse(data: <ReturnRequest>[]);
      }
      final res = await httpGet(
        MagentoHelper.buildUrl(
            domain, 'customers/me/returns', SettingsBox().languageCode)!,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (res.statusCode == 200) {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((e) => ReturnRequest.fromJson(e))
              .toList();
          return PagingResponse(data: list);
        }
      }
      return const PagingResponse(data: <ReturnRequest>[]);
    } catch (e) {
      printLog('getMyReturns error: $e');
      return const PagingResponse(data: <ReturnRequest>[]);
    }
  }

  @override
  Future<ReturnRequest> getReturnDetail(int id) async {
    final authToken = UserBox().userInfo?.cookie;
    if (authToken == null || authToken.isEmpty) {
      throw Exception(S.current.somethingWrong);
    }
    final res = await httpGet(
      MagentoHelper.buildUrl(
          domain, 'customers/me/returns/$id', SettingsBox().languageCode)!,
      headers: {'Authorization': 'Bearer $authToken'},
    );
    final body = res.body.isNotEmpty ? convert.jsonDecode(res.body) : null;
    if (body is Map && body['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(body));
    }
    if (res.statusCode == 200 && body is Map) {
      return ReturnRequest.fromJson(body);
    }
    throw Exception(S.current.somethingWrong);
  }

  @override
  Future<String> cancelReturn(int id, {String? comment}) async {
    return _returnAction('customers/me/returns/$id/cancel', {
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  @override
  Future<String> addReturnComment(int id, String comment) async {
    return _returnAction(
        'customers/me/returns/$id/comments', {'comment': comment});
  }

  @override
  Future<String> addReturnTracking(
    int id, {
    required String carrierCode,
    required String trackNumber,
  }) async {
    // Tracking payload is wrapped in `tracking`; inner keys are camelCase.
    return _returnAction('customers/me/returns/$id/tracking', {
      'tracking': {'carrierCode': carrierCode, 'trackNumber': trackNumber},
    });
  }

  /// Shared POST for the small write-actions on a return (cancel / comment /
  /// tracking). Each returns `{success, ..., message}` on 200; anything with a
  /// `message` and no success is surfaced as the server's shopper-ready error.
  Future<String> _returnAction(String endpoint, Map<String, dynamic> body) async {
    final authToken = UserBox().userInfo?.cookie;
    if (authToken == null || authToken.isEmpty) {
      throw Exception(S.current.somethingWrong);
    }
    final res = await httpPost(
      MagentoHelper.buildUrl(domain, endpoint, SettingsBox().languageCode)!,
      headers: {
        'Authorization': 'Bearer $authToken',
        'content-type': 'application/json',
      },
      body: convert.jsonEncode(body),
    );
    final decoded = res.body.isNotEmpty ? convert.jsonDecode(res.body) : null;
    if (decoded is Map && decoded['success'] == true) {
      return decoded['message']?.toString() ?? '';
    }
    if (decoded is Map && decoded['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(decoded));
    }
    throw Exception(S.current.somethingWrong);
  }

  @override
  Future<Map<String, ({String name, String? image})>> getReviewedProductInfo(
      List<String> skus) async {
    final result = <String, ({String name, String? image})>{};
    final distinct = skus.where((s) => s.isNotEmpty).toSet().toList();
    if (distinct.isEmpty) return result;
    try {
      final langCode = (SettingsBox().languageCode ?? 'en').toLowerCase();
      final store = langCode == 'ar' ? 'eg_ar' : 'eg_en';
      final skuList =
          distinct.map((s) => '"${s.replaceAll('"', r'\"')}"').join(',');
      final query = '''
{
  products(filter: {sku: {in: [$skuList]}}, pageSize: ${distinct.length}) {
    items { sku name small_image { url } }
  }
}''';
      final response = await httpPost(
        '$domain/graphql'.toUri()!,
        headers: {'content-type': 'application/json', 'Store': store},
        body: convert.jsonEncode({'query': query}),
      );
      if (response.statusCode == 200) {
        final body = convert.jsonDecode(response.body);
        final items = body?['data']?['products']?['items'];
        if (items is List) {
          for (final item in items) {
            if (item is! Map) continue;
            final sku = '${item['sku'] ?? ''}';
            if (sku.isEmpty) continue;
            var image = item['small_image'] is Map
                ? item['small_image']['url'] as String?
                : null;
            // GraphQL hands back the `/catalog/product/cache/<hash>/` resize
            // URL, which serves the store placeholder on this backend. Strip it
            // to the original path so the app's own `-small/-medium` resize
            // backend loads the real image — the same way the PLP/PDP do (the
            // Magento resize cache is unreliable here; the originals are fine).
            image = image?.replaceFirst(
                RegExp(r'/catalog/product/cache/[^/]+/'), '/catalog/product/');
            result[sku] = (name: '${item['name'] ?? ''}', image: image);
          }
        }
      }
    } catch (e) {
      printLog('getReviewedProductInfo error: $e');
    }
    return result;
  }

  /// Maps one object from a REST reviews feed (the public product feed or the
  /// customer's own feed — same shape) to a [Review], pulling photo URLs out
  /// of `images`, ordered by `sort_order`.
  Review _reviewFromRest(Map item) {
    final title = '${item['title'] ?? ''}'.trim();
    final detail = '${item['detail'] ?? ''}'.trim();
    final percent = item['rating_percent'];
    final urls = <String>[];
    final imgs = item['images'];
    if (imgs is List) {
      final sorted = imgs.whereType<Map>().toList()
        ..sort((a, b) => (((a['sort_order'] as num?) ?? 0))
            .compareTo(((b['sort_order'] as num?) ?? 0)));
      for (final img in sorted) {
        final url = '${img['url'] ?? ''}'.trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }
    return Review.fromMagentoJson({
      'id': item['review_id'],
      'sku': item['sku'],
      'status': item['status'],
      'name': item['nickname'],
      'review': _mergeTitleDetail(title, detail),
      // REST sends a 0-100 percentage; the UI expects 0-5.
      'rating': percent is num ? percent / 20.0 : null,
      'date_created': item['created_at'],
      'images': urls,
    });
  }

  /// The app's review form has a single field, so a submitted review's title is
  /// an auto-truncated copy of the body ("great pro…" vs "great product.").
  /// Show the title only when it's a genuinely distinct headline — otherwise
  /// the body would appear twice (86d3g53dk #10).
  String _mergeTitleDetail(String title, String detail) {
    final t = title.trim();
    final d = detail.trim();
    if (d.isEmpty) return t;
    if (t.isEmpty) return d;
    // Strip a trailing ellipsis/period/space so a truncated title still
    // matches the start of the full body.
    final core = t.replaceAll(RegExp(r'[…\.\s]+$'), '');
    if (t == d || (core.isNotEmpty && d.startsWith(core))) {
      return d;
    }
    return '$t\n$d';
  }

  Future<List<Review>> _getReviewsViaGraphQL(
      String productId, int page, int perPage) async {
    final langCode = (SettingsBox().languageCode ?? 'en').toLowerCase();
    final store = langCode == 'ar' ? 'eg_ar' : 'eg_en';
    final query = '''
{
  products(filter: {sku: {eq: "$productId"}}) {
    items {
      reviews(pageSize: $perPage, currentPage: $page) {
        items {
          nickname
          summary
          text
          average_rating
          created_at
        }
      }
    }
  }
}''';
    final response = await httpPost(
      '$domain/graphql'.toUri()!,
      headers: {'content-type': 'application/json', 'Store': store},
      body: convert.jsonEncode({'query': query}),
    );
    final list = <Review>[];
    if (response.statusCode == 200) {
      final body = convert.jsonDecode(response.body);
      final items = body?['data']?['products']?['items'];
      if (items is List && items.isNotEmpty) {
        final reviewItems = items.first?['reviews']?['items'];
        if (reviewItems is List) {
          for (final item in reviewItems) {
            final summary = '${item['summary'] ?? ''}'.trim();
            final text = '${item['text'] ?? ''}'.trim();
            final rating = item['average_rating'];
            list.add(Review.fromMagentoJson({
              'name': item['nickname'],
              'review': _mergeTitleDetail(summary, text),
              // GraphQL returns a 0-100 percentage; the UI expects 0-5.
              'rating': rating is num ? rating / 20.0 : null,
              'date_created': item['created_at'],
            }));
          }
        }
      }
    }
    return list;
  }

  @override
  Future<PagingResponse<ProductReview>>? getProductReviews(productSKU, {int page = 1, int perPage = 10}) async {
    try {
      // Same GraphQL source as getReviews — the REST route doesn't exist.
      final langCode = (SettingsBox().languageCode ?? 'en').toLowerCase();
      final store = langCode == 'ar' ? 'eg_ar' : 'eg_en';
      final query = '''
{
  products(filter: {sku: {eq: "$productSKU"}}) {
    items {
      reviews(pageSize: $perPage, currentPage: $page) {
        items {
          nickname
          summary
          text
          average_rating
          created_at
        }
      }
    }
  }
}''';
      final response = await httpPost(
        '$domain/graphql'.toUri()!,
        headers: {'content-type': 'application/json', 'Store': store},
        body: convert.jsonEncode({'query': query}),
      );
      var list = <ProductReview>[];
      if (response.statusCode == 200) {
        final body = convert.jsonDecode(response.body);
        final items = body?['data']?['products']?['items'];
        if (items is List && items.isNotEmpty) {
          final reviewItems = items.first?['reviews']?['items'];
          if (reviewItems is List) {
            for (final item in reviewItems) {
              final percent = item['average_rating'];
              list.add(ProductReview(
                title: item['summary'],
                detail: item['text'],
                nickname: item['nickname'],
                createdAt: '${item['created_at'] ?? ''}',
                ratings: [
                  if (percent is num)
                    // GraphQL sends a 0-100 percentage; the star row
                    // averages the 0-5 `value`s.
                    Ratings(
                      percent: percent.toInt(),
                      value: (percent / 20).round(),
                    ),
                ],
              ));
            }
          }
        }
      }
      return PagingResponse(data: list);
    } catch (e) {
      rethrow;
    }
  }

  /// Rating-code metadata: rating_id -> ordered list of option value ids
  /// (index i is the (i+1)-star option), from mobiconnect/review/ratingoption.
  List<Map<String, dynamic>>? _ratingOptionsCache;
  Future<List<Map<String, dynamic>>> _getRatingOptions() async {
    if (_ratingOptionsCache != null) return _ratingOptionsCache!;
    final result = <Map<String, dynamic>>[];
    try {
      final res = await httpGet(
          MagentoHelper.buildUrl(domain, 'mobiconnect/review/ratingoption')!,
          headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        final body = convert.jsonDecode(res.body);
        final first = body is List && body.isNotEmpty ? body[0] : null;
        final dataMap = first is Map ? first['data'] : null;
        final options = dataMap is Map ? dataMap['rating-option'] : null;
        if (options is List) {
          for (final o in options) {
            final ratingId = int.tryParse('${o['rating-id']}');
            final values = (o['option'] as List?)
                ?.map((v) => int.tryParse('${v['value']}'))
                .whereType<int>()
                .toList();
            if (ratingId != null && values != null && values.isNotEmpty) {
              result.add({'rating_id': ratingId, 'values': values});
            }
          }
        }
      }
    } catch (e) {
      printLog('getRatingOptions error: $e');
    }
    if (result.isNotEmpty) {
      _ratingOptionsCache = result;
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> createReview(
      {String? productId, Map<String, dynamic>? data, String? token}) async {
    // Clean, spoof-proof route: POST /products/{sku}/reviews, resource "self"
    // (customer derived server-side from the token).
    final sku = productId;
    if (sku == null || sku.isEmpty) {
      throw Exception('Missing product SKU');
    }
    final star = ((data?['rating'] as num?)?.round() ?? 0).clamp(1, 5);
    final ratingOptions = await _getRatingOptions();
    final ratings = <Map<String, dynamic>>[];
    for (final o in ratingOptions) {
      final values = o['values'] as List<int>;
      // index star-1, guarding shorter lists.
      final valueId = values[(star - 1).clamp(0, values.length - 1)];
      ratings.add({'rating_id': o['rating_id'], 'value_id': valueId});
    }
    // The store requires every configured rating (Quality/Value/Price). If the
    // rating-option lookup came back empty — a transient failure, since it is
    // only cached once it succeeds — posting anyway gets rejected by Magento
    // with an opaque message, which is what made submitting look random
    // (86d3g53dk #10). Fail here instead, with something actionable.
    if (ratings.isEmpty) {
      throw Exception(
          'Could not load the rating options. Check your connection and try again.');
    }
    final text = '${data?['review'] ?? ''}'.trim();
    // Magento rejects a blank nickname; fall back to the email local part for
    // accounts whose profile carries no name.
    var nickname = '${data?['reviewer'] ?? ''}'.trim();
    if (nickname.isEmpty) {
      nickname = '${data?['reviewer_email'] ?? ''}'.split('@').first.trim();
    }
    // Photos ride along as an array of base64 strings; the backend saves them
    // and returns their URLs in the response (86d3g53dk #10). They sit inside
    // the `review` object with the other review fields.
    final images = data?['images'] is List
        ? (data!['images'] as List).whereType<String>().toList()
        : const <String>[];
    final body = {
      'review': {
        'nickname': nickname,
        // Magento requires a title; derive a short one from the body.
        'summary': text.length > 40 ? '${text.substring(0, 40)}…' : text,
        'text': text,
        'ratings': ratings,
        if (images.isNotEmpty) 'images': images,
      }
    };
    final res = await httpPost(
      // Post to the ACTIVE store view. buildUrl falls back to eg-en when no
      // locale is passed, so a review written on the Arabic view was stamped
      // with the English store_id — reviews still show on every store view, but
      // review_detail.store_id (and any "which view did this come from"
      // reporting) was wrong. The read/browse calls already pass the locale.
      MagentoHelper.buildUrl(domain,
          'products/${Uri.encodeComponent(sku)}/reviews',
          SettingsBox().languageCode)!,
      headers: {
        'Authorization': 'Bearer ${token ?? UserBox().userInfo?.cookie}',
        'content-type': 'application/json'
      },
      body: convert.jsonEncode(body),
    );
    final resBody = convert.jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return resBody is Map
          ? Map<String, dynamic>.from(resBody)
          : {'status': 'pending'};
    }
    throw Exception(
        (resBody is Map ? MagentoHelper.getErrorMessage(resBody) : null) ??
            'Failed to submit review');
  }

  @override
  Future<List<ProductVariation>> getProductVariations(Product product,
      {String? lang = 'en'}) async {
    final sku = product.sku ?? '';
    if (sku.isEmpty) return _fetchProductVariations(product, lang: lang);

    final inFlight = _variationsInFlight[sku];
    if (inFlight != null) {
      // A sibling widget (variant body / bottom bar) already started this fetch
      // on PDP open — reuse it instead of firing a second children +
      // per-variant-stock round-trip. Attributes are cached, so populating this
      // product's copy is cheap.
      final list = await inFlight;
      product.attributes = await getConfigurableproductsAttributes(sku);
      return list;
    }

    final future = _fetchProductVariations(product, lang: lang);
    _variationsInFlight[sku] = future;
    future.whenComplete(() => _variationsInFlight.remove(sku));
    return future;
  }

  Future<List<ProductVariation>> _fetchProductVariations(Product product,
      {String? lang = 'en'}) async {
    try {
      // Kick off the children list and the attribute set together — both only
      // need the SKU, so there's no reason to wait for one before the other.
      final childrenFuture = httpGet(
          MagentoHelper.buildUrl(
              domain, 'configurable-products/${product.sku}/children')!,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'content-type': 'application/json'
          });
      final attributesFuture =
          getConfigurableproductsAttributes(product.sku ?? "");
      final res = await childrenFuture;
      final attributes = await attributesFuture;
      product.attributes = attributes;

      /// The store's configurable attribute codes vary per attribute set
      /// (all_color, top_size, bottom_size...), so extract them from the
      /// options/list response instead of the hard-coded config list.
      final attributeCodes =
          attributes.map((a) => a.name).whereType<String>().toList();
      var list = <ProductVariation>[];
      if (res.statusCode == 200) {
        final children = (convert.jsonDecode(res.body) as List)
            .map((item) => ProductVariation.fromMagentoJson(item, product,
                attributeCodes: attributeCodes))
            .toList();

        // Fetch every child's stock status in PARALLEL. This used to be one
        // awaited call per child, so a configurable with N variants blocked on
        // N sequential round trips before the variations (and therefore the
        // selected variant + Add to Cart) were ready — until then the button
        // silently did nothing, so it read as "slow / had to click more than
        // once" (86d3ppam2 #2). One round trip's worth of latency now.
        final stocks =
            await Future.wait(children.map((c) => getStockStatus(c.sku)));

        for (var i = 0; i < children.length; i++) {
          final prod = children[i];
          final productStock = stocks[i];
          prod.inStock = productStock?.inStock;
          prod.stockQuantity = productStock?.stockQuantity;
          prod.configurable_product_options =
              product.configurable_product_options;
          prod.configurable_product_links =
              product.configurable_product_links;
          list.add(prod);
        }
      }

      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ShippingMethod>> getShippingMethods({CartModel? cartModel, String? token, String? checkoutId, Store? store, String? langCode}) async {
    try {
      printLog('[Magento] customer token ${isBlank(token) ? 'MISSING' : 'present'}');
      var address = cartModel!.address!;
      printLog(convert.jsonEncode(address.toMagentoJson()));
      var url = token != null
          ? MagentoHelper.buildUrl(
              domain, 'carts/mine/estimate-shipping-methods')!
          : MagentoHelper.buildUrl(
              domain, 'guest-carts/$guestQuoteId/estimate-shipping-methods')!;
      final res = await httpPost(url,
          body: convert.jsonEncode(address.toMagentoJson()),
          headers: token != null
              ? {
                  'Authorization': 'Bearer $token',
                  'content-type': 'application/json'
                }
              : {'content-type': 'application/json'});

      if (res.statusCode == 200) {
        var list = <ShippingMethod>[];
        for (var item in convert.jsonDecode(res.body)) {
          list.add(ShippingMethod.fromMagentoJson(item));
        }
        // if (list.isEmpty) {
        //   throw Exception(S.current.emptyShippingMsg);
        // }
        return list;
      } else {
        final body = convert.jsonDecode(res.body);
        throw Exception(body['message'] != null
            ? MagentoHelper.getErrorMessage(body)
            : S.current.canNotGetShipping);
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<List<PaymentMethod>> getPaymentMethods({CartModel? cartModel, ShippingMethod? shippingMethod, String? token, String? langCode}) async {
    try {
      var address = cartModel!.address;
      final params = {
        'addressInformation': {
          // Flag ONLY the shipping address for the address book. Magento saves
          // the quote's billing AND shipping addresses to the customer on order
          // placement, so posting the same address twice unflagged left two
          // identical entries after a new customer's first order (86d3tkj56 #1).
          'shipping_address':
              address?.toMagentoJson(saveInAddressBook: true)['address'],
          'billing_address': address?.toMagentoJson()['address'],
          'shipping_carrier_code': shippingMethod?.id,
          'shipping_method_code': shippingMethod?.methodId
        }
      };
      printLog(convert.jsonEncode(params));
      var url = token != null
          ? MagentoHelper.buildUrl(domain, 'carts/mine/shipping-information')!
          : MagentoHelper.buildUrl(
              domain, 'guest-carts/$guestQuoteId/shipping-information')!;
      printLog(url);
      printLog('[Magento] customer token ${isBlank(token) ? 'MISSING' : 'present'}');
      final res = await httpPost(url,
          body: convert.jsonEncode(params),
          headers: token != null
              ? {
                  'Authorization': 'Bearer $token',
                  'content-type': 'application/json'
                }
              : {'content-type': 'application/json'});

      final body = convert.jsonDecode(res.body);
      if (res.statusCode == 200) {
        var list = <PaymentMethod>[];
        for (var item in body['payment_methods']) {
          if (!item['code'].toString().contains('fake')) {
            list.add(PaymentMethod.fromMagentoJson(item));
          }
        }
        return list;
      } else if (body['message'] != null) {
        throw Exception(MagentoHelper.getErrorMessage(body));
      } else {
        throw Exception(S.current.canNotGetPayments);
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<PagingResponse<Order>> getMyOrders({User? user, dynamic cursor, String? cartId,}) async {
    try {
      //${cursor - 1}
      // Scope to the logged-in customer_id, exactly like the website's
      // "My Orders". Filtering by customer_email instead also matched GUEST
      // orders placed with the same email (customer_id null, is_guest 1) — which
      // the website never lists — so the app showed orders the site did not, and
      // an account whose only orders were guest checkouts saw a list where the
      // website showed none (86d3tkhgz #1). customer_id additionally drops any
      // same-email order that belongs to a different account.
      var endPoint = '?';
      endPoint +=
          'searchCriteria[filter_groups][0][filters][0][field]=customer_id&searchCriteria[filter_groups][0][filters][0][value]=${user!.id}&searchCriteria[filter_groups][0][filters][0][condition_type]=eq';
      endPoint += '&searchCriteria[currentPage]=${cursor}';
      endPoint += '&searchCriteria[sortOrders][1][field]=created_at';
      endPoint += '&searchCriteria[pageSize]=$apiPageSize';
      endPoint += '&dummy=${DateTime.now().millisecondsSinceEpoch}';

      printLog('[Magento] admin token ${isBlank(accessToken) ? 'MISSING' : 'present'}');
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'orders$endPoint')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      var list = <Order>[];
      if (response.statusCode == 200) {
        for (var item in convert.jsonDecode(response.body)['items']) {
          list.add(Order.fromJson(item));
        }
      }
      return PagingResponse(data: list);
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<Order> createOrder({CartModel? cartModel, UserModel? user, bool? paid, String? transactionId}) async {
    try {
      var isGuest = user!.user == null || user.user!.cookie == null;
      var url = !isGuest
          ? MagentoHelper.buildUrl(domain, 'carts/mine/payment-information')!
          : MagentoHelper.buildUrl(
              domain, 'guest-carts/$guestQuoteId/payment-information')!;
      var params = Order().toMagentoJson(cartModel!, null, paid);
      if (isGuest) {
        // Email is optional at checkout — effectiveEmail falls back to the
        // per-phone default when the shopper left the field empty.
        params['email'] = cartModel.address!.effectiveEmail;
        params['firstname'] = cartModel.address!.firstName;
        params['lastname'] = cartModel.address!.lastName;
      }
      if (transactionId != null && transactionId.isNotEmpty) {
        params['paymentMethod'] = {
          'method': params['paymentMethod']['method'],
          'additional_data': {'rzp_payment_id': transactionId}
        };
      }
     // params['order_currency_code'] = "SAR";
      if (cartModel.paymentMethod!.id?.contains('stripe') ?? false) {
        params['paymentMethod'] = {
          'method': params['paymentMethod']['method'],
          'additional_data': {
            'cc_stripejs_token': 'pm_card_visa'
          } // Use pm_card_threeDSecureRequired for 3DS authentication
        };
      }
      printLog(params);
      final res = await httpPost(url,
          body: convert.jsonEncode(params),
          headers: !isGuest
              ? {
                  'Authorization': 'Bearer ${user.user!.cookie!}',
                  'content-type': 'application/json'
                }
              : {'content-type': 'application/json'});

      final body = convert.jsonDecode(res.body);
      'res.body: ${body}'.log();
      'res.statusCode: ${res.statusCode}'.log();

      if (res.statusCode == 200) {
        // The quote is consumed by the order. Holding on to the id meant the
        // next guest checkout kept posting to guest-carts/<spent-id>/… until
        // something happened to mint a new quote, which surfaced as errors and
        // a checkout that never finished loading (86d3g53f8 #8).
        if (isGuest) {
          guestQuoteId = null;
        }

        var order = await getSingleOrder(user: user, entityId: body.toString());
      //  order.id = body.toString();
     //   order.number = body.toString();
     //   order.status = OrderStatus.pending;
        return order;
      } else {
        if (body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        } else {
          throw Exception(S.current.canNotCreateOrder);
        }
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<Order> getSingleOrder({required UserModel? user, required String entityId}) async {
    try {

      var url =  MagentoHelper.buildUrl(domain, 'orders/$entityId')!;
      printLog(url);
      printLog('[Magento] admin token ${isBlank(accessToken) ? 'MISSING' : 'present'}');
      final res = await httpGet(url,
          headers:  {
            'Authorization': 'Bearer ${accessToken}',
            'content-type': 'application/json'
          });

      final body = convert.jsonDecode(res.body);
      'res.body: ${body}'.log();
      'res.statusCode: ${res.statusCode}'.log();

      if (res.statusCode == 200) {
        var order = Order.fromJson(body);
        return order;
      } else {
        if (body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        } else {
          throw Exception(S.current.canNotCreateOrder);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future updateOrder(orderId, {status, required token}) async {
    try {
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mstore/me/orders/$orderId/cancel')!,
        body: convert.jsonEncode({}),
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json'
        },
      );
      final body = convert.jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        throw Exception(MagentoHelper.getErrorMessage(body));
      } else {
        return;
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<Order?> cancelOrder({Order? order, String? userCookie,}) async {
    await updateOrder(order!.id, status: 'cancelled', token: userCookie);
    order.status = OrderStatus.cancelled;
    return order;
  }

  @override
  Future<PagingResponse<Product>> searchProducts({name, categoryId, categoryName, tag, attribute, attributeId, page, lang, listingLocation, userId}) async {
    try {
      var endPoint = '?';
      if (name != null) {
        endPoint +=
            'searchCriteria[filter_groups][0][filters][0][field]=name&searchCriteria[filter_groups][0][filters][0][value]=%$name%&searchCriteria[filter_groups][0][filters][0][condition_type]=like';
      }
      if (page != null) {
        endPoint += '&searchCriteria[currentPage]=$page';
      }
      endPoint += '&searchCriteria[pageSize]=$apiPageSize';
      endPoint +=
          '&searchCriteria[filter_groups][1][filters][0][field]=visibility&searchCriteria[filter_groups][1][filters][0][value]=4';

      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'mstore/products$endPoint')!,
          headers: {'Authorization': 'Bearer $accessToken'});

      var list = <Product>[];
      if (response.statusCode == 200) {
        final body = convert.jsonDecode(response.body);
        if (!MagentoHelper.isEndLoadMore(body)) {
          // Resolve brand labels so search-result cards show the seller/brand
          // name (product.vendor), matching the grid path. Cached, so this is
          // a single cheap lookup per search. See ClickUp 86d3g53dk.
          final brandLabels = await getBrandLabels();
          for (var item in body['items']) {
            var product = parseProductFromJson(item, brandLabels: brandLabels);
            list.add(product);
          }
        }
      }
      return PagingResponse(data: list);
    } catch (err, trace) {
      //  log
      logTalker(
        classFileName: 'MagentoService',
        logType: TalkerType.info,
        message: 'MagentoService: trace:$trace, >>err:$err',
      );

      printError(err, trace);
      rethrow;
    }
  }

  @override
  Future<User> createUser({String? firstName, String? lastName, String? username, String? password, String? phoneNumber, bool isVendor = false,}) async {
    try {
      final payLoad = convert.jsonEncode({
        'customer': {
          'email': username,
          'firstname': firstName,
          'lastname': lastName,
          "custom_attributes":[
            {
              'attribute_code': "mobile",
              'value': phoneNumber,
            },
            {
              'attribute_code': "mobile_token",
              'value': "",
            }
          ]
        },
        'password': password
      });

      // Not logged: payLoad carries the new account's password in cleartext.
      'create user request built'.log();

      var response =
          await httpPost(MagentoHelper.buildUrl(domain, 'customers')!,
              body: payLoad,
              headers: {'content-type': 'application/json'});

      'create user response is ${response.body}'.log();
      'create user response StatusCode is ${response.statusCode}'.log();

      if (response.statusCode == 200) {
        return await login(username: username, password: password);
      } else {
        final body = convert.jsonDecode(response.body);
        throw Exception(body['message'] != null
            ? MagentoHelper.getErrorMessage(body)
            : 'Can not get token');
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<User> getUserInfo(cookie) async {
    try {
      var res = await httpGet(MagentoHelper.buildUrl(domain, 'customers/me')!,
          headers: {'Authorization': 'Bearer $cookie'});
      final body = convert.jsonDecode(res.body);
      if (body['message'] != null) {
        throw Exception(MagentoHelper.getErrorMessage(body));
      } else {
        User user = User.fromMagentoJson(body, cookie);
        saveDataToLocal(user);
        return user;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Reads `extension_attributes.is_subscribed` off the customer resource.
  /// Null means the store doesn't expose the attribute at all, which the
  /// newsletter screen shows as unavailable rather than silently as "off".
  @override
  Future<bool?> getNewsletterSubscription() async {
    final res = await httpGet(MagentoHelper.buildUrl(domain, 'customers/me')!,
        headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'});
    final body = convert.jsonDecode(res.body);
    if (body is Map && body['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(body));
    }
    final ext = body['extension_attributes'];
    if (ext is Map && ext.containsKey('is_subscribed')) {
      return ext['is_subscribed'] == true;
    }
    return null;
  }

  @override
  Future<bool?> setNewsletterSubscription(bool subscribe) async {
    // Read-modify-write: Magento rebuilds the customer row from the payload and
    // saves it wholesale, so a minimal {email, firstname, lastname} body would
    // clear default_billing / default_shipping and every custom_attribute.
    // Echo the whole record back with one flag flipped instead.
    //
    // But drop `addresses` before sending. CustomerRepository::save() gates the
    // entire address block on `getAddresses() !== null`: present means re-save
    // every address and delete any stored id missing from the payload, absent
    // means leave the book completely alone. Absent is what we want — flipping
    // a newsletter flag has no business rewriting the address book, and a
    // single address that no longer passes validation would otherwise fail the
    // whole request. (This is also why updateUserInfo's long-standing partial
    // PUTs — which fire on every launch via updateDeviceToken — don't wipe
    // anyone's addresses.)
    final res = await httpGet(MagentoHelper.buildUrl(domain, 'customers/me')!,
        headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'});
    final customer = convert.jsonDecode(res.body);
    if (customer is Map && customer['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(customer));
    }
    customer.remove('addresses');
    final ext = customer['extension_attributes'];
    if (ext is Map) {
      ext['is_subscribed'] = subscribe;
    } else {
      customer['extension_attributes'] = {'is_subscribed': subscribe};
    }

    final put = await httpPut(MagentoHelper.buildUrl(domain, 'customers/me')!,
        headers: {
          'Authorization': 'Bearer ${UserBox().userInfo?.cookie}',
          'content-type': 'application/json',
        },
        body: convert.jsonEncode({'customer': customer}));
    final body = convert.jsonDecode(put.body);
    if (body is Map && body['message'] != null) {
      throw Exception(MagentoHelper.getErrorMessage(body));
    }
    final savedExt = body['extension_attributes'];
    if (savedExt is Map && savedExt.containsKey('is_subscribed')) {
      return savedExt['is_subscribed'] == true;
    }
    return null;
  }

  @override
  Future<bool> saveUserInfo(Address? address,bool isDelete) async {
    try {

      var params = <String, dynamic>{};
      params['id'] = UserBox().userInfo?.id;
      params['email'] = UserBox().userInfo?.email;
      params['firstname'] = UserBox().userInfo?.firstName;
      params['lastname'] = UserBox().userInfo?.lastName;
      // This PUT replaces the customer's ENTIRE address book, so any field left
      // out of the payload is cleared server-side. default_billing /
      // default_shipping were never modelled, so every add, edit and delete
      // silently wiped the shopper's default address — and with it the
      // checkout pre-fill. Carry them across, matched by address id, from the
      // last server copy we hold.
      final priorAddresses = UserBox().userInfo?.addresses ?? const <Addresses>[];
      Addresses? priorFor(int? id) {
        if (id == null) return null;
        for (final a in priorAddresses) {
          if (a.id == id) return a;
        }
        return null;
      }

      List<Addresses> addressArr = [];
      UserBox().addresses?.forEach((element){
        Addresses addresses = Addresses();
        addresses.customerId = int.parse(UserBox().userInfo?.id ?? '0');
        if(element.id == address?.id){
          addresses.id = int.parse(element.id ?? '0');
          addresses.firstname = address?.firstName;
          addresses.lastname = address?.lastName;
          addresses.telephone =
              MagentoHelper.normalizePhoneForMagento(address?.phoneNumber);
          addresses.street = [];
          addresses.street?.add(address?.street ?? "");
          addresses.city = address?.city;
          addresses.postcode = address?.zipCode;
          addresses.region = Region();
          addresses.region?.region = address?.state;
          addresses.countryId = address?.countryId;
        }else{
          addresses.id = int.parse(element.id ?? '0');
          addresses.firstname = element.firstName;
          addresses.lastname = element.lastName;
          // Untouched addresses are re-sent verbatim by this PUT, so one of
          // them holding a `+20…` number failed the whole save — including
          // deletes. Normalise them too (86d3rrpqr).
          addresses.telephone =
              MagentoHelper.normalizePhoneForMagento(element.phoneNumber);
          addresses.street = [];
          addresses.street?.add(element.street ?? "");
          addresses.city = element.city;
          addresses.postcode = element.zipCode;
          addresses.region = Region();
          addresses.region?.region = element.state;
          addresses.countryId = element.countryId;
        }
        // Restore the default flags for whichever address this is — otherwise
        // re-sending the book clears them.
        final prior = priorFor(addresses.id);
        addresses.defaultBilling = prior?.defaultBilling ?? false;
        addresses.defaultShipping = prior?.defaultShipping ?? false;
        if(element.id == address?.id && isDelete) {

        }else{
          addressArr.add(addresses);
        }
      });
      if(address?.id == null || address?.id == 0){
        Addresses addresses = Addresses();
        addresses.customerId = int.parse(UserBox().userInfo?.id ?? '0');
        addresses.firstname = address?.firstName;
        addresses.lastname = address?.lastName;
        addresses.telephone =
            MagentoHelper.normalizePhoneForMagento(address?.phoneNumber);
        addresses.street = [];
        addresses.street?.add(address?.street ?? "");
        addresses.city = address?.city;
        addresses.postcode = address?.zipCode;
        addresses.region = Region();
        addresses.region?.region = address?.state;
        addresses.countryId = address?.countryId ?? address?.country;
        addressArr.add(addresses);
      }
      params['addresses'] = addressArr.toList();
      printLog(convert.jsonEncode({'customer': params}));
      var res = await httpPut(MagentoHelper.buildUrl(domain, 'customers/me')!,
          headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'
            ,'content-type': 'application/json'},
          body: convert.jsonEncode({'customer': params}));
      final body = convert.jsonDecode(res.body);
      printLog(body);
      if (body['message'] != null) {
        throw Exception(MagentoHelper.getErrorMessage(body));
      } else {
        User user = User.fromMagentoJson(body, UserBox().userInfo?.cookie);
        saveDataToLocal(user);
        return true;
      }
    } catch (e) {
      rethrow;
    }
  }

  void saveDataToLocal(User user) {
    var listAddress = <Address>[];
    if (user.addresses != null) {
      user.addresses?.forEach((element){
        Address address = Address();
        address.id = element.id.toString();
        address.firstName = element.firstname;
        address.lastName = element.lastname;
        address.email = user.email;
        address.phoneNumber = element.telephone;
        address.street = element.street?.first;
        address.city = element.city;
        address.zipCode = element.postcode;
        address.state = element.region?.region;
        address.country = element.countryId;
        address.countryId = element.countryId;
        listAddress.add(address);
      });
    }
    UserBox().addresses = listAddress;

    // Keep the stored user's raw address list in step too. The local Address
    // entity has no notion of default billing/shipping, so saveUserInfo reads
    // those flags from userInfo.addresses — refreshing them here means an
    // install that logged in before the flags existed self-heals on the next
    // user refresh, instead of waiting for a re-login. Only the address list is
    // replaced; every other stored field (cookie, isSocial, …) is preserved.
    final stored = UserBox().userInfo;
    if (stored != null && user.addresses != null) {
      stored.addresses = user.addresses;
      UserBox().userInfo = stored;
    }
  }

  @override
  Future<User> login({username, password}) async {
    try {
      var response = await httpPost(
          MagentoHelper.buildUrl(domain, 'integration/customer/token')!,
          body:
              convert.jsonEncode({'username': username, 'password': password}),
          headers: {'content-type': 'application/json'});

      'login response is ${response.body}'.log();
      'login response StatusCode is ${response.statusCode}'.log();

      if (response.statusCode == 200) {
        final token = convert.jsonDecode(response.body);
        var user = await getUserInfo(token);
        return user;
      } else {
        final body = convert.jsonDecode(response.body);
        throw Exception(body['message'] != null
            ? MagentoHelper.getErrorMessage(body)
            : 'Can not get token');
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<User> loginMobile({String? mobile}) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildWithoutRestUrl(domain, 'wapplogin/customer/login?mobile=$mobile')!,
          headers: {'content-type': 'application/json'});

      'login response is ${response.body}'.log();
      'login response StatusCode is ${response.statusCode}'.log();

      // The wapplogin endpoint returns an HTML error page (not JSON) on a
      // server error, and has been observed to 500 even when the customer DOES
      // exist (the "customer found" path crashes). So a failure here must never
      // be shown as "no account found": parse defensively and only report a
      // missing account when the endpoint actually says so.
      dynamic responseData;
      try {
        responseData = convert.jsonDecode(response.body);
      } catch (_) {
        responseData = null;
      }

      if (response.statusCode == 200 && responseData is Map) {
        final data = responseData['data'];
        final token = data is Map ? data['token'] : null;
        if (token != null && '$token'.trim().isNotEmpty) {
          return await getUserInfo(token);
        }
        // 200 without a token: the endpoint reports the lookup outcome in
        // data.customer[].message (e.g. "There is no customer registered with
        // this number.") — surface that real message when present.
        final customer = data is Map ? data['customer'] : null;
        final message = (customer is List &&
                customer.isNotEmpty &&
                customer.first is Map)
            ? customer.first['message']?.toString()
            : null;
        throw Exception((message != null && message.isNotEmpty)
            ? message
            : 'Can not get token');
      }

      // Non-200 (or an unparseable HTML error page) is a backend failure, not a
      // missing account — show a neutral message instead of "user not found".
      throw Exception(responseData is Map && responseData['message'] != null
          ? MagentoHelper.getErrorMessage(responseData)
          : 'Something went wrong. Please try again.');
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<String> forgotPasswordMobile({String? mobile}) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildWithoutRestUrl(domain, 'wapplogin/customer/forgotPassword?mobile=$mobile')!,
          headers: {'content-type': 'application/json'});

      'login response is ${response.body}'.log();
      'login response StatusCode is ${response.statusCode}'.log();

      if (response.statusCode == 200) {
        final responseData = convert.jsonDecode(response.body);
        final customer = responseData['data']['customer'][0];
        bool success = customer['success'] ?? false;
        String message = customer['message'] ?? "";
        if(success){
          String resetUrl = responseData['data']['customer'][0]['reset_url'];
          return resetUrl;
        }
        return message;
      } else {
        final body = convert.jsonDecode(response.body);
        throw Exception(body['message'] != null
            ? MagentoHelper.getErrorMessage(body)
            : 'Can not get token');
      }
    } catch (err) {
      rethrow;
    }
  }


  @override
  Future<Product?> getProduct(id, {lang}) async {
    var endPoint =
        '?searchCriteria[filterGroups][0][filters][0][field]=entity_id&searchCriteria[filterGroups][0][filters][0][condition_type]=eq';
    endPoint += '&searchCriteria[filterGroups][0][filters][0][value]=$id';
    // `mstore/products`, not plain `products`: this catalogue discounts through
    // catalog price rules, and only the mstore module applies them — the stock
    // endpoint returns the undiscounted `price` with no `minimal_price` at all,
    // so the product page showed the full price with no strikethrough and no
    // percent label while the grid (already on mstore) showed the cut price.
    // Verified on testing.locafy.market that mstore returns a strict superset
    // of the stock payload: same description, short_description, media gallery
    // and extension_attributes, plus minimal_price.
    var response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mstore/products$endPoint')!,
        headers: {'Authorization': 'Bearer $accessToken'});
    var products = convert.jsonDecode(response.body)['items'];
    if (products.isEmpty) return null;
    // Resolve the brand label so the product page shows the seller/brand name
    // (product.vendor). The single-product payload only carries the numeric
    // `brand` option id and no extension_attributes.seller_name, so without this
    // the detail page had no seller name — the grid path already does this via
    // getBrandLabels() (cached, so this is effectively free). See ClickUp 86d3g53dk.
    final brandLabels = await getBrandLabels();
    return parseProductFromJson(products[0], brandLabels: brandLabels);
  }

  @override
  Future<Product?> getProductBySku(String sku) async {
    if (sku.isEmpty) return null;
    // Same admin-token product search as getProduct, but keyed by sku (the
    // reviews feed carries only the sku, not the numeric entity_id).
    final endPoint =
        '?searchCriteria[filterGroups][0][filters][0][field]=sku'
        '&searchCriteria[filterGroups][0][filters][0][condition_type]=eq'
        '&searchCriteria[filterGroups][0][filters][0][value]='
        '${Uri.encodeQueryComponent(sku)}';
    // mstore, for the catalog-price-rule reason documented in getProduct above.
    final response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mstore/products$endPoint')!,
        headers: {'Authorization': 'Bearer $accessToken'});
    final products = convert.jsonDecode(response.body)['items'];
    if (products == null || products.isEmpty) return null;
    final brandLabels = await getBrandLabels();
    return parseProductFromJson(products[0], brandLabels: brandLabels);
  }

  Future<bool> deleteItemsInCart(List<Map> items, String? token) async {
    Uri? url;
    try {
      await Future.forEach(items, (Map item) async {
        url = MagentoHelper.buildUrl(
            domain, 'carts/mine/items/${item['item_id']}');
        printLog(url);
        await httpDelete(
            url!,
            headers: {'Authorization': 'Bearer $token'});
      });
      url = MagentoHelper.buildUrl(domain, 'carts/mine/coupons');
      await httpDelete(url!,
          headers: {'Authorization': 'Bearer $token'});
      return true;
    } catch (err) {
      printLog(url);
      return true;
     // rethrow;
    }
  }

  @override
  Future<bool> deleteItemInCart(String itemId) async {
    Uri? url;
    try {
        url = MagentoHelper.buildUrl(
            domain, 'carts/mine/items/$itemId');
        await httpDelete(
            url!,
            headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'});
      return true;
    } catch (err) {
      return true;
      // rethrow;
    }
  }

  Future<bool> addToCart(CartModel cartModel, String? token, quoteId,
      {guestCartId}) async {
    try {
      //add items to cart
      await Future.forEach(cartModel.productsInCart.keys, (dynamic key) async {
        var params = <String, dynamic>{};
        params['qty'] = cartModel.productsInCart[key];
        params['quote_id'] = quoteId;
        params['sku'] = cartModel.productSkuInCart[key];
       // params['order_currency_code'] = "SAR";

        // productSkuInCart holds the *parent* sku for a configurable (see
        // addProductToCart), so re-adding the line here has to carry the
        // selected super attributes too — exactly like _sendCartItemRequest
        // does on the original add. Without them Magento rejects the parent sku
        // with "You need to choose options for your item", and since this runs
        // as part of doCheckout (after the server lines have been deleted) the
        // checkout page never opened for any configurable (86d4266v6).
        final product = cartModel.item[key];
        final metaData = cartModel.productsMetaDataInCart[key];
        final options = metaData is Map && metaData.isNotEmpty ? metaData : null;
        final configurableOptions = product != null
            ? await _buildConfigurableItemOptions(product, options)
            : null;
        if (configurableOptions != null) {
          params['product_option'] = {
            'extension_attributes': {
              'configurable_item_options': configurableOptions,
            }
          };
        } else if (options != null) {
          // Numeric attribute ids could not be resolved — degrade to the child
          // sku, which Magento accepts on its own. A line rebuilt from the
          // server carries no ProductVariation, but getShoppingList keeps the
          // child sku it replaced with the parent's in `variantSku`.
          final childSku = cartModel.productVariationInCart[key]?.sku ??
              product?.variantSku;
          if (childSku != null && childSku.isNotEmpty) {
            params['sku'] = childSku;
          }
        }

        final res = await httpPost(
            guestCartId == null
                ? MagentoHelper.buildUrl(domain, 'carts/mine/items')!
                : MagentoHelper.buildUrl(domain, 'guest-carts/$quoteId/items')!,
            body: convert.jsonEncode({'cartItem': params}),
            headers: token != null
                ? {
                    'Authorization': 'Bearer $token',
                    'content-type': 'application/json'
                  }
                : {'content-type': 'application/json'});
        final body = convert.jsonDecode(res.body);
        if (body['messages'] != null &&
            body['messages']['error'] != null &&
            body['messages']['error'][0].length > 0) {
          throw MagentoHelper.getErrorMessage(body['messages']['error'][0])!;
        } else if (body['message'] != null) {
          throw MagentoHelper.getErrorMessage(body)!;
        } else {
          // These lines were just re-created, so the item ids the cart is
          // holding are stale — refresh them, otherwise the next qty update or
          // remove PUT/DELETEs a dead item_id.
          if (body is Map && body['item_id'] != null) {
            product?.itemID = body['item_id'].toString();
          }
          printLog(body);
          return;
        }
      });
      return true;
    } catch (err) {
      rethrow;
    }
  }

  Future<bool> addItemsToCart(CartModel cartModel, String? token) async {

    Uri? url = MagentoHelper.buildUrl(domain, 'carts/mine');
    try {
      if (token != null) {
        //get cart info
        var res = await httpPost(url!,
            headers: {'Authorization': 'Bearer $token'});
        final cartInfo = convert.jsonDecode(res.body);
        if (res.statusCode == 200) {
          if (cartInfo is int) {
           // await deleteItemsInCart([], token);
            // Await each delete BEFORE re-adding. `forEach` with an async
            // callback does not await, so addToCart used to run while the old
            // items were still on the server — Magento then sums the re-added
            // SKU's quantity and rejects it ("The requested qty is not
            // available"), so checkout failed on the first attempt and only
            // worked after a retry (once the stray deletes had finished). This
            // race is why opening checkout needed multiple tries.
            for (final element in cartModel.shoppingList) {
              await Services().api.deleteItemInCart(element.itemID ?? "");
            }
            return await addToCart(cartModel, token, cartInfo);
          }else if (cartInfo['items'] is List) {
            await deleteItemsInCart(List<Map>.from(cartInfo['items']), token);
          }
        } else if (res.statusCode == 401) {
          printLog(url);
          throw Exception('Token expired. Please logout then login again');
        } else {
          // This used to read `!= 404`, so that a 404 fell through to the quote
          // creation below. It never did — makeRequest throws on a 404 unless
          // the call site opts in — and the fall-through would have been a
          // no-op anyway: for `token != null` the block below re-issues this
          // exact POST. A 404 from carts/mine is Magento failing to find the
          // customer, which creating a cart cannot fix, so the useful outcome
          // is to surface the backend's message rather than retry.
          printLog(url);
          throw Exception(MagentoHelper.getErrorMessage(cartInfo));
        }
      }

      //create a quote
      url = token != null
          ? MagentoHelper.buildUrl(domain, 'carts/mine')!
          : MagentoHelper.buildUrl(domain, 'guest-carts')!;
      var res = await httpPost(url,
          headers: token != null ? {'Authorization': 'Bearer $token'} : {});
      if (res.statusCode == 200) {
        if (token != null) {
          final quoteId = convert.jsonDecode(res.body);
          return await addToCart(cartModel, token, quoteId);
        } else {
          String? quoteId = convert.jsonDecode(res.body);
          var response = await httpGet(
              MagentoHelper.buildUrl(domain, 'guest-carts/$quoteId')!);
          final cartInfo = convert.jsonDecode(response.body);
          if (response.statusCode == 200) {
            final cartId = cartInfo['id'];
            guestQuoteId = quoteId;
            return await addToCart(cartModel, token, quoteId,
                guestCartId: cartId);
          } else {
            throw Exception(MagentoHelper.getErrorMessage(cartInfo));
          }
        }
      } else {
        throw Exception(
            MagentoHelper.getErrorMessage(convert.jsonDecode(res.body)));
      }
    } catch (err) {
      rethrow;
    }
  }


  var quoteId;
  Future<String> createCart() async {

    Uri? url = MagentoHelper.buildUrl(domain, 'carts/mine');
    printLog(url);
    try {
      var res =  await httpPost(url!,
          headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}','content-type': 'application/json'},);
      final body = convert.jsonDecode(res.body);
      if (res.statusCode == 200) {
        quoteId = convert.jsonDecode(res.body);
        return "";
      }else if (res.statusCode == 401) {
        _onLogout();
        throw Exception('Token expired. Please logout then login again');
      } else {
        if (body['message'] != null) {
          return body['message'];
        }else {
          return 'Something went wrong.';
        }
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<String> addUpdateItemsToCart(
      Product product, String sku, int qty, bool isUpdate,
      {Map? options, String? fallbackSku}) async {
    if(!UserBox().isLoggedIn){
      return "";
    }
    try {
      var res = await _sendCartItemRequest(product, sku, qty, isUpdate,
          options: options, fallbackSku: fallbackSku);
      var body = convert.jsonDecode(res.body);
      var message = body is Map ? MagentoHelper.getErrorMessage(body) : null;

      if (res.statusCode == 401) {
        // Customer token expired — mirror createCart()'s behaviour instead of
        // surfacing the raw "consumer isn't authorized" text.
        _onLogout();
        return S.current.sessionExpired;
      }

      /// A missing/inactive customer quote 404s here in two shapes: a brand-new
      /// customer who has no quote yet — the first add returns "The current
      /// customer does not have an active cart" (86d3tn1v1) — or a quote that
      /// went missing right after placing an order — "No such entity with
      /// cartId ...". Both are recovered the same way: recreate the quote and
      /// retry once.
      /// Only a fresh add (POST) is safe to retry this way — retrying a PUT
      /// (which carries an *absolute* quantity) as a POST would add that total
      /// on top of any existing line. A PUT that 404s on a stale item_id is
      /// left to the next cart resync instead of being blindly re-added.
      ///
      /// Reaching this at all needs `allowNotFound: true` on the request (see
      /// _sendCartItemRequest); without it makeRequest throws on the 404 and
      /// this whole branch is dead code.
      ///
      /// The match is on the substituted message: Magento sends
      /// `{"message":"No such entity with %fieldName = %fieldValue",
      /// "parameters":{"fieldName":"cartId",...}}` and getErrorMessage fills the
      /// named placeholders in. Matching prose is tolerable only because these
      /// cart URLs carry no locale, so buildUrl pins them to the eg-en store
      /// view — and the string is in fact untranslated on both store views
      /// today (checked against testing.locafy.market). Passing a locale to a
      /// cart call would put that assumption at risk.
      if (res.statusCode == 404) {
        final noCart = message?.toLowerCase() ?? '';
        if ((noCart.contains('no such entity') ||
                noCart.contains('active cart')) &&
            !isUpdate) {
          try {
            final created = await createCart();
            if (created.isNotEmpty) {
              return created;
            }
            res = await _sendCartItemRequest(product, sku, qty, false,
                options: options, fallbackSku: fallbackSku);
            body = convert.jsonDecode(res.body);
            message = body is Map ? MagentoHelper.getErrorMessage(body) : null;
          } catch (_) {
            return S.current.sessionExpired;
          }
        }
      }

      if (res.statusCode == 200) {
        if (!isUpdate && body is Map) {
          product.itemID = body['item_id'].toString();
        }
        return "";
      }
      if (message != null &&
          message.toLowerCase().contains('requested qty is not available')) {
        return S.current.requestedQtyNotAvailable;
      }
      return message ?? 'Something went wrong.';
    } catch (err) {
      rethrow;
    }
  }

  /// Resolves the selected super attributes into the shape Magento expects on
  /// a configurable cart line:
  /// `[{option_id: <numeric attribute_id>, option_value: <option value id>}]`.
  ///
  /// [options] is keyed by attribute *code* (that is what the variant picker
  /// produces), but the REST payload wants the numeric attribute id. The id is
  /// only exposed on `extension_attributes.configurable_product_options`, whose
  /// entries carry no attribute code — so each entry is matched by the option
  /// value it owns (`values[].value_index`, globally unique in Magento), and
  /// falls back to matching its `label` against the parent's attributes.
  ///
  /// Returns null when nothing could be resolved, so the caller degrades to the
  /// plain sku payload instead of failing the add.
  /// attribute code -> numeric attribute_id, for codes that had to be looked up
  /// against products/attributes/{code}. Stable per store, so cache for the
  /// session.
  final Map<String, String?> _attributeIdCache = {};

  Future<List<Map<String, dynamic>>?> _buildConfigurableItemOptions(
      Product product, Map? options) async {
    if (options == null || options.isEmpty) return null;

    final groups = product.configurable_product_options;
    // attribute code -> label, used for the fallback match below.
    final labelByCode = <String, String>{};
    for (final a in product.attributes ?? const <ProductAttribute>[]) {
      if (a.name != null && a.label != null) {
        labelByCode[a.name!.toLowerCase()] = a.label!.toLowerCase();
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in options.entries) {
      final code = entry.key;
      final value = entry.value;
      if (code == null || value == null) continue;
      final valueId = '$value';
      String? attributeId;

      if (groups is List) {
        for (final group in groups) {
          if (group is! Map) continue;
          final values = group['values'];
          if (values is List &&
              values.any((v) => v is Map && '${v['value_index']}' == valueId)) {
            attributeId = group['attribute_id']?.toString();
            break;
          }
          final label = group['label']?.toString().toLowerCase();
          if (label != null && label == labelByCode['$code'.toLowerCase()]) {
            attributeId = group['attribute_id']?.toString();
          }
        }
      }

      // A product opened from search/the cart often carries no
      // configurable_product_options (getProductDetail only fills `attributes`),
      // so resolve the id from the attribute itself rather than silently
      // degrading to the child-sku payload.
      if (attributeId == null || attributeId.isEmpty) {
        final key = '$code';
        if (!_attributeIdCache.containsKey(key)) {
          try {
            final attr = await getProductAttributes(key);
            _attributeIdCache[key] =
                (attr.id != null && attr.id != 'null') ? attr.id : null;
          } catch (_) {
            _attributeIdCache[key] = null;
          }
        }
        attributeId = _attributeIdCache[key];
      }

      if (attributeId != null && attributeId.isNotEmpty) {
        result.add({'option_id': attributeId, 'option_value': valueId});
      }
    }
    return result.isEmpty ? null : result;
  }

  Future<dynamic> _sendCartItemRequest(
      Product product, String sku, int qty, bool isUpdate,
      {Map? options, String? fallbackSku}) async {
    final params = <String, dynamic>{};
    params['qty'] = qty;
    if (isUpdate) {
      params['item_id'] = product.itemID;
    }
    params['quote_id'] = quoteId;
    // Without this a configurable is stored as a plain simple-product line, so
    // the website and the other app show no selected variant and the line
    // cannot be traced back to its parent (86d3g2npa #7/#9).
    final configurableOptions =
        await _buildConfigurableItemOptions(product, options);
    if (configurableOptions != null) {
      params['sku'] = sku;
      params['product_option'] = {
        'extension_attributes': {
          'configurable_item_options': configurableOptions,
        }
      };
    } else {
      // Could not resolve the numeric attribute ids — the parent sku alone
      // would be rejected ("You need to choose options for your item"), so
      // degrade to the child sku, which is the behaviour before this change.
      params['sku'] = (options != null && options.isNotEmpty)
          ? (fallbackSku?.isNotEmpty ?? false ? fallbackSku! : sku)
          : sku;
    }
    final url = isUpdate
        ? MagentoHelper.buildUrl(domain, 'carts/mine/items/${product.itemID}')!
        : MagentoHelper.buildUrl(domain, 'carts/mine/items')!;
    final headers = {
      'Authorization': 'Bearer ${UserBox().userInfo?.cookie}',
      'content-type': 'application/json'
    };
    // allowNotFound: addUpdateItemsToCart branches on statusCode before reading
    // the body, and needs to see the 404 to recover from an expired quote.
    // Without it the throw in makeRequest skips that recovery entirely.
    return isUpdate
        ? httpPut(url,
            headers: headers,
            body: convert.jsonEncode({'cartItem': params}),
            allowNotFound: true)
        : httpPost(url,
            headers: headers,
            body: convert.jsonEncode({'cartItem': params}),
            allowNotFound: true);
  }




  Future<double> applyCoupon(String? token, String? coupon) async {
    try {
      var url = token != null
          ? MagentoHelper.buildUrl(domain, 'carts/mine/coupons/$coupon')!
          : MagentoHelper.buildUrl(
              domain, 'guest-carts/$guestQuoteId/coupons/$coupon')!;
      var res = await httpPut(url,
          headers: token != null ? {'Authorization': 'Bearer $token'} : {});
      var body = convert.jsonDecode(res.body);
      if (res.statusCode == 200) {
        var totalUrl = token != null
            ? MagentoHelper.buildUrl(domain, 'carts/mine/totals')!
            : MagentoHelper.buildUrl(
                domain, 'guest-carts/$guestQuoteId/totals')!;
        var res = await httpGet(totalUrl,
            headers: token != null ? {'Authorization': 'Bearer $token'} : {});
        body = convert.jsonDecode(res.body);
        if (body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        } else {
          var discount = double.parse("${body['discount_amount']}");
          return discount < 0 ? discount * (-1) : discount;
        }
      } else {
        throw Exception(MagentoHelper.getErrorMessage(body));
      }
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<Coupons> getCoupons({int page = 1, String search = ''}) async {
    try {
      return Coupons.getListCoupons([]);
    } catch (e) {
      rethrow;
    }
  }


  @override
  Future<Map<String, dynamic>> updateUserInfo(Map<String, dynamic> json, String? token) async {
    try {
      if (isNotBlank(json['user_email'])) {
        var response = await httpPost(
          MagentoHelper.buildUrl(domain, 'mstore/customers/me/changeEmail')!,
          body: convert.jsonEncode({
            'new_email': json['user_email'],
            'current_password': json['current_pass']
          }),
          headers: {
            'Authorization': 'Bearer ${token!}',
            'content-type': 'application/json'
          },
        );
        final body = convert.jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        }
      }else if (isNotBlank(json['user_pass'])) {
        var response = await httpPost(
          MagentoHelper.buildUrl(domain, 'mstore/customers/me/changePassword')!,
          body: convert.jsonEncode({
            'new_password': json['user_pass'],
            'confirm_password': json['user_pass'],
            'current_password': json['current_pass']
          }),
          headers: {
            'Authorization': 'Bearer ${token!}',
            'content-type': 'application/json'
          },
        );

        printLog(convert.jsonEncode({
          'new_password': json['user_pass'],
          'confirm_password': json['user_pass'],
          'current_password': json['current_pass']
        }));
        final body = convert.jsonDecode(response.body);
        if (isNotBlank(json['phoneNumber'])){
          final payLoad = convert.jsonEncode({
            'customer': {
              'email': UserBox().userInfo?.email,
              'firstname': UserBox().userInfo?.firstName,
              'lastname': UserBox().userInfo?.lastName,
              "custom_attributes":[
                {
                  'attribute_code': "mobile",
                  'value': json['phoneNumber'],
                }
              ]
            }
          });
          var res = await httpPut(MagentoHelper.buildUrl(domain, 'customers/me')!,
              headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'
                ,'content-type': 'application/json'},
              body: payLoad);
          final phoneBody = convert.jsonDecode(res.body);
          printLog(phoneBody);
          // Same as the standalone phone branch: don't swallow a rejected
          // mobile write when the phone is changed together with the password
          // (86d3tkj7z #1, #2).
          if (phoneBody is Map && phoneBody['message'] != null) {
            throw Exception(MagentoHelper.getErrorMessage(phoneBody));
          }
        }
        if (body is Map && body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        }
      }else if (isNotBlank(json['deviceToken'])) {
        final payLoad = convert.jsonEncode({
          'customer': {
            'email': UserBox().userInfo?.email,
            'firstname': UserBox().userInfo?.firstName,
            'lastname': UserBox().userInfo?.lastName,
            "custom_attributes":[
              {
                'attribute_code': "mobile_token",
                'value': json['deviceToken'],
              }
            ]
          }
        });
        var res = await httpPut(MagentoHelper.buildUrl(domain, 'customers/me')!,
            headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'
              ,'content-type': 'application/json'},
            body: payLoad);
        final body = convert.jsonDecode(res.body);
        printLog(body);
        if (body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        } else {
          User user = User.fromMagentoJson(body, UserBox().userInfo?.cookie);
          return user.toJson();
        }
      }else if (isNotBlank(json['phoneNumber'])){
        final payLoad = convert.jsonEncode({
          'customer': {
            'email': UserBox().userInfo?.email,
            'firstname': UserBox().userInfo?.firstName,
            'lastname': UserBox().userInfo?.lastName,
            "custom_attributes":[
              {
                'attribute_code': "mobile",
                'value': json['phoneNumber'],
              }
            ]
          }
        });
        var res = await httpPut(MagentoHelper.buildUrl(domain, 'customers/me')!,
            headers: {'Authorization': 'Bearer ${UserBox().userInfo?.cookie}'
              ,'content-type': 'application/json'},
            body: payLoad);
        final body = convert.jsonDecode(res.body);
        printLog(body);
        // A phone update Magento rejects (most often a `mobile` that already
        // belongs to another account) used to be swallowed here: the method
        // returned success, the screen kept the new number locally, and it
        // reverted on the next customers/me refresh with no message shown
        // (86d3tkj7z #1, #2). Surface it so the screen's onError fires.
        if (body is Map && body['message'] != null) {
          throw Exception(MagentoHelper.getErrorMessage(body));
        }
      }
      return json;
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future getCountries() async {
    var response =
        await httpGet(MagentoHelper.buildUrl(domain, 'directory/countries')!);
    final body = convert.jsonDecode(response.body);
    return body;
  }

  final Map<String, String> _localizedCountryNames = {};
  String? _localizedCountryLang;

  @override
  Future<String?> getLocalizedCountryName(String code) async {
    if (code.isEmpty) return null;
    final lang = (SettingsBox().languageCode ?? 'en').toLowerCase();
    if (_localizedCountryLang != lang) {
      _localizedCountryNames.clear();
      _localizedCountryLang = lang;
    }
    if (_localizedCountryNames.containsKey(code)) {
      return _localizedCountryNames[code];
    }
    try {
      // directory/countries is public (getCountries above sends no token).
      // Fetch over the app language so full_name_locale comes back localized
      // (EG -> مصر / Egypt): the address book showed the country in English
      // even in the Arabic view (86d3tkj56 #3).
      final storePath = lang == 'ar' ? 'eg-ar' : 'eg-en';
      final res = await httpGet(
          '$domain/$storePath/rest/V1/directory/countries/$code'.toUri()!);
      final body = convert.jsonDecode(res.body);
      if (res.statusCode == 200 &&
          body is Map &&
          body['full_name_locale'] is String) {
        final name = (body['full_name_locale'] as String).trim();
        if (name.isNotEmpty) {
          _localizedCountryNames[code] = name;
          return name;
        }
      }
    } catch (e) {
      printLog('getLocalizedCountryName error: $e');
    }
    return null;
  }

  @override
  Future getCitiesByStateId(countryId, stateId) async {
    try {
      // Support get city list when user has extension installed https://codecanyon.net/item/magento-city-and-region-manager/17911995
      final response = await httpGet(
          '$domain/city/index/cities/?state=$stateId&country_id=$countryId'
              .toUri()!);
      var body = convert.jsonDecode(response.body);
      return body['cities'];
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future getCitiesByCountryId(countryId) async {
    try {
      // Support get city list when user has extension installed https://codecanyon.net/item/magento-city-and-region-manager/17911995

     printLog(MagentoHelper.buildUrl(domain, 'city?country=$countryId')!);
      final response = await httpGet(
          MagentoHelper.buildUrl(domain, 'city?country=$countryId')!);
      var body = convert.jsonDecode(response.body);
      return body[0]['message'];
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future getZonesByCityId(cityId) async {
    try {
      // Support get city list when user has extension installed https://codecanyon.net/item/magento-city-and-region-manager/17911995
      printLog(MagentoHelper.buildUrl(domain, 'zone?city=$cityId')!);
      final response = await httpGet(
          MagentoHelper.buildUrl(domain, 'zone?city=$cityId')!);
      var body = convert.jsonDecode(response.body);
      return body[0]['message'];
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future getZipCodeByAddress(countryId, stateId, city) async {
    try {
      // Support get zipCode when user has extension installed https://codecanyon.net/item/magento-city-and-region-manager/17911995
      final response = await httpGet(
          '$domain/city/index/zips/?city=$city&state=$stateId&country_id=$countryId'
              .toUri()!);
      var body = convert.jsonDecode(response.body);
      return body.first;
    } catch (err) {
      return '';
    }
  }

  Future<bool?> resetPassword(String email) async {
    try {
      var response = await httpPut(
        MagentoHelper.buildUrl(domain, 'customers/password')!,
        body: convert.jsonEncode({'email': email, 'template': 'email_reset'}),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'content-type': 'application/json'
        },
      );

      return convert.jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String?> createPaymentIntentStripe(
      {required String totalPrice,
      String? currencyCode,
      String? emailAddress,
      String? name,
      required String paymentMethodId}) async {
    try {
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mstore/stripe/payment-intent')!,
        body: convert.jsonEncode({
          'payment_method_id': paymentMethodId,
          'email': emailAddress,
          'amount': totalPrice,
          'currencyCode': currencyCode,
          'captureMethod': (kStripeConfig['enableManualCapture'] ?? false)
              ? 'manual'
              : 'automatic'
        }),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'content-type': 'application/json'
        },
      );

      var body = convert.jsonDecode(response.body);
      body = body is List && body.isNotEmpty ? body[0] : body;
      if (body['client_secret'] != null) {
        return body['client_secret'];
      } else if (body['message'] != null) {
        throw Exception(body['message']);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getTaxes(CartModel cartModel) async {
    try {
      var response = await httpGet(
        MagentoHelper.buildUrl(domain, 'taxRates/search?searchCriteria')!,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'content-type': 'application/json'
        },
      );

      var body = convert.jsonDecode(response.body);
      if (body is Map && body['items'] != null && body['items'] is List) {
        var taxes = <Tax>[];
        final address = cartModel.address?.toMagentoJson()['address'];
        body['items'].forEach((item) {
          if ((item['tax_country_id'] == '*' ||
                  item['tax_country_id'] == address['country_id']) &&
              (item['tax_region_id'] == 0 ||
                  item['tax_region_id'] == address['region_id']) &&
              (item['tax_postcode'] == '*' ||
                  item['tax_postcode'] == address['postcode'])) {
            taxes.add(Tax.fromMagentoJson(item, cartModel.getSubTotal() ?? 0));
          }
        });
        taxes = taxes.where((e) => e.amount != null && e.amount! > 0).toList();
        return {
          'items': taxes,
          'total': '${taxes.isNotEmpty ? taxes[0].amount : 0}'
        };
      } else if (body['message'] != null) {
        throw Exception(body['message']);
      }
      return null;
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<List<BannerImagesModel>?> getBannerImages() {
    final cached = _bannersCache;
    final at = _bannersCachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _bannersTtl) {
      return Future.value(cached);
    }
    // Reuse an in-flight request so ~7 simultaneous section mounts share one
    // network round-trip instead of firing seven identical ones.
    return _bannersInFlight ??= _fetchBannerImages().then((result) {
      _bannersInFlight = null;
      if (result != null) {
        _bannersCache = result;
        _bannersCachedAt = DateTime.now();
      }
      return result;
    });
  }

  Future<List<BannerImagesModel>?> _fetchBannerImages() async {
    "getBannerImages: ${MagentoHelper.buildUrl(domain, 'mobile/home/config')}"
        .log();
    printLog(
        '[Magento] admin token ${isBlank(accessToken) ? 'MISSING' : 'present'}');
    try {
      var response = await httpGet(
        MagentoHelper.buildUrl(domain, 'mobile/home/config')!,
        // Use the field, not another copy of the literal — an inline copy
        // means rotating env.dart would silently miss this call.
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final body = convert.jsonDecode(response.body);

      "💫💫💫💫BannersResponse: $body".log();
      final bannersList = <BannerImagesModel>[];
      (body as List).first.forEach((key, value) {
        bannersList.add(BannerImagesModel.fromJson(value));
      });
      return bannersList;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Product>?>? getWishList() async {
    try {
      printLog(MagentoHelper.buildUrl(domain, 'mobiconnect/wishlist/getwishlist')!);
      printLog('[Magento] admin token ${isBlank(accessToken) ? 'MISSING' : 'present'}');
      printLog('customer_id ${UserBox().userInfo?.id}');
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mobiconnect/wishlist/getwishlist')!,
        headers: {
          'Authorization': 'Bearer ${accessToken}',
          'content-type': 'application/json'
        },
        body: convert.jsonEncode({
          "parameters": {
            "customer_id":UserBox().userInfo?.id,
          }
        })
      );

      final body = convert.jsonDecode(response.body);
      var list = <Product>[];

      if (response.statusCode == 200) {
        createCart();
        if (body.isNotEmpty) {
          var firstElement = body.first;
          if (firstElement.containsKey("data")){
            var data = firstElement["data"];
            if (data is Map && data.containsKey("products")) {
              var products = data["products"];
              list = (products as List).map((i) => Product.fromWislitJson(i,domain)).toList();
            }
          }
        }
      }else if (response.statusCode == 401) {
        // This endpoint authenticates with the *integration* token, not the
        // customer's — a 401 here means the backend integration is missing the
        // MageNative (`magenative_oauth`) resource, which says nothing about
        // the customer's session. Logging the customer out on it signed people
        // straight back out of a successful login, because the login screen
        // refreshes the wishlist as soon as login succeeds.
        throw Exception(S.current.somethingWrong);
      }else{
        if (body['message'] != null) {
          throw Exception(body['message']);
        }else {
          throw Exception('Something went wrong.');
        }
      }
      return list;
    } catch (e) {

      return null;
    }
  }

  //calling for cart list
  @override
  Future<List<Product>?>? getShoppingList(CartModel model,
      {bool replace = false}) async {
    printLog('[Magento] customer token ${isBlank(UserBox().userInfo?.cookie) ? 'MISSING' : 'present'}');
    try {
      var response = await httpGet(
        MagentoHelper.buildUrl(domain, 'carts/mine/items')!,
        headers: {
          'Authorization': 'Bearer ${UserBox().userInfo?.cookie}',
          'content-type': 'application/json'
        },
      );

      final body = convert.jsonDecode(response.body);
      var list = <Product>[];
      if (response.statusCode == 200) {
        list = (body as List).map((i) => Product.fromShopJson(i,domain)).toList();
        // When refreshing an existing cart (replace), reset the in-memory
        // product lines to the server's current state first so quantities are
        // not duplicated and items removed on another platform disappear.
        // Coupon / shipping / payment / notes are preserved. Done only after
        // the fetch succeeds so a network error never blanks a cart that still
        // exists on the server. Default (login path) keeps the original merge
        // behaviour untouched.
        // Preserve the variant context across the refresh. The server cart line
        // carries only option IDs and Product.fromShopJson leaves `attributes`
        // empty, so a plain rebuild drops the selected variant and the cart row
        // stops showing it after the cart is reopened/updated (86d3tntae).
        // Snapshot what this device already knows — keyed by the cart key,
        // which is the child SKU on both the local and the rebuilt path — and
        // re-attach it below for lines that are still in the cart.
        // Resolve each configurable line's selected super attributes against
        // the parent's attributes *before* adding it, so the cart key matches
        // the one a local add produces and the "Size: 12 Years" label renders
        // even for a cart filled on the website or the other app (86d3g2npa #9).
        final resolvedOptions = <Product, Map<String, String>>{};
        for (final product in list) {
          final raw = product.configurableItemOptions;
          if (raw == null || raw.isEmpty || (product.sku?.isEmpty ?? true)) {
            continue;
          }
          try {
            final attributes = <ProductAttribute>[];
            final selections = <String, String>{};
            for (final entry in raw) {
              final valueId = entry['option_value']?.toString();
              final attributeId = entry['option_id']?.toString();
              if (valueId == null || attributeId == null) continue;
              final attr = await getAttributeByIdOrCode(attributeId);
              if (attr?.name == null) continue;
              attributes.add(attr!);
              selections[attr.name!] = valueId;
            }
            if (selections.isNotEmpty) {
              // The rebuilt product has no attributes of its own; attach the
              // ones the row needs to turn option ids into labels.
              product.attributes = attributes;
              resolvedOptions[product] = selections;
              // Swap the child sku Magento reports for the parent's, so the row
              // opens the configurable (with its variant picker) and keys the
              // same way a locally added line does.
              // product.id is the line's extension_attributes.entity_id, which
              // for a configurable line is the *parent's* id (86d3g2npa #7).
              final parentSku = await getConfigurableParentSku(
                  product.sku!, product.name,
                  parentEntityId: product.id);
              if (parentSku != null && parentSku.isNotEmpty) {
                // Keep the child sku: it is the one that actually carries stock.
                product.variantSku = product.sku;
                product.sku = parentSku;
              }
            }
          } catch (_) {
            // A failed attribute lookup just means no variant label for this
            // line; never let it blank the whole cart.
          }
        }
        // Everything above is resolved BEFORE the cart is cleared: the
        // lookups are network calls, and clearing first left the cart empty
        // for the whole round trip — a pull-to-refresh visibly emptied the
        // cart, and any throw in that window left it empty for good.
        var savedVariations = <String, dynamic>{};
        var savedOptions = <String, dynamic>{};
        var savedItems = <String, dynamic>{};
        if (replace) {
          savedVariations = Map<String, dynamic>.from(model.productVariationInCart);
          savedOptions = Map<String, dynamic>.from(model.productsMetaDataInCart);
          savedItems = Map<String, dynamic>.from(model.item);
          model.productsInCart.clear();
          model.item.clear();
          model.productVariationInCart.clear();
          model.productsMetaDataInCart.clear();
        }
        model.shoppingList = list;
        list.forEach((product){
          model.addProductToCart(
              product: product,
              quantity: product.shopQuantity,
              options: resolvedOptions[product],
              isFromApi: true);
        });
        if (replace) {
          for (final key in model.productsInCart.keys) {
            final variation = savedVariations[key];
            if (variation is ProductVariation) {
              model.productVariationInCart[key] = variation;
            }
            final options = savedOptions[key];
            if (options != null) {
              model.productsMetaDataInCart[key] = options;
            }
            // The rebuilt product ships no attributes; carry over the ones the
            // locally added product had, since the variant label is resolved
            // from them (option value id -> label).
            final saved = savedItems[key];
            final rebuilt = model.item[key];
            if (saved is Product &&
                rebuilt != null &&
                (saved.attributes?.isNotEmpty ?? false) &&
                (rebuilt.attributes?.isEmpty ?? true)) {
              rebuilt.attributes = saved.attributes;
            }
          }
        }
      }else if (response.statusCode == 401) {
        _onLogout();
        throw Exception('Token expired. Please logout then login again');
      }else{
        if (body['message'] != null) {
          throw Exception(body['message']);
        }else {
          throw Exception('Something went wrong.');
        }
      }
      return list;
    } catch (e) {

      return null;
    }
  }

  @override
  Future<String?>? addProductToWishList(Product product) async {
    try {
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mobiconnect/wishlist/add')!,
        headers: {
          'Authorization': 'Bearer ${accessToken}',
          'content-type': 'application/json'
        },
        body: convert.jsonEncode({
          "parameters": {
            "customer_id":UserBox().userInfo?.id,
            "prodID": product.id
          }
        }),
      );

      final body = convert.jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (body.isNotEmpty && body[0].containsKey('wishlist-item-id')) {
          product.itemID = body[0]['wishlist-item-id'];
        }
        return "";
      }else if (response.statusCode == 401) {
        // Integration-token 401 — not the customer's session. See getWishList.
        return S.current.somethingWrong;
      }else{
        if (body['message'] != null) {
          return body['message'];
        }else {
          return 'Something went wrong.';
        }
      }
    } catch (e) {
      //rethrow;

      return null;
    }
  }

  @override
  Future<String?>? removeProductToWishList(String productId) async {
    try {
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mobiconnect/wishlist/remove')!,
        headers: {
          'Authorization': 'Bearer ${accessToken}',
          'content-type': 'application/json'
        },
        body: convert.jsonEncode({
          "parameters": {
            "customer_id":UserBox().userInfo?.id,
            "itemId": productId
          }
        })
      );

      final body = convert.jsonDecode(response.body);
      if (response.statusCode == 200) {
         return "";
      }else if (response.statusCode == 401) {
        // Integration-token 401 — not the customer's session. See getWishList.
        return S.current.somethingWrong;
      }else{
        if (body['message'] != null) {
          return body['message'];
        }else {
          return 'Something went wrong.';
        }
      }
    } catch (e) {
      //rethrow;
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> mobileSendOtp(String number,String otpText) async {
    Map<String, dynamic> parameters = {
      "type": "text",
      "text": otpText,
    };

    Map<String, dynamic> bodyComponents = {
      "type": "body",
      "parameters": [parameters],
    };

    Map<String, dynamic> buttonComponents = {
      "type": "button",
      "sub_type": "url",
      "index": "0",
      "parameters": [parameters],
    };

    Map<String, dynamic> language = {
      "policy": "deterministic",
      "code": "ar",
    };

    Map<String, dynamic> template = {
      "language": language,
      "name": "otp_new",
      "components": [bodyComponents, buttonComponents],
    };

    Map<String, dynamic> mainBody = {
      "messaging_product": "whatsapp",
      "recipient_type": "individual",
      "to": number,
      "type": "template",
      "template": template,
    };
    try {
      var response = await httpPost("https://graph.facebook.com/v20.0/122095038332010689/messages".toUri()!,
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer EAAXa7lItDpYBO84bpz10qjSzZAKcXe6YnUNgWEMsCarHKEUUOc7wFk3e4opjOESdKT1xGwguyV8yeuJu3jjfh3SvUeVOryl6jR4EZBRZAl4SUfwbgS2aGCipWTusU9tEyZBpPgjncTojB7dn6aocFw1wtQ0dnRIyLoPcdhSZAzc3ycQCVZA3L6ZBU5Blp7n2HX8LQVlTwg3fA3Ingb4'
        },
        body: convert.jsonEncode(mainBody)
      );
      final body = convert.jsonDecode(response.body);
      printLog(body);
      return body;
    } catch (e) {
      return null;
    }
  }

  /// Pre-check for "one phone ↔ one account": returns true when [phone] is
  /// already registered. Backed by the MagentoEgypt_CustomerPhoneUnique
  /// module's anonymous endpoint (POST /rest/V1/mstore/phone/is-registered,
  /// body {"phone": "..."} -> bare boolean at HTTP 200).
  @override
  Future<bool> isPhoneRegistered(String phone) async {
    try {
      var response = await httpPost(
        MagentoHelper.buildUrl(domain, 'mstore/phone/is-registered')!,
        body: convert.jsonEncode({'phone': phone}),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'content-type': 'application/json'
        },
      );
      return convert.jsonDecode(response.body) == true;
    } catch (e) {
      // Fail open: never block registration on a pre-check error — the
      // backend uniqueness rule is the authoritative guard.
      return false;
    }
  }

  void _onLogout() {
    if(UserBox().isLoggedIn) {
      eventBus.fire(const EventExpiredCookie());
    }
  }

}

/// The category behind a storefront URL, as resolved by
/// [MagentoService.resolveCategoryUrls].
class CategoryUrlTarget {
  final String id;
  final String? name;

  const CategoryUrlTarget({required this.id, this.name});
}
//We'll email you a link to reset your password.
//https://stg.locafy.market/eg-en/rest/V1/mstore/brands
//https://stg.locafy.market/eg-en/rest/V1/products?searchCriteria[filterGroups][0][filters][0][field]=entity_id&searchCriteria[filterGroups][0][filters][0][condition_type]=eq&searchCriteria[filterGroups][0][filters][0][value]=29189
