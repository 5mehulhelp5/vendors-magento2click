import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:magentoegypt/common/tools/navigate_tools.dart';
import 'package:magentoegypt/modules/dynamic_layout/header/header_search.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../common/logger.dart';
import '../../generated/l10n.dart';
import '../../menu/maintab_delegate.dart';
import '../../models/index.dart' show AppModel, UserModel, CartModel;
import '../../modules/dynamic_layout/tabbar/tabbar_icon.dart';
import '../../services/index.dart';
import '../cart/cart_screen.dart';
import '../common/app_bar_mixin.dart';
import 'category_search_screen.dart';
import 'layouts/card.dart';
import 'layouts/column.dart';
import 'layouts/grid.dart';
import 'layouts/multi_level.dart';
import 'layouts/parallax.dart';
import 'layouts/side_menu.dart';
import 'layouts/side_menu_with_group.dart';
import 'layouts/side_menu_with_sub.dart';
import 'layouts/sub.dart';

class CategoriesScreen extends StatefulWidget {
  final bool showSearch;
  final bool enableParallax;
  final double? parallaxImageRatio;

  const CategoriesScreen({
    Key? key,
    this.showSearch = true,
    this.enableParallax = false,
    this.parallaxImageRatio,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return CategoriesScreenState();
  }
}

class CategoriesScreenState extends State<CategoriesScreen>
    with
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin,
        AppBarMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    screenScrollController = _scrollController;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appModel = Provider.of<AppModel>(context);
    final categoryLayout = appModel.categoryLayout;
    // final categoryLayout = 'sideMenuWithGroup';

    //  log
    logTalker(
      classFileName: 'CategoriesScreen',
      logType: TalkerType.log,
      message: 'categoryLayout is:  $categoryLayout',
    );

    return renderScaffold(
      routeName: RouteList.category,
      backgroundColor: Theme.of(context).colorScheme.background,
      child: categoryLayout == CardCategories.type
          // Home: keep the logo + search header sticky, but NOT the
          // login/register buttons — those render inside the scrolling
          // HomeSectionsView (showAuthButtons: false) so only they scroll away.
          ? Column(
              children: <Widget>[
                const HeaderCategory(showSearch: true, showAuthButtons: false),
                Expanded(
                  child: renderCategories(
                    categoryLayout,
                    "categogies",
                    widget.enableParallax,
                    widget.parallaxImageRatio,
                    _scrollController,
                  ),
                ),
              ],
            )
          : [
              GridCategory.type,
              ColumnCategories.type,
              SideMenuCategories.type,
              SubCategories.type,
              SideMenuSubCategories.type,
              SideMenuGroupCategories.type,
              ParallaxCategories.type,
              MultiLevelCategories.type,
            ].contains(categoryLayout)
              ? Column(
                  children: <Widget>[
                    HeaderCategory(showSearch: widget.showSearch),
                    Expanded(
                      child: renderCategories(
                        categoryLayout,
                        "categogies",
                        widget.enableParallax,
                        widget.parallaxImageRatio,
                        _scrollController,
                      ),
                    )
                  ],
                )
              : renderCategories(
                  categoryLayout,
                  "categogies",
                  widget.enableParallax,
                  widget.parallaxImageRatio,
                  _scrollController,
                ),
    );
  }

  Widget renderCategories(
    String layout,
    String isComingFrom,
    bool enableParallax,
    double? parallaxImageRatio, [
    ScrollController? scrollController,
  ]) {
    return Services().widget.renderCategoryLayout(
          layout: layout,
          isComingFrom: isComingFrom,
          enableParallax: enableParallax,
          parallaxImageRatio: parallaxImageRatio,
          scrollController: scrollController,
        );
  }
}

class HeaderCategory extends StatelessWidget {
  const HeaderCategory({
    Key? key,
    required this.showSearch,
    this.showAuthButtons = true,
  }) : super(key: key);
  final bool showSearch;
  final bool showAuthButtons;

  @override
  Widget build(BuildContext context) {

    final screenSize = MediaQuery.of(context).size;
    return SizedBox(
      width: screenSize.width,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (ModalRoute.of(context)?.canPop ?? false)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.arrow_back_ios,
                    ),
                  ),
                ),
              // Padding(
              //   padding:
              //       const EdgeInsets.only(top: 10, left: 10, bottom: 10, right: 0),
              //   child: Text(
              //     S.of(context).category,
              //     style: Theme.of(context)
              //         .textTheme
              //         .headlineSmall!
              //         .copyWith(fontWeight: FontWeight.w700),
              //   ),
              // ),
              SizedBox(width: 25,),
              // IconButton(
              //   icon: const Icon(Icons.menu),
              //   onPressed: () {
              //     NavigateTools.onTapOpenDrawerMenu(context);
              //   },
              // ),
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 50,
              ),
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
            ],
          ),
          /// 🔍 Rounded "Search" view
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              // Navigate to next screen when tapped
              //Navigator.of(context).pushNamed(RouteList.categorySearch);
              // MainTabControlDelegate.getInstance().tabAnimateTo(
              //   1,
              // );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategorySearch(isNavigation: true,isComingFrom: "homeSearch"),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.all(15),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    S.of(context).search,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          // Login/Register buttons — shown in the sticky header for non-home
          // layouts. On home this is false and the buttons are rendered inside
          // the scrolling content instead, so only they scroll away.
          if (showAuthButtons) const HeaderAuthButtons(),

        ],
      ),
    );
  }
}

/// Login / Register buttons row (hidden once the user is logged in). Extracted
/// so it can live either in the sticky [HeaderCategory] or inside a scroll
/// view (home page) where it should scroll away.
class HeaderAuthButtons extends StatelessWidget {
  const HeaderAuthButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel>(
      builder: (context, userModel, _) {
        if (userModel.loggedIn) return const SizedBox.shrink();

        return Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🖤 Login Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        NavigateTools.navigateToLogin(context);
                      },
                      child: Text(
                        S.of(context).login,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 🤍 Create Account Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        NavigateTools.navigateRegister(context);
                      },
                      child: Text(
                        S.of(context).newcreateAccount,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
