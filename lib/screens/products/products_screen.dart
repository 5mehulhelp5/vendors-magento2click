import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart'
    show
        AppModel,
        CategoryFilterModel,
        CategoryModel,
        FilterAttributeModel,
        Product,
        ProductModel,
        TagModel,
        UserModel;
import '../../modules/dynamic_layout/helper/countdown_timer.dart';
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../modules/dynamic_layout/index.dart';
import '../../services/index.dart';
import '../../widgets/asymmetric/asymmetric_view.dart';
import '../../widgets/backdrop/backdrop.dart';
import '../../widgets/backdrop/backdrop_menu.dart';
import '../../widgets/product/product_bottom_sheet.dart';
import '../../widgets/product/product_list.dart';
import '../common/app_bar_mixin.dart';
import 'filter_mixin/products_filter_mixin.dart';
import 'products_backdrop.dart';
import 'products_flatview.dart';
import 'products_mixin.dart';
import 'widgets/category_description.dart';
import 'widgets/category_menu.dart';

class ProductsScreen extends StatefulWidget {
  final List<Product>? products;
  final ProductConfig? config;
  final Duration countdownDuration;
  final String? listingLocation;
  final bool enableSearchHistory;
  final String? routeName;
  final bool autoFocusSearch;

  /// When set, the category strip lists this parent's children — the current
  /// category's *siblings* — instead of the current category's own children,
  /// so a leaf subcategory page opened from a home banner still shows the
  /// "remaining subcategories" to switch between (ClickUp 86d3g3mea item 1).
  /// Null for Search and direct category taps, which keep the child strip.
  final String? siblingParentId;

  /// Hides the category description card. Set when the page is opened from
  /// the Search screen's category menu, where browsing straight to the
  /// products is the point.
  final bool hideDescription;

  const ProductsScreen({
    super.key,
    this.products,
    this.countdownDuration = Duration.zero,
    this.listingLocation,
    this.config,
    this.enableSearchHistory = false,
    this.routeName,
    this.autoFocusSearch = true,
    this.siblingParentId,
    this.hideDescription = false,
  });

  @override
  State<StatefulWidget> createState() {
    return ProductsScreenState();
  }
}

