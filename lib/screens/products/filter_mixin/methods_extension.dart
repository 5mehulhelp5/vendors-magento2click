part of 'products_filter_mixin.dart';

extension ProductsFilterMixinMethodExtension on ProductsFilterMixin {
  @protected
  void onFilter({
    dynamic minPrice,
    dynamic maxPrice,
    dynamic categoryId,
    String? categoryName,
    String? tagId,
    dynamic listingLocationId,
    FilterSortBy? sortBy,
    String? search,
  }) {
    printLog('[onFilter] ♻️ Reload product list');
    onCloseFilter();
    filterSortBy = sortBy ?? filterSortBy;

    if (listingLocationId != null) {
      this.listingLocationId = listingLocationId;
    }

    if (minPrice == maxPrice && minPrice == 0) {
      this.minPrice = null;
      this.maxPrice = null;
    } else {
      this.minPrice = minPrice ?? this.minPrice;
      this.maxPrice = maxPrice ?? this.maxPrice;
    }

    if (tagId != null) {
      this.tagId = tagId;
    }

    if (search != null) {
      // An empty string means the user cleared the search box (e.g. via the
      // field's clear button) — treat it as "no search" so the title and
      // product list revert to the category being browsed instead of
      // getting stuck on the "Results" view.
      this.search = search.isEmpty ? null : search;
    }

    // set attribute
    if (filterAttrModel.selectedAttr != null &&
        filterAttrModel.indexSelectedAttr != -1 &&
        filterAttrModel.lstProductAttribute != null) {
      var selectedAttr = filterAttrModel.indexSelectedAttr <
              filterAttrModel.lstProductAttribute!.length
          ? filterAttrModel
              .lstProductAttribute![filterAttrModel.indexSelectedAttr]
          : null;
      attribute = selectedAttr?.slug;
    }

    /// Set category title, ID
    if (categoryId != null) {
      this.categoryId = categoryId;

      final selectedCategoryName = categoryModel.categories!
          .firstWhereOrNull((element) => element.id == categoryId.toString())
          ?.name;

      if (selectedCategoryName != null) {
        onCategorySelected(selectedCategoryName);
      }
    }

    /// reset paging and clean up product
    page = 1;
    clearProductList();

    getProductList();
    rebuild();
  }

  Future<void> onLoadMore() async {
    page++;
    await getProductList();
  }

  @protected
  String getAttributeTerm({bool showName = false}) {
    var terms = '';
    for (var i = 0; i < filterAttrModel.lstCurrentSelectedTerms.length; i++) {
      if (filterAttrModel.lstCurrentSelectedTerms[i]) {
        if (showName) {
          terms += '${filterAttrModel.lstCurrentAttr[i].name},';
        } else {
          terms += '${filterAttrModel.lstCurrentAttr[i].id},';
        }
      }
    }
    return terms.isNotEmpty ? terms.substring(0, terms.length - 1) : '';
  }

  Future<void> onRefresh() async {
    page = 1;
    rebuild();
    // Explicit pull-to-refresh must show live data, so bypass the short-TTL
    // catalog cache for this fetch.
    await getProductList(refresh: true);
  }

  void initFilter({ProductConfig? config}) {
    minPrice = null;
    maxPrice = null;
    page = 1;
    attribute = null;
    // Route an incoming search keyword (e.g. from a search-results
    // navigation) through the working name/SKU "like" filter. The backend's
    // full-text `q=` parameter (sent separately as `searchText`) 500s when
    // combined with searchCriteria filters, so it must not be relied on.
    search = config?.searchText;
    filterSortBy = const FilterSortBy();

    categoryId = config?.category;
    tagId = config?.tag;
    filterSortBy = filterSortBy
        .copyWith(
          onSale: config?.onSale,
          featured: config?.featured,
        )
        .copyWithString(
          orderBy: config?.orderby,
          order: config?.order,
        );
    listingLocationId = config?.jsonData?['location']?.toString();
    include = config?.include;
  }

  @protected
  void resetFilter() {
    filterAttrModel.resetFilter();
  }

  @protected
  void resetPrice() {
    minPrice = 0.0;
    maxPrice = 0.0;
  }

  @protected
  void resetTag() {
    tagId = null;
  }
}
