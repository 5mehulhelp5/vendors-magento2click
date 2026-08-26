import 'package:flutter/material.dart';
import 'package:magentoegypt/common/extensions.dart';
import 'package:magentoegypt/core/colors.dart';

import '../config/app_config.dart';
import '../config/app_setting.dart';
import '../config/tab_bar_config.dart';
import '../helper/helper.dart';
import 'tab_indicator/index.dart';
import 'tabbar.dart' as custom;
import 'tabbar_icon.dart';

final _tweenOffset = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: const Offset(0.0, 0.0),
);

class TabBarCustom extends StatelessWidget {
  final TabController tabController;
  final Function(int) onTap;
  final List<TabBarMenuConfig> tabData;
  final bool shouldHideTabBar;
  final AppSetting config;

  final int totalCart;

  const TabBarCustom({
    Key? key,
    this.shouldHideTabBar = false,
    required this.config,
    required this.totalCart,
    required this.tabController,
    required this.onTap,
    required this.tabData,
  }) : super(key: key);

  Decoration _buildIndicator(context) {
    var indicator = config.tabBarConfig.tabBarIndicator;

    switch (config.tabBarConfig.indicatorStyle) {
      case IndicatorStyle.dot:
        return DotIndicator(
            radius: indicator.radius ?? 3,
            color: indicator.color ?? Theme.of(context).primaryColor,
            distanceFromCenter: indicator.distanceFromCenter ?? 20.0,
            strokeWidth: indicator.strokeWidth ?? 1.0,
            paintingStyle: indicator.paintingStyle ?? PaintingStyle.fill);
      case IndicatorStyle.material:
        final indicatorHeight = indicator.height ?? 4;
        if (indicatorHeight <= 0) {
          // What good is a indicator if its height is <= zero?
          break;
        }
        return MaterialIndicator(
            height: indicatorHeight,
            tabPosition: indicator.tabPosition,
            topRightRadius: indicator.topRightRadius ?? 5,
            topLeftRadius: indicator.topLeftRadius ?? 5,
            bottomRightRadius: indicator.bottomRightRadius ?? 0,
            bottomLeftRadius: indicator.bottomLeftRadius ?? 0,
            color: indicator.color ?? Theme.of(context).primaryColor,
            horizontalPadding: indicator.horizontalPadding ?? 0.0,
            strokeWidth: indicator.strokeWidth ?? 1.0,
            paintingStyle: indicator.paintingStyle ?? PaintingStyle.fill);
      case IndicatorStyle.rectangular:
        return RectangularIndicator(
            topRightRadius: indicator.topRightRadius ?? 5,
            topLeftRadius: indicator.topLeftRadius ?? 5,
            bottomRightRadius: indicator.bottomRightRadius ?? 0,
            bottomLeftRadius: indicator.bottomLeftRadius ?? 0,
            color: indicator.color ?? Theme.of(context).primaryColor,
            horizontalPadding: indicator.horizontalPadding ?? 0.0,
            strokeWidth: indicator.strokeWidth ?? 1.0,
            verticalPadding: indicator.verticalPadding ?? 0.0,
            paintingStyle: indicator.paintingStyle ?? PaintingStyle.fill);
      case IndicatorStyle.none:
      default:
        break;
    }

    return const BoxDecoration(color: Colors.transparent);
  }

