// ignore_for_file: unused_local_variable

import 'package:flutter/cupertino.dart'
    show
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoIcons,
        CupertinoSliverRefreshControl,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:inspireui/icons/icon_picker.dart';
import 'package:inspireui/inspireui.dart';
import 'package:magentoegypt/core/colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../../app.dart';
import '../../common/config.dart';
import '../../common/config/configuration_utils.dart';
import '../../common/constants.dart';
import '../../common/events.dart';
import '../../common/tools.dart';
import '../../data/boxes.dart';
import '../../generated/l10n.dart';
import '../../menu/maintab_delegate.dart';
import '../../models/SectionItem.dart';
import '../../models/index.dart'
    show Address, AppModel, ProductWishListModel, User, UserModel;
import '../../models/notification_model.dart';
import '../../modules/dynamic_layout/config/app_config.dart';
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/common/index.dart';
import '../../widgets/common/refresh_scroll_physics.dart';
import '../../widgets/general/index.dart';
import '../checkout/choose_address_screen.dart';
import '../checkout/widgets/shipping_address.dart';
import '../common/app_bar_mixin.dart';
import '../common/delete_account_mixin.dart';
import '../index.dart';
import '../users/user_point_screen.dart';
import 'rate_myapp_mixin.dart';

const itemPadding = 15.0;

class SettingScreen extends StatefulWidget {
  final List<dynamic>? settings;
  final Map? subGeneralSetting;
  final String? background;
  final Map? drawerIcon;
  final bool hideUser;

  const SettingScreen({
    super.key,
    this.settings,
    this.subGeneralSetting,
    this.background,
    this.drawerIcon,
    this.hideUser = false,
  });

  @override
  SettingScreenState createState() {
    return SettingScreenState();
  }
}

