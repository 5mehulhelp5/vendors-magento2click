import 'package:flutter/material.dart';

import '../models/sticky_banner_config.dart';
import 'banner_mixin.dart';

class StickyBanner extends StatefulWidget {
  final StickyBannerConfig config;
  final Widget child;

  const StickyBanner({Key? key, required this.config, required this.child})
      : super(key: key);

  @override
  State<StickyBanner> createState() => _StickyBannerState();
}

class _StickyBannerState extends State<StickyBanner> with BannerMixin {
  late bool _isShow;

  @override
  void initState() {
    super.initState();
    _isShow = widget.config.enable;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !_isShow
          ? const SizedBox()
          : Wrap(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                    color: Theme.of(context).colorScheme.background,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.3),
                        offset: const Offset(0, -1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      widget.child,
                      closeButton(
                        context,
                        onTap: () {
                          setState(() {
                            _isShow = false;
                          });
                        },
                        alignment: isRTL(context)
                            ? Alignment.topLeft
                            : Alignment.topRight,
                      )
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
