import 'package:flutter/cupertino.dart';

import '../../common/constants.dart';
import '../../common/tools.dart';
import '../serializers/user.dart';
import 'user_address.dart';

class User {
  String? id;
  bool? loggedIn;
  String? name;
  String? firstName;
  String? lastName;
  String? username;
  String? email;
  String? nicename;
  String? userUrl;
  String? picture;
  String? cookie;
  String? jwtToken;
  Shipping? shipping;
  Billing? billing;
  List<Addresses>? addresses;
  bool isVender = false;
  bool isDeliveryBoy = false;
  bool? isSocial = false;
  bool? isDriverAvailable;
  bool isManager = false;

  /// Google Auth
  String? phoneNumber;
  String? ggTokenId;

  User();

  User.init({
    this.id,
    this.loggedIn,
    this.name,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.nicename,
    this.userUrl,
    this.picture,
    this.cookie,
    this.jwtToken,
    this.shipping,
    this.billing,
    this.isSocial,
    this.isDriverAvailable,
    this.phoneNumber,
    this.ggTokenId,
  });

  String get fullName =>
      name ?? [firstName ?? '', lastName ?? ''].join(' ').trim();

  String get identifierInformation =>
      (email?.isEmpty ?? true) ? username ?? '' : email ?? '';

  ///FluxListing
  String? role;

  User.fromGoogleAuth({this.phoneNumber, this.ggTokenId});

  // from WooCommerce Json
  User.fromWooJson(Map json) {
    try {
      var user = json['user'];
      isSocial = true;
      loggedIn = true;
      id = json['wp_user_id'].toString();
      name = user['displayname'];
      cookie = json['cookie'];
      username = user['username'];
      nicename = user['nicename'];
      firstName = user['firstname'];
      lastName = user['lastname'];
      phoneNumber = user['phoneNumber'];
      email = user['email'] ?? id;
      isSocial = true;
      userUrl = user['avatar'];
      var roles = [];
      var roleJson = json['role'] ?? user['role'];
      if (roleJson is Map) {
        roles = roleJson.values.toList();
      } else {
        roles = roleJson as List;
      }

      var role = roles.firstWhere(
          (item) => ((item == 'seller') ||
              (item == 'wcfm_vendor') ||
              (item == 'administrator') ||
              (item == 'owner')),
          orElse: () => null);
      if (role != null) {
        isVender = true;
      } else {
        isVender = false;
      }
      if (user['dokan_enable_selling'] != null &&
          user['dokan_enable_selling'].toString().isNotEmpty) {
        isVender = user['dokan_enable_selling'] == 'yes';
      }
      role = roles.firstWhere(
          (item) => ((['wcfm_delivery_boy', 'driver'].contains(item))),
          orElse: () => null);
      if (role != null) {
        isDeliveryBoy = true;
      }
      if (json['shipping'] != null) {
        shipping = Shipping.fromJson(json['shipping']);
      }
      if (json['billing'] != null) {
        billing = Billing.fromJson(json['billing']);
      }
      if (shipping == null && user['shipping'] != null) {
        shipping = Shipping.fromJson(user['shipping']);
      }
      if (billing == null && user['billing'] != null) {
        billing = Billing.fromJson(user['billing']);
      }
      if (user['avatar'] != null) {
        picture = user['avatar'];
      }
      if (user['is_driver_available'] != null) {
        isDriverAvailable = user['is_driver_available'] == 'on' ||
            user['is_driver_available'] == true;
      }
    } catch (e) {
      printLog(e.toString());
    }
  }

  User.fromJson(Map json) {
    try {
      isSocial = json['isSocial'] ?? false;
      loggedIn = json['loggedIn'];
      id = json['id'].toString();
      cookie = json['cookie'];
      username = json['username'];
      nicename = json['nicename'];
      firstName = json['firstName'];
      lastName = json['lastName'];
      phoneNumber = json['phoneNumber'];
      name = json['displayname'] ??
          json['displayName'] ??
          '${firstName ?? ''}${(lastName?.isEmpty ?? true) ? '' : ' $lastName'}';

      email = json['email'] ?? id;
      userUrl = json['avatar'];
    } catch (e) {
      printLog(e.toString());
    }
  }