class SettingScreenState extends State<SettingScreen>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<SettingScreen>,
        DeleteAccountMixin,
        RateMyAppMixin,
        WidgetsBindingObserver,
        AppBarMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  User? get user => Provider.of<UserModel>(context, listen: false).user;
  bool isAbleToPostManagement = false;

  final bannerHigh = 150.0;

  List<SectionItem> items = [];
  // Getter (not a cached `late` field) so the labels rebuild in the current
  // language when the user switches locale — otherwise they stay frozen in the
  // language that was active when the screen first built.
  List<SectionItem> get myAccountItems => [
    SectionItem(title: S.of(context).myOrders, url: "myOrders"),
    SectionItem(title: S.of(context).myWishList, url: "myWishList"),
    SectionItem(title: S.of(context).addressBook, url: "addressBook"),
    SectionItem(title: S.of(context).accountInformation, url: "accountInformation"),
    SectionItem(title: S.of(context).newsletterSubscriptions, url: "newsletterSubscription"),
    SectionItem(title: S.of(context).myReviews, url: "myReviews"),
    SectionItem(title: S.of(context).myReturns, url: "myReturns"),
    // My Reviews is native now (above): the backend added
    // GET /V1/customers/me/reviews (self), so the customer's own reviews render
    // in-app instead of the dead webview that used to land on the login form.
    //
    // Stored Payment Methods (/vault/cards/listaction/) stays removed: it also
    // opened a storefront webview that holds no Magento session — the app
    // authenticates with a REST bearer token, not a PHP session cookie — so it
    // landed on the login form, and there is still no REST surface for a card
    // vault. Restore it only once the backend provides a session-bootstrap
    // endpoint. See 86d3rrtpy.
    //
    // Discount Coupons (/referralsystem/payout/), My Wallet
    // (/wallet/wallet/transaction/) and Return Merchandise Authorization
    // (/csrma/customerrma/index/) were removed: none of those modules is
    // installed on the store, so all three 404 into Magento's no-route handler,
    // which 302s to a *catalog search* for the words in the path — the shopper
    // tapped "My Wallet" and got a product grid. Logging in would not change
    // that. Restore them only once the backend confirms the modules are live
    // (and the webview can hold a session). See 86d3rrtpy.
  ];

  // Getter (not a cached `late final` field) so section titles/items rebuild in
  // the current language on locale switch instead of staying in the language
  // active at first build.
  List<Section> get sections => [
    Section(
      title: S.of(context).customerService,
      items: [
        SectionItem(title: S.of(context).contactUs, url: "${serverConfig['url']}/eg-en/contact"),
        SectionItem(title: S.of(context).faqs, url: "${serverConfig['url']}/eg-en/faqs-english"),
        SectionItem(title: S.of(context).deliveryReturns, url: "${serverConfig['url']}/eg-en/delivery-returns-en"),
        SectionItem(title: S.of(context).termsConditions, url: "${serverConfig['url']}/eg-en/terms-conditions-en"),
        SectionItem(title: S.of(context).privacyPolicy, url: "${serverConfig['url']}/eg-en/privacy-policy-en"),
      ],
    ),
    Section(
      title:  S.of(context).aboutLocafy,
      items: [
        SectionItem(title: S.of(context).aboutUs, url: "${serverConfig['url']}/eg-en/about-us"),
      ],
    ),
    Section(
      title: S.of(context).quickLinks,
      // Quick Links mirror the website footer (testing.locafy.market):
      // Kids Collections, Newborn Collections, All Brands.
      items: [
        SectionItem(title: S.of(context).kidsCollections, url: "${serverConfig['url']}/eg-en/kidswear/kids-3-12-years.html"),
        SectionItem(title: S.of(context).newbornCollections, url: "${serverConfig['url']}/eg-en/newborn.html"),
        SectionItem(title: S.of(context).allBrands, url: "${serverConfig['url']}/eg-en/csmarketplace/vshops/index/?search="),
      ],
    ),
    Section(
      title: S.of(context).followUs,
      items: [
        SectionItem(title: "", url: "https://example.com/men"),
        SectionItem(title: "", url: "https://example.com/women"),
        SectionItem(title: "", url: "https://example.com/kids"),
        SectionItem(title: "", url: "https://example.com/brands"),
      ],
    ),
  ];

  void checkAddPostRole() {
    for (var legitRole in addPostAccessibleRoles) {
      if (user!.role == legitRole) {
        setState(() {
          isAbleToPostManagement = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    screenScrollController = _scrollController;
    WidgetsBinding.instance.addObserver(this);
    // Reflect the real OS notification permission on the toggle. Previously the
    // toggle showed only a stale local flag, so a notification that was enabled
    // at the OS level (iOS/Android) could still read as OFF here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NotificationModel>(context, listen: false).checkGranted();
      }
    });
  }

  /// Pull-to-refresh: re-read the account from the server (name, email and
  /// phone can change on the website) and re-check the OS notification
  /// permission, which is what [initState] does on open.
  Future<void> _reload() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    if (userModel.loggedIn) {
      await userModel.getUser();
    }
    if (mounted) {
      await Provider.of<NotificationModel>(context, listen: false)
          .checkGranted();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Returning from the OS Settings (where the permission may have been
    // toggled) — re-sync the notification toggle to the real state.
    if (state == AppLifecycleState.resumed && mounted) {
      Provider.of<NotificationModel>(context, listen: false).checkGranted();
    }
  }

  void updateAddress(Address? newAddress) {

  }
  /// Render the Delivery Menu.
  /// Currently support WCFM
  Widget renderDeliveryBoy() {
    var isDelivery = user?.isDeliveryBoy ?? false;

    if (!isDelivery) {
      return const SizedBox();
    }

    return Card(
      color: Theme.of(context).colorScheme.background,
      margin: const EdgeInsets.only(bottom: 2.0),
      elevation: 0,
      child: ListTile(
        onTap: () {
          FluxNavigate.push(
            MaterialPageRoute(
              builder: (context) =>
                  Services().widget.getDeliveryScreen(context, user)!,
            ),
            forceRootNavigator: true,
          );
        },
        leading: Icon(
          CupertinoIcons.cube_box,
          size: 24,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          S.of(context).deliveryManagement,
          style: const TextStyle(fontSize: 16),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  /// Render the Admin Vendor Menu.
  /// Currently support WCFM & Dokan. Will support WooCommerce soon.
  Widget renderVendorAdmin() {
    var isVendor = user?.isVender ?? false;

    if (!isVendor ||
        ServerConfig().isListeoType ||
        !ServerConfig().typeName.isMultiVendor) {
      return const SizedBox();
    }

    return Card(
      color: Theme.of(context).colorScheme.background,
      margin: const EdgeInsets.only(bottom: 2.0),
      elevation: 0,
      child: ListTile(
        onTap: () {
          FluxNavigate.pushNamed(
            RouteList.vendorAdmin,
            arguments: user,
            forceRootNavigator: true,
          );
        },
        leading: Icon(
          Icons.dashboard,
          size: 24,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          S.of(context).vendorAdmin,
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget renderVendorVacation() {
    var isVendor = user?.isVender ?? false;

    if ((ServerConfig().typeName.isMultiVendor && !isVendor) ||
        !ServerConfig().typeName.isWcfm ||
        !kVendorConfig.disableNativeStoreManagement) {
      return const SizedBox();
    }

    return Card(
      color: Theme.of(context).colorScheme.background,
      margin: const EdgeInsets.only(bottom: 2.0),
      elevation: 0,
      child: ListTile(
        onTap: () {
          FluxNavigate.push(
            MaterialPageRoute(
              builder: (context) => Services().widget.renderVacationVendor(
                    user!.id!,
                    user!.cookie!,
                    isFromMV: true,
                  ),
            ),
          );
        },
        leading: Icon(
          Icons.house,
          size: 24,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          S.of(context).storeVacation,
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  /// Render the custom profile link via Webview
  /// Example show some special profile on the woocommerce site: wallet, wishlist...
  Widget renderWebViewProfile() {
    if (user == null) {
      return const SizedBox();
    }

    return Card(
      color: Theme.of(context).colorScheme.background,
      margin: const EdgeInsets.only(bottom: 2.0),
      elevation: 0,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebView(
                auth: true,
                url: '${ServerConfig().url}/my-account',
                title: S.of(context).updateUserInfor,
              ),
            ),
          );
        },
        leading: Icon(
          CupertinoIcons.profile_circled,
          size: 24,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          S.of(context).updateUserInfor,
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Theme.of(context).colorScheme.secondary,
          size: 18,
        ),
      ),
    );
  }

  Widget renderItem(value) {
    Widget icon;
    String title;
    Widget? trailing;
    Function() onTap;
    var isMultiVendor = ServerConfig().typeName.isMultiVendor;
    var subGeneralSetting = widget.subGeneralSetting != null
        ? ConfigurationUtils.loadSubGeneralSetting(widget.subGeneralSetting!)
        : kSubGeneralSetting;

    var item = subGeneralSetting[value];

    if (value.contains('web')) {
      return GeneralWebWidget(item: item);
    }


    if (value.contains('title')) {
      return GeneralTitleWidget(item: item, itemPadding: itemPadding);
    }

    if (value.contains('button')) {
      return GeneralButtonWidget(item: item);
    }

    if (value.contains('product-')) {
      return GeneralProductWidget(item: item);
    }

    if (value.contains('category-')) {
      return GeneralCategoryWidget(item: item);
    }

    if (value.contains('banner-')) {
      return GeneralBannerWidget(item: item);
    }

    if (value.contains('blog-')) {
      return GeneralBlogWidget(item: item);
    }

    if (value.contains('blogCategory-')) {
      return GeneralBlogCategoryWidget(item: item);
    }

    switch (value) {
      case 'products':
        {
          if (!(user != null ? user!.isVender : false) || !isMultiVendor) {
            return const SizedBox();
          }
          title = S.of(context).myProducts;
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.cube_box);
          onTap = () => Navigator.pushNamed(context, RouteList.productSell);
          break;
        }

      case 'chat':
        {
          if (user == null || ServerConfig().isListingType || !isMultiVendor) {
            return const SizedBox();
          }
          title = S.of(context).conversations;
          icon =
              const SettingScreenItemIcon(icon: CupertinoIcons.chat_bubble_2);

          onTap = () {
            Navigator.pushNamed(
              context,
              RouteList.listChat,
              arguments: isMultiVendor && user?.isVender == true,
            );
          };
          break;
        }
    case 'addresshistory':
      if (user == null) {
        return const SizedBox();
      }
      {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios, size: 18, color: kGrey600)
          ],
        );

        title = S.of(context).addressHistory;
        icon = const SettingScreenItemIcon(icon: CupertinoIcons.location_solid);
        onTap = () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChooseAddressScreen(updateAddress,true),
          ),
        );
        break;
      }
      case 'wishlist':
        if (user == null) {
          return const SizedBox();
        }
        {
          trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<ProductWishListModel>(
                builder: (context, model, child) {
                  if (model.products.isNotEmpty) {
                    return Text(
                      '${model.products.length} ${S.of(context).items}',
                      style: TextStyle(
                          fontSize: 14, color: Theme.of(context).primaryColor),
                    );
                  } else {
                    return const SizedBox();
                  }
                },
              ),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_forward_ios, size: 18, color: kGrey600)
            ],
          );

          title = S.of(context).myWishList;
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.heart);
          onTap = () => MainTabControlDelegate.getInstance().tabAnimateTo(2);//Navigator.of(context).pushNamed(RouteList.wishlist);
          break;
        }
      case 'notifications':
        {
          return Consumer<NotificationModel>(builder: (context, model, child) {
            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 2.0,left: 15,right: 10),
                  elevation: 0,
                  child: SwitchListTile(
                  //  secondary: const SettingScreenItemIcon(icon: CupertinoIcons.bell),
                    value: model.enable,
                    activeColor: AppColors.kPrimaryRed,
                    onChanged: (bool enableNotification) async {
                      if (enableNotification) {
                        await model.enableNotification();
                        // Still off => the OS notification permission was
                        // denied (often permanently). Guide the user to the
                        // system settings instead of silently doing nothing.
                        if (!model.enable && mounted) {
                          _promptOpenNotificationSettings();
                        }
                      } else {
                        model.disableNotification();
                      }
                    },
                    title: Text(
                      S.of(context).getNotification,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                // const Divider(
                //   color: Colors.black12,
                //   height: 1.0,
                //   indent: 75,
                //   //endIndent: 20,
                // ),
                if (model.enable) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 2.0,left: 15,right: 15),
                    elevation: 0,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteList.notify);
                      },
                      child: ListTile(
                     //   leading: const SettingScreenItemIcon(icon: CupertinoIcons.list_bullet),
                        title: Text(S.of(context).listMessages,style: const TextStyle(fontSize: 14),),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: kGrey600,
                        ),
                      ),
                    ),
                  ),
                  // const Divider(
                  //   color: Colors.black12,
                  //   height: 1.0,
                  //   indent: 75,
                  //   //endIndent: 20,
                  // ),
                ],
              ],
            );
          });
        }
      case 'language':
        {
          return Selector<AppModel, String?>(
            selector: (context, model) => model.langCode,
            builder: (context, langCode, _) {
              final languages = getLanguages();
              return _SettingItem(
                icon: const SettingScreenItemIcon(icon: CupertinoIcons.globe),
                title: S.of(context).language,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languages.firstWhere(
                        (element) => langCode == element['code'],
                        orElse: () => {'text': ''},
                      )['text'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: kGrey600,
                    )
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(RouteList.language);
                },
              );
            },
          );
        }
      case 'currencies':
        return const SizedBox();
        {
          if (ServerConfig().isListingType) {
            return const SizedBox();
          }
          return Selector<AppModel, String?>(
            selector: (context, model) => model.currency,
            builder: (context, currency, _) {
              return _SettingItem(
                icon: const SettingScreenItemIcon(
                    icon: CupertinoIcons.money_dollar_circle),
                title: S.of(context).currencies,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currency',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: kGrey600,
                    )
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(RouteList.currencies);
                },
              );
            },
          );
        }
      case 'darkTheme':
        return const SizedBox();
        {
          return Selector<AppModel, bool>(
            selector: (context, model) => model.darkTheme,
            builder: (context, darkTheme, _) {
              return _SettingItem(
                icon: darkTheme
                    ? const SettingScreenItemIcon(icon: CupertinoIcons.moon)
                    : const SettingScreenItemIcon(icon: CupertinoIcons.sun_min),
                title: S.of(context).appearance,
                trailing: Text(
                  darkTheme
                      ? S.of(context).darkTheme
                      : S.of(context).lightTheme,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                onTap: () {
                  context.read<AppModel>().updateTheme(!darkTheme);
                },
              );
            },
          );
        }
      case 'order':
        {
          var items = UserBox().orders;
          if (user == null && items.isEmpty) {
            return const SizedBox();
          }
          if (ServerConfig().isListingType) {
            return const SizedBox();
          }
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.time);

          title = S.of(context).orderHistory;
          onTap = () {
            final user = Provider.of<UserModel>(context, listen: false).user;
            FluxNavigate.pushNamed(
              RouteList.orders,
              arguments: user,
            );
          };
          break;
        }
      case 'point':
        {
          if (!(kAdvanceConfig.enablePointReward && user != null)) {
            return const SizedBox();
          }
          if (ServerConfig().isListingType) {
            return const SizedBox();
          }
          icon =
              const SettingScreenItemIcon(icon: CupertinoIcons.bag_badge_plus);

          title = S.of(context).myPoints;
          onTap = () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserPointScreen(),
                ),
              );
          break;
        }
      case 'rating':
        {
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.star);
          title = S.of(context).rateTheApp;
          onTap = showRateMyApp;
          break;
        }
      case 'privacy':
        {
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.doc_text);

          title = S.of(context).agreeWithPrivacy;
          onTap = () {
            final privacy = subGeneralSetting['privacy'];
            final pageId = privacy?.pageId ??
                (privacy?.webUrl == null
                    ? kAdvanceConfig.privacyPoliciesPageId
                    : null);
            String? pageUrl =
                privacy?.webUrl ?? kAdvanceConfig.privacyPoliciesPageUrl;
            // if (pageId != null) {
            //   Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => PostScreen(
            //           pageId: pageId,
            //           pageTitle: S.of(context).agreeWithPrivacy,
            //         ),
            //       ));
            //   return;
            // }
            if (pageUrl.isNotEmpty) {
              ///Display multiple languages WebView
              var locale =
                  Provider.of<AppModel>(context, listen: false).langCode;
              pageUrl += '?lang=$locale';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebView(
                    url: pageUrl,
                    title: S.of(context).agreeWithPrivacy,
                  ),
                ),
              );
            }
          };
          break;
        }
      case 'about':
        {
          icon = const SettingScreenItemIcon(icon: CupertinoIcons.info);
          title = S.of(context).aboutUs;
          onTap = () {
            final about = subGeneralSetting['about'];
            final aboutUrl = about?.webUrl ?? SettingConstants.aboutUsUrl;

            if (kIsWeb) {
              return Tools.launchURL(aboutUrl);
            }
            return FluxNavigate.push(
              MaterialPageRoute(
                builder: (context) => WebView(
                  url: aboutUrl,
                  // title: S.of(context).aboutUs,
                ),
              ),
            );
          };
          break;
        }

      case 'post':
        {
          if (user != null) {
            trailing = const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: kGrey600,
            );
            title = S.of(context).postManagement;
            icon = Icon(
              CupertinoIcons.chat_bubble_2,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            );

            onTap = () {
              Navigator.of(context).pushNamed(RouteList.postManagement);
            };
          } else {
            return const SizedBox();
          }

          break;
        }
      default:
        {
          trailing =
              const Icon(Icons.arrow_forward_ios, size: 18, color: kGrey600);
          icon = Icon(
            Icons.error,
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
          );
          title = S.of(context).dataEmpty;
          onTap = () {};
        }
    }
    return _SettingItem(
      icon: icon,
      title: title,
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _handleUpdateProfile() async {
    final hasChangePassword = await FluxNavigate.pushNamed(
      RouteList.updateUser,
    ) as bool?;

    /// If change password with Shopify
    /// need to log out and log in again
    if (ServerConfig().isShopify && (hasChangePassword ?? false)) {
      await _showDialogLogout();
    }
  }

  /// Shown when the user tries to enable notifications but the OS permission
  /// is denied — offers to jump straight to the app's system settings.
  Future<void> _promptOpenNotificationSettings() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).getNotification),
        content: Text(S.of(context).notificationBlockedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.of(context).settings),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
  }

  Widget renderDrawerIcon() {
    var icon = Icons.blur_on;
    if (widget.drawerIcon != null) {
      icon = iconPicker(
              widget.drawerIcon!['icon'], widget.drawerIcon!['fontFamily']) ??
          Icons.blur_on;
    }
    return Icon(
      icon,
      color: Colors.white70,
    );
  }

  Widget renderUser() {
    return ListenableProvider.value(
      value: Provider.of<UserModel>(context),
      child: Consumer<UserModel>(
        builder: (context, model, child) {
          final user = model.user;
          final loggedIn = model.loggedIn;
          return Column(
            children: [
              const SizedBox(height: 10.0),
              if (user != null && user.name != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: (user.picture?.isNotEmpty ?? false)
                        ? Hero(
                            tag: 'user-avatar-${user.picture}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: FluxImage(
                                imageUrl: user.picture!,
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.face,
                            size: 50,
                          ),
                    title: Text(
                      user.name ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                    ),
                    horizontalTitleGap: 24.0,
                    subtitle: (user.identifierInformation.isNotEmpty)
                        ? Text(
                            user.identifierInformation,
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.secondary),
                          )
                        : null,
                    onTap: _handleUpdateProfile,
                    trailing: !ServerConfig().isWordPress
                        ? IconButton(
                            onPressed: _handleUpdateProfile,
                            icon: const Icon(Icons.edit),
                          )
                        : null,
                  ),
                ),
              if (user == null)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        10.0), // Set the desired border radius
                  ),
                  color: Theme.of(context).cardColor,
                  margin: const EdgeInsets.only(bottom: 2.0),
                  elevation: 0,
                  child: ListTile(
                    onTap: () {
                      if (!loggedIn) {
                        NavigateTools.navigateToLogin(context);
                        return;
                      }
                      Provider.of<UserModel>(context, listen: false).logout();
                      if (kLoginSetting.isRequiredLogin) {
                        Navigator.of(
                          App.fluxStoreNavigatorKey.currentContext!,
                        ).pushNamedAndRemoveUntil(
                          RouteList.login,
                          (route) => false,
                        );
                      }
                    },
                 //   leading: const Icon(Icons.person),
                    title: Text(
                      loggedIn ? S.of(context).logout : S.of(context).login,
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 18, color: kGrey600),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget>? renderActions({Color? color, bool sliver = false}) {
    var canPop = ModalRoute.of(context)?.canPop ?? false;
    var popButton = GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Icon(
        Icons.close,
        color: color ?? Colors.white,
      ),
    );
    var actions = sliver
        ? <Widget>[
            Selector<AppModel, AppBarConfig?>(
              selector: (context, model) => model.appConfig?.appBar,
              shouldRebuild: (oldValue, newValue) =>
                  oldValue?.toJson().toString() !=
                  newValue?.toJson().toString(),
              builder: (context, value, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: isAtTopNotifier,
                  builder: (context, bool isAtTop, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: EdgeInsets.symmetric(vertical: isAtTop ? 4 : 0),
                      decoration: value?.backgroundColor != null
                          ? BoxDecoration(
                              color: HexColor(value?.backgroundColor),
                            )
                          : null,
                      child: popButton,
                    );
                  },
                );
              },
            )
          ]
        : <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: popButton,
            )
          ];
    return canPop ? actions : null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Listen to the auth state so this screen rebuilds immediately on
    // login/logout (the `user` getter reads with listen:false). Without this the
    // My Account page kept showing the old logged-in/out state until a language
    // switch forced a rebuild.
    Provider.of<UserModel>(context);

    var settings = widget.settings ?? kDefaultSettings;
    var background = widget.background ?? kProfileBackground;

    final appBarWidget = (showAppBar(RouteList.profile))
        ? getSliverAppBarWidget(
            appBar: appBar,
            actions: renderActions(
              color: Theme.of(context).colorScheme.secondary,
              sliver: true,
            ),
          )
        : SliverAppBar(
            backgroundColor: Theme.of(context).primaryColor,
            leading: (context.read<AppModel>().appConfig?.drawer?.enable ??
                    true)
                ? IconButton(
                    icon: renderDrawerIcon(),
                    onPressed: () => NavigateTools.onTapOpenDrawerMenu(context),
                  )
                : null,
            expandedHeight: bannerHigh,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                S.of(context).settings,
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
              background: FluxImage(
                imageUrl: background,
                fit: BoxFit.cover,
              ),
            ),
            actions: renderActions(),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        // decoration: const BoxDecoration(
        //   image: DecorationImage(
        //     image: AssetImage(
        //         'assets/images/settings-bg.png'), // Replace with your own image path
        //     fit: BoxFit.cover,
        //   ),
        // ),
        child: CustomScrollView(
          controller: _scrollController,
          // RefreshScrollPhysics so the pull is reported even when the account
          // list is shorter than the viewport.
          physics: const RefreshScrollPhysics(),
          slivers: <Widget>[
            //appBarWidget,
            CupertinoSliverRefreshControl(onRefresh: _reload),
            SliverToBoxAdapter(
                child: SafeArea(child: (user == null || items.isNotEmpty) ? HeaderSettingScreen(items: items,onBack: () {
                  items.clear();
                  setState(() {});
                },):const SizedBox())),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  if(items.length > 0 && items.first.title.isEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      socialIcon(
                        context,
                        'assets/icons/brands/instagram.svg',
                        'https://www.instagram.com/locafy.eg/',
                      ),
                      socialIcon(
                        context,
                        'assets/icons/brands/facebook.svg',
                        'https://www.facebook.com/Locafy.eg',
                      ),
                      socialIcon(
                        context,
                        'assets/icons/brands/tiktok.svg',
                        'https://www.tiktok.com/@locafy.eg',
                      ),
                      socialIcon(
                        context,
                        'assets/icons/brands/linkedIn.svg',
                        'https://www.linkedin.com/company/locafy-eg/',
                      ),
                    ],
                  )
                  else if(items.length > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                         horizontal: 30,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          items.length,
                              (index) {
                            var item = items[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6.0 //isTitle ? 0.0 : itemPadding,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  _openSectionItem(item);
                                },
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    decoration: TextDecoration.underline,
                                  )),
                              )
                            );
                          },
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SizedBox(height: 10.0),
                          if (user != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.name ?? '',
                                  style: const TextStyle(fontSize: 18,fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 20.0),
                                Text(S.of(context).myAccount,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],),)
                          else
                            Padding(
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
                       //   const SizedBox(height: 10.0),
                          // Text(
                          //   S.of(context).generalSetting,
                          //   style: const TextStyle(
                          //       fontSize: 18, fontWeight: FontWeight.w600),
                          // ),
                          // const SizedBox(height: 10.0),
                       //   renderVendorAdmin(),

                          /// Render some extra menu for Vendor.
                          /// Currently support WCFM & Dokan. Will support WooCommerce soon.
                          // if (ServerConfig().typeName.isMultiVendor &&
                          //     (user?.isVender ?? false)) ...[
                          //   Services().widget.renderVendorOrder(context),
                          //   renderVendorVacation(),
                          // ],
                          // renderDeliveryBoy(),

                          /// Render custom Wallet feature
                          // renderWebViewProfile(),

                          /// render some extra menu for Listing
                          if (user != null && ServerConfig().isListingType) ...[
                            Services().widget.renderNewListing(context),
                            Services().widget.renderBookingHistory(context),
                          ],

                          // const SizedBox(height: 10.0),
                          // if (user != null)
                          //   const Divider(
                          //     color: Colors.black12,
                          //     height: 1.0,
                          //     indent: 75,
                          //     //endIndent: 20,
                          //   ),
                        ],
                      ),
                    ),

                      if (user != null)
                        ...List.generate(
                          myAccountItems.length,
                              (index) {
                            var section = myAccountItems[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0 //isTitle ? 0.0 : itemPadding,
                              ),
                              child: _SettingItem(
                                title:section.title,
                                onTap: () async {
                                  _openSectionItem(section);
                                },
                              ),
                            );
                          },
                        ),
                    /// render list of dynamic menu
                    /// this could be manage from the Fluxbuilder
                    Container(
                      padding: const EdgeInsets.only(top: 10, bottom: 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadiusDirectional.circular(10),
                      ),
                      //  margin: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: List.generate(
                          settings.length,
                              (index) {
                            var item = settings[index];
                            var isTitle = item.contains('title');
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0 //isTitle ? 0.0 : itemPadding,
                              ),
                              child: renderItem(item),
                            );
                          },
                        ),
                      ),
                    ),
                    // The top-level "Contact us" / "تواصل معنا" tile was removed
                    // (86d3fh4g7 #6). It was hand-placed here rather than driven
                    // by [sections], which is why deleting the "for sellers"
                    // Section left it on screen and the fix looked like it had
                    // failed. Contact us is still reachable under Customer
                    // Service. (It also launched an unlocalised "/contact" with
                    // no store code, unlike every sections entry.)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 5
                      ),
                      child:Text(S.of(context).support,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        // horizontal: itemPadding,
                      ),
                      child: Column(
                        children: List.generate(
                          sections.length,
                              (index) {
                            var section = sections[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0 //isTitle ? 0.0 : itemPadding,
                              ),
                              child: _SettingItem(
                                title:section.title,
                                onTap: () async {
                                 setState(() {
                                   items = section.items;
                                 });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Selector<AppModel, String?>(
                      selector: (context, model) => model.langCode,
                      builder: (context, langCode, _) {
                        final languages = getLanguages();
                      return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// 🔹 Title
                              Text(
                                S.of(context).languageAndRegion,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 12),
                              InkWell(
                                onTap: (){
                                  Navigator.of(context).pushNamed(RouteList.language);
                                },
                                child: Row(
                                  children: [
                                    /// 🌐 Icon
                                    Icon(Icons.language, size: 22, color: Colors.black54),
                                    const SizedBox(width: 12),
                                    /// Texts
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            languages.firstWhere(
                                                  (element) => langCode == element['code'],
                                              orElse: () => {'text': ''},
                                            )['text'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            S.of(context).language,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    /// Arrow
                                    Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),),
                            ],
                          ),
                        );
                      },
                    ),
                    // if (user != null &&
                    //     kAdvanceConfig.gdprConfig.showDeleteAccount &&
                    //     ServerConfig().isSupportDeleteAccount)
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          // horizontal: itemPadding,
                        ),
                        child: _SettingItem(
                          iconWidget: const SettingScreenItemIcon(
                              icon: CupertinoIcons.delete),
                          titleWidget: Text(
                            S.current.deleteAccount,
                            style: const TextStyle(color: kColorRed),
                          ),
                          onTap: () async {
                            final acceptDelete =
                            await showConfirmDeleteAccountDialog(
                              App.fluxStoreNavigatorKey.currentContext ?? context,
                            );
                            if (acceptDelete) {
                              _processDeleteAccount();
                            }
                          },
                        ),
                      ),
                      if (user != null)
                        Center(
                          child: TextButton(
                            onPressed: _onLogout,
                            child: Text(
                              S.of(context).signOut,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 30),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget socialIcon(BuildContext context, String asset, String url) {
    return GestureDetector(
      onTap: () => openUrl(url),
      child: SvgPicture.asset(
        asset,
        height: 35,
        width: 35,
        colorFilter: ColorFilter.mode(
          Theme.of(context).primaryColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _openAuthWebView(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebView(
          auth: true,
          url: url,
          title: title,
        ),
      ),
    );
  }

  /// Rewrites a store-view URL to the Arabic store view when the app language
  /// is Arabic, so support / quick-link pages open in the matching language
  /// (Arabic pages -> /eg-ar/..., English pages -> /eg-en/...).
  /// CMS pages whose Arabic slug differs are mapped explicitly; pages that
  /// have no Arabic version yet keep the English URL to avoid a 404.
  String _localizeUrl(String url) {
    final isArabic =
        (Provider.of<AppModel>(context, listen: false).langCode ?? '')
            .toLowerCase()
            .startsWith('ar');
    if (!isArabic || !url.contains('/eg-en/')) return url;

    // CMS pages with no Arabic version -> keep the English URL. Empty now that
    // all four support pages exist in Arabic, but keep the escape hatch: the
    // generic /eg-en/ -> /eg-ar/ rewrite below would otherwise send a new
    // English-only page to the store's no-route handler, which 302s to a
    // catalog-search results page rather than showing a 404.
    const keepEnglish = <String>[];
    for (final slug in keepEnglish) {
      if (url.contains(slug)) return url;
    }

    var localized = url.replaceFirst('/eg-en/', '/eg-ar/');
    // CMS pages whose Arabic slug differs from the English one. All verified
    // live against the eg-ar store view and matching the website's Arabic
    // footer links (86d3fh4g7 #4).
    const slugMap = {
      'delivery-returns-en': 'delivery-returns-ar',
      'terms-conditions-en': 'terms-conditions-ar',
      'faqs-english': 'faqs-ar',
      'privacy-policy-en': 'privacy-policy-ar',
    };
    slugMap.forEach((en, ar) {
      localized = localized.replaceFirst(en, ar);
    });
    return localized;
  }

  void _openSectionItem(SectionItem item) {
    final url = item.url;
    if (url.startsWith('http')) {
      _openAuthWebView(_localizeUrl(url), item.title);
      return;
    }
    switch (url) {
      case 'myOrders':
        FluxNavigate.pushNamed(
          RouteList.orders,
          arguments: user,
        );
        break;
      case 'myReturns':
        FluxNavigate.pushNamed(
          RouteList.returns,
          arguments: user,
        );
        break;
      case 'myReviews':
        FluxNavigate.pushNamed(RouteList.myReviews);
        break;
      case 'myWishList':
        // By route, not by bottom-tab index: tabAnimateTo(2) hard-codes the
        // wishlist's position in the tab bar, so adding, removing or reordering
        // a tab silently sends this row to whatever screen now sits at index 2
        // — a wrong destination rather than an obvious break.
        FluxNavigate.pushNamed(RouteList.wishlist);
        break;
      case 'addressBook':
        // ChooseAddressScreen, not ShippingAddress: the latter is the *add a
        // new address* form, so "Address Book" opened an empty form and the
        // shopper's saved addresses were nowhere to be seen — reported as "no
        // old addresses show up" (86d3rrpqr). ChooseAddressScreen lists the
        // saved addresses and offers a "+" to add one, and is what the other
        // entry point to this screen in this same file already uses.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChooseAddressScreen(updateAddress, true),
          ),
        );
        break;
      case 'accountInformation':
        // Was a webview on '{store}/my-account' — the WooCommerce account path,
        // left over from the FluxStore Woo original. Magento has no such route,
        // so its no-route handler turned it into a catalog search for the words
        // "my account", and because the path carries no store-view prefix it
        // resolved to the *Arabic* store view: an English shopper tapped
        // "Account Information" and got an Arabic product grid (86d3rrtpy).
        // UserUpdateScreen is native and already used by _handleUpdateProfile.
        FluxNavigate.pushNamed(RouteList.updateUser);
        break;
      case 'newsletterSubscription':
        FluxNavigate.pushNamed(RouteList.newsletterSubscription);
        break;
      default:
        // Every url either starts with http (handled above) or matches a case,
        // so this is unreachable today — but a typo in a new sentinel would
        // otherwise produce a row that silently does nothing, which is exactly
        // the failure this ticket was first misdiagnosed as.
        printLog('[Settings] unhandled My Account item: $url');
        assert(false, 'Unhandled My Account menu item: $url');
    }
  }

  void _processDeleteAccount() async {
    final result = await FluxNavigate.pushNamed(
      RouteList.deleteAccount,
      arguments: DeleteAccountArguments(
        confirmCaptcha: "PERMANENTLY DELETE",
        userToken:
            Provider.of<UserModel>(context, listen: false).user?.cookie ?? '',
      ),
    ) as bool?;
    if (result ?? false) {
      _deleteUserOnFirebase();
      _onLogout();
    }
  }

  void _onLogout() {
    eventBus.fire(const EventExpiredCookie());
  }

  void _deleteUserOnFirebase() {
    Services().firebase.deleteAccount();
  }

  /// Need to force log out when change the password for Shopify
  Future<void> _showDialogLogout() async {
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(S.current.notice),
        content: Text(S.current.needToLoginAgain),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _onLogout();
            },
            child: Text(S.current.ok),
          )
        ],
      ),
    );
  }
}

