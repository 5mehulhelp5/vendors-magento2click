import 'package:flutter/material.dart';
import 'package:magentoegypt/common/extensions.dart';
import 'package:magentoegypt/env.dart';
import 'package:magentoegypt/models/banner_images_model.dart';
import 'package:magentoegypt/modules/dynamic_layout/banner/app_banner.dart';
import 'package:magentoegypt/modules/dynamic_layout/banner/banner_group_items.dart';
import 'package:magentoegypt/modules/dynamic_layout/banner/banner_horizontal.dart';
import 'package:magentoegypt/modules/dynamic_layout/banner/banner_slider.dart';
import 'package:magentoegypt/modules/dynamic_layout/category/category_icon.dart';
import 'package:magentoegypt/modules/dynamic_layout/category/category_image.dart';
import 'package:magentoegypt/modules/dynamic_layout/category/category_menu_with_products.dart';
import 'package:magentoegypt/modules/dynamic_layout/category/category_text.dart';
import 'package:magentoegypt/modules/dynamic_layout/helper/home_section_header_text.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../models/index.dart';
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import 'banner/banner_animate_items.dart';
import 'button/button.dart';
import 'config/index.dart';
import 'divider/divider.dart';
import 'header/header_search.dart';
import 'header/header_text.dart';
import 'helper/helper.dart';
import 'logo/logo.dart';
import 'product/product_list_simple.dart';
import 'product/product_recent_placeholder.dart';
import 'spacer/spacer.dart';

class DynamicLayout extends StatefulWidget {
  final dynamic config;
  final bool cleanCache;

  const DynamicLayout({super.key, this.config, this.cleanCache = false});

  @override
  State<DynamicLayout> createState() => _DynamicLayoutState();
}

class _DynamicLayoutState extends State<DynamicLayout> {
  List<BannerImagesModel>? banners = [];

  @override
  void initState() {
    super.initState();

    //only call banners Api
    // IF Backend is magento
    if (environment["serverConfig"]["type"] == "magento") {
      callBannersAPI();
    }
  }

