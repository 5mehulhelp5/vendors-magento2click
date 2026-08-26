import 'dart:async';
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:inspireui/inspireui.dart';
import 'package:magentoegypt/models/SearchResponse.dart';
import 'package:magentoegypt/models/banner_images_model.dart';
import 'package:magentoegypt/models/entities/product_review.dart';
import '../common/config.dart';
import '../data/boxes.dart';
import '../frameworks/magento/services/magento_helper.dart';
import '../models/entities/order_delivery_date.dart';
import '../models/entities/paging_response.dart';
import '../models/entities/prediction.dart';
import '../models/entities/vacation_settings.dart';
import '../models/index.dart';
import '../modules/dynamic_layout/config/app_config.dart';
import 'https.dart';
import 'service_config.dart';

export '../models/entities/paging_response.dart';

abstract class BaseServices {


  final String domain;

  final String adminKey = "jd7u3bu9g7ca1vgocv0dvpr77xof57jf";

  BaseServices({
    required this.domain,
    String? blogDomain,
  });

  String get currencyCode => SettingsBox().currencyCode ?? 'USD';

  String get languageCode => SettingsBox().languageCode ?? 'en';

  // get sort key to filter products
  String? getOrderByKey(orderBy) => null;

  dynamic getOrderDirection(order) => null;

  Future<List<Category>?>? getCategories({lang}) async => const <Category>[];

  Future<SearchResponse?>? searchProductsResult(String? search) => null;

  Future<List<Product>>? getProducts({userId}) => null;

  Future<List<Product>?> fetchProductsLayout(
          {required config, lang, userId, bool refreshCache = false}) async =>
      const <Product>[];

  Future<List<Product>?> fetchProductsByCategory(
          {categoryId,
          tagId,
          required page,
          minPrice,
          maxPrice,
          orderBy,
          lang,
          order,
          featured,
          onSale,
          attribute,
          attributeTerm,
          listingLocation,
          userId,
          String? search,
            String? searchText,
          Map<String, List<String>>? attributeFilters,
          String? include,
          String? nextCursor,
          int? perPage,
          bool refreshCache = false}) async =>
      const <Product>[];

  Future<AppConfig?> getAppConfig({String lang = 'en'}) async => null;


  Future<User>? loginMobile({String? mobile}) => null;

  Future<String>? forgotPasswordMobile({String? mobile}) => null;

  Future<bool> isUserExisted({String? phone, String? username}) async => true;

  Future<PagingResponse<Review>>? getReviews(productId,
          {int page = 1, int perPage = 10}) =>
      null;

  /// The signed-in customer's own reviews (all products, includes pending).
  Future<PagingResponse<Review>>? getMyReviews(
          {int page = 1, int perPage = 20, String? token}) =>
      null;

  /// Product name + thumbnail keyed by SKU — gives the My Reviews list product
  /// context, since the reviews feed carries only SKUs.
  Future<Map<String, ({String name, String? image})>> getReviewedProductInfo(
          List<String> skus) async =>
      {};

  Future<PagingResponse<ProductReview>>? getProductReviews(productSKU,
          {int page = 1, int perPage = 10}) =>
      null;

  Future<List<ProductVariation>?>? getProductVariations(Product product,
          {String? lang}) =>
      null;

  Future<List<ShippingMethod>>? getShippingMethods(
          {CartModel? cartModel,
          String? token,
          String? checkoutId,
          Store? store,
          String? langCode}) =>
      null;

  Future<List<PaymentMethod>>? getPaymentMethods(
          {CartModel? cartModel,
          ShippingMethod? shippingMethod,
          String? token,
          String? langCode}) =>
      null;

  Future<Order>? createOrder({
    CartModel? cartModel,
    UserModel? user,
    bool? paid,
    String? transactionId,
  }) =>
      null;

  Future<PagingResponse<Order>>? getMyOrders({
    User? user,
    dynamic cursor,
    String? cartId,
  }) =>
      null;

