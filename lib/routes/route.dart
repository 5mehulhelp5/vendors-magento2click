import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// use ClickalizeStoryWidget.StoryWidget when you want to refer to the StoryWidget from the clickalize library
// use StoryWidget when you want to refer to the StoryWidget from the dynamic_layout library

// use StoryWidget from the dynamic_layout library
import '../common/config.dart';
import '../common/constants.dart';
import '../common/tools.dart';
import '../menu/maintab.dart';
import '../models/category/category_model.dart';
import '../models/index.dart'
    show
        AppModel,
        BackDropArguments,
        Product,
        ProductModel,
        User,
        UserModel;
import '../modules/dynamic_layout/helper/helper.dart';
import '../modules/dynamic_layout/index.dart';

import '../screens/checkout/CheckoutOption.dart';
import '../screens/dynamic/dynamic_scrollable_screen.dart';
import '../screens/dynamic/dynamic_tabmenu_screen.dart';
import '../screens/index.dart';
import '../screens/order_history/index.dart';
import '../screens/returns/index.dart';
import '../screens/page_tab_screen.dart';
import '../screens/reviews/my_reviews_screen.dart';
import '../screens/subcategories/models/subcategory_model.dart';
import '../screens/settings/newsletter_subscription_screen.dart';
import '../screens/user_update/user_update_screen.dart';
import '../screens/user_update/user_update_woo_screen.dart';
import '../services/index.dart';

// use StoryWidget from the dynamic_layout library

class Routes {
  static Map<String, WidgetBuilder> getAll() => _routes;

  static final Map<String, WidgetBuilder> _routes = {
    RouteList.dashboard: (context) => const MainTabs(),
    RouteList.notificationRequest: (context) =>
        const NotificationRequestScreen(),
    RouteList.privacyTerms: (context) => const PrivacyTermScreen(),
    RouteList.register: (context) {
      final userModel = Provider.of<UserModel>(context, listen: false);
      return RegistrationScreen(
        loginFB: userModel.loginFB,
       // loginApple: userModel.loginApple,
        loginGoogle: userModel.loginGoogle,
      );
    },
    RouteList.login: (context) {
      final userModel = Provider.of<UserModel>(context, listen: false);
      return LoginScreen(
        login: userModel.login,
        loginMobile: userModel.loginMobile,
        loginFB: userModel.loginFB,
       // loginApple: userModel.loginApple,
        loginGoogle: userModel.loginGoogle,
      );
    },
    RouteList.products: (context) => const LanguageScreen(),//const ProductsScreen(),
    RouteList.wishlist: (context) => Services().widget.renderWishListScreen(),
    RouteList.notify: (context) => NotificationScreen(),
    RouteList.language: (context) => const LanguageScreen(),
    RouteList.currencies: (context) => const CurrenciesScreen(),
    RouteList.category: (context) => const CategoriesScreen(),
    // AudioPlaylistScreen(audioService: injector.get()),
  };