  void callBannersAPI() async {
    final result = await Services().api.getBannerImages();

    "banners are fetched: ${result?.length}".log();

    setState(() {
      banners = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't listen to the whole AppModel here — that rebuilt every home section
    // on any AppModel change. Only the Logo case depends on it, and it now
    // subscribes narrowly (themeConfig) via context.select below.
    switch (widget.config['layout']) {
      case Layout.logo:
        final themeConfig =
            context.select((AppModel appModel) => appModel.themeConfig);
        return Logo(
          config: LogoConfig.fromJson(widget.config),
          logo: themeConfig.logo,
          totalCart:
              Provider.of<CartModel>(context, listen: true).totalCartQuantity,
          notificationCount:
              Provider.of<NotificationModel>(context).unreadCount,
          onSearch: () {
            FluxNavigate.pushNamed(RouteList.homeSearch);
          },
          onCheckout: () {
            FluxNavigate.pushNamed(RouteList.cart);
          },
          onTapNotifications: () {
            FluxNavigate.pushNamed(RouteList.notify);
          },
          onTapDrawerMenu: () => NavigateTools.onTapOpenDrawerMenu(context),
        );

      case Layout.headerText:
        return HeaderText(
          config: HeaderConfig.fromJson(widget.config),
        );

      case Layout.headerSearch:
        return HeaderSearch(
          config: HeaderConfig.fromJson(widget.config),
          onSearch: () {
            FluxNavigate.pushNamed(
              RouteList.homeSearch,
              forceRootNavigator: true,
            );
          },
        );
      case Layout.featuredVendors:
        return Services().widget.renderFeatureVendor(widget.config);
      case Layout.bannerImage:
        if (widget.config['isSlider'] == true) {
          final bannerConfig = BannerConfig.fromJson(widget.config);

          // banners?[0] is the top slider banners receiving via api
          // check each banner if not not null in banners api
          if (bannerConfig.items[0].image.contains('HomeTopBanner')) {
            if ((banners?.length ?? 0) > 0 && banners?[0].image1 != null) {
              bannerConfig.items[0].image =
                  "${kMediaDomain}/media/${banners?[0].image1}";
            }

            if ((banners?.length ?? 0) > 0 && banners?[0].image2 != null) {
              bannerConfig.items[1].image =
                  "${kMediaDomain}/media/${banners?[0].image2}";
            }

            if ((banners?.length ?? 0) > 0 && banners?[0].image3 != null) {
              bannerConfig.items[2].image =
                  "${kMediaDomain}/media/${banners?[0].image3}";
            }

            if ((banners?.length ?? 0) > 0 && banners?[0].image4 != null) {
              bannerConfig.items[3].image =
                  "${kMediaDomain}/media/${banners?[0].image4}";
            }
          }

          return BannerSlider(
            config: bannerConfig,
            onTap: (itemConfig) {
              NavigateTools.onTapNavigateOptions(
                context: context,
                config: itemConfig,
              );
            },
          );
        }

        if (widget.config['isHorizontal'] == true) {
          return BannerHorizontal(
            config: BannerConfig.fromJson(widget.config),
            onTap: (itemConfig) {
              NavigateTools.onTapNavigateOptions(
                context: context,
                config: itemConfig,
              );
            },
          );
        }
        //

        if (widget.config['isAppBanner'] == true) {
          final bannerConfig = BannerConfig.fromJson(widget.config);

          // banners?[0] is the top slider banners receiving via api
          // check each banner if not not null in banners api
          if (bannerConfig.items[0].image.contains('HomeTopBanner')) {
            if ((banners?.length ?? 0) > 0 && banners?[0].image1 != null) {
              bannerConfig.items[0].image =
                  "${kMediaDomain}/media/${banners?[0].image1}";
            }
          }

          if (bannerConfig.items[0].image.contains('category-banner-two')) {
            if ((banners?.length ?? 0) > 4 && banners?[0].image1 != null) {
              bannerConfig.items[0].image =
              "${kMediaDomain}/media/${banners?[4].image1}";
            }
          }

          if (bannerConfig.items[0].image.contains('winter-products-banner')) {
            if ((banners?.length ?? 0) > 2 && banners?[2].image1 != null) {
              bannerConfig.items[0].image =
                  "${kMediaDomain}/media/${banners?[2].image1}";
            }
          }

          if (bannerConfig.items[0].image.contains('advertizing-banner')) {
            if ((banners?.length ?? 0) > 3 && banners?[3].image1 != null) {
              bannerConfig.items[0].image =
                  "${kMediaDomain}/media/${banners?[3].image1}";
            }
          }

          //${kMediaDomain}/media/
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: AppBanner(
              config: bannerConfig,
              onTap: (itemConfig) {
                "it is tapped on Banner".log();
                NavigateTools.onTapNavigateOptions(
                  context: context,
                  config: itemConfig,
                );
              },
            ),
          );
        }

        // return Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 18),
        //   child: Image.asset('assets/images/HomeTopBanner.png'),
        // );

        return BannerGroupItems(
          config: BannerConfig.fromJson(widget.config),
          onTap: (itemConfig) {
            NavigateTools.onTapNavigateOptions(
              context: context,
              config: itemConfig,
            );
          },
        );
      case Layout.category:
        // return Container(
        //   height: 50,
        //   color: Colors.black,
        // );
        if (widget.config['type'] == 'image') {
          final categoryConfig = CategoryConfig.fromJson(widget.config);

          if((banners?.length ?? 0) > 1) {
            categoryConfig.items[0].image =
            "${kMediaDomain}/media/${banners?[1].image1}";
            categoryConfig.items[1].image =
            "${kMediaDomain}/media/${banners?[1].image2}";

            categoryConfig.items[2].image =
            "${kMediaDomain}/media/${banners?[1].image3}";
            categoryConfig.items[3].image =
            "${kMediaDomain}/media/${banners?[1].image4}";
          }
          //${kMediaDomain}/media/

          return Column(
            children: [
              const HomeSectionHeaderText(headerText: 'Shop By Category'),
              CategoryImages(
                config: categoryConfig,
              ),
            ],
          );
        }
        return Selector<CategoryModel, Map<String?, Category>>(
          selector: (_, model) => model.categoryList,
          builder: (context, categoryList, child) {
            var configValue = CategoryConfig.fromJson(widget.config);
            var listCategoryName =
                categoryList.map((key, value) => MapEntry(key, value.name));
            void onShowProductList(CategoryItemConfig item) {
              FluxNavigate.pushNamed(
                RouteList.backdrop,
                arguments: BackDropArguments(
                  config: item.toJson(),
                  data: item.data,
                ),
              );
            }

            if (widget.config['type'] == 'menuWithProducts') {
              return CategoryMenuWithProducts(
                config: configValue,
                listCategoryName: listCategoryName,
                onShowProductList: onShowProductList,
              );
            }

            if (widget.config['type'] == 'text') {
              return CategoryTexts(
                config: configValue,
                listCategoryName: listCategoryName,
                onShowProductList: onShowProductList,
              );
            }

            return CategoryIcons(
              config: configValue,
              listCategoryName: listCategoryName,
              onShowProductList: onShowProductList,
            );
          },
        );
      case Layout.bannerAnimated:
        if (kIsWeb) return const SizedBox();
        return BannerAnimated(config: BannerConfig.fromJson(widget.config));

      case Layout.recentView:
        if (ServerConfig().isBuilder) {
          return ProductRecentPlaceholder();
        }
        return Services().widget.renderHorizontalListItem(widget.config);
      case Layout.fourColumn:
      case Layout.threeColumn:
      case Layout.twoColumn:
      case Layout.staggered:
      case Layout.saleOff:
      case Layout.card:
      case Layout.listTile:
        return Services().widget.renderHorizontalListItem(widget.config,
            cleanCache: widget.cleanCache);

      /// New product layout style.
      case Layout.largeCardHorizontalListItems:
      case Layout.largeCard:
        return Services()
            .widget
            .renderLargeCardHorizontalListItems(widget.config);
      case Layout.simpleVerticalListItems:
      case Layout.simpleList:
        return SimpleVerticalProductList(
          config: ProductConfig.fromJson(widget.config),
        );
      case Layout.sliderList:
        return Services().widget.renderSliderList(widget.config);
      case Layout.sliderItem:
        return Services().widget.renderSliderItem(widget.config);
      case Layout.geoSearch:
        return Services().widget.renderGeoSearch(widget.config);
      case Layout.divider:
        return DividerLayout(config: DividerConfig.fromJson(widget.config));
      case Layout.spacer:
        return SpacerLayout(config: SpacerConfig.fromJson(widget.config));
      case Layout.button:
        return ButtonLayout(config: ButtonConfig.fromJson(widget.config));
      default:
        return const SizedBox();
    }
  }
}