  Future? updateOrder(orderId, {status, required token}) => null;

  Future? deleteOrder(orderId, {required token}) => null;

  Future<Order?>? cancelOrder({
    required Order? order,
    required String? userCookie,
  }) =>
      null;

  // ---- Customer Returns (RMA) ----

  /// Store-wide returns config. Null means the feature is unavailable, so
  /// callers can hide returns entirely.
  Future<ReturnPolicy?> getReturnPolicy() async => null;

  /// Orders (with their eligible line items) the customer may open a return
  /// against.
  Future<List<ReturnableOrder>> getReturnableOrders() async =>
      const <ReturnableOrder>[];

  /// Opens a return; returns the full return detail (status `pending`).
  Future<ReturnRequest>? createReturn({
    required int orderId,
    required List<ReturnLineInput> items,
    required String resolution,
    String? comment,
  }) =>
      null;

  /// The customer's returns, newest first (list summaries).
  Future<PagingResponse<ReturnRequest>>? getMyReturns({
    User? user,
    dynamic cursor,
  }) =>
      null;

  /// One return in full.
  Future<ReturnRequest>? getReturnDetail(int id) => null;

  /// Withdraws a return; returns a confirmation message.
  Future<String> cancelReturn(int id, {String? comment}) async => '';

  /// Adds a message to a return; returns a confirmation message.
  Future<String> addReturnComment(int id, String comment) async => '';

  /// Attaches return-shipment tracking; returns a confirmation message.
  Future<String> addReturnTracking(
    int id, {
    required String carrierCode,
    required String trackNumber,
  }) async =>
      '';

  Future<PagingResponse<Product>>? searchProducts({
    name,
    categoryId,
    categoryName,
    tag,
    attribute,
    attributeId,
    required page,
    lang,
    listingLocation,
    userId,
  }) =>
      null;

  Future<User?>? getUserInfo(cookie) => null;
  Future<bool?>? saveUserInfo(Address? address,bool isDelete) => null;

  /// Whether the customer is subscribed to the newsletter.
  ///
  /// Magento carries this on the customer resource as
  /// `extension_attributes.is_subscribed`. Returns null on frameworks that
  /// don't expose it, which the UI treats as "unavailable" rather than "off".
  Future<bool?>? getNewsletterSubscription() => null;

  /// Subscribes or unsubscribes the customer, returning the state the server
  /// confirms — not the state that was requested, so the UI can't drift out of
  /// step with the store if the write is rejected.
  Future<bool?>? setNewsletterSubscription(bool subscribe) => null;

  Future<User?>? createUser({
    String? firstName,
    String? lastName,
    String? username,
    String? password,
    String? phoneNumber,
    bool isVendor = false,
  }) =>
      null;

  Future<Map<String, dynamic>?>? updateUserInfo(
          Map<String, dynamic> json, String? token) =>
      null;

  Future<User?>? login({
    username,
    password,
  }) =>
      null;

  Future<Product?>? getProduct(id, {lang}) => null;

  /// Full product looked up by SKU — lets a review link back to its product.
  Future<Product?>? getProductBySku(String sku) => null;

  Future<ProductVariation?>? getVariationProduct(id, variationId, {lang}) =>
      null;

  Future<Coupons>? getCoupons({int page = 1, String search = ''}) => null;

  Future<List<OrderNote>>? getOrderNote({
    String? userId,
    String? orderId,
  }) =>
      null;

  Future? createReview(
          {String? productId, Map<String, dynamic>? data, String? token}) =>
      null;

  Future<Map<String, dynamic>?>? getHomeCache(String? lang) => null;


  Future? getCategoryWithCache() => null;

  Future<List<FilterAttribute>>? getFilterAttributes({String? lang}) => null;

  Future<List<SubAttribute>>? getSubAttributes({
    int? id,
    String? lang,
    int page = 1,
  }) =>
      null;

