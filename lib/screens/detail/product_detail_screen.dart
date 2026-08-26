import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools/flash.dart';
import '../../common/tools/image_tools.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart'
    show AppModel, Product, ProductModel, ProductWishListModel, UserModel;
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../base_screen.dart';
import '../common/app_bar_mixin.dart';
import 'widgets/image_galery.dart';

export 'themes/full_size_image_type.dart';
export 'themes/half_size_image_type.dart';
export 'themes/simple_type.dart';

/// Route arguments for [ProductDetailScreen] when the caller needs to open the
/// page with a variant already chosen — currently only the shopping cart, which
/// opens the *parent* configurable with the line's selected options applied
/// (86d3g2npa #7). Passing a bare [Product] still works and is the common case.
class ProductDetailArguments {
  final Product product;
  final Map<String?, String?>? preselectedOptions;

  const ProductDetailArguments(this.product, {this.preselectedOptions});
}

class ProductDetailScreen extends StatefulWidget {
  final Product? product;
  final String? id;

  /// {attribute_code: option value id} to start the variant picker on.
  final Map<String?, String?>? preselectedOptions;

  const ProductDetailScreen({this.product, this.id, this.preselectedOptions});

  static void showMenu(BuildContext context, Product? product,
      {bool isLoading = false}) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext modalContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (Services().widget.enableShoppingCart(null) &&
                !ServerConfig().isListingType)
              ListTile(
                title: Text(
                  S.of(modalContext).myCart,
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  FluxNavigate.pushNamed(
                    RouteList.cart,
                    forceRootNavigator: true,
                  );
                },
              ),
            ListTile(
              title: Text(
                S.of(modalContext).showGallery,
                textAlign: TextAlign.center,
              ),
              onTap: () {
                Navigator.of(modalContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return ImageGalery(images: product?.images, index: 0);
                  },
                );
              },
            ),
            if (!isLoading && product != null)
              ListTile(
                title: Text(
                  S.of(modalContext).saveToWishList,
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  Provider.of<ProductWishListModel>(context, listen: false)
                      .addToWishlist(product);
                  Navigator.of(modalContext).pop();
                },
              ),

            /// Share feature not supported in Strapi.
            if (!ServerConfig().isStrapi && !ServerConfig().isNotion)
              ListTile(
                title:
                    Text(S.of(modalContext).share, textAlign: TextAlign.center),
                onTap: () {
                  var url = product?.permalink;
                  if (url?.isNotEmpty ?? false) {
                    unawaited(
                      FlashHelper.message(
                        context,
                        message: S.of(context).generatingLink,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    // context anchors the popover on iPad; without it
                    // share_plus presents nothing at all.
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
            Container(
              height: 1,
              decoration: const BoxDecoration(color: kGrey200),
            ),
            ListTile(
              title: Text(
                S.of(modalContext).cancel,
                textAlign: TextAlign.center,
              ),
              onTap: () {
                Navigator.of(modalContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  BaseScreen<ProductDetailScreen> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends BaseScreen<ProductDetailScreen>
    with AppBarMixin {
  Product? product;
  bool isLoading = true;
  bool _isChecking = Services().widget.enableMembershipUltimate;
  String? _checkingErrorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  Future<void> afterFirstLayout(BuildContext context) async {}

  @override
  void initState() {
    screenScrollController = _scrollController;
    // Hand the selection to the variant widgets before they load; they apply it
    // once the variations arrive.
    // Always assign — clearing matters as much as setting, or the next product
    // opened from somewhere without a preselection would inherit this one's.
    final preselected = widget.preselectedOptions;
    Provider.of<ProductModel>(context, listen: false).preselectedVariantOptions =
        (preselected != null && preselected.isNotEmpty)
            ? Map.of(preselected)
            : null;
    WidgetsBinding.instance.endOfFrame.then((_) async {
      if (mounted) {
        await _loadProduct();
      }
    });
    super.initState();
  }

  /// The detail fetch, shared by the initial load and pull-to-refresh so a
  /// price, stock or option change made server-side shows up without leaving
  /// the page.
  /// [refresh] is set only by the pull-to-refresh gesture, never by the
  /// initial load: it additionally drops the cached image bytes, which is
  /// worth a re-download when the shopper explicitly asked for current data
  /// but not every time the page opens.
  Future<void> _loadProduct({bool refresh = false}) async {
    try {
      if (widget.product is Product) {
        var initial = widget.product!;

        /// A product handed over by the wishlist is a display stub — the
        /// wishlist feed carries a name, a price and a couple of image names,
        /// nothing else. Rendered as-is the page showed a placeholder image,
        /// "out of stock", and a buy button stuck on LOADING forever, because
        /// the variant picker bails out when the product has no attributes and
        /// only ever runs on the product it is first built with. So fetch the
        /// catalog record BEFORE the first render (86d3uqvmx #2); the stub is
        /// kept only if that fetch comes back empty, so the page still shows
        /// something offline.
        if (initial.isPartial) {
          final catalogProduct = await Services().api.getProduct(initial.id);
          if (catalogProduct != null) {
            /// Carry the wishlist item id across — it is not part of the
            /// catalog payload, and removing from the wishlist needs it.
            catalogProduct.itemID ??= initial.itemID;
            initial = catalogProduct;
          }
        }
        if (!mounted) return;

        /// Get more detail info from product
        setState(() {
          product = initial;
        });
        final check = await _checkProductPermission(initial);
        if (check) {
          // Keep the product we already have if the detail fetch fails or
          // returns null, so the page renders with what it has instead of
          // hanging on a blank loading spinner forever.
          final full =
              await Services().widget.getProductDetail(context, product);
          if (full != null) {
            product = full;
          }
        }
      } else {
        /// Request the product by Product ID which is using for web param
        product = await Services().api.getProduct(widget.id);
        await _checkProductPermission(product);
      }
    } catch (_) {
      // Fall back to whatever product we already have so the page renders
      // with partial data instead of hanging on a blank loader.
    } finally {
      // The gallery URLs do not change when the photos behind them do, so a
      // refresh has to evict the bytes as well or the carousel repaints from
      // the cache and looks unchanged (86d3x5ex6).
      if (refresh) {
        final images = product?.images ?? const <String>[];
        await ImageTools.evictProductImages(
            [product?.imageFeature, ...images]);
      }
      isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _checkProductPermission(Product? p) async {
    if (Services().widget.enableMembershipUltimate &&
        (p?.isRestricted ?? false)) {
      setState(() {
        _isChecking = true;
      });
      final cookie =
          Provider.of<UserModel>(context, listen: false).user?.cookie;
      try {
        final check =
            await Services().api.checkProductPermission(p?.id ?? '0', cookie);
        setState(() {
          _isChecking = false;
        });
        return check == true;
      } catch (e) {
        setState(() {
          _isChecking = false;
          _checkingErrorMessage = e.toString();
        });
        return false;
      }
    } else {
      setState(() {
        _isChecking = false;
      });
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (product?.id == null) {
      return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
          ),
          body: Center(
            child: isLoading
                ? kLoadingWidget(context)
                : Text(S.of(context).notFound),
          ));
    }

    if (_isChecking || (_checkingErrorMessage?.isNotEmpty ?? false)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
        ),
        body: Center(
            child: (_checkingErrorMessage?.isNotEmpty ?? false)
                ? Text(
                    _checkingErrorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                : kLoadingWidget(context)),
      );
    }
    return _renderContent();
  }

  Widget _renderContent() {
    var layoutType = Provider.of<AppModel>(context).productDetailLayout;

    var layout = Services().widget.renderDetailScreen(
          context,
          product!,
          layoutType,
          isLoading,
          scrollController: _scrollController,
        );

    layout = Scaffold(
      body: Column(
        children: [
          if (showAppBar(RouteList.productDetail)) appBarWidget,
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: showAppBar(RouteList.productDetail)
                    ? EdgeInsets.zero
                    : null,
              ),
              // Wrapped here rather than inside each detail theme: the layout
              // comes from Services().widget.renderDetailScreen, and
              // RefreshIndicator picks up scroll notifications from whichever
              // scrollable that factory returns. The themes only need
              // AlwaysScrollableScrollPhysics for short pages to overscroll.
              child: RefreshIndicator(
                onRefresh: () => _loadProduct(refresh: true),
                child: layout,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        var currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: layout,
    );
  }
}
