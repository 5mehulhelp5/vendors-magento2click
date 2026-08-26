import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:inspireui/extensions/string_extension.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../common/config.dart'
    show kProductCard, kProductDetail, kSaleOffProduct;
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart' show Product;
import '../../modules/dynamic_layout/config/product_config.dart';
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../modules/dynamic_layout/vertical/pinterest_card.dart';
import '../../services/index.dart';
import '../backdrop/backdrop_constants.dart';
import '../common/no_internet_connection.dart';
import 'product_simple_view.dart';

class ProductList extends StatefulWidget {
  final List<Product>? products;
  final bool isFetching;
  final bool? isEnd;
  final String? errMsg;
  final double? width;
  final double padding;
  final String? layout;
  final Future Function() onRefresh;
  final Future Function() onLoadMore;
  final double? ratioProductImage;
  final double productListItemHeight;
  final List<Widget>? header;
  final Widget? appbar;
  final ScrollController? scrollController;

  const ProductList({
    super.key,
    this.isFetching = false,
    this.isEnd = true,
    this.errMsg,
    this.products,
    this.width,
    this.padding = 8.0,
    required this.onRefresh,
    required this.onLoadMore,
    this.layout = 'list',
    this.ratioProductImage,
    this.productListItemHeight = 125.0,
    this.header,
    this.appbar,
    this.scrollController,
  });

  @override
  State<ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  late RefreshController _refreshController;

  bool get isEnd => widget.isEnd ?? true;

  List<Product> emptyList = [
    Product.empty('1'),
    Product.empty('2'),
    Product.empty('3'),
    Product.empty('4'),
    Product.empty('5'),
    Product.empty('6')
  ];

  @override
  void initState() {
    super.initState();

    /// if there are existing product from previous navigate we don't need to enable the refresh
    _refreshController = RefreshController(initialRefresh: false);
  }

  void _onRefresh() async {
    if (!widget.isFetching) {
      await widget.onRefresh();
    }
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    if (!widget.isFetching && !isEnd) {
      await widget.onLoadMore();
    }
    _refreshController.loadComplete();
  }