  Future<List<FilterTag>>? getFilterTags({String? lang}) => null;

  Future<String>? getCheckoutUrl(Map<String, dynamic> params, String? lang) =>
      null;

  Future<String?>? submitForgotPassword({
    String? forgotPwLink,
    Map<String, dynamic>? data,
  }) =>
      null;

  Future? logout(String? token) => null;

  Future? checkoutWithCreditCard(String? vaultId, CartModel cartModel,
      Address address, PaymentSettingsModel paymentSettingsModel) {
    return null;
  }

  Future<PaymentSettings>? getPaymentSettings() {
    return null;
  }

  Future<PaymentSettings>? addCreditCard(
      PaymentSettingsModel paymentSettingsModel,
      CreditCardModel creditCardModel) {
    return null;
  }

 // Future<Map<String, dynamic>?>? getCurrencyRate() => null;
  Future<Map<String, dynamic>?> getCurrencyRate() async {
    try {
      final url = '$domain/rest/V1/directory/currency';

      final response = await httpCache(url.toUri()!,headers: {'Authorization': 'Bearer $adminKey'});
      var body = convert.jsonDecode(response.body);
      if (response.statusCode == 200 && body != null && body is Map) {
        var data = Map<String, dynamic>.from(body);
        var currency = <String, dynamic>{};
        var exchange_rates = data["exchange_rates"];
        exchange_rates.forEach((item) {
          currency[item["currency_to"]] = double.parse("${item["rate"]}");
        });
        // for (var key in data.keys) {
        //   currency[key.toUpperCase()] =
        //       double.parse("${data[key]['rate'] == 0 ? 1 : data[key]['rate']}");
        // }
        return currency;
      } else {
        return null;
      }
    } catch (err) {
      return null;
    }
  }