  Widget _buildTabBar(context) {
    final theme = Theme.of(context);
    final tabConfig = config.tabBarConfig;

    '_buildTabBar tabConfig.colorActiveIcon ${tabConfig.colorActiveIcon}'.log();
    '_buildTabBar tabConfig.colorIcon ${tabConfig.colorIcon}'.log();
    '_buildTabBar $_buildTabBar'.log();

    final labelTextStyle = theme.primaryTextTheme.bodyLarge?.copyWith(
      fontSize: 12,
    );
    final colorIcon = tabConfig.colorIcon ?? AppColors.colorIcon;
    final colorActiveIcon = tabConfig.colorActiveIcon ??  AppColors.black900;

    final indicatorSize = tabConfig.indicatorStyle == IndicatorStyle.rectangular
        ? TabBarIndicatorSize.tab
        : TabBarIndicatorSize.label;

    final position = tabConfig.tabBarFloating.position;
    final floatingIndex = (position != null && position < tabData.length)
        ? position
        : (tabData.length / 2).floor();

    /// only disable visible tab icon and not the tabMenu
    // var tabList =
    //     tabData.where((e) => e.visible != false && e.tabMenu != true).toList();

    return custom.TabBar(
      key: const Key('mainTabBar'),
      controller: tabController,
      onTap: onTap,
      tabs: [
        for (var i = 0; i < tabData.length; i++)
          tabData[i].visible == false || tabData[i].groupLayout == true
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TabBarIcon(
                    key: Key('TabBarIcon-$i'),
                    item: tabData[i],
                    totalCart: totalCart,
                    isActive: i == tabController.index,
                    isEmptySpace: tabConfig.showFloating && i == floatingIndex,
                    config: tabConfig,
                  ),
                ),
      ],
      isScrollable: false,
      labelColor: colorActiveIcon,
      unselectedLabelColor: colorIcon,
      indicatorSize: indicatorSize,
      indicatorColor: colorActiveIcon,
      indicator: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      unselectedLabelStyle: labelTextStyle,
      labelStyle: labelTextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    var tabConfig = config.tabBarConfig;

    /// The tab list always has [tabData.length] children, so the shared
    /// [TabController] must have the same length or the underlying TabBar
    /// asserts. During a tab/config reload (e.g. language switch) the two can
    /// briefly disagree — hide the bar for that one frame instead of throwing.
    ///
    /// This used to be "handled" by `ErrorWidget.builder = (_) => SizedBox()`,
    /// which muted EVERY build error in the whole app into a blank box — the
    /// root cause of the "app hangs / all screens go blank white" reports.
    /// The global handler is now configured once, safely, in main().
    final tabCountMismatch = tabController.length != tabData.length;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        final offsetAnimation = _tweenOffset.animate(animation);
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      child: (shouldHideTabBar || tabCountMismatch)
          ? const SizedBox()
          : Container(
              padding: EdgeInsets.only(
                left: tabConfig.paddingLeft,
                right: tabConfig.paddingRight,
                top: tabConfig.paddingTop,
                bottom: tabConfig.paddingBottom,
              ),
              margin: EdgeInsets.only(
                left: tabConfig.marginLeft,
                right: tabConfig.marginRight,
                bottom: tabConfig.marginBottom,
                top: tabConfig.marginTop,
              ),
              decoration: BoxDecoration(
                //  color: tabConfig.showFloating ? null : AppColors.kPrimaryRed,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(tabConfig.radiusTopLeft),
                    topRight: Radius.circular(tabConfig.radiusTopRight),
                    bottomLeft: Radius.circular(tabConfig.radiusBottomLeft),
                    bottomRight: Radius.circular(tabConfig.radiusBottomRight),
                  ),
                  boxShadow: [
                    if (!tabConfig.showFloating)
                      BoxShadow(
                          spreadRadius:
                              tabConfig.boxShadow?.spreadRadius ?? 0.0,
                          blurRadius: tabConfig.boxShadow?.blurRadius ?? 0.0,
                          offset: Offset(tabConfig.boxShadow?.x ?? 0.0,
                              tabConfig.boxShadow?.y ?? 0.0),
                          color: Colors.grey.withOpacity(
                              tabConfig.boxShadow?.colorOpacity ?? 0.0)),
                  ]),
              child: SafeArea(
                bottom: tabConfig.isSafeArea,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: !Layout.isDisplayDesktop(context)
                      ? SizedBox(
                          width: double.infinity,
                          child: _buildTabBar(context),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Spacer(),
                              Expanded(
                                flex: 6,
                                child: _buildTabBar(context),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}