  static Route getRouteGenerate(RouteSettings settings) {
    var routingData = settings.name!.getRoutingData;

    printLog('[🧬Builder RouteGenerate] ${routingData.route}');

    switch (routingData.route) {
      case RouteList.backdrop:
        final arguments = settings.arguments;
        if (arguments is BackDropArguments) {
          final config = arguments.config;


          // Woo
          final routeSetting = RouteSettings(
              name: RouteList.products, arguments: settings.arguments);

          return _buildRoute(routeSetting, (context) {
            final cateId = arguments.cateId;
            final cateName = arguments.cateName;
            final tag = arguments.tag;
            final searchText = arguments.searchText;
            final products = arguments.data?.cast<Product>();
            final config = arguments.config;
            final showCountdown = arguments.showCountdown;
            final countdownDuration = arguments.countdownDuration;
            try {
              var configValue = config != null
                  ? ProductConfig.fromJson(config)
                  : ProductConfig.empty();

              var categoryId = cateId ?? configValue.category;
              var categoryName = cateName ?? configValue.name;
              var listingLocationId = config?['location']?.toString();

              // Main (top-level) categories open the merchandised landing
              // page instead of a flat product list (86d3g36q4).
              if (_isTopLevelCategory(context, categoryId)) {
                return CategoryLandingScreen(
                  categoryId: '$categoryId',
                  categoryName: categoryName,
                );
              }

              var tagId = tag ?? configValue.tag;

              if (kIsWeb ||
                  (Layout.isDisplayDesktop(context) &&
                      !Layout.isDisplayTablet(context))) {
                eventBus.fire(const EventCloseCustomDrawer());
              } else {
                eventBus.fire(const EventCloseNativeDrawer());
              }

              /// for fetching beforehand
              final productModel =
                  Provider.of<ProductModel>(context, listen: false);
              if (productModel.categoryId != categoryId) {
                productModel.setProductsList([], notify: false);
              }
              if (categoryId != null || listingLocationId != null) {
                productModel.fetchProductsByCategory(
                  categoryId: categoryId,
                  categoryName: categoryName,
                  listingLocationId: listingLocationId,
                  notify: false,
                );
              } else {
                productModel.setCategoryName(null);
              }

              /// override product config
              var productConfig = configValue
                ..category = categoryId
                ..tag = tagId
                ..searchText = searchText
                ..name =
                    configValue.onSale && showCountdown ? categoryName : null
                ..showCountDown = configValue.showCountDown &&
                    configValue.onSale &&
                    showCountdown;

              /// for caching current products list from HomeCache
              if (products != null && products.isNotEmpty) {
                productModel.setProductsList(products, notify: false);

                return ProductsScreen(
                  products: products,
                  config: productConfig,
                  listingLocation: listingLocationId,
                  countdownDuration: countdownDuration,
                  siblingParentId: arguments.siblingParentId,
                  hideDescription: arguments.hideDescription,
                );
              }

              /// clear old products
              productModel.updateTagId(
                  tagId: config != null ? config['tag'] : null, notify: false);

              return ProductsScreen(
                products: products ?? [],
                config: productConfig,
                countdownDuration: countdownDuration,
                listingLocation: listingLocationId,
                siblingParentId: arguments.siblingParentId,
                hideDescription: arguments.hideDescription,
              );
            } catch (e, trace) {
              printError(e, trace);
              return const ProductsScreen();
            }
          });
        }
        return _errorRoute();
      case RouteList.homeSearch:
        return _buildRouteFade(
          settings,
          Services().widget.renderHomeSearchScreen(),
        );

      case RouteList.productDetail:
        Product? product;

        /// Opened from the cart: the parent product plus the options the cart
        /// line was added with, so the variant picker starts on that variant.
        if (settings.arguments is ProductDetailArguments) {
          final args = settings.arguments as ProductDetailArguments;
          return _buildRoute(
            settings,
            (_) => ProductDetailScreen(
              product: args.product,
              id: args.product.id,
              preselectedOptions: args.preselectedOptions,
            ),
          );
        }

        /// The product detail is product
        if (settings.arguments is Product) {
          product = settings.arguments as Product?;
          return _buildRoute(
            settings,
            (_) => ProductDetailScreen(product: product, id: product!.id),
          );
        }

        /// The product detail is ID
        var productId = routingData.getPram('id');
        if (productId != null) {
          return _buildRoute(
            settings,
            (_) => ProductDetailScreen(id: productId),
          );
        }
        return _errorRoute();
      case RouteList.category:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (_) => CategoriesScreen(
              key: const Key('category'),
              showSearch: data.jsonData['showSearch'] ?? true,
              enableParallax: data.jsonData['parallax'] ?? false,
              parallaxImageRatio:
                  Tools.formatDouble(data.jsonData['parallaxImageRatio']),
            ),
          );
        }
        return _buildRoute(
          settings,
          (_) => const CategoriesScreen(
            key: Key('category'),
            showSearch: true,
          ),
        );
      case RouteList.categorySearch:
        return _buildRouteFade(
          settings,
          CategorySearch(),
        );

