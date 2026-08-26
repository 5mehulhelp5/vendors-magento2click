import 'dart:async';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:provider/provider.dart';
import '../../common/constants.dart';
import '../../common/tools/tools.dart';
import '../../generated/l10n.dart';
import '../../models/cart/cart_base.dart';
import '../../models/user_model.dart';
import '../../modules/dynamic_layout/tabbar/tabbar_icon.dart';
import '../../services/service_config.dart';
import '../../services/services.dart';
import '../cart/cart_screen.dart';
import 'products_mixin.dart';
import 'products_searchview.dart';

enum MenuType { cart, wishlist, share, login }

class ProductFlatView extends StatefulWidget {
  final Widget builder;
  final Widget? bottomSheet;
  final Widget? titleFilter;

  /// Optional "Filter" trigger shown inline to the right of the search box
  /// (the active-filter chips stay in [titleFilter]'s sticky row below).
  final Widget? filterButton;
  final Function? onSort;
  final Function onFilter;
  final Function onSearch;
  final bool enableSearchHistory;
  final bool autoFocusSearch;
  final bool hasAppBar;
  String currentTitle = '';
  String productCount = '';

   ProductFlatView({
    required this.builder,
    required this.onSearch,
    this.bottomSheet,
    this.titleFilter,
    this.filterButton,
    this.onSort,
    required this.onFilter,
    this.enableSearchHistory = false,
    this.autoFocusSearch = true,
    this.hasAppBar = false,
    required this.currentTitle,
     required this.productCount,
    Key? key,
  }) : super(key: key);

  @override
  State<ProductFlatView> createState() => _ProductFlatViewState();
}

class _ProductFlatViewState extends State<ProductFlatView> with ProductsMixin {
  Color get labelColor => Colors.black;

