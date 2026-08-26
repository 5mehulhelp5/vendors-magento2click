import 'package:flutter/material.dart';
import 'package:magentoegypt/modules/dynamic_layout/config/banner_config.dart';
import 'package:magentoegypt/widgets/common/flux_image.dart';

class AppBanner extends StatelessWidget {
  final BannerConfig config;
  final Function onTap;
  const AppBanner({
    super.key,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var height = config.height != null
        ? config.height! * MediaQuery.of(context).size.height
        : null;
    return Container(
      margin: EdgeInsets.only(
        left: config.marginLeft,
        right: config.marginRight,
        top: config.marginTop,
        bottom: config.marginBottom,
      ),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: config.items[0].padding ?? 0.0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            config.items[0].radius ?? 0.0,
          ),
          child: InkWell(
            onTap: () => onTap(config.items[0].jsonData),
            child: FluxImage(
              imageUrl: config.items[0].image,
              fit: config.fit,
            ),
          ),
        ),
      ),
    );
  }
}
