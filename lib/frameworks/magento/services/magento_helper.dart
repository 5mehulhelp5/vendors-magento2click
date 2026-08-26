import 'package:inspireui/inspireui.dart';
import '../../../common/config.dart';
import '../../../common/constants.dart';

class MagentoHelper {
  /// Rewrites a stored phone number into the local form Magento's Egyptian
  /// validator accepts — `01020104267`, the shape its own error message gives
  /// as the example ("Please enter a valid mobile number for Egypt (for
  /// example 01012345678)").
  ///
  /// The address form's phone widget hands back the dial code joined to the
  /// national number (`+201020104267`), and nothing between there and the API
  /// converted it, so `customers/me` rejected the save (86d3rrpqr). Because
  /// that PUT re-sends the *whole* address book, a single address in the wrong
  /// shape failed adding, editing and deleting alike — so this is applied to
  /// every address in the payload, not just the one being edited.
  ///
  /// Deliberately NOT used by [Address.toMagentoJson]: checkout posts the same
  /// `+20…` value and Magento accepts it there, so that path is left alone.
  ///
  /// Anything that is not a recognisable local number is returned unchanged
  /// rather than guessed at — this normalises formatting, it does not repair
  /// bad data.
  static String? normalizePhoneForMagento(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return phone;

    final dial =
        kPhoneNumberConfig.dialCodeDefault.replaceAll(RegExp(r'[^0-9]'), '');

    var national = digits;
    // Only strip the dial code when what remains can still be a full national
    // number, so a 10-digit number that merely happens to start with "20" is
    // left intact.
    if (dial.isNotEmpty &&
        national.length > 10 &&
        national.startsWith(dial)) {
      national = national.substring(dial.length);
    }

    if (national.length == 10 && !national.startsWith('0')) {
      return '0$national';
    }
    // Already local (0 + 10 digits) — hand it back untouched.
    if (national.length == 11 && national.startsWith('0')) {
      return national;
    }
    return phone;
  }

