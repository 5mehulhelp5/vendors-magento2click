import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class RiveSplashScreen extends StatefulWidget {
  final Function onSuccess;
  final String imageUrl;
  final Color? color;
  final String animationName;
  final int duration;
  final Color backgroundColor;
  final BoxFit boxFit;
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double paddingRight;

  const RiveSplashScreen({
    Key? key,
    required this.onSuccess,
    required this.imageUrl,
    required this.animationName,
    this.color,
    this.duration = 1000,
    this.backgroundColor = Colors.white,
    this.boxFit = BoxFit.contain,
    this.paddingTop = 0.0,
    this.paddingBottom = 0.0,
    this.paddingLeft = 0.0,
    this.paddingRight = 0.0,
  }) : super(key: key);

  @override
  State<RiveSplashScreen> createState() => _RiveSplashScreenState();
}

class _RiveSplashScreenState extends State<RiveSplashScreen> {
  File? _riveFile;
  Artboard? _riveArtboard;
  SingleAnimationPainter? _painter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.endOfFrame.then((_) async {
      if (mounted) {
        // rive resolves both sources itself now, so the bytes no longer have
        // to be fetched here.
        final file = widget.imageUrl.startsWith('http')
            ? await File.url(widget.imageUrl, riveFactory: Factory.flutter)
            : await File.asset(widget.imageUrl, riveFactory: Factory.flutter);
        final artboard = file?.defaultArtboard();

        if (mounted && artboard != null) {
          setState(() {
            _riveFile = file;
            _riveArtboard = artboard;
            _painter = SingleAnimationPainter(
              widget.animationName,
              fit: _fit(widget.boxFit),
            );
          });
        } else {
          artboard?.dispose();
          file?.dispose();
        }

        // Fix hang issue from splash screen, need to call onSuccess without require the animation
        await Future.delayed(Duration(milliseconds: widget.duration))
            .then((value) => widget.onSuccess());
      }
    });
  }

  Fit _fit(BoxFit boxFit) {
    switch (boxFit) {
      case BoxFit.fill:
        return Fit.fill;
      case BoxFit.cover:
        return Fit.cover;
      case BoxFit.fitWidth:
        return Fit.fitWidth;
      case BoxFit.fitHeight:
        return Fit.fitHeight;
      case BoxFit.none:
        return Fit.none;
      case BoxFit.scaleDown:
        return Fit.scaleDown;
      case BoxFit.contain:
        return Fit.contain;
    }
  }

  @override
  void dispose() {
    _painter?.dispose();
    _riveArtboard?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _riveArtboard;
    final painter = _painter;

    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: widget.backgroundColor,
      padding: EdgeInsets.only(
        top: widget.paddingTop,
        bottom: widget.paddingBottom,
        left: widget.paddingLeft,
        right: widget.paddingRight,
      ),
      child: Center(
        child: artboard == null || painter == null
            ? const SizedBox()
            : RiveArtboardWidget(
                artboard: artboard,
                painter: painter,
              ),
      ),
    );
  }
}
