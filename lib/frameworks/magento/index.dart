import 'package:flutter/material.dart';
import 'package:inspireui/widgets/coupon_card.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../data/boxes.dart';
import '../../generated/l10n.dart';
import '../../models/entities/ProdcutOptionAttribute.dart' show ConfigurableSwatch;
import '../../models/entities/filter_sorty_by.dart';
import '../../models/index.dart';
import '../../screens/detail/widgets/review.dart';
import '../../services/index.dart';
import '../../widgets/common/expansion_info.dart';
import '../frameworks.dart';
import '../product_variant_mixin.dart';
import 'magento_payment.dart';
import 'magento_variant_mixin.dart';
import 'services/magento_service.dart';

class MagentoWidget extends BaseFrameworks
    with ProductVariantMixin, MagentoVariantMixin {
  final MagentoService api;

  MagentoWidget(this.api);

  @override
  bool get enableProductReview => false;

  /// Expandable "Reviews" section on the product page (web parity). Reviews
  /// are read via GraphQL and submitted via the customer-token review API;
  /// the submit form is shown to logged-in users only (Reviews gates on it).
  @override
  Widget productReviewWidget(Product product) {
    if (!kProductDetail.enableReview) {
      return const SizedBox();
    }
    return ExpansionInfo(
      title: S.current.reviews,
      children: [
        Reviews(product.sku, allowRating: true),
      ],
    );
  }

  @override
  Future<void> applyCoupon(context,
      {Coupons? coupons,
      String? code,
      Function? success,
      Function? error}) async {
    try {
      final cartModel = Provider.of<CartModel>(context, listen: false);
      final userModel = Provider.of<UserModel>(context, listen: false);
     // await api.addItemsToCart(cartModel, userModel.user != null ? userModel.user!.cookie : null);
      final discountAmount = await api.applyCoupon(
          userModel.user != null ? userModel.user!.cookie : null, code);
      cartModel.discountAmount = discountAmount;
      var discount = Discount();
      discount.coupon = Coupon.fromJson({
        'amount': discountAmount,
        'code': code,
        'discount_type': 'fixed_cart'
      });
      discount.discountValue = discountAmount;
      success!(discount);
    } catch (err) {
      error!(err.toString());
    }
  }

  @override
  Future<void> doCheckout(context,
      {Function? success, Function? error, Function? loading}) async {
    final cartModel = Provider.of<CartModel>(context, listen: false);
    final userModel = Provider.of<UserModel>(context, listen: false);
    try {
      await api.addItemsToCart(cartModel, userModel.user != null ? userModel.user!.cookie : null);
      if (cartModel.couponObj != null) {
        final discountAmount = await api.applyCoupon(
            userModel.user != null ? userModel.user!.cookie : null,
            cartModel.couponObj!.code);
        cartModel.discountAmount = discountAmount;
      }
      success!();
    } catch (e, trace) {
      error!(e.toString());
      printError(e, trace);
    }
  }

  @override
  Future<void> createOrder(context,
      {Function? onLoading,
      Function? success,
      Function? error,
      paid = false,
      cod = false,
      bacs = false,
      transactionId = ''}) async {
    var listOrder = <Map>[];
    var isLoggedIn = Provider.of<UserModel>(context, listen: false).loggedIn;
    final cartModel = Provider.of<CartModel>(context, listen: false);
    final userModel = Provider.of<UserModel>(context, listen: false);

    try {
      onLoading!(true);
      final order = await Services().api.createOrder(
          cartModel: cartModel,
          user: userModel,
          paid: paid,
          transactionId: transactionId)!;

      if (!isLoggedIn) {
        var items = UserBox().orders;
        if (items.isNotEmpty) {
          listOrder = items;
        }
        listOrder.add(order.toOrderJson(cartModel, null));
        UserBox().orders = listOrder;
      }
      if (kMagentoPayments.contains(cartModel.paymentMethod!.id)) {
        onLoading(false);
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MagentoPayment(
                    onFinish: (order) => success!(order),
                    order: order,
                  )),
        );
      } else {
        success!(order);
      }
    } catch (e, trace) {
      error!(e.toString());
      printError(e, trace);
    }
  }

  @override
  void placeOrder(
    context, {
    CartModel? cartModel,
    PaymentMethod? paymentMethod,
    Function? onLoading,
    Function? success,
    Function? error,
  }) {
    Provider.of<CartModel>(context, listen: false)
        .setPaymentMethod(paymentMethod);
    printLog(paymentMethod!.id);

    createOrder(context,
        cod: true, onLoading: onLoading, success: success, error: error);
  }

  @override
  Map<String, dynamic>? getPaymentUrl(context) {
    return null;
  }

  @override
  void updateUserInfo(
      {User? loggedInUser,
      context,
      required onError,
      onSuccess,
      required currentPassword,
      required userDisplayName,
      userEmail,
        phoneNumber,
      userNiceName,
      userUrl,
      userPassword,
      userFirstname,
      userLastname}) {
    if (currentPassword.isEmpty && !loggedInUser!.isSocial!) {
      onError(S.of(context!).currentPasswordrequired);
      return;
    }

    var params = {
      'user_id': loggedInUser!.id,
      'display_name': userDisplayName,
      'user_email': userEmail,
      'user_nicename': userNiceName,
      'user_url': userUrl,
    };
    if (userEmail == loggedInUser.email && !loggedInUser.isSocial!) {
      params['user_email'] = '';
    }

    if (phoneNumber != loggedInUser.phoneNumber) {
      params['phoneNumber'] = phoneNumber;
    }
    if (!loggedInUser.isSocial! && userPassword!.isNotEmpty) {
      params['user_pass'] = userPassword;
    }
    if (!loggedInUser.isSocial! && currentPassword.isNotEmpty) {
      params['current_pass'] = currentPassword;
    }
    Services().api.updateUserInfo(params, loggedInUser.cookie)!.then((value) {
      var param = {
        'firstname': loggedInUser.firstName,
        'lastname': loggedInUser.lastName,
        'id': loggedInUser.id,
        'email': userEmail == '' ? loggedInUser.email : userEmail
      };
      onSuccess!(User.fromMagentoJson(param, loggedInUser.cookie));
    }).catchError((e) {
      onError(e.toString());
    });
  }

  @override
  Widget renderCurrentPassInputforEditProfile(
      {BuildContext? context,
      TextEditingController? currentPasswordController}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(S.of(context!).currentPassword,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            )),
        const SizedBox(
          height: 5,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: Theme.of(context).primaryColorLight, width: 1.5)),
          child: TextField(
            obscureText: true,
            decoration: const InputDecoration(border: InputBorder.none),
            controller: currentPasswordController,
          ),
        ),
        const SizedBox(
          height: 15,
        ),
      ],
    );
  }

  void getListCountries() {
    api.getCountries().then((countries) async {
      SettingsBox().countries = countries;
    });
  }

  void getAllAttributes() {
    api.getAllAttributes().then((value) {}).catchError((err) {});
  }

  @override
  Future<void> onLoadedAppConfig(String? lang, Function callback) async {
    getAllAttributes();
    getListCountries();
    // Warm the visible-on-front attribute metadata so the first product
    // page's "Product Details" section isn't blocked on this fetch.
    api.getVisibleFrontAttributes(lang: lang).catchError(
        (_) => <String, Map<String, dynamic>>{});
  }

  @override
  Widget renderVariantCartItem(
      BuildContext context, Product? product, variation, Map? options) {
    // Show the selected configurable options (e.g. "Size: 6 yrs") under the
    // name so cart lines for different variants are distinguishable — this was
    // a stub returning SizedBox, so the variant never rendered (86d3tntae).
    // The selection is stored as {attribute_code: option_value_id}; the human
    // label lives in the parent product's attribute options
    // (option['value'] == id -> option['label']) — the same map the variant
    // swatches resolve against.
    final attributes = product?.attributes;
    if (attributes == null || attributes.isEmpty) return const SizedBox();

    // attribute_code -> selected option value id. Prefer the options map
    // captured on add; fall back to the variation's own attributes.
    final selections = <String, String>{};
    options?.forEach((k, v) {
      if (k != null && v != null) selections['$k'] = '$v';
    });
    if (selections.isEmpty && variation is ProductVariation) {
      for (final a in variation.attributes) {
        if (a.name != null && a.option != null) selections[a.name!] = a.option!;
      }
    }
    if (selections.isEmpty) return const SizedBox();

    final parts = <String>[];
    selections.forEach((code, valueId) {
      ProductAttribute? attr;
      for (final a in attributes) {
        if ((a.name ?? '').toLowerCase() == code.toLowerCase()) {
          attr = a;
          break;
        }
      }
      if (attr == null) return;
      var label = valueId;
      for (final o in attr.options ?? const []) {
        if (o is Map && '${o['value']}' == valueId && o['label'] is String) {
          label = o['label'] as String;
          break;
        }
      }
      final title = (attr.label?.trim().isNotEmpty ?? false)
          ? attr.label!.trim()
          : (attr.name ?? '').trim();
      if (label.trim().isNotEmpty && label != 'null') {
        parts.add(title.isNotEmpty ? '$title: $label' : label);
      }
    });
    if (parts.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        parts.join('   •   '),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void loadShippingMethods(context, CartModel cartModel, bool beforehand) {
//    if (!beforehand) return;
    final cartModel = Provider.of<CartModel>(context, listen: false);
    Future.delayed(Duration.zero, () {
      final token = Provider.of<UserModel>(context, listen: false).user != null
          ? Provider.of<UserModel>(context, listen: false).user!.cookie
          : null;
      var langCode = Provider.of<AppModel>(context, listen: false).langCode;
      Provider.of<ShippingMethodModel>(context, listen: false)
          .getShippingMethods(
              cartModel: cartModel,
              token: token,
              checkoutId: cartModel.getCheckoutId(),
              langCode: langCode);
    });
  }

  @override
  Widget renderButtons(
      BuildContext context, Order order, cancelOrder, createRefund) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: cancelOrder,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (order.status!.isCancelled)
                        ? Colors.blueGrey
                        : Colors.red),
                child: Text(
                  'Cancel'.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  String? getPriceItemInCart(Product product, ProductVariation? variation,
      Map<String, dynamic> currencyRate, String? currency,
      {List<AddonsOption>? selectedOptions}) {
    return variation != null && variation.id != null
        ? PriceTools.getVariantPriceProductValue(
            variation,
            currencyRate,
            currency,
            onSale: true,
            selectedOptions: selectedOptions,
          )
        : PriceTools.getPriceProduct(product, currencyRate, currency,
            onSale: true);
  }

  @override
  Future<List<Country>?> loadCountries() async {
    List<Country>? countries = <Country>[];
    try {
      countries = ListCountry.fromMagentoJson(SettingsBox().countries).list;
    } catch (err) {
      printLog(err);
    }
    return countries;
  }

  @override
  Future<List<CountryState>> loadStates(Country country) async {
    return country.states ?? [];
  }


  @override
  Future<List<City>> loadCities(Country country, CountryState state) async {
    var states = <City>[];
    try {
      final items =
          await Services().api.getCitiesByStateId(country.id, state.id);
      for (var item in items) {
        states.add(City.fromConfig(item));
      }
    } catch (e) {
      printLog(e.toString());
    }

    return states;
  }

  @override
  Future<List<City>> loadCitiesWithCountry(Country country) async {
    var states = <City>[];
    try {
      final items =
      await Services().api.getCitiesByCountryId(country.id);
      for (var item in items) {
        states.add(City.cityConfig(item));
      }
    } catch (e) {
      printLog(e.toString());
    }

    return states;
  }

  @override
  Future<List<City>> loadZones(City city) async {
    var states = <City>[];
    try {
      final items =
      await Services().api.getZonesByCityId(city.name);
      for (var item in items) {
        states.add(City.zoneConfig(item));
      }
    } catch (e) {
      printLog(e.toString());
    }

    return states;
  }

  @override
  Future<String> loadZipCode(
      Country country, CountryState state, City city) async {
    var zipCode;
    try {
      zipCode = await Services()
          .api
          .getZipCodeByAddress(country.id, state.id, city.name);
    } catch (e) {
      printLog(e.toString());
    }

    return zipCode;
  }

  @override
  Future<void> resetPassword(BuildContext context, String username) async {
    try {
      var isSuccess = await api.resetPassword(username);
      if (isSuccess == true) {
        Tools.showSnackBar(
            ScaffoldMessenger.of(context), S.of(context!).resetPasswordLink);
        Future.delayed(
            const Duration(seconds: 2), () => Navigator.of(context).pop());
      } else {
        Tools.showSnackBar(
            ScaffoldMessenger.of(context), 'Please Enter Correct Email');
      }
      return;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Product?> getProductDetail(context, Product? product) async {
    try {
      // Null-safe on purpose: `configurable_product_options` is dynamic and
      // several parsers never set it, so `.length` on null threw a
      // NoSuchMethodError out of this method and skipped everything below it —
      // stock, the details rows and the swatches — for the whole product.
      final configurableOptions = product?.configurable_product_options;
      if (configurableOptions is List && configurableOptions.isNotEmpty) {
        /// Seed the configurable attributes from the same options/list call
        /// the variation loader uses. This used to walk
        /// configurable_product_options itself, which cost one attribute
        /// lookup per product and got two things wrong:
        ///
        ///  * it fetched the *first* attribute's option set and then reused it
        ///    for every attribute, so on a Colour+Size product the Size block
        ///    matched nothing and rendered as an empty selection box; and
        ///  * it took the attribute *code* from `label`, which the API returns
        ///    as the store-view label ("Color", "الألوان") as often as the real
        ///    code, breaking the swatch lookup that keys off it.
        ///
        /// options/list carries the code, the label and each attribute's own
        /// options in one response (86d3g53dk #7).
        ///
        /// Seeding is best-effort: the variation loader re-fetches the same
        /// attributes moments later, so a hiccup here should cost the variant
        /// picker a frame, not fail the whole product page.
        try {
          final attrs =
              await api.getConfigurableproductsAttributes(product?.sku ?? '');
          if (attrs.isNotEmpty) {
            product!.attributes = attrs;
          }

          /// Backs getColorCode()'s last-resort hex lookup in BasicSelection.
          final attributeId = '${configurableOptions[0]["attribute_id"]}';
          product?.productOptions =
              await api.getProductAttributesWithOption(attributeId);
        } catch (e) {
          printLog('seed configurable attributes error: $e');
        }
      }
      // Fetch stock and the "Product Details" rows concurrently — this is
      // awaited before the PDP renders. getProductInfors never throws (it
      // returns [] on failure).
      final stockFuture = api.getStockStatus(product?.sku);
      final inforsFuture = api.getProductInfors(product?.sku);
      // Backfill swatches when the product didn't come with them (e.g. from
      // live search); browse products already carry them from mstore/products.
      final Future<List<ConfigurableSwatch>> swatchFuture =
          (product?.swatches?.isNotEmpty ?? false) || product?.sku == null
              ? Future.value(product?.swatches ?? <ConfigurableSwatch>[])
              : api.getProductSwatches(product?.sku);
      Product? productStock = await stockFuture;
      product!.inStock = productStock?.inStock;
      product.stockQuantity ??= productStock?.stockQuantity;

      /// Localized "Product Details" table rows (web "More Information").
      product.infors = await inforsFuture;
      final swatches = await swatchFuture;
      if (swatches.isNotEmpty) {
        product.swatches = swatches;
      }
      return product;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void onFinishOrder(
      BuildContext context, Function onSuccess, Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => MagentoPayment(
                onFinish: (order) {
                  onSuccess(order);
                },
                order: order,
              )),
    );
  }

  @override
  List<OrderByType> get supportedSortByOptions => [
        OrderByType.menu_order,
        OrderByType.onSale,
        OrderByType.date,
        OrderByType.price,
        OrderByType.title,
      ];
}
