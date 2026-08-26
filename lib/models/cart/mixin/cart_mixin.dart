import '../../../common/config.dart';
import '../../../common/tools.dart';
import '../../index.dart';

/// The in-memory key a cart line is stored under, in every map on [CartMixin].
///
/// Configurable products are sent to Magento as the *parent* sku plus the
/// selected super attributes (`configurable_item_options`), which is what makes
/// the selection visible on the website and the other app (86d3g2npa #9). That
/// means a cart rebuilt from `carts/mine/items` only ever sees the parent sku
/// and has no variation object, so two variants of the same parent would
/// collapse into a single row if the sku alone were the key.
///
/// Keying configurables on `parentSku|attr=value,...` instead keeps the locally
/// added line and the server-rebuilt line under the *same* key, so a refresh
/// preserves the variation/attribute context rather than duplicating rows.
/// Lines with no selected options keep the plain sku key they have always had.
String buildCartItemKey(
    Product product, ProductVariation? variation, Map? options) {
  if (options != null && options.isNotEmpty) {
    final parts = options.entries
        .where((e) => e.key != null && e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    if (parts.isNotEmpty) {
      return '${product.sku ?? product.id}|${parts.join(',')}';
    }
  }
  return variation?.sku ?? product.sku ?? product.id.toString();
}

mixin CartMixin {
  User? user;
  double taxesTotal = 0;
  List<Tax> taxes = [];
  double rewardTotal = 0;
  double walletAmount = 0;

  PaymentMethod? paymentMethod;

  String? notes;
  String? currencyCode;
  Map<String, dynamic>? currencyRates;

  final Map<String?, Product?> item = {};
  List<Product> shoppingList = [];

  final Map<String, ProductVariation?> productVariationInCart = {};

  final Map<String, List<AddonsOption>?> productAddonsOptionsInCart = {};

  // The IDs and quantities of products currently in the cart.
  final Map<String, int?> productsInCart = {};

  // The IDs and meta_data of products currently in the cart for woo commerce
  final Map<String, dynamic> productsMetaDataInCart = {};

  void removeItemFromProductId(String productId) {}

  int get totalCartQuantity => productsInCart.values.fold(0, (v, e) => v + e!);

  bool _hasProductVariation(String id) =>
      productVariationInCart[id] != null &&
      productVariationInCart[id]!.price != null &&
      productVariationInCart[id]!.price!.isNotEmpty;

  double getProductPrice(id) {
    if (_hasProductVariation(id)) {
      return double.parse(productVariationInCart[id]!.price!) *
          productsInCart[id]!;
    } else {
      var productId = Product.cleanProductID(id);

      var price =
          PriceTools.getPriceProductValue(item[productId], onSale: true);
      if ((price?.isNotEmpty ?? false) && productsInCart[id] != null) {
        return double.parse(price!) * productsInCart[id]!;
      }
      return 0.0;
    }
  }

  double getProductAddonsPrice(String id) {
    if (productAddonsOptionsInCart.isNotEmpty) {
      var price = 0.0;
      if (productAddonsOptionsInCart[id] == null) {
        return 0.0;
      }
      for (var option in productAddonsOptionsInCart[id]!) {
        var quantity = productsInCart[id] ?? 0;
        var optionPrice = (double.tryParse(option.price ?? '0.0') ?? 0.0);
        if (option.isQuantityBased) {
          optionPrice *= quantity;
        }
        price += optionPrice;
      }
      return price;
    }
    return 0.0;
  }

  double? getSubTotal() {
    return productsInCart.keys.fold(0.0, (sum, id) {
      return sum! + getProductPrice(id) + getProductAddonsPrice(id);
    });
  }

  void setPaymentMethod(data) {
    paymentMethod = data;
  }

  // Returns the Product instance matching the provided id.
  Product? getProductById(String id) {
    return item[id];
  }

  // Returns the Product instance matching the provided id.
  ProductVariation? getProductVariationById(String key) {
    return productVariationInCart[key];
  }

  String? getCheckoutId() {
    return '';
  }

  void setUser(data) {
    user = data;
  }

  void loadSavedCoupon() {}

  bool isEnabledShipping() {
    return kPaymentConfig.enableShipping;
  }

  void setWalletAmount(double total) {
    walletAmount = total;
  }

  bool isWalletCart() {
    return false;
  }

  void addWalletProductToCart({
    required Product product,
    int quantity = 1,
  }) {
    final key = product.sku ?? product.id.toString();
    item[key] = product;
    productsInCart[key] = quantity;

    currencyCode = kAdvanceConfig.defaultCurrency?.currencyCode;
  }

  void setTaxInfo(List<Tax> taxes, double taxesTotal) {
    this.taxes = taxes;
    this.taxesTotal = taxesTotal;
  }

  double getCODExtraFee() {
    final enabled = (kPaymentConfig.smartCOD?.enabled ?? false) &&
        ((paymentMethod?.id?.contains('cod') ?? false) ||
            (paymentMethod?.id?.contains('cashondelivery') ?? false));
    final extraFee = kPaymentConfig.smartCOD?.extraFee ?? 0;
    final amountStop = kPaymentConfig.smartCOD?.amountStop ?? 0;
    final subtotal = getSubTotal() ?? 0;
    return (enabled && extraFee > 0 && subtotal < amountStop) &&
            double.tryParse('$extraFee') != null
        ? double.parse('$extraFee')
        : 0;
  }

  /// Get product detail with quantity in the current cart
  List getProductsInCart() {
    var productList = [];
    for (var key in productsInCart.keys) {
     // var productId = Product.cleanProductID(key);
      var product = getProductById(key);

      if (product != null) {
        productList.add(
            {'id': key, 'product': product, 'quantity': productsInCart[key]});
      }
    }
    return productList;
  }
}
