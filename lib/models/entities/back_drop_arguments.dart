class BackDropArguments {
  final dynamic cateId;
  final String? cateName;
  final String? tag;
  final List? data;
  final Map? config;
  final String? brandId;
  final String? brandName;
  final String? brandImg;
  final String? searchText;
  final bool showCountdown;

  /// When set, the products page shows a horizontal strip of the *sibling*
  /// subcategories (the other children of this category id) so the user can
  /// switch between the "remaining subcategories of the main category" in
  /// place — the web-style category page. Set only on the home-banner →
  /// subcategory flow (see [SubcategoryScreen]); left null for Search and
  /// direct category taps, which keep the child-category strip / flat list
  /// (ClickUp 86d3g3mea item 1).
  final String? siblingParentId;

  /// Suppresses the category's description card on the products page. Set by
  /// the Search screen: browsing the category menu there is navigation, so a
  /// category opened from it goes straight to the products. Reached any other
  /// way — a home banner, a landing page, a link in the copy — the page shows
  /// the description like the website does.
  final bool hideDescription;
  Duration countdownDuration = Duration.zero;

  BackDropArguments({
    this.cateId,
    this.cateName,
    this.tag,
    this.data,
    this.config,
    this.brandId,
    this.brandName,
    this.brandImg,
    this.searchText,
    this.showCountdown = false,
    this.siblingParentId,
    this.hideDescription = false,
    this.countdownDuration = Duration.zero,
  });
}