  Future<Product?> getStockStatus(sku) async {
    try {
      var response = await httpGet(
          MagentoHelper.buildUrl(domain, 'stockStatuses/$sku')!,
          headers: {'Authorization': 'Bearer $adminKey'}
      );
      final body = convert.jsonDecode(response.body);
      print("stock_status ${body['stock_status']}");
      if (response.statusCode == 200) {
        return Product.fromStockStatusJson(body, domain, sku);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>?>? getCartInfo(String? token) => null;

  Future? syncCartToWebsite(CartModel cartModel, User? user) => null;

  Future<Map<String, dynamic>>? getCustomerInfo(String? id) => null;

  Future<Map<String, dynamic>?>? getTaxes(CartModel cartModel) => null;

  Future<PagingResponse<Tag>?> getTags({String? lang}) async => null;

  Future<Tag>? getTagById({required String tagId}) => null;

  Future<PagingResponse<Tag>>? getTagsByPage(
          {String? lang, int? page, required int limit}) =>
      null;

  Future<Tag?> getTagBySlug(String slug) async => null;

  Future? getCountries() => null;

  Future? getStatesByCountryId(countryId) => null;

  Future? getCitiesByStateId(countryId, stateId) => null;

  Future? getCitiesByCountryId(countryId) => null;

  Future? getZonesByCityId(CityId) => null;

  Future? getZipCodeByAddress(countryId, stateId, city) => null;

  Future<Point?>? getMyPoint(String? token) => null;

  Future? updatePoints(String? token, Order? order) => null;

  //For vendor
  Future<Store?>? getStoreInfo(storeId) => null;

  Future<bool>? pushNotification(
    cookie, {
    receiverEmail,
    senderName,
    message,
  }) =>
      null;

  Future<List<Review>>? getReviewsStore({storeId, page, perPage}) => null;

  Future<List<Product>>? getProductsByStore(
          {storeId,
          int? page,
          int? perPage,
          int? catId,
          bool? onSale,
          String? order,
          String? orderBy,
          String? searchTerm,
          String lang = 'en'}) =>
      null;

  Future<List<Store>>? searchStores({
    String? keyword,
    int? page,
  }) =>
      null;

  Future<List<Store>>? getFeaturedStores() => null;

  Future<PagingResponse<Order>>? getVendorOrders({
    required User user,
    dynamic cursor,
  }) =>
      null;

  Future<Product>? createProduct(String? cookie, Map<String, dynamic> data) =>
      null;

  Future<void>? deleteProduct(
          {required String? cookie, required String? productId}) =>
      null;

  Future<List<Product>>? getOwnProducts(
    String? cookie, {
    int? page,
    int? perPage,
  }) =>
      null;

  Future<dynamic>? uploadImage(dynamic data, String? token) => null;

  Future<List<Prediction>>? getAutoCompletePlaces(
          String term, String? sessionToken) =>
      null;

  Future<Prediction>? getPlaceDetail(
          Prediction prediction, String? sessionToken) =>
      null;

  Future<List<Store>>? getNearbyStores(Prediction prediction,
          {int page = 1, int perPage = 10, int radius = 10, String? name}) =>
      null;

  Future<Product?> getProductByPermalink(String productPermalink) async {
    return null;
  }

  Future<Category?> getProductCategoryByPermalink(
      String productCategoryPermalink) async {
    return null;
  }

  Future<Store?> getStoreByPermalink(String storePermaLink) async {
    return null;
  }


  Future<List<Product>?> fetchProductsByBrand(
          {dynamic page, String? lang, String? brandId}) async =>
      null;

  ///----FLUXSTORE LISTING----///
  Future<dynamic>? bookService({userId, value, message}) => null;

  Future<List<Product>>? getProductNearest(location) => null;

  Future<List<ListingBooking>>? getBooking({userId, page, perPage}) => null;

  Future<Map<String, dynamic>?>? checkBookingAvailability({data}) => null;

  Future<List<dynamic>>? getLocations() => null;

  /// BOOKING FEATURE
  Future<bool>? createBooking(dynamic bookingInfo) => null;

  Future<List<dynamic>>? getListStaff(String? idProduct) => null;

  Future<List<String>>? getSlotBooking(
          String? idProduct, String idStaff, String date) =>
      null;


  Future<void> updateOrderIdForRazorpay(paymentId, orderId) async {
    try {
      final token = base64.encode(latin1.encode(
          '${kRazorpayConfig['keyId']}:${kRazorpayConfig['keySecret']}'));

      var body = {};
      if (ServerConfig().isWooType) {
        body = {
          'notes': {'woocommerce_order_id': orderId}
        };
      }

      await http.patch(
          'https://api.razorpay.com/v1/payments/$paymentId'.toUri()!,
          headers: {
            'Authorization': 'Basic ${token.trim()}',
            'Content-Type': 'application/json'
          },
          body: json.encode(body));
    } catch (e) {
      return;
    }
  }




  Future<List<Category>> getCategoriesByPage(
          {lang,
          page,
          limit,
          storeId,
          String? searchTerm,
          int? parent,
          bool useCompute = true}) async =>
      [];

  Future<PagingResponse<Category>> getSubCategories({
    String? langCode,
    dynamic page = 1,
    int limit = 25,
    required String? parentId,
  }) async =>
      const PagingResponse<Category>();

  Future<List<OrderDeliveryDate>> getListDeliveryDates({storeId}) async =>
      <OrderDeliveryDate>[];

  Future<Category?> getProductCategoryById(
          {required String categoryId}) async =>
      null;

  Future<VacationSettings?> getVacationSettings(String storeId) async => null;

  Future<bool?> setVacationSettings(
          String cookie, VacationSettings vacationSettings) async =>
      null;


  Future<dynamic>? getDataFromScanner(String data, {String? cookie}) => null;

  Future<String?> getBlogContent(dynamic id) async => null;

  Future<List<Order>> getVendorAdminOrders(
      {required String cookie,
      int page = 1,
      int perPage = 10,
      String? status,
      String? search,
      String? name}) async {
    var list = <Order>[];
    try {
      var base64Str = EncodeUtils.encodeCookie(cookie);
      var endpoint =
          '$domain/wp-json/vendor-admin/vendor-orders?page=$page&per_page=$perPage&token=$base64Str&platform=${ServerConfig().platform}';
      if (status != null) {
        if (status.toLowerCase() == 'onhold') {
          status = 'on-hold';
        }
        endpoint += '&status=$status';
      }
      if (search != null && search.trim().isNotEmpty) {
        endpoint += '&search=$search';
      }
      if (name != null && name.trim().isNotEmpty) {
        endpoint += '&name=$name';
      }
      printLog(endpoint);

      final response = await httpGet(
        endpoint.toUri()!,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);

        for (var item in result['response']) {
          list.add(Order.fromJson(item));
        }
      }
    } catch (e) {
      printLog('vendor_admin.dart getVendorOrders: $e');
    }
    return list;
  }

  Future<String?> createPaymentIntentStripe(
      {required String totalPrice,
      String? currencyCode,
      String? emailAddress,
      String? name,
      required String paymentMethodId}) async {
    try {
      final urlReq = '${kStripeConfig["serverEndpoint"]}/payment-intent';
      final result = await http.post(
        urlReq.toUri()!,
        body: jsonEncode(
          {
            'payment_method_id': paymentMethodId,
            'email': emailAddress,
            'amount': totalPrice,
            'currencyCode': currencyCode,
            'returnUrl': kStripeConfig['returnUrl'],
            'captureMethod': (kStripeConfig['enableManualCapture'] ?? false)
                ? 'manual'
                : 'automatic',
          },
        ),
        headers: {'content-type': 'application/json'},
      );

      var response = json.decode(result.body);
      if (result.statusCode == 200) {
        final body = response is List ? response[0] : response;
        final success = body['success'];
        if (success) {
          return body['client_secret'];
        }
      } else if (response['message'] != null) {
        throw Exception(response['message']);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<String?> createPaymentIntentStripeV2({
    required String totalPrice,
    String? currencyCode,
    String? emailAddress,
    String? name,
  }) async {
    try {
      final urlReq = '${kStripeConfig["serverEndpoint"]}/payment-intent-v2';
      final result = await http.post(
        urlReq.toUri()!,
        body: jsonEncode(
          {
            'email': emailAddress,
            'amount': totalPrice,
            'currencyCode': currencyCode,
            'returnUrl': kStripeConfig['returnUrl'],
            'captureMethod': (kStripeConfig['enableManualCapture'] ?? false)
                ? 'manual'
                : 'automatic',
          },
        ),
        headers: {'content-type': 'application/json'},
      );

      var response = json.decode(result.body);
      if (result.statusCode == 200) {
        final body = response is List ? response[0] : response;
        final success = body['success'];
        if (success == true) {
          return body['client_secret'];
        }

        if (response['message'] != null) {
          throw Exception(response['message']);
        }
      }

      throw Exception('Unknown error. Please try again.');
    } catch (e, trace) {
      printError(e, trace);
      rethrow;
    }
  }

  Future<String?> createPaymentIntentStripeV3({
    String? orderId,
    required String totalPrice,
    String? currencyCode,
    String? emailAddress,
    String? name,
  }) async {
    try {
      final urlReq = '${kStripeConfig["serverEndpoint"]}/payment-intent-v3';
      final result = await http.post(
        urlReq.toUri()!,
        body: jsonEncode(
          {
            'email': emailAddress,
            'amount': totalPrice,
            'currencyCode': currencyCode,
            'returnUrl': kStripeConfig['returnUrl'],
            'captureMethod': (kStripeConfig['enableManualCapture'] ?? false)
                ? 'manual'
                : 'automatic',
            'request3dSecure': 'any',
            'orderId': orderId,
          },
        ),
        headers: {'content-type': 'application/json'},
      );

      var response = json.decode(result.body);
      if (result.statusCode == 200) {
        final body = response is List ? response[0] : response;
        final success = body['success'];
        if (success == true) {
          return body['client_secret'];
        }

        if (response['message'] != null) {
          throw Exception(response['message']);
        }
      }

      throw Exception('Unknown error. Please try again.');
    } catch (e, trace) {
      printError(e, trace);
      rethrow;
    }
  }

  Future<List<ProductItem>> getListProductItemByOrderId(String orderId) async {
    return const <ProductItem>[];
  }

  Future<List<String>> getImagesByProductId(String productId) async {
    return const <String>[];
  }

  /// Resolve a configurable order line's option ids (each `{'attr': <id>,
  /// 'value': <id>}`) to localized display pairs `{'name': <attribute label>,
  /// 'value': <option label>}`. Default is empty; only Magento implements it
  /// (86d3tkhgz #3).
  Future<List<Map<String, dynamic>>> resolveConfigurableOptions(
      List<Map<String, dynamic>> options) async {
    return const <Map<String, dynamic>>[];
  }

  /// Localized country display name for an ISO-2 code (e.g. "EG" -> "مصر" in
  /// Arabic), or null if unavailable — callers fall back to the English name.
  /// Only Magento implements it (86d3tkj56 #3).
  Future<String?> getLocalizedCountryName(String code) async => null;

  Future<bool> checkProductPermission(String productId, String? cookie) async {
    return true;
  }

  Future<bool> deleteAccount(String token) async {
    /// If so fast, Apple will be suspect this action is ambiguous
    /// And has no effect on the account.
    /// So we need to wait for a while.
    /// This is a workaround.
    var res = await httpDelete(MagentoHelper.buildUrl(domain, 'customers/${UserBox().userInfo?.id}')!,
        headers: {'Authorization': 'Bearer $adminKey'
          ,'content-type': 'application/json'},);
    return Future.delayed(const Duration(seconds: 2), () => true);
  }


  Future<PagingResponse<Product>> getProductsByCategoryId(
    String categoryId, {
    String? langCode,
    dynamic page = 1,
    int limit = 25,
  }) async =>
      const PagingResponse<Product>();

  Future<int?> getProductCountOfCategory(String categoryId) async {
    return null;
  }

  Future<Order>? createIAPOrder(Map<String, dynamic> params, User? user) =>
      null;

  Future<List<BannerImagesModel>?>? getBannerImages() async {
    return null;
  }

  Future<List<Product>?>? getWishList() async {
    return null;
  }

  Future<String?>? addProductToWishList(Product product) async {
    return null;
  }

  Future<String?>? removeProductToWishList(String productId) async {
    return null;
  }

  Future<List<Product>?>? getShoppingList(CartModel model,
      {bool replace = false}) async {
    return null;
  }

  /// [options] are the selected configurable super attributes, keyed by
  /// attribute code. When present, [sku] is the *parent* sku and [fallbackSku]
  /// is the child sku to fall back to if the options cannot be resolved.
  Future<String?>? addUpdateItemsToCart(
      Product product, String sku, int qty, bool isUpdate,
      {Map? options, String? fallbackSku}) async {
    return null;
  }

  Future<bool?> deleteItemInCart(String itemId)async {
    return null;
  }

  Future<Map<String, dynamic>?> mobileSendOtp(String otpText,String number)async {
    return null;
  }

  /// Returns true when [phone] is already tied to an existing account.
  /// Used as a friendly pre-check during registration; the backend
  /// uniqueness rule remains the authoritative guard.
  Future<bool> isPhoneRegistered(String phone) async => false;

  // Future<Map<String, dynamic>?> mobileVerifyOtp(Map<String, dynamic> params)async {
  //   return null;
  // }
}
