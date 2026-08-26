part of '../constants.dart';

/// check if the environment is web
final bool kIsWeb = UniversalPlatform.isWeb;
final bool isIos = UniversalPlatform.isIOS;
final bool isAndroid = UniversalPlatform.isAndroid;
final bool isMacOS = UniversalPlatform.isMacOS;
final bool isWindow = UniversalPlatform.isWindows;
final bool isMobile = UniversalPlatform.isIOS || UniversalPlatform.isAndroid;
final bool isDesktop = UniversalPlatform.isMacOS || UniversalPlatform.isWindows;

/// Host that serves catalog media (product/category images, banners).
///
/// Derived from the active server config (`serverConfig.url` in env.dart) so it
/// always matches the environment the app is pointed at — switch environments
/// in one place and media follows. Media is served under `/media/...` (NOT
/// `/pub/media/...`). Falls back to production if the config isn't loaded yet.
///
/// Note: an earlier build hardcoded `cdn.locafy.market`, which only
/// 302-redirects to production — so on any non-production environment the
/// catalog media 404'd. Deriving from the server URL avoids that class of bug.
String get kMediaDomain {
  final url = serverConfig['url'];
  return (url is String && url.isNotEmpty) ? url : 'https://vendors.magento2.click';
}

/// constant for Magento payment
const kMagentoPayments = [
  'HyperPay_Amex',
  'HyperPay_ApplePay',
  'HyperPay_Mada',
  'HyperPay_Master',
  'HyperPay_PayPal',
  'HyperPay_SadadNcb',
  'HyperPay_Visa',
  'HyperPay_SadadPayware'
];

/// The result is limited to 10 items (https://tppr.me/QYsm9) if `options` or `modifiers` is used in `include` field. Refer to this link https://developer.bigcommerce.com/api-reference/4101d472a814d-get-all-products. So we need to override apiPageSize to 10 instead
final apiPageSize = ServerConfig().isBigCommerce ? 100 : 100;

/// A home carousel renders a single horizontal rail, so fetching a full
/// [apiPageSize] page (100) to show a handful of items is pure waste. One-shot
/// (non-paginated) layout fetches cap at this instead. A section can still
/// override with its own `limit`, and paginated grids keep [apiPageSize].
const kHomeCarouselLimit = 10;

/// Page size for the paginated product grid (PLP / in-list search).
///
/// The PLP used to request a full [apiPageSize] (100) products for its FIRST
/// page — a heavy first load (large JSON parse + 100 cards + 100 image fetches)
/// that kept the grid on a spinner far longer than needed. It paginates on
/// scroll (`currentPage`; the end is detected when a page comes back empty,
/// independent of page size), and the header count comes from the API's real
/// `total_count`, so a smaller page paints much sooner and the rest streams in
/// as the user scrolls — with no effect on the displayed total. Tune here.
const kProductListPerPage = 20;


const kSizeLeftMenu = 250.0;

class SettingConstants {
  static const aboutUsUrl = 'https://www.magentoegypt.com/';
}

class SplashScreenTypeConstants {
  static const fadeIn = 'fade-in';
  static const zoomIn = 'zoom-in';
  static const zoomOut = 'zoom-out';
  static const topDown = 'top-down';
  static const rive = 'rive';
  static const flare = 'flare';
  static const static = 'static';
  static const lottie = 'lottie';
}

/// FluxNews
//Legit roles to access post management at Setting screens.
const addPostAccessibleRoles = ['author', 'administrator'];

const kEmptyCategoryID = '-1';

const isrgRootX1 = '''-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
''';
