import 'package:flutter/material.dart';

import '../models/flexible_banner_config.dart';
import '../models/popup_banner_config.dart';
import '../models/smart_engagement_banner_config.dart';
import '../models/sticky_banner_config.dart';
import 'flexible_banner.dart';
import 'popup_banner.dart';
import 'sticky_banner.dart';

typedef ChildWidget = Widget Function(dynamic value);

class SmartEngagementBanner extends StatefulWidget {
  final BuildContext context;
  final SmartEngagementBannerConfig config;
  final ChildWidget childWidget;
  final bool enablePopup;
  final bool enableFlexible;
  final bool enableSticky;
  final VoidCallback? afterClosePopup;

  const SmartEngagementBanner({
    Key? key,
    required this.context,
    required this.config,
    required this.childWidget,
    this.enablePopup = true,
    this.enableFlexible = true,
    this.enableSticky = true,
    this.afterClosePopup,
  }) : super(key: key);

  @override
  State<SmartEngagementBanner> createState() => _SmartEngagementBannerState();
}

class _SmartEngagementBannerState extends State<SmartEngagementBanner> {
  FlexibleBannerConfig get flexible => widget.config.flexible;
  StickyBannerConfig get sticky => widget.config.sticky;
  PopupBannerConfig get popup => widget.config.popup;

  @override
  void initState() {
    super.initState();
    if (widget.enablePopup && popup.enable && popup.data?.isNotEmpty) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(widget.context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => PopupBanner(
                config: popup,
                afterClose: widget.afterClosePopup,
                child: widget.childWidget(popup.data),
              ),
              opaque: false,
            ),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.enableFlexible &&
                  flexible.enable &&
                  flexible.data?.isNotEmpty)
                Expanded(
                  child: FlexibleBanner(
                    config: flexible,
                    child: widget.childWidget(flexible.data),
                  ),
                ),
              if (widget.enableSticky &&
                  sticky.enable &&
                  sticky.data?.isNotEmpty)
                StickyBanner(
                  config: sticky,
                  child: widget.childWidget(sticky.data),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