  @override
  void didUpdateWidget(ProductList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isFetching == false && oldWidget.isFetching == true) {
      _refreshController.refreshCompleted();
      _refreshController.loadComplete();
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = Tools.isTablet(MediaQuery.of(context));

    var widthScreen = widget.width ?? screenSize.width;
    var widthContent = screenSize.width;
    var crossAxisCount = 1;
    var childAspectRatio = 0.8;

    if (Layout.isDisplayDesktop(context)) {
      widthScreen -= BackdropConstants.drawerWidth;
    }
    if (widget.layout == 'card') {
      crossAxisCount = isTablet ? 2 : 1;
      widthContent = isTablet ? widthScreen / 2 : widthScreen; //one column
    } else if (widget.layout == 'columns') {
      crossAxisCount = isTablet ? 4 : 3;
      widthContent =
          isTablet ? widthScreen / 4 : (widthScreen / 3); //three columns
    } else if (widget.layout == 'listTile') {
      crossAxisCount = isTablet ? 2 : 1;
      widthContent = widthScreen; // one column
    } else {
      /// 2 columns on mobile, 3 columns on ipad
      crossAxisCount = isTablet ? 3 : 2;
      //layout is list
      widthContent =
          isTablet ? widthScreen / 3 : (widthScreen / 2); //two columns
    }
    var itemHeight = widget.productListItemHeight;
    if (kProductDetail.showQuantityInList) {
     // itemHeight += 30;
    }
    if (kProductCard.showCartButton) {
     // itemHeight += 30;
    }
    itemHeight -= 50;
    // Extra room under the price for the on-card variant preview
    // (colour-image circles + size chips). Sized for the worst bounded case —
    // one colour row plus up to two size-chip rows (the swatch widget caps the
    // rest to a "+N" chip) — so a product with many sizes no longer overflows
    // the fixed grid cell. Multi-column layouts get less since their narrower
    // cards show fewer chips per row.
    if (widget.layout != 'columns') {
      itemHeight += 186;
    } else {
      itemHeight += 150;
    }
    childAspectRatio = widthContent /
        (widthContent * (widget.ratioProductImage ?? 1.2) + itemHeight);

    final hasNoProduct = widget.products == null || widget.products!.isEmpty;

    final productsList =
        hasNoProduct && widget.isFetching ? emptyList : widget.products;

    if (hasNoProduct &&
        widget.errMsg != null &&
        widget.errMsg!.isNoInternetError) {
      return NoInternetConnection(onRefresh: _onRefresh);
    }

    Widget typeList = const SizedBox();

    if (productsList == null || productsList.isEmpty) {
      typeList = SliverFillRemaining(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.of(context).noProduct,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    } else {
      if (widget.layout != Layout.pinterest) {
        if (widget.layout == Layout.listTile ||
            widget.layout == Layout.simpleList) {
          typeList = buildListView(products: productsList);
        } else {
          typeList = buildGridViewProduct(
            childAspectRatio: childAspectRatio,
            crossAxisCount: crossAxisCount,
            products: productsList,
            widthContent: widthContent,
          );
        }
      } else {
        typeList = buildStaggeredGridView(
          products: productsList,
          widthContent: widthScreen,
        );
      }
    }

    return SmartRefresher(
      header: MaterialClassicHeader(
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      enablePullDown: true,
      enablePullUp: !isEnd,
      controller: _refreshController,
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      footer: kCustomFooter(context),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: <Widget>[
          if (widget.appbar != null)
            SliverAppBar(
              primary: false,
              titleSpacing: 10,
              backgroundColor: Theme.of(context).colorScheme.background,
              toolbarHeight: 44,
              elevation: 1.0,
              pinned: true,
              floating: false,
              leadingWidth: 0,
              leading: const SizedBox(),
              title: widget.appbar,
              actions: null,
            ),
          SliverToBoxAdapter(
            child: Column(
              children: widget.header ?? [],
            ),
          ),
          typeList,
        ],
      ),
    );
  }

  Widget buildGridViewProduct({
    required int crossAxisCount,
    required double childAspectRatio,
    double? widthContent,
    required List<Product> products,
  }) {
    // Aligned rows with per-row equal-height cards. Each row is chunked into
    // `crossAxisCount` cards and wrapped in IntrinsicHeight, so the row takes
    // only the height its *tallest* card needs and both cards stretch to match
    // it. This keeps left/right cards the same height (no staggering) while
    // avoiding the old fixed grid's one-height-for-all reservation, which left
    // a large gap under cards with few swatches. `childAspectRatio` is no
    // longer used here.
    const gap = 8.0;
    final rowCount = (products.length / crossAxisCount).ceil();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          addAutomaticKeepAlives: false,
          childCount: rowCount,
          (BuildContext context, int rowIndex) {
            final start = rowIndex * crossAxisCount;
            final cells = <Widget>[];
            for (var c = 0; c < crossAxisCount; c++) {
              if (c > 0) cells.add(const SizedBox(width: gap));
              final idx = start + c;
              cells.add(
                Expanded(
                  child: idx < products.length
                      ? Services().widget.renderProductCardView(
                            item: products[idx],
                            width: widthContent,
                            ratioProductImage: widget.ratioProductImage ?? 1.2,
                            config: ProductConfig.empty()
                              ..showHeart = true
                              // The row owns the spacing; drop card margins so
                              // the cards fill their cell and align edge to edge.
                              ..hMargin = 0
                              ..vMargin = 0
                              ..imageRatio = widget.ratioProductImage ?? 1.2
                              ..showCountDown = kSaleOffProduct.showCountDown &&
                                  widget.layout == Layout.saleOff
                              ..showCartIcon = ProductConfig.empty()
                                      .showCartIcon &&
                                  (widget.layout != Layout.columns &&
                                      products[idx].canBeAddedToCartFromList()),
                          )
                      : const SizedBox.shrink(),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cells,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildStaggeredGridView({
    required List<Product>? products,
    double? widthContent,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.only(
        bottom: 32,
        left: 8,
        right: 8,
      ),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 8.0,
        childCount: products!.length,
        itemBuilder: (context, index) => PinterestCard(
          item: products[index],
          width: MediaQuery.of(context).size.width / 2,
          config: ProductConfig.empty()
            ..showCartIcon = ProductConfig.empty().showCartIcon &&
                widget.layout != 'columns' &&
                products[index].canBeAddedToCartFromList(),
        ),
        // staggeredTileBuilder: (index) => const StaggeredTile.fit(2),
      ),
    );
  }

  Widget buildListView({
    required List<Product>? products,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        addAutomaticKeepAlives: false,
        (context, index) {
          if (widget.layout == Layout.simpleList) {
            return ProductSimpleView(
              item: products![index],
              isFromSearchScreen: true,
            );
          }
          return Services().widget.renderProductItemTileView(
                item: products![index],
                padding: const EdgeInsets.only(bottom: 10),
                config: ProductConfig.empty(),
              );
        },
        childCount: products?.length,
      ),
    );
  }
}
