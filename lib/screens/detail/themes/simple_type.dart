import 'dart:async';
import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inspireui/extensions/build_context_ext.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:magentoegypt/ajstoreui/widgets/app_bar/appbar_image.dart';
import 'package:magentoegypt/ajstoreui/widgets/app_bar/custom_app_bar.dart';
import 'package:magentoegypt/generated/l10n.dart';
import 'package:magentoegypt/screens/detail/widgets/product_cart_buttons.dart';
import 'package:magentoegypt/screens/detail/widgets/product_common_info.dart';
import 'package:magentoegypt/screens/detail/widgets/product_image_carasoul.dart';
import 'package:magentoegypt/widgets/product/widgets/heart_button.dart';
import 'package:magentoegypt/widgets/product/widgets/store_name.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/tools.dart';
import '../../../common/tools/flash.dart';
import '../../../models/index.dart'
    show AppModel, Product, ProductModel, UserModel, CartModel;
import '../../../modules/dynamic_layout/tabbar/tabbar_icon.dart';
import '../../../services/index.dart';
import '../../cart/cart_screen.dart';
import '../../chat/vendor_chat.dart';
import '../product_detail_screen.dart';
import '../widgets/index.dart';

class SimpleLayout extends StatefulWidget {
  final Product product;
  final bool isLoading;
  final ScrollController? scrollController;

  const SimpleLayout({
    super.key,
    required this.product,
    this.isLoading = false,
    this.scrollController,
  });

  @override
  // ignore: no_logic_in_create_state
  State<SimpleLayout> createState() => _SimpleLayoutState(product: product);
}