class SettingScreenItemIcon extends StatelessWidget {
  const SettingScreenItemIcon({
    super.key,
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox();
    // return Container(
    //   padding: const EdgeInsets.all(5),
    //   width: 40,
    //   height: 40,
    //   decoration: BoxDecoration(
    //     color: isDarkMode(context)
    //         ? AppColors.whiteA700.withOpacity(0.7)
    //         : AppColors.red80063,
    //     borderRadius: BorderRadius.circular(7),
    //   ),
    //   child: Icon(
    //     icon,
    //     color: AppColors.kPrimaryRed,
    //     size: 24,
    //   ),
    // );
  }
}

class _SettingItem extends StatelessWidget {
  final Widget? icon;
  final Widget? iconWidget;
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingItem({
    Key? key,
    this.icon,
    this.iconWidget,
    this.title,
    this.titleWidget,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 2.0,left: 15,right: 15),
          elevation: 0,
          child: ListTile(
         //   leading: icon ?? iconWidget,
            title: title != null
                ? Text(
                    title!,
                    style: const TextStyle(fontSize: 14),
                  )
                : titleWidget,
            trailing: trailing ??
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: kGrey600,
                ),
            onTap: onTap,
          ),
        ),
        // const Divider(
        //   color: Colors.black12,
        //   height: 1.0,
        //   indent: 75,
        //   //endIndent: 20,
        // ),
      ],
    );
  }
}

class HeaderSettingScreen extends StatelessWidget {
  final List<SectionItem> items;
  final VoidCallback onBack;
   HeaderSettingScreen({Key? key,required this.items,required this.onBack,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return SafeArea(child: Container(
      width: screenSize.width,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(
              10.0), // Set the desired radius for the top left corner
          bottomLeft: Radius.circular(
              10.0), // Set the desired radius for the bottom left corner
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if(items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed:onBack
          ),
          Spacer(),
          // Image.asset(
          //   'assets/images/logo.png',
          //   width: 150,
          //   height: 50,
          // ),
          if(items.isEmpty)
          Text(
            S.of(context).generalSettings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Spacer()
          // const Icon(
          //   CupertinoIcons.search,
          //   color: Colors.transparent,
          // ),
        ],
      ),
    ));
  }
}