      case RouteList.orderDetail:
        final arguments = settings.arguments;
        if (arguments is OrderDetailArguments) {
          return _buildRoute(
            settings,
            (_) {
              return ChangeNotifierProvider<OrderHistoryDetailModel>.value(
                value: arguments.model,
                child: OrderHistoryDetailScreen(
                    enableReorder: arguments.enableReorder,
                    disableReview: arguments.disableReview),
              );
            },
          );
        }
        return _errorRoute();
      case RouteList.orders:
        final user = settings.arguments;
        return _buildRoute(
          settings,
          (_) => ChangeNotifierProvider<ListOrderHistoryModel>(
            create: (context) => ListOrderHistoryModel(
              repository: ListOrderRepository(
                  user: user == null ? User() : user as User),
            ),
            child: ListOrderHistoryScreen(),
          ),
        );
      case RouteList.returns:
        final returnsArg = settings.arguments;
        return _buildRoute(
          settings,
          (_) => ChangeNotifierProvider<ListReturnsModel>(
            create: (_) => ListReturnsModel(
              user: returnsArg is User ? returnsArg : User(),
            ),
            child: const ListReturnsScreen(),
          ),
        );
      case RouteList.returnCreate:
        return _buildRoute(
          settings,
          (_) => ChangeNotifierProvider<CreateReturnModel>(
            create: (_) => CreateReturnModel(),
            child: const CreateReturnScreen(),
          ),
        );
      case RouteList.returnDetail:
        final returnDetailArg = settings.arguments;
        if (returnDetailArg is ReturnDetailArguments) {
          return _buildRoute(
            settings,
            (_) => ChangeNotifierProvider<ReturnDetailModel>.value(
              value: returnDetailArg.model,
              child: const ReturnDetailScreen(),
            ),
          );
        }
        return _errorRoute();
      case RouteList.myReviews:
        return _buildRoute(settings, (_) => const MyReviewsScreen());
      case RouteList.search:
        return _buildRoute(
          settings,
          (_) => AutoHideKeyboard(
            child: Services().widget.renderSearchScreen(),
          ),
        );
      case RouteList.profile:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (_) => SettingScreen(
              settings: data.jsonData['settings'],
              subGeneralSetting: data.jsonData['subGeneralSetting'],
              background: data.jsonData['background'],
              drawerIcon: data.jsonData['drawerIcon'],
              hideUser: data.jsonData['hideUser'] ?? false,
            ),
          );
        }
        return _errorRoute();
      // No usage on this Route found
      // case RouteList.blog:
      //   final data = settings.arguments;
      //   if (data is Map) {
      //     return _buildRoute(
      //       settings,
      //       (_) => HorizontalSliderList(config: data as Map<String, dynamic>?),
      //     );
      //   }
      // return _errorRoute();
      case RouteList.page:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (_) => WebViewScreen(
              title: data.jsonData['title'],
              url: data.jsonData['url'],
              auth: data.jsonData['auth'] ?? false,
              script: '${data.jsonData['script'] ?? ''}'.isEmptyOrNull
                  ? kAdvanceConfig.webViewScript
                  : '${data.jsonData['script'] ?? ''}',
              enableBackward: data.jsonData['enableBackward'] ?? true,
              enableForward: data.jsonData['enableForward'] ?? true,
            ),
          );
        }
        return _errorRoute();
      case RouteList.html:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (_) => StaticSite(data: data.jsonData['data']),
          );
        }
        return _errorRoute();
      case RouteList.vendorDashboard:
        return _buildRoute(
          settings,
          (context) => Services().widget.renderVendorDashBoard(),
        );
      case RouteList.vendorAdmin:
        final data = settings.arguments;
        if (data is User) {
          return _buildRoute(
              settings,
              (context) =>
                  Services().widget.getAdminVendorScreen(context, data));
        }
        return _errorRoute();
      case RouteList.delivery:

        /// If the app needs to call this route, then it definitely is from MV.
        return _buildRoute(
          settings,
          (context) => Services().widget.renderDelivery(isFromMV: true),
        );
      case RouteList.dynamic:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (context) => DynamicScreen(
                configs: data.jsonData['configs'], previewKey: data.key),
          );
        }
        return _errorRoute(data.toString());
      case RouteList.tabMenu:
        final data = settings.arguments;
        if (data is List<TabBarMenuConfig>) {
          return _buildRoute(
            settings,
            (context) => DynamicTabMenuScreen(data: data),
          );
        }
        return _errorRoute(data.toString());
      case RouteList.scrollable:
        final data = settings.arguments;
        if (data is List<TabBarMenuConfig>) {
          return _buildRoute(
            settings,
            (context) => DynamicScrollableScreen(data: data),
          );
        }
        return _errorRoute(data.toString());
      case RouteList.pageTab:
        final data = settings.arguments;
        if (data is TabBarMenuConfig) {
          return _buildRoute(
            settings,
            (context) => PageTabScreen(data),
          );
        }
        return _errorRoute(data.toString());
      case RouteList.home:
        return _buildRoute(
          settings,
          (context) => const HomeScreen(),
        );
      case RouteList.onBoarding:
        return _buildRoute(
          settings,
          (context) => const OnBoardScreen(),
        );
      case RouteList.cart:
        final cartArgument = settings.arguments;
        if (cartArgument is CartScreenArgument) {
          return _buildRoute(
            settings,
            (context) => CartScreen(
              isBuyNow: cartArgument.isBuyNow,
              isModal: true,//cartArgument.isModal,
              hideNewAppBar: cartArgument.hideNewAppBar,
            ),
            fullscreenDialog: true,
          );
        }
        return _buildRoute(
          settings,
          (context) => const CartScreen(),
        );
      case RouteList.postManagement:
        return _buildRoute(
          settings,
          (context) => Services().widget.renderPostManagementScreen(),
        );
      case RouteList.checkoutOption:
        final argument = settings.arguments;
        if (argument is CheckoutArgument) {
          return _buildRoute(
            settings,
                (context) => CheckoutOption(), //Checkout(isModal: argument.isModal),
          );
        }
        return _errorRoute();
      case RouteList.checkout:
        final argument = settings.arguments;
        if (argument is CheckoutArgument) {
          return _buildRoute(
            settings,
            (context) => Checkout(isModal: argument.isModal),
          );
        }
        return _errorRoute();
      case RouteList.subCategories:
        final arguments = settings.arguments;
        if (arguments is SubcategoryArguments) {
          final subcategoryModel =
              SubcategoryModel(parentId: arguments.parentId)..getData();
          return _buildRoute(
            settings,
            (context) {
              // A main (top-level) category shows the merchandised landing
              // page (86d3g36q4) rather than a bare subcategory grid.
              if (_isTopLevelCategory(context, arguments.parentId)) {
                return CategoryLandingScreen(
                  categoryId: arguments.parentId,
                  categoryName: arguments.categoryName,
                );
              }
              return ChangeNotifierProvider.value(
                value: subcategoryModel,
                child: ChangeNotifierProvider.value(
                  value: subcategoryModel.listSubcategoryModel,
                  child: SubcategoryScreen(
                    categoryName: arguments.categoryName,
                    level: arguments.level,
                    parentId: arguments.parentId,
                  ),
                ),
              );
            },
          );
        }
        return _errorRoute();
      case RouteList.categoryLanding:
        final arguments = settings.arguments;
        if (arguments is BackDropArguments) {
          return _buildRoute(
            settings,
            (context) => CategoryLandingScreen(
              categoryId: '${arguments.cateId}',
              categoryName: arguments.cateName,
            ),
          );
        }
        return _errorRoute();
      case RouteList.newsletterSubscription:
        return _buildRoute(
            settings, (context) => const NewsletterSubscriptionScreen());
      case RouteList.updateUser:
        if (ServerConfig().isWooType) {
          return _buildRoute(settings, (context) => UserUpdateWooScreen());
        }
        return _buildRoute(settings, (context) => const UserUpdateScreen());
      case RouteList.deleteAccount:
        final arguments = settings.arguments;
        if (arguments is! DeleteAccountArguments) {
          return _errorRoute();
        }
        return _buildRoute(
          settings,
          (context) => DeleteAccountScreen(
            confirmCaptcha: arguments.confirmCaptcha,
            userToken: arguments.userToken,
          ),
        );
      default:
        final allRoutes = {
          ...getAll(),
          ...Services().getWalletRoutesWithSettings(settings),
          ...Services().getMembershipUltimateRoutesWithSettings(settings),
          ...Services().getPaidMembershipProRoutesWithSettings(settings),
          ...Services().getPOSRoutesWithSettings(settings),
          ...Services().getDigitsMobileLoginRoutesWithSettings(settings)
        };
        if (allRoutes.containsKey(settings.name)) {
          return _buildRoute(
            settings,
            allRoutes[settings.name!]!,
          );
        }

        if (ServerConfig().isVendorType()) {
          return _buildRoute(settings, Services().getVendorRoute(settings));
        }
        return _errorRoute();
    }
  }

  static WidgetBuilder? getRouteByName(String name) {
    if (_routes.containsKey(name) == false) {
      return _routes[RouteList.login];
    }
    return _routes[name];
  }

  static Route _errorRoute([String message = 'Page not founds']) {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(message),
        ),
      );
    });
  }

  static PageRouteBuilder _buildRouteFade(
    RouteSettings settings,
    Widget builder,
  ) {
    return _FadedTransitionRoute(
      settings: settings,
      widget: builder,
    );
  }

  static MaterialPageRoute _buildRoute(
      RouteSettings settings, WidgetBuilder builder,
      {bool fullscreenDialog = false}) {
    return MaterialPageRoute(
      settings: settings,
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// A top-level (main) category — Kidswear, Menswear, etc. — is stored with
  /// `parent == '0'` by [MagentoService.getCategories]. These open the
  /// merchandised landing page (86d3g36q4); everything below them keeps the
  /// normal product-list / subcategory behaviour.
  static bool _isTopLevelCategory(BuildContext context, dynamic categoryId) {
    if (categoryId == null) {
      return false;
    }
    try {
      final model = Provider.of<CategoryModel>(context, listen: false);
      final category = model.categoryList['$categoryId'];
      return category != null && category.parent == '0';
    } catch (_) {
      return false;
    }
  }
}

class _FadedTransitionRoute extends PageRouteBuilder {
  final Widget? widget;
  @override
  final RouteSettings settings;

  _FadedTransitionRoute({this.widget, required this.settings})
      : super(
          settings: settings,
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) {
            return widget!;
          },
          transitionDuration: const Duration(milliseconds: 100),
          transitionsBuilder: (BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        );
}