class _SimpleLayoutState extends State<SimpleLayout>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _selectIndexNotifier = ValueNotifier(0);

  late Product product;

  _SimpleLayoutState({required this.product});

  Map<String, String> mapAttribute = HashMap();
  var _hideController;
  var top = 0.0;

  /// Sticky app-bar title: shows name + price once the on-page title
  /// scrolls out of view.
  late final ScrollController _scrollController;
  bool _ownsScrollController = false;
  final ValueNotifier<bool> _showStickyTitle = ValueNotifier(false);
  final GlobalKey _titleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0,
    );
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) {
      return;
    }
    var show = false;
    final titleContext = _titleKey.currentContext;
    final box = titleContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached) {
      final appBarBottom = MediaQuery.of(context).padding.top + 60;
      final titleBottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      show = titleBottom < appBarBottom;
    } else if (_scrollController.hasClients) {
      show = _scrollController.offset > 300;
    }
    if (_showStickyTitle.value != show) {
      _showStickyTitle.value = show;
    }
  }

  @override
  void didUpdateWidget(SimpleLayout oldWidget) {
    if (oldWidget.product.type != widget.product.type) {
      setState(() {
        product = widget.product;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    _showStickyTitle.dispose();
    _hideController.dispose();
    _selectIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final size = MediaQuery.of(context).size;
    //final widthHeight = size.height;
    var item = Product.cloneFrom(product);
    if (!kProductDetail.showVideo && item.videoUrl != null) {
      item.videoUrl = null;
    }

    final userModel = Provider.of<UserModel>(context, listen: false);

    // When the PDP is pushed inside a tab's nested navigator, the app tab bar
    // stays below it and already clears the system-nav inset — so the action
    // bar must sit flush (no extra bottom inset) or a gap appears above the
    // tab bar. When pushed full-screen (e.g. from search) there is no tab bar,
    // so it must clear the inset itself.
    final isNestedInTab =
        Navigator.of(context) != Navigator.of(context, rootNavigator: true);
    final bottomBarInset =
        isNestedInTab ? 0.0 : MediaQuery.of(context).padding.bottom;

    return Container(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        bottom: false,
        //top: kProductDetail.safeArea,
        child: ChangeNotifierProvider(
          // This screen runs on its own ProductModel, so carry over any
          // preselection the route set on the outer one — otherwise a
          // configurable opened from the cart loses the variant it was added
          // with (86d3g2npa #7).
          create: (_) => ProductModel()
            ..preselectedVariantOptions =
                context.read<ProductModel>().preselectedVariantOptions,
          child: Stack(
            children: <Widget>[
              Scaffold(
                floatingActionButton: (!ServerConfig().isVendorType() ||
                        !kConfigChat['EnableSmartChat'])
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: VendorChat(
                          user: userModel.user,
                          store: product.store,
                        ),
                      ),
                backgroundColor: Theme.of(context).colorScheme.background,
                appBar: CustomAppBar(
                  // Fixed 60: the scaled value is < 60 on real devices and
                  // squeezes the cart action until its badge gets clipped.
                  height: 60,
                  leadingWidth: 40,
                  title: ValueListenableBuilder<bool>(
                    valueListenable: _showStickyTitle,
                    builder: (context, show, _) => AnimatedOpacity(
                      opacity: show ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !show,
                        child: _StickyTitle(product: widget.product),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                    onPressed: () {
                      context.read<ProductModel>().clearProductVariations();
                      Navigator.pop(context);
                    },
                  ),
                  actions: [
                    // AppbarImage(
                    //   height: getSize(24),
                    //   width: getSize(24),
                    //   svgPath: ImageConstant.imgShare,
                    //   margin:
                    //       getMargin(left: 15, top: 18, right: 15, bottom: 18),
                    // )

                    Padding(
                      padding: const EdgeInsets.only(top: 8,left: 12,bottom: 12,right: 8),
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .primaryColorLight
                            .withOpacity(0.7),
                        child: Selector<CartModel, int>(
                          selector: (_, model) => model.totalCartQuantity,
                          builder: (context, totalCart, child) {
                            return IconButton(
                              // Give IconCart (icon + badge, ~29x29) a slot it
                              // fits in; the default 24px slot clips the badge.
                              padding: EdgeInsets.zero,
                              iconSize: 30,
                              icon: IconCart(icon: Icon(
                                CupertinoIcons.bag,
                                size: 22,
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                              ), totalCart: totalCart),
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  RouteList.cart,
                                  arguments: CartScreenArgument(isBuyNow: true, isModal: false),
                                );
                              },
                            );
                          },
                        ),
                          //     ProductDetailScreen.showMenu(
                          //   context,
                          //   widget.product,
                          //   isLoading: widget.isLoading,
                          // ),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: Container(
                  // See bottomBarInset above: flush under a tab bar, inset
                  // when full-screen.
                  padding: EdgeInsets.only(bottom: bottomBarInset),
                  color: Theme.of(context).cardColor,
                  child: Container(
                    height: 80,
                    padding:
                        getPadding(left: 10, right: 10, top: 10, bottom: 10),
                    decoration: AppDecoration.outlineBlack90019.copyWith(
                        borderRadius: BorderRadiusStyle.roundedBorder8,
                        color: Theme.of(context).cardColor),
                    child: ProductCartButtons(
                      widget.product,
                      isBuyNow: true,
                    ),
                  ),
                ),
                body: SingleChildScrollView(
                  controller: _scrollController,
                  // Lets a short product page still overscroll, so the
                  // RefreshIndicator in ProductDetailScreen fires.
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: <Widget>[
                      // SliverAppBar(
                      //   backgroundColor:
                      //       Theme.of(context).colorScheme.background,
                      //   elevation: 1.0,
                      //   expandedHeight:
                      //       kIsWeb ? 0 : widthHeight * kProductDetail.height,
                      //   pinned: true,
                      //   floating: false,
                      //   leading: Padding(
                      //     padding: const EdgeInsets.all(8),
                      //     child: CircleAvatar(
                      //       backgroundColor: Theme.of(context)
                      //           .primaryColorLight
                      //           .withOpacity(0.7),
                      //       child: IconButton(
                      //         icon: Icon(
                      //           Icons.close,
                      //           color: Theme.of(context).primaryColor,
                      //         ),
                      //         onPressed: () {
                      //           context
                      //               .read<ProductModel>()
                      //               .clearProductVariations();
                      //           Navigator.pop(context);
                      //         },
                      //       ),
                      //     ),
                      //   ),
                      //   actions: <Widget>[
                      //     if (widget.isLoading != true)
                      //       HeartButton(
                      //         product: product,
                      //         size: 20.0,
                      //         color: Theme.of(context).primaryColor,
                      //       ),
                      //     Padding(
                      //       padding: const EdgeInsets.all(12),
                      //       child: CircleAvatar(
                      //         backgroundColor: Theme.of(context)
                      //             .primaryColorLight
                      //             .withOpacity(0.7),
                      //         child: IconButton(
                      //           icon: const Icon(Icons.more_vert, size: 19),
                      //           color: Theme.of(context).primaryColor,
                      //           onPressed: () => ProductDetailScreen.showMenu(
                      //             context,
                      //             widget.product,
                      //             isLoading: widget.isLoading,
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      //   flexibleSpace: Builder(builder: (context) {
                      //     return kIsWeb
                      //         ? const SizedBox()
                      //         : kProductDetail.productImageLayout.isList
                      //             ? ProductImageList(
                      //                 product: item,
                      //                 onChange: (index) {
                      //                   _selectIndexNotifier.value = index;
                      //                 })
                      //             : ProductImageSlider(
                      //                 product: item,
                      //                 onChange: (index) {
                      //                   _selectIndexNotifier.value = index;
                      //                 },
                      //               );
                      //   }),
                      // ),

                  //    ProductBreadCrumb(product: product),
                      Stack(
                        children: [
                          ProductImageCarasoul(
                            product: item,
                            onChange: (index) {
                              _selectIndexNotifier.value = index;
                            },
                          ),
                          Positioned(
                            right: context.isRtl ? null : 6,
                            left: context.isRtl ? 6 : null,
                            child: HeartButton(
                              product: widget.product,
                              size: 18,
                            ),
                          ),
                          Positioned(
                            top: 30,
                            right: context.isRtl ? null : 6,
                            left: context.isRtl ? 6 : null,
                            child: IconButton(
                              icon: Icon(
                                CupertinoIcons.share,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                              ),
                              color: Theme.of(context).primaryColor,
                              onPressed: () {
                                var url = product.permalink;
                                if (url?.isNotEmpty ?? false) {
                                  unawaited(
                                    FlashHelper.message(
                                      context,
                                      message: S.of(context).generatingLink,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                  // context anchors the popover on iPad.
                                  Services().firebase.shareDynamicLinkProduct(
                                    itemUrl: url,
                                    context: context,
                                  );
                                } else {
                                  unawaited(
                                    FlashHelper.errorMessage(
                                      context,
                                      message: S.of(context).failedToGenerateLink,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      Column(
                        children: <Widget>[
                          const SizedBox(height: 2),
                          if (kIsWeb)
                            ValueListenableBuilder<int>(
                              valueListenable: _selectIndexNotifier,
                              builder: (context, index, child) {
                                return ProductGallery(
                                  product: widget.product,
                                  selectIndex: index,
                                );
                              },
                            ),
                          Padding(
                            key: _titleKey,
                            padding: const EdgeInsets.only(
                              top: 8.0,
                              bottom: 4.0,
                              left: 15,
                              right: 15,
                            ),
                            child: widget.product.isGroupedProduct
                                ? const SizedBox()
                                : ProductTitle(product),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 15,
                              right: 15,
                              bottom: 4,
                            ),
                            child: StoreName(
                              product: product,
                              hide: false,
                            ),
                          ),
                        ],
                      ),
                      if (Services().widget.enableShoppingCart(
                          product.copyWith(isRestricted: false)))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: widget.isLoading
                                ? kLoadingWidget(context)
                                : ProductCommonInfo(
                                    product: widget.product,
                                    isLoading: widget.isLoading,
                                    wrapSliver: false,
                                  ),
                          ),
                        ),
                      if((product.size_chart ?? "").isNotEmpty)
                      InkWell(
                        onTap: (){
                          showSizeGuidePopup(context);
                        },
                        child: Container(
                          height: 40,
                          margin: EdgeInsets.only(left: 15,right: 15),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: Theme.of(context).primaryColor
                          ),
                          child: Center(
                            child: Text(S.of(context).sizeGuide
                                .toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Short description is rendered by makeProductTitleWidget
                      // (under the price), so it is intentionally not repeated
                      // here — doing both showed it twice.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          // horizontal: 15.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15.0,
                              ),
                              child: Column(
                                children: [
                                  Services().widget.renderVendorInfo(product),
                                  ProductDescription(product),
                                  if (kProductDetail.showProductCategories)
                                    ProductDetailCategories(product),
                                  if (kProductDetail.showProductTags)
                                    ProductTag(product),
                                  Services()
                                      .widget
                                      .productReviewWidget(product),
                                ],
                              ),
                            ),
                            if (kProductDetail
                                    .showRelatedProductFromSameStore &&
                                product.store?.id != null)
                              RelatedProductFromSameStore(product),
                            if (kProductDetail.showRelatedProduct)
                              RelatedProduct(product),
                            if (kProductDetail.showRecentProduct)
                              RecentProducts(excludeProduct: product),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // if (Services().widget.enableShoppingCart(
              //         product.copyWith(isRestricted: false)) &&
              //     kAdvanceConfig.showBottomCornerCart)
              //   Align(
              //     alignment: Tools.isRTL(context)
              //         ? Alignment.centerLeft
              //         : Alignment.centerRight,
              //     child: ExpandingBottomSheet(
              //       hideController: _hideController,
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }

  void showSizeGuidePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context).sizeGuide,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Image
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: product.size_chart ?? "$kMediaDomain/media/ced/csmarketplace/default/updated_size_chart_3_480x480.png", // replace this with your image URL
                    httpHeaders: const {'Accept': 'image/webp'},
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact name + price shown in the app bar once the on-page title has
/// scrolled out of view. Reads the page-local [ProductModel] so the price
/// follows the selected variation.
class _StickyTitle extends StatelessWidget {
  const _StickyTitle({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final variation =
        context.select((ProductModel model) => model.selectedVariation);
    final appModel = Provider.of<AppModel>(context);

    String? price;
    if (!product.isGroupedProduct) {
      final onSale = variation != null
          ? variation.onSale ?? false
          : product.onSale ?? false;
      price = variation != null && (variation.price?.isNotEmpty ?? false)
          ? variation.price
          : (product.price?.isNotEmpty ?? false)
              ? product.price
              : product.regularPrice;
      if (onSale) {
        price = variation != null
            ? variation.salePrice
            : (product.salePrice?.isNotEmpty ?? false)
                ? product.salePrice
                : product.price;
      }
    }
    final formattedPrice = (price?.isEmpty ?? true)
        ? null
        : PriceTools.getCurrencyFormatted(price, appModel.currencyRate,
            currency: appModel.currency);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (formattedPrice != null)
          Text(
            formattedPrice,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
          ),
      ],
    );
  }
}

class ProductBreadCrumb extends StatelessWidget {
  const ProductBreadCrumb({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: getPadding(
        left: 15,
        right: 15,
        bottom: 25,
        top: 15,
      ),
      child: Row(
        children: [
          Padding(
            padding: getPadding(bottom: 1),
            child: buildText(context, S.of(context).home),
          ),
          // if (product.categoryName != '' || product.categoryName != null)
          //   Padding(
          //     padding: getPadding(left: 3, bottom: 1),
          //     child: buildText(context, '/'),
          //   ),
          Padding(
            padding: getPadding(left: 5, top: 1),
            child: buildText(context, product.categoryName ?? ''),
          ),
          Padding(
            padding: getPadding(left: 2, bottom: 1),
            child: buildText(context, '/'),
          ),
          Padding(
            padding: getPadding(left: 5, bottom: 1),
            child: Expanded(
              child: Text(
                stripStringIfTooLong(product.name ?? ' '),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: AppStyle.txtBarlowRegular13
                    .copyWith(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          )
        ],
      ),
    );
  }

  Text buildText(BuildContext context, String text) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
      style: AppStyle.txtBarlowRegular13
          .copyWith(color: Theme.of(context).colorScheme.onPrimary),
    );
  }

  String stripStringIfTooLong(String input) {
    if (input.length > 30) {
      return '${input.substring(0, 30)}...'; // Strip the string to the first 50 characters
    } else {
      return input; // Return the input string as is
    }
  }

}