class ProductsScreenState extends State<ProductsScreen>
    with
        SingleTickerProviderStateMixin,
        AppBarMixin,
        ProductsMixin,
        ProductsFilterMixin {
  late AnimationController _controller;

  bool get hasAppBar => showAppBar(widget.routeName ?? RouteList.backdrop);

  ProductConfig get productConfig => widget.config ?? ProductConfig.empty();

  @override
  bool get enableSearchHistory => widget.enableSearchHistory;

  @override
  CategoryModel get categoryModel =>
      Provider.of<CategoryModel>(context, listen: false);

  TagModel get tagModel => Provider.of<TagModel>(context);

  ProductModel get productModel =>
      Provider.of<ProductModel>(context, listen: false);

  CategoryFilterModel get categoryFilterModel =>
      Provider.of<CategoryFilterModel>(context, listen: false);

  @override
  FilterAttributeModel get filterAttrModel =>
      Provider.of<FilterAttributeModel>(context, listen: false);

  UserModel get userModel => Provider.of<UserModel>(context, listen: false);

  AppModel get appModel => Provider.of<AppModel>(context, listen: false);

  /// Image ratio from Product Cart
  double get ratioProductImage => appModel.ratioProductImage;

  double get productListItemHeight => kProductDetail.productListItemHeight;

  bool get enableProductBackdrop => kAdvanceConfig.enableProductBackdrop;

  bool get showBottomCornerCart => kAdvanceConfig.showBottomCornerCart;

  List<Product>? products = [];
  String? errMsg;

  String _currentTitle = '';

  String get currentTitle =>
      search != null ? S.of(context).results : _currentTitle;

  /// "202 items" beside the title — empty while the count for *this* category
  /// is still unknown. The product model is shared between product pages, so
  /// a number shown before the fetch lands is the previous category's.
  String productCountLabel(ProductModel model) {
    final count = model.totalCount ??
        (model.isFetching ? null : model.productsList?.length);
    return count == null ? '' : '$count ${S.of(context).items}';
  }

  @override
  void initState() {
    super.initState();
    initFilter(config: productConfig);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0,
    );

    /// only request to server if there is empty config params
    // / If there is config, load the products one
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        resetFilter();
        // Load the web-parity attribute filters for this category. Called
        // before onRefresh: load() synchronously clears any selection held
        // from a previously-browsed category, so getProductList never applies
        // a stale filter to this category's list.
        loadCategoryFilters();
        onRefresh();
      }
    });
  }

  /// (Re)load the layered-navigation filters for the current category. L2/L3
  /// (main category and subcategory) get the website's trimmed list — Brand
  /// and Colour, alongside the category tree and price slider already in the
  /// panel. L4 and deeper keep every aggregation. See ClickUp 86d3g3mea item 3.
  void loadCategoryFilters() {
    final categories =
        Provider.of<CategoryModel>(context, listen: false).categoryList;
    categoryFilterModel.load(
      categoryId,
      appModel.langCode,
      webParityOnly: CategoryFilterModel.webParityFor(
          categories, categoryId == null ? null : '$categoryId'),
    );
  }

  @override
  void clearProductList() {
    productModel.setProductsList([]);
  }

  @override
  Future<void> getProductList({bool refresh = false}) async {
    await productModel.getProductsList(
      refresh: refresh,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      page: page,
      lang: appModel.langCode,
      orderBy: filterSortBy.orderByType?.name,
      order: filterSortBy.orderType?.name,
      featured: filterSortBy.featured,
      onSale: filterSortBy.onSale,
      tagId: tagId,
      attribute: attribute,
      attributeTerm: getAttributeTerm(),
      userId: userModel.user?.id,
      listingLocation: listingLocationId,
      include: include,
      search: search,
      attributeFilters: categoryFilterModel.selectedFilters,
    );
  }

  ProductBackdrop backdrop({
    products,
    isFetching,
    errMsg,
    isEnd,
    width,
    required String layout,
  }) {
    return ProductBackdrop(
      backdrop: Backdrop(
        hasAppBar: hasAppBar,
        bgColor: productConfig.backgroundColor,
        frontLayer: layout.isListView
            ? ProductList(
                products: products,
                onRefresh: onRefresh,
                onLoadMore: onLoadMore,
                isFetching: isFetching,
                errMsg: errMsg,
                isEnd: isEnd,
                layout: layout,
                ratioProductImage: ratioProductImage,
                productListItemHeight: productListItemHeight,
                width: width,
              )
            : AsymmetricView(
                products: products,
                isFetching: isFetching,
                isEnd: isEnd,
                onLoadMore: onLoadMore,
                width: width),
        backLayer: BackdropMenu(
          onFilter: onFilter,
          categoryId: categoryId,
          tagId: tagId,
          sortBy: filterSortBy,
          listingLocationId: listingLocationId,
        ),
        frontTitle: productConfig.showCountDown
            ? Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentTitle),
                      CountDownTimer(widget.countdownDuration)
                    ],
                  ),
                ],
              )
            : Text(currentTitle),
        backTitle: Text(S.of(context).filter),
        controller: _controller,
        appbarCategory: ProductCategoryMenu(
          enableSearchHistory: widget.enableSearchHistory,
          newCategoryId: categoryId,
          siblingParentId: widget.siblingParentId,
          onTap: (categoryId, categoryName) {
            include = null;
            // Switching subcategory from the tab strip changes the category in
            // place without re-routing, so the panel has to be reloaded here
            // too — otherwise it keeps the previous category's options and
            // (via the model's own category guard) its selection, which would
            // then be applied to the new category's product query.
            this.categoryId = categoryId;
            loadCategoryFilters();
            onFilter(categoryId: categoryId);
          },
        ),
        onTapShareButton: () async {
          await shareProductsLink(context);
        },
      ),
      // expandingBottomSheet: (Services().widget.enableShoppingCart(null) &&
      //         !ServerConfig().isListingType &&
      //         kAdvanceConfig.showBottomCornerCart)
      //     ? ExpandingBottomSheet(hideController: _controller)
      //     : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    _currentTitle = productConfig.name ??
        productModel.categoryName ??
        S.of(context).results;

    Widget buildMain = LayoutBuilder(
      builder: (context, constraint) {
        return FractionallySizedBox(
          widthFactor: 1.0,
          child: Selector<AppModel, String>(
            selector: (context, provider) => provider.productListLayout,
            builder: (context, productListLayout, child) {
              /// override the layout to listTile if enableSearchUX
              /// otherwise, using default productListLayout from the Config
              var layout = widget.enableSearchHistory
                  ? Layout.simpleList
                  : productListLayout;

              return ListenableProvider.value(
                value: productModel,
                child: Consumer<ProductModel>(
                  builder: (context, model, child) {
                    var backdropLayout = enableProductBackdrop;

                    if (!backdropLayout) {
                      var currentCategory =
                          categoryModel.categoryList[productModel.categoryId];

                      return ProductFlatView(
                        hasAppBar: hasAppBar,
                        autoFocusSearch: widget.autoFocusSearch,
                        enableSearchHistory: widget.enableSearchHistory,
                        currentTitle: currentTitle,
                        // Blank until this category's own count is known —
                        // "0 items" beside a loading grid reads as an empty
                        // category.
                        productCount: productCountLabel(model),
                        builder: layout.isListView
                            ? Consumer<CategoryFilterModel>(
                                builder: (context, filterModel, _) =>
                                    ProductList(
                                products: model.productsList,
                                onRefresh: onRefresh,
                                onLoadMore: onLoadMore,
                                isFetching: model.isFetching,
                                errMsg: model.errMsg,
                                isEnd: model.isEnd,
                                layout: layout,
                                ratioProductImage: ratioProductImage,
                                productListItemHeight: productListItemHeight,
                                width: constraint.maxWidth,
                                // The "Filter" trigger now sits beside the
                                // search box (see filterButton below); this
                                // header keeps only the active-filter chips.
                                //
                                // Null when nothing is filtered: ProductList
                                // turns a non-null appbar into a *pinned*
                                // SliverAppBar with a fixed 44px toolbarHeight,
                                // so passing a widget whose child collapses to
                                // SizedBox.shrink still left an empty band
                                // between the search box and the products.
                                appbar: hasActiveFilters(filterModel)
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: renderActiveFilters(context),
                                      )
                                    : null,
                                header: [
                                  // The website's category page lists the
                                  // category's OWN child categories (Boys ->
                                  // Outwear / Homewear / …). This row used to
                                  // show the current category's *siblings*,
                                  // which read as "the remaining subcategories
                                  // of the main category" and was disabled
                                  // outright; ProductCategoryMenu now lists the
                                  // children and hides itself on a leaf
                                  // category (86d3g3mea / 86d3g43qr).
                                  ProductCategoryMenu(
                                    imageLayout: true,
                                    isComingFrom: "product_screen",
                                    enableSearchHistory:
                                        widget.enableSearchHistory,
                                    newCategoryId: categoryId,
                                    // Banner→subcategory flow lists siblings
                                    // (the parent's other children) to switch
                                    // between; null elsewhere keeps children.
                                    siblingParentId: widget.siblingParentId,
                                    onTap: (categoryId, categoryName) {
                                      include = null;
                                      // Same in-place category switch as the
                                      // backdrop layout: reload the panel for
                                      // the new category before onFilter fires
                                      // getProductList, or the previous
                                      // category's selection is applied to it
                                      // (86d3g3mea item 3).
                                      this.categoryId = categoryId;
                                      loadCategoryFilters();
                                      onFilter(categoryId: categoryId);
                                    },
                                  ),
                                  // The category's own SEO copy, which the
                                  // website shows right under the category
                                  // title. Collapses to nothing on a category
                                  // that has none, and is skipped outright
                                  // when the page came from the Search menu.
                                  if (!widget.hideDescription)
                                    CategoryDescription(categoryId: categoryId),
                                  // Only render the header block when there's
                                  // countdown content. Previously this padded
                                  // Column was always present, so its top:25 /
                                  // bottom:10 padding left an empty gap between
                                  // the filter toolbar and the product grid.
                                  if (productConfig.showCountDown)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                          bottom: 10,
                                          top: 25),
                                      child: Row(
                                        children: [
                                          Text(
                                            S
                                                .of(context)
                                                .endsIn('')
                                                .toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary
                                                      .withOpacity(0.8),
                                                )
                                                .apply(fontSizeFactor: 0.6),
                                          ),
                                          CountDownTimer(
                                              widget.countdownDuration),
                                        ],
                                      ),
                                    ),
                                ],
                              ))
                            : AsymmetricView(
                                products: model.productsList,
                                isFetching: model.isFetching,
                                isEnd: model.isEnd,
                                onLoadMore: onLoadMore,
                                width: constraint.maxWidth),
                        titleFilter: layout.isListView
                            ? null
                            : renderActiveFilters(context),
                        // The Filter trigger sits beside the search box for both
                        // list and grid layouts.
                        filterButton: renderFilterButton(context),
                        onFilter: onFilter,
                        onSearch: (String searchText) => {
                          onFilter(
                            minPrice: minPrice,
                            maxPrice: maxPrice,
                            categoryId: categoryId,
                            tagId: tagId,
                            listingLocationId: listingLocationId,
                            search: searchText,
                          )
                        },
                        // bottomSheet: (Services()
                        //             .widget
                        //             .enableShoppingCart(null) &&
                        //         !ServerConfig().isListingType &&
                        //         showBottomCornerCart)
                        //     ? ExpandingBottomSheet(hideController: _controller)
                        //     : null,
                      );
                    }
                    return backdrop(
                      products: model.productsList,
                      isFetching: model.isFetching,
                      errMsg: model.errMsg,
                      isEnd: model.isEnd,
                      width: constraint.maxWidth,
                      layout: layout,
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );

    buildMain = renderScaffold(
      routeName: widget.routeName ?? RouteList.backdrop,
      child: buildMain,
    );

    return kIsWeb
        ? WillPopScope(
            onWillPop: () async {
              eventBus.fire(const EventOpenCustomDrawer());
              // LayoutWebCustom.changeStateMenu(true);
              Navigator.of(context).pop();
              return false;
            },
            child: buildMain,
          )
        : buildMain;
  }

  @override
  String get lang => appModel.langCode;

  @override
  void onCategorySelected(String name) {
    productModel.categoryName = name;
    _currentTitle = name;
  }

  @override
  void onCloseFilter() {
    _controller.forward();
  }

  @override
  void rebuild() {
    setState(() {});
  }

  @override
  String get tagName => tagModel.getTagName(tagId);
}