  // from Magento Json
  User.fromMagentoJson(Map json, token) {
    try {
      loggedIn = true;
      id = json['id'].toString();
      name = json['firstname'] + ' ' + json['lastname'];
      username = '';
      cookie = token;
      firstName = json['firstname'];
      lastName = json['lastname'];
      email = json['email'];
      picture = '';
      if (json['addresses'] != null) {
        addresses = <Addresses>[];
        json['addresses'].forEach((v) {
          addresses!.add(new Addresses.fromJson(v));
        });
      }
      final telephone = (json['custom_attributes'] as List?)?.firstWhere(
              (item) => item['attribute_code'] == "mobile",
          orElse: () => null);
      if (telephone != null) {
        phoneNumber = telephone["value"];
      }
      // `== true`, not a bare truthiness check: Magento OMITS default_billing
      // and default_shipping from any address that isn't the default, so those
      // keys are null rather than false. `null || null` threw a TypeError,
      // which the catch below swallowed — leaving `billing` null and, further
      // down the chain, checkout with no address at all. Order-dependent too:
      // it only threw when a non-default address came first in the list
      // (86d3r3gpd).
      final address = (json['addresses'] as List?)?.firstWhere(
          (item) =>
              item['default_billing'] == true ||
              item['default_shipping'] == true,
          orElse: () => null);
      if (address != null) {
        billing = Billing.fromMagentoJson(address);
        shipping = Shipping.fromMagentoJson(address);
      }


    } catch (e) {
      printLog(e.toString());
    }
  }

  // from Opencart Json
  User.fromOpencartJson(Map json, token) {
    try {
      loggedIn = true;
      id = (json['customer_id'] != null ? int.parse(json['customer_id']) : 0)
          .toString();
      name = json['firstname'] + ' ' + json['lastname'];
      username = '';
      cookie = token;
      firstName = json['firstname'];
      lastName = json['lastname'];
      email = json['email'];
      picture = '';
    } catch (e) {
      printLog(e.toString());
    }
  }

  // from Shopify json
  User.fromShopifyJson(Map json, token) {
    try {
      printLog('fromShopifyJson user $json');

      loggedIn = true;
      id = json['id'].toString();
      username = '';
      cookie = token;
      firstName = json['firstName'];
      lastName = json['lastName'];
      name = json['displayName'] ?? json['displayname'] ?? _getDisplayName;
      email = json['email'];
      picture = '';
    } catch (e) {
      printLog(e.toString());
    }
  }

  User.fromPrestaJson(Map json) {
    try {
      printLog('fromPresta user $json');

      loggedIn = true;
      id = json['id'].toString();
      name = json['firstname'] + ' ' + json['lastname'];
      username = json['email'];
      cookie = json['secure_key'];
      firstName = json['firstname'];
      lastName = json['lastname'];
      email = json['email'];
    } catch (e) {
      printLog(e.toString());
    }
  }

