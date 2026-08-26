import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inspireui/extensions.dart';
import 'package:intl/intl.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:magentoegypt/ajstoreui/widgets/app_bar/appbar_image.dart';
import 'package:magentoegypt/common/logger.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../common/tools/flash.dart';
import '../../generated/l10n.dart';
import '../../menu/index.dart' show MainTabControlDelegate;
import '../../models/index.dart' show AppModel, CartModel, Product, UserModel;
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/common/refresh_scroll_physics.dart';
import '../../widgets/product/cart_item.dart';
import '../../widgets/product/product_bottom_sheet.dart';
import '../checkout/checkout_screen.dart';
import 'widgets/empty_cart.dart';
import 'widgets/shopping_cart_sumary.dart';
import 'widgets/wishlist.dart';

/// Validate stock and cap quantities for every line in the cart. This fires a
/// stock request per item and can mutate the cart, so it runs ONCE when the
/// cart opens (see [_MyCartState.initState]) — never from build(), where it
/// used to re-fire on every rebuild.
void validateCartStockAndQuantities(CartModel model) {
  // ignore: curly_braces_in_flow_control_structures
  model.productsInCart.forEach((key, value) async {
    var product = model.getProductById(key);
    // The cart key is not a sku for a configurable line — it is
    // "parentSku|attr=value" so two variants stay separate rows. Ask about the
    // *child*: the key 404s, and the configurable parent reports qty 0, which
    // clamped the line to zero and emptied the cart on every refresh.
    final sku = model.getProductVariationById(key)?.sku ??
        product?.variantSku ??
        product?.sku ??
        key;
    var productCheck = await Services().api.getStockStatus(sku);

    // Only drop the line when the server EXPLICITLY reports the product out of
    // stock. Previously any inconclusive stock response (non-200 -> null, or a
    // null inStock) matched `!= true` and silently removed a just-added item —
    // the "product doesn't get added right away" bug. A genuinely out-of-stock
    // item is still re-validated server-side at checkout.
    if (productCheck != null && productCheck.inStock == false) {
      model.removeItemFromCart(key);
    }

    var cartQty = model.productsInCart[key];
    var availQty = productCheck?.stockQuantity;

    // minus product quantity if not available. CODE GOES BELOW
    if (availQty != null && cartQty! > availQty) {
      model.updateQuantity(product!, key, availQty);
    }
  });
}

// createShoppingCartRows stays outside MyCart to reuse for POS. It now only
// builds the row widgets — stock validation moved to
// validateCartStockAndQuantities so it doesn't re-run on every rebuild.
List<Widget> createShoppingCartRows(CartModel model, BuildContext context) {
  var productList = {};
  var productListWidget = model.productsInCart.keys.map(
    (key) {
      var product = model.getProductById(key);

      if (product != null) {
        productList[key] = {
          'id': key,
          'product': product,
          'quantity': model.productsInCart[key]
        };

        return ShoppingCartRow(
          product: product,
          addonsOptions: model.productAddonsOptionsInCart[key],
          variation: model.getProductVariationById(key),
          quantity: model.productsInCart[key],
          options: model.productsMetaDataInCart[key],
          onRemove: () {
            model.removeItemFromCart(key);
          },
          onChangeQuantity: (val) async {
            var message = await model.updateQuantity(product, key, val);
            if (message.isNotEmpty) {
              final snackBar = SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 1),
              );
              Future.delayed(
                const Duration(milliseconds: 300),
                () => ScaffoldMessenger.of(context).showSnackBar(snackBar),
              );
            }
          },
        );
      }
      return const SizedBox();
    },
  ).toList();


  return productListWidget;
}

class MyCart extends StatefulWidget {
  final bool? isModal;
  final bool? isBuyNow;
  final bool hasNewAppBar;
  final ScrollController? scrollController;

  const MyCart({
    this.isModal,
    this.isBuyNow = false,
    this.hasNewAppBar = false,
    this.scrollController,
  });

  @override
  State<MyCart> createState() => _MyCartState();
}