  /// The 10-digit Egyptian national number, with the dial code (`+20` / `20`)
  /// and the local leading `0` removed. `+201147375697`, `201147375697`,
  /// `01147375697` and `1147375697` all collapse to `1147375697` — the same
  /// subscriber. The checkout phone check uses this so a saved or pasted number
  /// in any of those forms isn't falsely rejected as "10 digits, no leading 0"
  /// (86d3tmxra) — a saved address stores the local `0…` form, the widget hands
  /// back the `+20…` form. Returns the bare digits for anything it can't map;
  /// callers still length-check.
  static String egyptianNationalNumber(String? phone) {
    var digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final dial =
        kPhoneNumberConfig.dialCodeDefault.replaceAll(RegExp(r'[^0-9]'), '');
    // Strip the dial code only when what's left is still a full national
    // number, so a 10-digit number that merely starts with "20" is kept whole.
    if (dial.isNotEmpty && digits.length > 10 && digits.startsWith(dial)) {
      digits = digits.substring(dial.length);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String? getCustomAttribute(customAttributes, attribute) {
    String? value;
    if (customAttributes != null && customAttributes.length > 0) {
      for (var item in customAttributes) {
        if (item['attribute_code'] == attribute) {
          value = item['value'];
          break;
        }
      }
    }
    return value;
  }

  /// The gallery entries of a product, ordered the way the storefront orders
  /// them: the image carrying the `image`/`small_image`/`thumbnail` role first,
  /// then everything else by `position`.
  ///
  /// Magento does not return the gallery role-first, and the roles are what
  /// decide which photo represents the product — `media_gallery_entries[0]` is
  /// simply whichever row came back first. On this catalogue those disagree:
  /// "test image product" carries a stray logo at position 1 with `types: []`
  /// and its real photo at position 2 with all four roles, so the app showed
  /// the logo on every grid while the website and the search suggestions —
  /// both of which read the role — showed the photo (86d3x5ex6).
  ///
  /// Returns the raw `file` paths; callers turn them into URLs.
  static List<String> orderedGalleryFiles(dynamic entries) {
    if (entries is! List) return const [];
    final rows = <Map>[];
    for (final entry in entries) {
      if (entry is Map && entry['file'] != null) rows.add(entry);
    }
    if (rows.isEmpty) return const [];

    int position(Map row) {
      final raw = row['position'];
      return raw is int ? raw : int.tryParse('$raw') ?? 1 << 30;
    }

    bool hasRole(Map row) {
      final types = row['types'];
      if (types is! List) return false;
      return types.any((t) =>
          t == 'image' || t == 'small_image' || t == 'thumbnail');
    }

    rows.sort((a, b) => position(a).compareTo(position(b)));
    // A stable partition rather than a sort key, so the roled image wins
    // outright and everything else keeps catalogue order.
    final roled = rows.where(hasRole).toList();
    final rest = rows.where((r) => !hasRole(r)).toList();
    return [...roled, ...rest].map((r) => '${r['file']}').toList();
  }

  static String getProductImageUrlByName(domain, imageName) {
    // Media is served by the CDN (kMediaDomain), not the API domain, because
    // staging has no media files. Same host is used for live and staging.
    return '$kMediaDomain/media/catalog/product$imageName';
  }

  static String getProductImageUrl(domain, item, [attribute = 'thumbnail']) {
    final imageName = getCustomAttribute(item['custom_attributes'], attribute);
    if (imageName != null) {
      return imageName.contains('http')
          ? imageName
          : getProductImageUrlByName(domain, imageName);
    } else {
      return '';
    }
  }

  static String getCategoryImageUrl(domain, item, [attribute = 'image']) {
    final imageName = getCustomAttribute(item['custom_attributes'], attribute);
    if (imageName != null) {
      return '$kMediaDomain/media/catalog/category/$imageName';
    }
    return '';
  }

  static String? getErrorMessage(body) {
    String? message = body['message'];
    if (body['parameters'] != null && body['parameters'].length > 0) {
      final params = body['parameters'];
      final keys = params is List ? params : params.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        if (params is List) {
          message = message!.replaceAll('%${i + 1}', keys[i].toString());
        } else {
          message =
              message!.replaceAll('%${keys[i]}', params[keys[i]].toString());
        }
      }
    }
    return message;
  }

  static Uri? buildWithoutRestUrl(String? domain, String endpoint, [String? locale]) {
    final languages = getLanguages();
    // if (isNotBlank(locale)) {
    //   var language = languages.firstWhereOrNull(
    //       (o) => o['code'] == locale && isNotBlank(o['storeViewCode']));
    //   if (language != null) {
    //     return "$domain/${language["storeViewCode"]}/rest/V1/$endpoint" //"$domain/index.php/rest/${language["storeViewCode"]}/V1/$endpoint"
    //         .toUri();
    //   }
    // }
    return '$domain/eg-en/$endpoint'.toUri();
    //'$domain/${SettingsBox().languageCode}/rest/V1/$endpoint'.toUri();
    // '$domain/index.php/rest/V1/$endpoint'.toUri();
  }

  static Uri? buildUrl(String? domain, String endpoint, [String? locale]) {
    return '$domain/${_storeViewCode(locale)}/rest/V1/$endpoint'.toUri();
  }

  /// Public storefront URL (no /rest/V1) on the store view matching [locale] —
  /// e.g. `https://…/eg-ar/<url_key>.html`. Used for shareable product links,
  /// which must open the website rather than the API.
  ///
  /// Unlike [buildWithoutRestUrl], which is pinned to eg-en, this honours the
  /// app language so a link shared from the Arabic app opens the Arabic page.
  static String storefrontUrl(String? domain, String path, [String? locale]) {
    return '$domain/${_storeViewCode(locale)}/$path';
  }

  /// Store-view path segment for a REST call. Content endpoints pass the
  /// current app language so the API returns localized (e.g. Arabic) text;
  /// calls that pass no locale (customer / cart / checkout) stay on the
  /// default English store view, whose REST config is known-good.
  ///
  /// Reads `storeViewCode` from the language config (env `languagesInfo`):
  /// en -> "" -> falls back to eg-en; ar -> eg-ar. Anything unmapped/blank
  /// falls back to eg-en.
  static String _storeViewCode(String? locale) {
    const fallback = 'eg-en';
    if (locale == null || locale.isEmpty) return fallback;
    for (final lang in getLanguages()) {
      if (lang['code'] == locale) {
        final code = lang['storeViewCode'];
        return (code is String && code.isNotEmpty) ? code : fallback;
      }
    }
    return fallback;
  }

  static bool isEndLoadMore(body) {
    int totalCount = body['total_count'];
    int pageSize = body['search_criteria']['page_size'];
    int currentPage = body['search_criteria']['current_page'];
    var maxPage = (totalCount / pageSize).ceil();
    return currentPage > maxPage;
  }
}