  User.fromStrapi(Map<String, dynamic> parsedJson) {
    debugPrint('User.fromStrapi $parsedJson');
    loggedIn = true;

    var model = SerializerUser.fromJson(parsedJson);
    id = model.user!.id.toString();
    jwtToken = model.jwt;
    email = model.user!.email;
    username = model.user!.username;
    nicename = model.user!.displayName;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loggedIn': loggedIn,
      'name': name,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'phoneNumber': phoneNumber,
      'email': email,
      'picture': picture,
      'cookie': cookie,
      'nicename': nicename,
      'url': userUrl,
      'isSocial': isSocial,
      'isVender': isVender,
      'billing': billing?.toJson(),
      'jwtToken': jwtToken,
      'addresses' : this.addresses?.map((v) => v.toJson()).toList(),
      'role': role
    };
  }

  User.fromLocalJson(Map json) {
    try {
      loggedIn = json['loggedIn'];
      id = json['id'].toString();
      name = json['name'];
      cookie = json['cookie'];
      username = json['username'];
      phoneNumber = json['phoneNumber'];
      firstName = json['firstName'];
      lastName = json['lastName'];
      email = json['email'];
      picture = json['picture'];
      nicename = json['nicename'];
      userUrl = json['url'];
      isSocial = json['isSocial'];
      isVender = json['isVender'];
      jwtToken = json['jwtToken'];
      if (json['addresses'] != null) {
        addresses = <Addresses>[];
        json['addresses'].forEach((v) {
          addresses!.add(new Addresses.fromJson(v));
        });
      }
      if (json['billing'] != null) {
        billing = Billing.fromJson(json['billing']);
      }
      role = json['role'];
    } catch (e) {
      printLog(e.toString());
    }
  }

  User.fromBigCommerce(Map json) {
    id = '${json['id']}';
    username = json['email'];
    email = username;

    final spaceNicename =
        json['first_name'] != null && json['last_name'] != null ? ' ' : '';
    nicename =
        '${json['first_name'] ?? ''}$spaceNicename${json['last_name'] ?? ''}';
    name = nicename;
    firstName = json['first_name'];
    lastName = json['last_name'];
  }

  User.fromNotion(Map json) {
    id = json['id'];
    final properties = json['properties'];
    username = NotionDataTools.fromRichText(properties['Email'])?.first;
    email = username;
    nicename = NotionDataTools.fromTitle(properties['Name']);
    name = nicename;
    firstName = NotionDataTools.fromRichText(properties['Firstname'])?.first;
    lastName = NotionDataTools.fromRichText(properties['Lastname'])?.first;
  }

  // from Create User
  User.fromAuthUser(Map json, String? cookieVal) {
    try {
      cookie = cookieVal;
      id = json['id'].toString();
      name = json['displayname'];
      username = json['username'];
      phoneNumber = json['phoneNumber'];
      firstName = json['firstname'];
      lastName = json['lastname'];
      email = json['email'];
      picture = json['avatar'];
      nicename = json['nicename'];
      userUrl = json['url'];
      loggedIn = true;
      var roles = [];
      if (json['role'] is Map) {
        roles = json['role'].values.toList();
      } else {
        roles = json['role'] as List;
      }

      isVender = false;
      if (roles.isNotEmpty) {
        role = roles.first;
        if (roles.contains('seller') ||
            roles.contains('wcfm_vendor') ||
            roles.contains('administrator') ||
            roles.contains('owner')) {
          isVender = true;
        }
        if (roles.contains('wcfm_delivery_boy') || roles.contains('driver')) {
          isDeliveryBoy = true;
        }
        isManager =
            roles.contains('shop_manager') || roles.contains('administrator');
      } else {
        isVender = (json['capabilities']['wcfm_vendor'] as bool?) ?? false;
      }
      if (json['dokan_enable_selling'] != null &&
          json['dokan_enable_selling'].trim().isNotEmpty) {
        isVender = json['dokan_enable_selling'] == 'yes';
      }
      if (json['addresses'] != null) {
        addresses = <Addresses>[];
        json['addresses'].forEach((v) {
          addresses!.add(new Addresses.fromJson(v));
        });
      }
      if (json['shipping'] != null) {
        shipping = Shipping.fromJson(json['shipping']);
      }
      if (json['billing'] != null) {
        billing = Billing.fromJson(json['billing']);
      }
      if (json['is_driver_available'] != null) {
        isDriverAvailable = json['is_driver_available'] == 'on' ||
            json['is_driver_available'] == true;
      }
    } catch (e) {
      printLog(e.toString());
    }
  }

  User.fromWordpressUser(Map json, String? cookieVal) {
    try {
      cookie = cookieVal;
      id = json['id'].toString();
      name = json['displayname'];
      username = json['username'];
      firstName = json['firstname'];
      lastName = json['lastname'];
      email = json['email'];
      picture = json['avatar'];
      nicename = json['nicename'];
      userUrl = json['url'];
      loggedIn = true;
      var roles = [];
      if (json['role'] is Map) {
        roles = json['role'].values.toList();
      } else {
        roles = json['role'] as List;
      }

      if (roles.isNotEmpty) {
        role = roles.first;
      }
    } catch (e) {
      printLog(e.toString());
    }
  }

  String get _getDisplayName =>
      '${firstName ?? ''}${(lastName?.isEmpty ?? true) ? '' : ' $lastName'}';

  Future<String> getIdToken([bool forceRefresh = false]) => Future.value('');

  @override
  String toString() => 'User { username: $id $name $email}';
}

