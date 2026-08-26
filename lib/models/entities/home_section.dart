/// Models for `GET mstore/homepage-sections` — the backend-curated home /
/// main-category sections (86d3f2jb6). The response is a list of groups, each
/// a list of section objects sharing a `type` (banner / category / brands).
class HomeBrand {
  final int? id;
  final String? name;
  final String? logoUrl;
  final String? shopUrl;

  HomeBrand.fromJson(Map json)
      : id = json['id'] is int
            ? json['id']
            : int.tryParse('${json['id']}'),
        name = json['name']?.toString(),
        logoUrl = json['logo_url']?.toString(),
        shopUrl = json['shop_url']?.toString();
}

class HomeSection {
  /// `banner` | `category` | `brands`.
  final String type;
  final String? identifier;
  final String? title;
  final String? subtitle;
  final String? content;
  final String? imageUrl;
  final String? buttonLabel;
  final String? buttonUrl;

  /// In-app category id the CTA opens (preferred over [buttonUrl] for
  /// navigation).
  final String? buttonCategoryId;

  /// Only populated for `brands` sections.
  final List<HomeBrand> brands;

  HomeSection.fromJson(Map json)
      : type = json['type']?.toString() ?? '',
        identifier = json['identifier']?.toString(),
        title = json['title']?.toString(),
        subtitle = json['subtitle']?.toString(),
        content = json['content']?.toString(),
        imageUrl = (json['image_url']?.toString().isEmpty ?? true)
            ? null
            : json['image_url'].toString(),
        buttonLabel = json['button_label']?.toString(),
        buttonUrl = json['button_url']?.toString(),
        buttonCategoryId = json['button_category_id'] == null
            ? null
            : '${json['button_category_id']}',
        brands = ((json['brands'] as List?) ?? const [])
            .whereType<Map>()
            .map(HomeBrand.fromJson)
            .toList();

  bool get isBanner => type == 'banner';
  bool get isCategory => type == 'category';
  bool get isBrands => type == 'brands';

  /// Parse the `[{ "banner":[…], "category":[…], "brands":[…] }]` response
  /// into a flat, render-ordered list (banner -> category -> brands). Each
  /// section carries its own `type`, so callers can re-group as needed.
  static List<HomeSection> parseResponse(dynamic data) {
    final result = <HomeSection>[];
    Map? root;
    if (data is List && data.isNotEmpty && data.first is Map) {
      root = data.first as Map;
    } else if (data is Map) {
      root = data;
    }
    if (root == null) return result;
    for (final key in const ['banner', 'category', 'brands']) {
      final group = root[key];
      if (group is List) {
        for (final section in group) {
          if (section is Map) result.add(HomeSection.fromJson(section));
        }
      }
    }
    return result;
  }
}