  bool get isLoggedIn =>
      Provider.of<UserModel>(context, listen: false).loggedIn;

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    bool isSelect = false,
  }) {
    final menuItemStyle = TextStyle(
      fontSize: 13.0,
      color: isSelect
          ? Theme.of(context).primaryColor
          : Theme.of(context).colorScheme.secondary,
      height: 24.0 / 15.0,
    );
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Icon(icon,
                color: isSelect
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).colorScheme.secondary,
                size: 17),
          ),
          Text(label, style: menuItemStyle),
        ],
      ),
    );
  }

  Future<void> _onSeeMore(MenuType type) async {
    switch (type) {
      case MenuType.cart:
        await Navigator.of(context).pushNamed(
          RouteList.cart,
          arguments: CartScreenArgument(isBuyNow: true, isModal: false),
        );
        break;
      case MenuType.share:
        await shareProductsLink(context);
        break;
      case MenuType.wishlist:
        await Navigator.of(context).pushNamed(RouteList.wishlist);
        break;
      case MenuType.login:
        await Navigator.of(context).pushNamed(RouteList.login);
        break;
    }
  }

  Widget _buildMoreWidget(bool loggedIn) {
    final sortByData = [
      if (Services().widget.enableShoppingCart(null) &&
          !ServerConfig().isListingType)
        {
          'type': MenuType.cart.name,
          'title': S.of(context).myCart,
          'icon': CupertinoIcons.bag,
        },
      {
        'type': MenuType.wishlist.name,
        'title': S.of(context).myWishList,
        'icon': CupertinoIcons.heart,
      },
      if (!loggedIn)
        {
          'type': MenuType.login.name,
          'title': S.of(context).login,
          'icon': CupertinoIcons.person,
        },
    ];

    return PopupMenuButton<String>(
      onSelected: (value) => _onSeeMore(MenuType.values.byName(value)),
      itemBuilder: (BuildContext context) =>
          List<PopupMenuItem<String>>.generate(
        sortByData.length,
        (index) => _buildMenuItem(
          icon: sortByData[index]['icon'] as IconData,
          label: '${sortByData[index]['title']}',
          value: '${sortByData[index]['type']}',
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Icon(
          CupertinoIcons.bag,
          size: 20,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void onSearch(String value) {
    EasyDebounce.debounce('searchCategory', const Duration(milliseconds: 200),
        () => widget.onSearch(value));
  }

  Widget _getStickyWidget() {
    // The chip bar (titleFilter) now carries its own styling and self-collapses
    // when no filter is applied, so this just hosts it.
    return widget.titleFilter ?? const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    /// using for the Search Screen UX
    if (widget.enableSearchHistory) {
      return ProductSearchView(
        hasAppBar: widget.hasAppBar,
        builder: widget.builder,
        onSearch: widget.onSearch,
        bottomSheet: widget.bottomSheet,
        titleFilter: widget.titleFilter,
        onSort: widget.onSort,
        onFilter: widget.onFilter,
        autoFocusSearch: widget.autoFocusSearch,
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
      color: Theme.of(context).colorScheme.background,
      child: Column(
        children: [
          AppBar(
              primary: !widget.hasAppBar,
              titleSpacing: 0,
              backgroundColor: Theme.of(context).colorScheme.background,
              leading: Navigator.of(context).canPop()
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        CupertinoIcons.back,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              title: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.currentTitle,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width:10),
                    Text(
                      widget.productCount,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                        color: Theme.of(context)
                            .hintColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                ],
              ),
              actions: [

                // Selector<UserModel, bool>(
                //   selector: (context, provider) => provider.loggedIn,
                //   builder: (context, loggedIn, child) {
                //     return _buildMoreWidget(loggedIn);
                //   },
                // ),
                Selector<CartModel, int>(
                  selector: (_, model) => model.totalCartQuantity,
                  builder: (context, totalCart, child) {
                    return IconButton(
                      icon: IconCart(icon: Icon(
                        CupertinoIcons.bag,
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
                const SizedBox(width: 4),
              ]),

          // const SizedBox(height: 10),
          // CustomImageView(
          //   imagePath: ImageConstant.imgRectangle162,
          //   height: getVerticalSize(180),
          //   width: getHorizontalSize(382),
          //   radius: BorderRadius.circular(getHorizontalSize(2)),
          //   margin: getMargin(top: 10),
          // ),
          // Container(
          //   margin: getMargin(top: 20, right: 15, left: 15),
          //   padding: getPadding(left: 61, top: 9, right: 61, bottom: 9),
          //   decoration: AppDecoration.outlineBluegray50019
          //       .copyWith(borderRadius: BorderRadiusStyle.roundedBorder4),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       CustomImageView(
          //           svgPath: ImageConstant.imgMenuBlack900,
          //           height: getSize(20),
          //           width: getSize(20),
          //           margin: getMargin(left: 4)),
          //       Padding(
          //           padding: getPadding(left: 8, top: 3, bottom: 1),
          //           child: Text('Filter',
          //               overflow: TextOverflow.ellipsis,
          //               textAlign: TextAlign.left,
          //               style: AppStyle.txtBarlowRegular14Black900)),
          //       const Spacer(flex: 53),
          //       SizedBox(
          //           height: getVerticalSize(20),
          //           child: VerticalDivider(
          //               width: getHorizontalSize(1),
          //               thickness: getVerticalSize(1),
          //               color: ColorConstant.black9006c)),
          //       const Spacer(flex: 46),
          //       CustomImageView(
          //           svgPath: ImageConstant.imgMenuBlack900,
          //           height: getSize(20),
          //           width: getSize(20)),
          //       Padding(
          //           padding: getPadding(left: 9, top: 4),
          //           child: Text('Sort by',
          //               overflow: TextOverflow.ellipsis,
          //               textAlign: TextAlign.left,
          //               style: AppStyle.txtBarlowRegular14Black900))
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 10),
          Padding(
            padding: EdgeInsetsDirectional.only(
                start: Navigator.of(context).canPop() ? 0 : 15,
                end: widget.filterButton != null ? 10 : 0),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    onChanged: onSearch,
                    onSubmitted: onSearch,
                    placeholder: S.of(context).searchForItems,
                    style: Theme.of(context).textTheme.bodySmall,
                    prefixIcon: Container(
                      margin: getMargin(
                        top: 8,
                        right: 12,
                        bottom: 8,
                      ),
                      child: CustomImageView(
                        svgPath: ImageConstant.imgSearch,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: ColorConstant.whiteA700,
                      boxShadow: [
                        BoxShadow(
                          color: ColorConstant.blueGray50019,
                          spreadRadius: 2,
                          blurRadius: getHorizontalSize(2),
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.filterButton != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: widget.filterButton,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    _getStickyWidget(),
                    Expanded(child: widget.builder),
                  ],
                ),
                Align(
                  alignment: Tools.isRTL(context)
                      ? Alignment.bottomLeft
                      : Alignment.bottomRight,
                  child: widget.bottomSheet,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}



