import 'package:flutter/material.dart';

import '../models/flexible_banner_config.dart';
import 'banner_mixin.dart';

class FlexibleBanner extends StatefulWidget {
  final FlexibleBannerConfig config;
  final Widget child;

  const FlexibleBanner({Key? key, required this.config, required this.child})
      : super(key: key);

  @override
  State<FlexibleBanner> createState() => _FlexibleBannerState();
}

class _FlexibleBannerState extends State<FlexibleBanner> with BannerMixin {
  final ValueNotifier<Offset> _positionNotifier =
      ValueNotifier(const Offset(0, 0));

  late final GlobalKey _parentKey;
  late final GlobalKey _key;
  late final Offset _minOffset;
  late Offset _maxOffset;

  late bool _isShow;

  @override
  void initState() {
    super.initState();
    _parentKey = GlobalKey();
    _key = GlobalKey();
    _isShow = widget.config.enable;
    _minOffset = const Offset(0, 0);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _setBoundary(init: true));
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setBoundary({bool init = false}) {
    var parentRenderBox =
        _parentKey.currentContext?.findRenderObject() as RenderBox;
    var renderBox = _key.currentContext?.findRenderObject() as RenderBox;

    var parentSize = parentRenderBox.size;
    var size = renderBox.size;

    var maxDx = parentSize.width - size.width;
    var maxDy = parentSize.height - size.height;

    _maxOffset = Offset(maxDx, maxDy);

    if (init) {
      _positionNotifier.value = isRTL(context) ? Offset(0, maxDy) : _maxOffset;
    }
  }

  void _updatePosition(Offset newOffset) {
    var dx = _positionNotifier.value.dx + newOffset.dx;
    var dy = _positionNotifier.value.dy + newOffset.dy;

    if (dx < _minOffset.dx) {
      dx = _minOffset.dx;
    } else if (dx > _maxOffset.dx) {
      dx = _maxOffset.dx;
    }

    if (dy < _minOffset.dy) {
      dy = _minOffset.dy;
    } else if (dy > _maxOffset.dy) {
      dy = _maxOffset.dy;
    }

    _positionNotifier.value = Offset(dx, dy);
  }

  void _afterUpdatePosition() {
    var dx = _positionNotifier.value.dx;
    var dy = _positionNotifier.value.dy;

    if (dx < _maxOffset.dx / 2) {
      dx = _minOffset.dx;
    } else {
      dx = _maxOffset.dx;
    }

    _positionNotifier.value = Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isShow) {
      return const SizedBox();
    }

    Widget child = Container(
      padding: const EdgeInsets.all(10.0),
      key: _key,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height - 200,
      ),
      width: widget.config.width.toDouble(),
      height: widget.config.height.toDouble(),
      child: Stack(
        children: [
          widget.child,
          if (widget.config.canClose)
            closeButton(
              context,
              onTap: () {
                setState(() {
                  _isShow = false;
                });
              },
              iconSize: 18,
              alignment:
                  isRTL(context) ? Alignment.topLeft : Alignment.topRight,
              isCircleIcon: true,
            )
        ],
      ),
    );

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _setBoundary());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: ValueListenableBuilder<Offset>(
          valueListenable: _positionNotifier,
          builder: (_, position, __) {
            return Stack(
              key: _parentKey,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  left: position.dx,
                  top: position.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (widget.config.canDrag) {
                        _updatePosition(details.delta);
                      }
                    },
                    onPanEnd: (_) {
                      if (widget.config.canDrag) {
                        _afterUpdatePosition();
                      }
                    },
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
