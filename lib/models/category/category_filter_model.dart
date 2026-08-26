// `Category` here is the app's catalog entity — hide Flutter's unrelated
// `Category` annotation so the entity import wins.
import 'package:flutter/foundation.dart' hide Category;

import '../../frameworks/magento/services/magento_service.dart';
import '../../services/index.dart';
import '../entities/category.dart';
import '../entities/category_filter.dart';

/// Web-parity layered-navigation filters for the product-listing (category)
/// page: the available attribute options + counts fetched from the storefront
/// GraphQL `aggregations`, plus the shopper's current selection.
///
/// Selection is keyed by `attribute_code` → set of selected option ids. The
/// product query applies these as extra REST `searchCriteria[filter_groups]`
/// (one group per attribute — values OR'd within an attribute, attributes
/// AND'd across each other), exactly mirroring Magento layered navigation and
/// the website. See docs/qa-followups.md item 3.
class CategoryFilterModel extends ChangeNotifier {
  List<CategoryFilterAttribute> _attributes = const [];
  List<CategoryFilterAttribute> get attributes => _attributes;

  /// attribute_code -> selected option ids.
  final Map<String, Set<String>> _selected = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// The category the currently-held [attributes]/selection belong to, so the
  /// selection can be reset when the shopper navigates to a different one.
  String? _categoryId;

  bool get hasSelection => _selected.values.any((s) => s.isNotEmpty);

  /// Magento level of [id] within [categories], using the numbering from the
  /// admin and the ticket: **L2** = main category (Kidswear, 192), **L3** =
  /// subcategory (Boys, 270), **L4** = sub-subcategory (Shoes, 286). Returns 0
  /// when the id isn't in the tree (brand pages, search results).
  ///
  /// `MagentoService.getCategories` stores main categories with `parent == '0'`
  /// and never adds Magento's two root levels to the app's tree, so a top-level
  /// category walks to depth 1 — hence the `+ 1` to land back on Magento's
  /// numbering.
  static int levelOf(Map<String?, Category> categories, String? id) {
    if (id == null) return 0;
    var depth = 0;
    var current = categories[id];
    // Bounded so a malformed parent cycle can't spin here.
    while (current != null && depth < 10) {
      depth++;
      final parent = current.parent;
      if (parent == null || parent == '0') break;
      current = categories[parent];
    }
    return depth == 0 ? 0 : depth + 1;
  }

  /// Whether [id] should show the website's trimmed filter list. Must be used
  /// by *every* caller of [load] — the sheet reloads filters when it opens, so
  /// a caller that omits it silently overwrites the trimmed set with the full
  /// one. See ClickUp 86d3g3mea item 3.
  static bool webParityFor(Map<String?, Category> categories, String? id) {
    final level = levelOf(categories, id);
    return level == 2 || level == 3;
  }

  int get selectedCount =>
      _selected.values.fold(0, (sum, s) => sum + s.length);

  bool isSelected(String code, String value) =>
      _selected[code]?.contains(value) ?? false;

  /// Selected filters as `attribute_code` -> option ids, with empty
  /// attributes dropped. Consumed by the product query to build REST filter
  /// groups.
  Map<String, List<String>> get selectedFilters => {
        for (final entry in _selected.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
      };

  /// All currently-selected options flattened, for rendering removable chips
  /// in the listing toolbar.
  List<CategoryFilterOption> get selectedOptions => [
        for (final attr in _attributes)
          for (final opt in attr.options)
            if (isSelected(opt.code, opt.value)) opt,
      ];

  /// Load the available filters for [categoryId]. When the category changes,
  /// any prior selection is cleared synchronously (filters are
  /// category-scoped) so a stale selection can never leak onto a new
  /// category's product query. Safe to call without awaiting.
  ///
  /// [webParityOnly] trims the panel to the attributes the website shows on a
  /// subcategory page (Brand, Colour) — passed for level 2/3 categories. See
  /// [MagentoService.fetchCategoryFilters].
  Future<void> load(
    String? categoryId,
    String lang, {
    bool webParityOnly = false,
  }) async {
    final api = Services().api;
    if (api is! MagentoService || categoryId == null) {
      _selected.clear();
      _attributes = const [];
      _categoryId = categoryId;
      notifyListeners();
      return;
    }

    if (categoryId != _categoryId) {
      _selected.clear();
      _attributes = const [];
    }
    _categoryId = categoryId;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await api.fetchCategoryFilters(
        categoryId: categoryId,
        lang: lang,
        webParityOnly: webParityOnly,
      );
      // Guard against a stale response arriving after the shopper moved on.
      if (categoryId == _categoryId) {
        _attributes = result;
      }
    } catch (_) {
      if (categoryId == _categoryId) _attributes = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggle(String code, String value) {
    final set = _selected.putIfAbsent(code, () => <String>{});
    if (!set.remove(value)) set.add(value);
    if (set.isEmpty) _selected.remove(code);
    notifyListeners();
  }

  void clearAll() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