class UserPoints {
  int? points;
  List<UserEvent> events = [];

  UserPoints.fromJson(Map json) {
    points = json['points_balance'];

    if (json['events'] != null) {
      for (var event in json['events']) {
        events.add(UserEvent.fromJson(event));
      }
    }
  }
}

class UserEvent {
  String? id;
  String? userId;
  String? orderId;
  String? date;
  String? description;
  String? points;

  UserEvent.fromJson(Map json) {
    id = json['id'];
    userId = json['user_id'];
    orderId = json['order_id'];
    date = json['date_display_human'];
    description = json['description'];
    points = json['points'];
  }
}

class Addresses {
  int? id;
  int? customerId;
  Region? region;
  int? regionId;
  String? countryId;
  List<String>? street;
  String? telephone;
  String? postcode;
  String? city;
  String? firstname;
  String? lastname;

  /// Whether this is the customer's default billing / shipping address.
  ///
  /// These have to be carried explicitly: saveUserInfo re-sends the customer's
  /// WHOLE address book on every add, edit and delete, so any flag missing from
  /// the payload is cleared by Magento. They were not modelled at all, which
  /// silently wiped the shopper's default address whenever they touched the
  /// address book — and with it, the checkout pre-fill.
  bool? defaultBilling;
  bool? defaultShipping;

  Addresses(
      {this.id,
        this.customerId,
        this.region,
        this.regionId,
        this.countryId,
        this.street,
        this.telephone,
        this.postcode,
        this.city,
        this.firstname,
        this.lastname,
        this.defaultBilling,
        this.defaultShipping});

  Addresses.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    customerId = json['customer_id'];
    region =
    json['region'] != null ? new Region.fromJson(json['region']) : null;
    regionId = json['region_id'];
    countryId = json['country_id'];
    street = json['street'].cast<String>();
    telephone = json['telephone'];
    postcode = json['postcode'];
    city = json['city'];
    firstname = json['firstname'];
    lastname = json['lastname'];
    // `== true`: Magento omits these keys entirely on non-default addresses,
    // so absence must read as false rather than null.
    defaultBilling = json['default_billing'] == true;
    defaultShipping = json['default_shipping'] == true;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['customer_id'] = this.customerId;
    // Emitted only when true, mirroring how Magento itself represents them.
    if (this.defaultBilling == true) data['default_billing'] = true;
    if (this.defaultShipping == true) data['default_shipping'] = true;
    if (this.region != null) {
      data['region'] = this.region!.toJson();
    }
    data['region_id'] = this.regionId;
    data['country_id'] = this.countryId;
    data['street'] = this.street;
    data['telephone'] = this.telephone;
    data['postcode'] = this.postcode;
    data['city'] = this.city;
    data['firstname'] = this.firstname;
    data['lastname'] = this.lastname;
    return data;
  }
}

class Region {
  String? regionCode;
  String? region;
  int? regionId;

  Region({this.regionCode, this.region, this.regionId});

  Region.fromJson(Map<String, dynamic> json) {
    regionCode = json['region_code'];
    region = json['region'];
    regionId = json['region_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['region_code'] = this.regionCode;
    data['region'] = this.region;
    data['region_id'] = this.regionId;
    return data;
  }
}