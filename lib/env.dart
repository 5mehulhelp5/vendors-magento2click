// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars final
Map<String, dynamic> environment = {
  "version": '2.2.0',
  //This code is specifying the location of a configuration file for an application.
  "appConfig": "lib/config/config_ar.json",

  /// ➡️ lib/common/config.dart
  "serverConfig": {
    "type": "magento",
    // Base URL for this build: the vendors.magento2.click Magento backend.
    // No trailing slash - MagentoHelper builds "$domain/eg-en/rest/V1/..." by
    // string concatenation, so a trailing slash yields a double slash.
    "url": "https://vendors.magento2.click",
    "accessToken": "jd7u3bu9g7ca1vgocv0dvpr77xof57jf",
    'blog': "https://mstore.io",
    //"https://magentoegypt.com/blog/ar/",
    //'https://magentoegypt.com/userguide/ug/%d9%85%d9%82%d8%af%d9%85%d8%a9-%d8%b9%d9%86-%d9%82%d8%a7%d8%a6%d9%85%d8%a9-%d8%a7%d9%84%d9%85%d8%a8%d9%8a%d8%b9%d8%a7%d8%aa-sales-menu-%d9%81%d9%89-%d9%85%d8%aa%d8%ac%d8%b1-%d9%85%d8%a7%d8%ac%d9%86%d8%aa%d9%88-2/',
    // Empty → login screen uses the app's native customer forgot-password flow
    // (wapplogin mobile-OTP, verified live on production). The old value pointed
    // at the STAGING Magento *admin* password-reset page (admin_dnx0xy), which
    // doesn't exist on production and isn't the customer flow anyway.
    "forgetPassword": ""
  },

  /// ➡️ lib/common/config/general.dart
  "defaultDarkTheme": false,
  "loginSMSConstants": {
    "countryCodeDefault": "EG",
    "dialCodeDefault": "+20",
    "nameDefault": "Egypt",
  },
  "storeIdentifier": {
    "disable": true,
    "android": "app.locafy.customer",
    "ios": "6811112359"
  },
  "advanceConfig": {
    //This code sets the default language to Arabic.
    "DefaultLanguage": "ar",
    "DetailedBlogLayout": "halfSizeImageType",
    "EnablePointReward": false,
    "hideOutOfStock": false,
    "EnableRating": true,
    "hideEmptyProductListRating": true,

    /// Enable search by SKU in search screen
    "EnableSkuSearch": true,

    /// Show stock Status on product List & Product Detail
    "showStockStatus": true,

    /// Gird count setting on Category screen
    "GridCount": 3,

    /// set isCaching to true if you have upload the config file to mstore-api
    /// set kIsResizeImage to true if you have finished running Re-generate image plugin
    /// ref: https://support.inspireui.com/help-center/articles/3/8/19/app-performance
    ///
    /// kIsResizeImage OFF for this backend, pending verification. ON makes
    /// ImageTools.formatImage request a -small/-medium/-large sibling, which
    /// 404s to a grey placeholder if the backend never ran the Re-generate
    /// Images plugin; OFF requests the original, which always exists. So OFF
    /// is the fail-safe default until vendors.magento2.click is checked, and
    /// the sibling locafy.magento2.click backend is known to have no variants.
    ///
    /// To confirm and flip this on: take any product image URL under /media/
    /// and request the same path with `-small` appended before the extension.
    /// If it returns 200 (not 404), set this to true for smaller payloads.
    "isCaching": false,
    "kIsResizeImage": false,

    /// Stripe payment only: set currencyCode and smallestUnitRate.
    /// All API requests expect amounts to be provided in a currency’s smallest unit.
    /// For example, to charge 10 USD, provide an amount value of 1000 (i.e., 1000 cents).
    /// Reference: https://stripe.com/docs/currencies#zero-decimal
    "DefaultCurrency": {
      "symbol": "EGP",
      "decimalDigits": 2,
      "symbolBeforeTheNumber": true,
      "currency": "EGP",//"Pound sterling",
      "currencyCode": "EGP",
      "smallestUnitRate": 100,
      /// 100 cents = 1 usd
    },
    "Currencies": [
      {
        "symbol": "\$",
        "decimalDigits": 2,
        "symbolBeforeTheNumber": true,
        "currency": "USD",
        "currencyCode": "usd",
        "smallestUnitRate": 100,
        /// 100 cents = 1 usd
      },
      {
        "symbol": "SAR",
        "decimalDigits": 2,
        "symbolBeforeTheNumber": false,
        "currency": "SAR",
        "currencyCode": "SAR",
      },
      {
        "symbol": "€",
        "decimalDigits": 2,
        "symbolBeforeTheNumber": true,
        "currency": "EUR",
        "currencyCode": "EUR",
      },
      {
        "symbol": "EGP",
        "decimalDigits": 2,
        "symbolBeforeTheNumber": true,
        "currency": "EGP",//"Pound sterling",
        "currencyCode": "EGP",
        "smallestUnitRate": 100,

        /// 100 pennies = 1 pound
      },
    ],

    /// Below config is used for Magento store
    "DefaultStoreViewCode": "",
    "EnableAttributesConfigurableProduct": ["color", "size"],
    "EnableAttributesLabelConfigurableProduct": ["color", "size"],

    /// if the woo commerce website supports multi languages
    /// set false if the website only have one language
    "isMultiLanguages": true,

    ///Review gets approved automatically on woocommerce admin without requiring administrator to approve.
    "EnableApprovedReview": false,

    /// Sync Cart from website and mobile
    "EnableSyncCartFromWebsite": false,
    "EnableSyncCartToWebsite": false,

    /// Disable shopping Cart due to Listing Users request
    "EnableShoppingCart": false,

    /// Enable firebase to support FCM, realtime chat for Fluxstore MV
    "EnableFirebase": true,

    /// ratio Product Image, default value is 1.2 = height / width
    "RatioProductImage": 1.2,

    /// Enable Coupon Code When checkout
    "EnableCouponCode": true,

    /// Enable to Show Coupon list.
    "ShowCouponList": true,

    /// Enable this will show all coupons in Coupon list.
    /// Disable will show only coupons which is restricted to the current user"s email.
    "ShowAllCoupons": true,

    /// Show expired coupons in Coupon list.
    "ShowExpiredCoupons": true,
    "AlwaysShowTabBar": false,

    /// Privacy Policies page ID. Accessible in the app via Settings > Privacy menu.
    "PrivacyPoliciesPageId": 25569,

    /// If page id null
    /// Privacy Policies page Url. Accessible in the app via Settings > Privacy menu.
    "PrivacyPoliciesPageUrl": "https://vendors.magento2.click/eg-en/privacy-policy-en",

    "SupportPageUrl": "https://support.inspireui.com/",

    "DownloadPageUrl": 'https://mstore.io/#download',

    "SocialConnectUrl": [
      {
        "name": "Facebook",
        "icon": "assets/icons/logins/facebook.png",
        "url": "https://www.facebook.com/inspireui"
      },
      {
        "name": "Instagram",
        "icon": "assets/icons/logins/instagram.png",
        "url": "https://www.instagram.com/inspireui9/"
      },
    ],

    /// The radius to get vendors in map view for Fluxstore MV
    "QueryRadiusDistance": 10, //km

    "AutoDetectLanguage": false,

    /// Enable new SMS Login
    "EnableNewSMSLogin": false,

    /// Enable bottom add to cart from product card view
    "EnableBottomAddToCart": true,

    "gdpr": {
      "showPrivacyPolicyFirstTime": false,
      "showDeleteAccount": true,
      "confirmCaptcha": "PERMANENTLY DELETE",
    },
  },
  "defaultDrawer": {
    "logo": "assets/images/logo.png",
    "background": null,
    "items": [
      {"type": "home", "show": true},
      {"type": "blog", "show": true},
      {"type": "categories", "show": true},
      {"type": "cart", "show": true},
      {"type": "profile", "show": true},
      {"type": "login", "show": true},
      {"type": "category", "show": true}
    ]
  },
  "defaultSettings": [
   // "products",
   // "chat",
  //  "wishlist",
  //  "addresshistory",
    "notifications",
 //   "language",
    "currencies",
    "darkTheme",
  //  "order",
    "point",
    "rating",
    "privacy",
    // "about"
  ],
  "loginSetting": {
    "IsRequiredLogin": false,
    "showAppleLogin": false,
    "showFacebook": false,
    "showSMSLogin": false,
    "showGoogleLogin": false,
    "showPhoneNumberWhenRegister": true,
    "requirePhoneNumberWhenRegister": true
  },
  "oneSignalKey": {
    "enable": false,
    "appID": "8b45b6db-7421-45e1-85aa-75e597f62714"
  },

  /// ➡️ lib/common/onboarding.dart
  "onBoardingData": [
    {
      'title': 'Welcome to AJStore',
      'image': 'assets/images/fogg-delivery-1.png',
      'desc': 'AJStore is on the way to serve you'
    },
    {
      'title': 'Connect Surrounding World',
      'image': 'assets/images/fogg-uploading-1.png',
      'desc':
          'See all things happening around you just by a click in your phone. Fast, convenient and clean.'
    },
    {
      'title': "Let's Get Started",
      'image': 'assets/images/fogg-order-completed.png',
      'desc': "Waiting no more, let's see what we get!"
    }
  ],

  /// ➡️ lib/common/advertise.dart
  "adConfig": {
    "enable": false,
    "facebookTestingId": "",
    "googleTestingId": [],
    "ads": [
      {
        "type": "banner",
        "provider": "google",
        "iosId": "ca-app-pub-3940256099942544/2934735716",
        "androidId": "ca-app-pub-3940256099942544/6300978111",
        "showOnScreens": ["home", "search"],
        "waitingTimeToDisplay": 2,
      },
      {
        "type": "banner",
        "provider": "google",
        "iosId": "ca-app-pub-2101182411274198/5418791562",
        "androidId": "ca-app-pub-2101182411274198/4052745095",

        /// "showOnScreens": ["home", "category", "product-detail"],
      },
      {
        "type": "interstitial",
        "provider": "google",
        "iosId": "ca-app-pub-3940256099942544/4411468910",
        "androidId": "ca-app-pub-3940256099942544/4411468910",
        "showOnScreens": ["profile"],
        "waitingTimeToDisplay": 5,
      },
      {
        "type": "reward",
        "provider": "google",
        "iosId": "ca-app-pub-3940256099942544/1712485313",
        "androidId": "ca-app-pub-3940256099942544/4411468910",
        "showOnScreens": ["cart"],

        /// "waitingTimeToDisplay": 8,
      },
      {
        "type": "banner",
        "provider": "facebook",
        "iosId": "IMG_16_9_APP_INSTALL#430258564493822_876131259906548",
        "androidId": "IMG_16_9_APP_INSTALL#430258564493822_489007588618919",
        "showOnScreens": ["home"],

        /// "waitingTimeToDisplay": 8,
      },
      {
        "type": "interstitial",
        "provider": "facebook",
        "iosId": "430258564493822_489092398610438",
        "androidId": "IMG_16_9_APP_INSTALL#430258564493822_489092398610438",

        /// "showOnScreens": ["profile"],
        /// "waitingTimeToDisplay": 8,
      },
    ]
  },

  /// ➡️ lib/common/dynamic_link.dart
  "firebaseDynamicLinkConfig": {
    "isEnabled": true,

    /// Domain is the domain name for your product.
    /// Let’s assume here that your product domain is “example.com”.
    /// Then you have to mention the domain name as : https://example.page.link.
    "uriPrefix": "https://fluxstoreinspireui.page.link",
    //The link your app will open
    "link": "https://mstore.io/",
    //----------* Android Setting *----------//
    "androidPackageName": "app.locafy.customer",
    "androidAppMinimumVersion": 1,
    //----------* iOS Setting *----------//
    "iOSBundleId": "app.locafy.customer",
    "iOSAppMinimumVersion": "1.0.1",
    "iOSAppStoreId": "6811112359"
  },

  /// ➡️ lib/common/languages.dart
  "languagesInfo": [
    {
      "name": "English",
      "icon": "assets/images/country/gb.png",
      "code": "en",
      "text": "English",
      "storeViewCode": ""
    },
    {
      "name": "Arabic",
      "icon": "assets/images/country/ar.png",
      "code": "ar",
      "text": "Arabic",
      "storeViewCode": "eg-ar"
    }
  ],
  "unsupportedLanguages": ['ku'],

  /// ➡️  lib/common/config/payments.dart
  "paymentConfig": {
    "DefaultCountryISOCode": "EG",

    "DefaultStateISOCode": "SG",

    /// Enable the Shipping option from Checkout, support for the Digital Download
    "EnableShipping": true,

    /// Enable the address shipping.
    /// Set false if use for the app like Download Digial Asset which is not required the shipping feature.
    "EnableAddress": true,

    /// Allow customers to add note when order
    "EnableCustomerNote": true,

    /// Allow customers to add address location link to order note
    "EnableAddressLocationNote": false,

    /// Allow both alphabetical and numerical characters in ZIP code
    "EnableAlphanumericZipCode": false,

    /// Enable the product review option
    "EnableReview": true,

    /// enable the google map picker from Billing Address
    "allowSearchingAddress": false,
    "GuestCheckout": true,

    /// Enable Payment option
    "EnableOnePageCheckout": false,
    "NativeOnePageCheckout": false,

    /// This config is same with checkout page slug in the website
    "CheckoutPageSlug": {"en": "checkout"},

    /// Enable Credit card payment (only available for Fluxstore Shopipfy)
    "EnableCreditCard": false,

    /// Enable update order status to processing after checkout by COD on woo commerce
    "UpdateOrderStatus": false,

    /// Show order notes in order history detail.
    "ShowOrderNotes": true,

    /// Show Refund and Cancel button on Order Detail
    "EnableRefundCancel": false
  },
  "payments": {
    "paypal": "assets/icons/payment/paypal.png",
    "stripe": "assets/icons/payment/stripe.png",
    "razorpay": "assets/icons/payment/razorpay.png",
    "tap": "assets/icons/payment/tap.png"
  },
  "stripeConfig": {
    "serverEndpoint": "https://stripe-server.vercel.app",
    "publishableKey": "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY",
    "enabled": true,
    "paymentMethodId": "stripe",
    "returnUrl": "fluxstore://inspireui.com",

    /// Enable this automatically captures funds when the customer authorizes the payment.
    /// Disable will Place a hold on the funds when the customer authorizes the payment,
    /// but don’t capture the funds until later. (Not all payment methods support this.)
    /// https://stripe.com/docs/payments/capture-later
    /// Default: false
    "enableManualCapture": false
  },
  "paypalConfig": {
    "clientId":
        "ASlpjFreiGp3gggRKo6YzXMyGM6-NwndBAQ707k6z3-WkSSMTPDfEFmNmky6dBX00lik8wKdToWiJj5w",
    "secret":
        "ECbFREri7NFj64FI_9WzS6A0Az2DqNLrVokBo0ZBu4enHZKMKOvX45v9Y1NBPKFr6QJv2KaSp5vk5A1G",
    "production": false,
    "paymentMethodId": "paypal",
    "enabled": true
  },
  "razorpayConfig": {
    "keyId": "rzp_test_SDo2WKBNQXDk5Y",
    "keySecret": "RrgfT3oxbJdaeHSzvuzaJRZf",
    "paymentMethodId": "razorpay",
    "enabled": true
  },
  "tapConfig": {
    "SecretKey": "sk_test_YOUR_TAP_SECRET_KEY",
    "paymentMethodId": "tap",
    "enabled": true
  },
  "mercadoPagoConfig": {
    "accessToken":
        "TEST-5726912977510261-102413-65873095dc5b0a877969b7f6ffcceee4-613803978",
    "production": false,
    "paymentMethodId": "woo-mercado-pago-basic",
    "enabled": true
  },
  "defaultCountryShipping": [],

  /// config for after shipping
  "afterShip": {
    "api": "e2e9bae8-ee39-46a9-a084-781d0139274f",
    "tracking_url": "https://fluxstore.aftership.com"
  },

  /// ➡️ lib/common/products.dart
  "productDetail": {
    "height": 0.4,
    "marginTop": 0,
    "safeArea": false,
    "showVideo": true,
    "showBrand": true,
    "showThumbnailAtLeast": 1,
    "layout": "simpleType",
    "borderRadius": 3.0,

    /// Show the full product image (letterboxed) instead of cropping it.
    "boxFit": "contain",

    /// Enable this to show selected image variant in the top banner.
    "ShowSelectedImageVariant": true,

    /// Enable this to add a white background to top banner for transparent product image.
    "ForceWhiteBackground": false,

    /// Auto select first attribute of variable product if there is no default attribute.
    "AutoSelectFirstAttribute": true,

    /// Enable this to show review in product description.
    "enableReview": true,
    "attributeImagesSize": 50.0,
    "showSku": true,
    "showStockQuantity": true,
    "showProductCategories": true,
    "showProductTags": true,
    "hideInvalidAttributes": false,

    /// Enable this to show a quantity selector in product list.
    "showQuantityInList": false,

    /// Increase this number if you have yellow layout overflow error in product list.
    /// Should check "RatioProductImage" before changing this number.
    "productListItemHeight": 125
  },
  "blogDetail": {
    'showComment': true,
    'showHeart': true,
    'showSharing': true,
    'showTextAdjustment': true,
    'enableAudioSupport': false,
  },
  "productVariantLayout": {
    "color": "color",
    "اللون": "color",
    "size": "box",
    "height": "option",
    "color-image": "image"
  },
  "productAddons": {
    /// Set the allowed file type for file upload.
    /// On iOS will open Photos app.
    "allowImageType": true,
    "allowVideoType": true,

    /// Enable to allow upload files other than image/video.
    /// On iOS will open Files app.
    "allowCustomType": true,

    /// Set allowed file extensions for custom type.
    /// Leave empty ("allowedCustomType": []) to support all extensions.
    "allowedCustomType": ["png", "pdf", "docx"],

    /// NOTE: WordPress might restrict some file types for security purpose.
    /// To allow it, you can add this line to wp-config.php:
    /// define('ALLOW_UNFILTERED_UPLOADS', true);
    /// - which is NOT recommended.
    /// Instead, try to use a plugin like https://wordpress.org/plugins/wp-extra-file-types
    /// to allow custom file types.

    /// Allow selecting multiple files for upload. Default: false.
    "allowMultiple": false,

    /// Set the file size limit (in MB) for upload. Recommended: <15MB.
    "fileUploadSizeLimit": 5.0
  },
  "cartDetail": {"minAllowTotalCartValue": 0, "maxAllowQuantity": 10},
  "productVariantLanguage": {
    "en": {
      "color": "Color",
      "size": "Size",
      "height": "Height",
      "color-image": "Color"
    },
    "ar": {
      "color": "اللون",
      "size": "بحجم",
      "height": "ارتفاع",
      "color-image": "اللون"
    },
    "vi": {
      "color": "Màu",
      "size": "Kích thước",
      "height": "Chiều Cao",
      "color-image": "Màu"
    }
  },

  /// Exclude this categories from the list
  "excludedCategory": 311,
  "saleOffProduct": {
    /// Show Count Down for product type SaleOff
    "ShowCountDown": true,
    "HideEmptySaleOffLayout": false,
    "Color": "#C7222B"
  },

  /// This is strict mode option to check the `visible` option from product variant
  /// https://tppr.me/4DJJs - default value is false
  "notStrictVisibleVariant": true,

  /// ➡️ lib/common/smartchat.dart
  "configChat": {
    "EnableSmartChat": true,
    "showOnScreens": ["profile"],
    "hideOnScreens": [],
  },

  /// config for the chat app
  /// config Whatapp: https://faq.whatsapp.com/en/iphone/23559013
  "smartChat": [
    {"app": "https://wa.me/201120002844", "iconData": "whatsapp"},
    {"app": "tel:201120002844", "iconData": "phone"},
    {"app": "sms://201120002844", "iconData": "sms"},
    {"app": "firebase", "iconData": "google"},
    {
      "app": "https://tawk.to/chat/5d830419c22bdd393bb69888/default",
      "iconData": "facebookMessenger"
    }
  ],
  "adminEmail": "admininspireui@gmail.com",
  "adminName": "InspireUI",

  /// ➡️ lib/common/vendor.dart
  "vendorConfig": {
    /// Show Register by Vendor
    "VendorRegister": true,

    /// Disable show shipping methods by vendor
    "DisableVendorShipping": false,

    /// Enable/Disable showing all vendor markers on Map screen
    "ShowAllVendorMarkers": true,

    /// Enable/Disable native store management
    "DisableNativeStoreManagement": false,

    /// Dokan Vendor Dashboard
    "dokan": "my-account?vendor_admin=true",
    "wcfm": "store-manager?vendor_admin=true"
  },

  "deliveryConfig": {
    "DisableDeliveryManagement": false,
  },

  //lib/common/loading.dart
  "loadingIcon": {"size": 30.0, "type": "fadingCube"}
};
