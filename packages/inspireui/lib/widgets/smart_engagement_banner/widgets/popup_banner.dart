import 'package:flutter/material.dart';

import '../models/popup_banner_config.dart';
import 'banner_mixin.dart';

class PopupBanner extends StatefulWidget {
  final PopupBannerConfig config;
  final Widget child;
  final VoidCallback? afterClose;
  final bool isPreview;

  const PopupBanner({
    Key? key,
    required this.config,
    required this.child,
    this.afterClose,
    this.isPreview = false,
  }) : super(key: key);

  @override
  State<PopupBanner> createState() => _PopupBannerState();
}

class _PopupBannerState extends State<PopupBanner>
    with BannerMixin, SingleTickerProviderStateMixin {
  bool _isTap = false;
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCirc,
    );

    WidgetsBinding.instance.endOfFrame
        .then((value) => _animationController.forward());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closePopup(context) {
    Navigator.of(context).pop();
    widget.afterClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black.withOpacity(0.5)),
          Container(
            margin: EdgeInsets.symmetric(
              vertical: widget.isPreview ? 10 : 60,
              horizontal: 10,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            child: Wrap(
              children: [
                Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.fromLTRB(
                        10,
                        10,
                        10,
                        widget.isPreview ? 10 : 64,
                      ),
                      child: Listener(
                        onPointerUp: (_) {
                          if (_isTap) {
                            _closePopup(context);
                          }
                          _isTap = false;
                        },
                        onPointerDown: (_) {
                          _isTap = true;
                        },
                        onPointerMove: (move) {
                          // In some cases, the popup doesn't close after the app navigator to the popup details screen. Or the popup will close without navigating to the detail screen
                          if (move.delta.distanceSquared > 2) {
                            _isTap = false;
                          }
                        },
                        child: widget.child,
                      ),
                    ),
                    Positioned.fill(
                      child: closeButton(
                        context,
                        onTap: () {
                          _animationController
                              .reverse()
                              .whenComplete(() => _closePopup(context));
                        },
                        isCircleIcon: true,
                        alignment: getAlignment(
                          widget.config.closePosition,
                          defaultValue: Alignment.bottomCenter,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