class _MyCartState extends State<MyCart> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  String errMsg = '';

  CartModel get cartModel => Provider.of<CartModel>(context, listen: false);

  @override
  void initState() {
    super.initState();
    // Pull the latest cart from the server when the cart opens so items added,
    // removed or updated on another platform (web / iOS) are reflected without
    // having to log out and back in. No-op for guests / non-Magento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        cartModel.reloadCartFromServer();
        // Validate stock / cap quantities once on open — this used to re-run
        // from build() on every rebuild, firing a stock request per line each
        // time and mutating the cart mid-build.
        validateCartStockAndQuantities(cartModel);
      }
    });
  }

  /// Pull-to-refresh: same pair [initState] runs on open, so a cart changed on
  /// the website or another device is picked up without leaving the screen.
  Future<void> _reload() async {
    await cartModel.reloadCartFromServer();
    if (mounted) {
      validateCartStockAndQuantities(cartModel);
    }
  }

  void _loginWithResult(BuildContext context) async {
    // final result = await Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => LoginScreen(
    //       fromCart: true,
    //     ),
    //     fullscreenDialog: kIsWeb,
    //   ),
    // );

    //BUG: Missing login SMS as default
    await FluxNavigate.pushNamed(
      RouteList.login,
    ).then((value) {
      final user = Provider.of<UserModel>(context, listen: false).user;
      if (user != null && user.name != null) {
        Tools.showSnackBar(ScaffoldMessenger.of(context),
            '${S.of(context).welcome} ${user.name} !');
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    printLog('[Cart] build');
    final defaultCurrency = kAdvanceConfig.defaultCurrency;
    final currency = Provider.of<AppModel>(context).currency;
    final currencyRate = Provider.of<AppModel>(context).currencyRate;
    final largeAmountStyle = TextStyle(
      color: Theme.of(context).colorScheme.onPrimary,
      fontSize: 20,
    );
    final formatter = NumberFormat.currency(
      locale: 'en',
      symbol: defaultCurrency?.symbol,
      decimalDigits: defaultCurrency?.decimalDigits,
    );
    final localTheme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    var layoutType = Provider.of<AppModel>(context).productDetailLayout;
    //final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    //final canPop = parentRoute?.canPop ?? false;
    return Selector<CartModel, int>(
        selector: (_, cartModel) => cartModel.totalCartQuantity,
        builder: (context, totalCartQuantity, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CloseButton(
                onPressed: () {
                  if (widget.isBuyNow!) {
                    Navigator.of(context).pop();
                    return;
                  }
                  if (Navigator.of(context).canPop() &&
                      layoutType != 'simpleType') {
                    Navigator.of(context).pop();
                  } else {
                    ExpandingBottomSheet.of(context, isNullOk: true)
                        ?.close();
                  }
                },
              ),
              if (totalCartQuantity > 0)
                Container(
                  // decoration: BoxDecoration(
                  //     color: Theme.of(context).primaryColorLight),
                  padding: const EdgeInsets.only(
                    right: 15.0,
                    top: 4.0,
                  ),
                  child: SizedBox(
                    width: screenSize.width,
                    child: SizedBox(
                      width: screenSize.width /
                          (2 /
                              (screenSize.height /
                                  screenSize.width)),
                      child: Row(
                        children: [
                          const SizedBox(width: 25.0),
                          Text(
                            '${S.of(context).shoppingCart} ($totalCartQuantity)',
                            style: localTheme.textTheme.titleMedium!
                                .copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (totalCartQuantity > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 10.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 15.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${S.of(context).subtotal}:',
                          style: largeAmountStyle,
                        ),
                      ),
                      cartModel.calculatingDiscount
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                        ),
                      )
                          : Text(
                        PriceTools.getCurrencyFormatted(
                            cartModel.getTotal()! -
                                cartModel.getShippingCost()!,
                            currencyRate,
                            currency: cartModel.isWalletCart()
                                ? defaultCurrency
                                ?.currencyCode
                                : currency)!,
                        style: largeAmountStyle,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: CustomScrollView(
                controller: widget.scrollController,
                // RefreshScrollPhysics (not plain Bouncing) so a one-line cart
                // still overscrolls enough to trigger the control below.
                physics: const RefreshScrollPhysics(),
                slivers: [
                  MediaQuery.removePadding(
                    context: context,
                    removeTop: widget.hasNewAppBar && widget.isModal != true,
                    child: SliverAppBar(
                      toolbarHeight: widget.isModal == true ?0:kToolbarHeight,
                      pinned: true,
                      centerTitle: true,
                      leading: widget.isModal == true
                          ? SizedBox(height: 0,)
                          : AppbarImage(
                        height: getSize(24),
                        width: getSize(24),
                        svgPath: ImageConstant.imgMenu,
                        margin: getMargin(left: 16, top: 18, bottom: 18),
                        onTap: () => NavigateTools.onTapOpenDrawerMenu(context),
                      ),

                      backgroundColor: Theme.of(context).colorScheme.background,

                      // Text(
                      //   S.of(context).myCart,
                      //   style: Theme.of(context)
                      //       .textTheme
                      //       .headlineSmall!
                      //       .copyWith(fontWeight: FontWeight.w700),
                      // ),
                      actions: const [],
                    ),
                  ),
                  // Sits below the pinned SliverAppBar so the spinner appears
                  // under the bar rather than pushing it down.
                  CupertinoSliverRefreshControl(onRefresh: _reload),
                  SliverToBoxAdapter(
                    child: Selector<CartModel, int>(
                      selector: (_, cartModel) => cartModel.totalCartQuantity,
                      builder: (context, totalCartQuantity, child) {
                        return AutoHideKeyboard(
                          child: Container(
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.background),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 80.0),
                              child: Column(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      // const SizedBox(height: 16.0),
                                      if (totalCartQuantity > 0)
                                        Column(
                                          children: createShoppingCartRows(
                                              cartModel, context),
                                        ),

                                      if (totalCartQuantity == 0) EmptyCart(),
                                      // Checkout Button
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 16,
                                        ),
                                        child: Selector<CartModel, bool>(
                                          selector: (_, cartModel) =>
                                          cartModel.calculatingDiscount,
                                          builder:
                                              (context, calculatingDiscount, child) {
                                            //  log
                                            logTalker(
                                              classFileName: 'MyCart',
                                              logType: TalkerType.info,
                                              message:
                                              'inside MyCart screen child: $child',
                                            );

                                            // if (calculatingDiscount) {
                                            //   LoadingScreen().show(
                                            //     context: context,
                                            //     text: 'Please wait for a moment ...',
                                            //   );
                                            // } else {
                                            //   LoadingScreen().hide();
                                            // }
                                            return Container(
                                              margin: getMargin(
                                                top: 16,
                                              ),
                                              padding: getPadding(
                                                  left: 16,
                                                  top: 15,
                                                  right: 16,
                                                  bottom: 15),
                                              decoration: AppDecoration
                                                  .outlineBlack90019
                                                  .copyWith(
                                                borderRadius:
                                                BorderRadiusStyle.roundedBorder8,
                                                color: Theme.of(context).cardColor,
                                              ),
                                              child: TextButton(
                                                onPressed: calculatingDiscount
                                                    ? null
                                                    : () {
                                                  if (kAdvanceConfig
                                                      .alwaysShowTabBar) {
                                                    MainTabControlDelegate
                                                        .getInstance()
                                                        .changeTab(RouteList.cart,
                                                        allowPush: false);
                                                    // return;
                                                  }
                                                  onCheckout(model: cartModel);
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                  Theme.of(context).primaryColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(4.0),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 20,
                                                  ),
                                                  textStyle: const TextStyle(
                                                    letterSpacing: 0.8,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: child!,
                                              ),
                                            );
                                          },
                                          child: Selector<CartModel, int>(
                                            selector: (_, carModel) =>
                                            cartModel.totalCartQuantity,
                                            builder:
                                                (context, totalCartQuantity, child) {
                                              // if (totalCartQuantity == 0) {
                                              //   return const SizedBox();
                                              // }
                                              return Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                                  children: [
                                                    const Spacer(),
                                                    totalCartQuantity > 0
                                                        ? (isLoading
                                                        ? Row(
                                                      children: [
                                                        const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child:
                                                          CircularProgressIndicator(
                                                              color: Colors
                                                                  .white),
                                                        ),
                                                        const SizedBox(
                                                            width: 5),
                                                        Text(S
                                                            .of(context)
                                                            .loading
                                                            .toUpperCase()),
                                                      ],
                                                    )
                                                        : Text(S
                                                        .of(context)
                                                        .checkout
                                                        .toUpperCase()))
                                                        : Text(S
                                                        .of(context)
                                                        .startShopping
                                                        .toUpperCase()),
                                                    const Spacer(),
                                                    Align(
                                                      alignment: Alignment.centerRight, // move to left
                                                      child: Transform(
                                                        alignment: Alignment.center,
                                                        transform: context.isRtl ? Matrix4.rotationY(3.1416):Matrix4.rotationY(0), // flip horizontally (180°)
                                                        child: CustomImageView(
                                                          svgPath: ImageConstant.imgArrowrightWhiteA700,
                                                          height: getSize(20),
                                                          width: getSize(20),
                                                          margin: getMargin(top: 1, bottom: 1),
                                                        ),
                                                      ),
                                                    )
                                                    // Align(
                                                    //   alignment: Alignment.centerRight,
                                                    //   child: CustomImageView(
                                                    //     svgPath: ImageConstant.imgArrowrightWhiteA700,
                                                    //     height: getSize(20),
                                                    //     width: getSize(20),
                                                    //     margin: getMargin(
                                                    //         top: 1, bottom: 1),
                                                    //   ),
                                                    // ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      if (errMsg.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 10,
                                          ),
                                          child: Text(
                                            errMsg,
                                            style: const TextStyle(
                                                color: Colors.red, fontSize: 20),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      const SizedBox(height: 4.0),
                                      // WishList()
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ))
            ],
          );
        });
  }

  Future<Widget> clearCartPopup(context) async {
    return await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(S.of(context).confirmClearTheCart),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(S.of(context).keep),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                cartModel.clearCart(true);
              },
              child: Text(
                S.of(context).clear,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void onCheckout({required CartModel model}) {
    var isLoggedIn = Provider.of<UserModel>(context, listen: false).loggedIn;
    final currencyRate =
        Provider.of<AppModel>(context, listen: false).currencyRate;
    final currency = Provider.of<AppModel>(context, listen: false).currency;
    var message;

    if (isLoading) return;

    if (kCartDetail['minAllowTotalCartValue'] != null) {
      if (kCartDetail['minAllowTotalCartValue'].toString().isNotEmpty) {
        var totalValue = model.getSubTotal() ?? 0;
        var minValue = PriceTools.getCurrencyFormatted(
            kCartDetail['minAllowTotalCartValue'], currencyRate,
            currency: currency);
        if (totalValue < kCartDetail['minAllowTotalCartValue'] &&
            model.totalCartQuantity > 0) {
          message = '${S.of(context).totalCartValue} $minValue';
        }
      }
    }

    if (kVendorConfig.disableMultiVendorCheckout &&
        ServerConfig().isVendorType()) {
      if (!model.isDisableMultiVendorCheckoutValid(
          model.productsInCart, model.getProductById)) {
        message = S.of(context).youCanOnlyOrderSingleStore;
      }
    }

    if (message != null) {
      FlashHelper.errorMessage(context, message: message);

      return;
    }

    if (model.totalCartQuantity == 0) {
      if (widget.isModal == true) {
        // try {
        //   ExpandingBottomSheet.of(context)!.close();
        // } catch (e) {
        //   Navigator.of(context).pushNamed(RouteList.dashboard);
        // }
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.canPop ?? false) {
          Navigator.of(context).pop();
        }
        MainTabControlDelegate.getInstance().tabAnimateTo(1);
      } else {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.canPop ?? false) {
          Navigator.of(context).pop();
        }
       // MainTabControlDelegate.getInstance().changeTab(RouteList.categorySearch);
      //  MainTabControlDelegate.getInstance().tabAnimateTo(1);
      }
    } else if (isLoggedIn || kPaymentConfig.guestCheckout) {
      doCheckout();
    } else {
      _loginWithResult(context);
    }
  }

  Future<void> doCheckout() async {
    showLoading();

    await Services().widget.doCheckout(
      context,
      success: () async {
        hideLoading('');
        await FluxNavigate.pushNamed(
          RouteList.checkoutOption,
          arguments: CheckoutArgument(isModal: widget.isModal),
          forceRootNavigator: true,
        );
      },
      error: (message) async {
        if (message ==
            Exception('Token expired. Please logout then login again')
                .toString()) {
          setState(() {
            isLoading = false;
          });
          //logout
          final userModel = Provider.of<UserModel>(context, listen: false);
          await userModel.logout();
          await Services().firebase.signOut();

          _loginWithResult(context);
        } else {
          hideLoading(message);
          Future.delayed(const Duration(seconds: 3), () {
            setState(() => errMsg = '');
          });
        }
      },
      loading: (isLoading) {
        setState(() {
          this.isLoading = isLoading;
        });
      },
    );
  }

  void showLoading() {
    setState(() {
      isLoading = true;
      errMsg = '';
    });
  }

  void hideLoading(error) {
    setState(() {
      isLoading = false;
      errMsg = error;
    });
  }
}
