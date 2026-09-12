import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

import '../../../common/tools/tools.dart';
import '../../../generated/l10n.dart';
import '../model/vendor_on_boarding_model.dart';
import 'export.dart';

class VendorIndex extends StatelessWidget {
  final String userCookie;
  final VoidCallback onFinish;

  const VendorIndex(
      {Key? key, required this.userCookie, required this.onFinish})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VendorOnBoardingModel>(
      create: (_) => VendorOnBoardingModel(userCookie),
      child: VendorInformation(
        onFinish: onFinish,
      ),
    );
  }
}

class VendorInformation extends StatefulWidget {
  final VoidCallback onFinish;

  const VendorInformation({Key? key, required this.onFinish}) : super(key: key);

  @override
  State<VendorInformation> createState() => _VendorInformationState();
}

class _VendorInformationState extends State<VendorInformation> {
  final _pageController = PageController();
  int _currentIndex = 0;
  var _currentSlide = 1;
  var _prevSlide = 1;

  final _rivePath = 'assets/images/loading_widget.rive';
  File? _riveFile;
  Artboard? _artboard;
  _CompletionAwarePainter? _painter;
  var _finished = false;

  List<Widget>? _listPages;

  void _updatePage({bool isPrev = false}) {
    Tools.hideKeyboard(context);
    if (!isPrev) {
      if (_currentIndex >= _listPages!.length - 1) {
        final model =
            Provider.of<VendorOnBoardingModel>(context, listen: false);

        _onStartUpdating();
        model.updateProfile().then((value) => _onEndUpdating(_onFinished));
        return;
      }
    }

    isPrev ? _currentIndex-- : _currentIndex++;
    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.linear,
    );
  }

  void _onFinished() {
    // Both the tick animation and its fallback timer land here.
    if (_finished) {
      return;
    }
    _finished = true;

    final model = Provider.of<VendorOnBoardingModel>(context, listen: false);
    Future.delayed(const Duration(seconds: 2)).then((value) {
      model.onFinish();
      Future.delayed(const Duration(seconds: 1)).then((value) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      widget.onFinish();
    });
  }

  void _loadRiveFile() async {
    _riveFile = await File.asset(_rivePath, riveFactory: Factory.flutter);
  }

  void _onStartUpdating() {
    _play('light');
  }

  void _onEndUpdating(VoidCallback onFinish) {
    _play('light_tick', onCompleted: onFinish);

    // The tick reports its own end while advancing. Should the file ever stop
    // doing so, the overlay would sit on screen for good, so also finish on a
    // timer.
    Future.delayed(const Duration(seconds: 3), onFinish);
  }

  /// Each painter binds to one artboard, and the spinner and the tick are
  /// separate animations, so swap both when the animation changes.
  void _play(String animationName, {VoidCallback? onCompleted}) {
    final file = _riveFile;
    final artboard = file?.defaultArtboard();
    if (!mounted || artboard == null) {
      return;
    }

    final previousPainter = _painter;
    final previousArtboard = _artboard;

    setState(() {
      _artboard = artboard;
      _painter = _CompletionAwarePainter(
        animationName,
        onCompleted: onCompleted,
      );
    });

    // Let the frame that still paints them finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousPainter?.dispose();
      previousArtboard?.dispose();
    });
  }

  @override
  void initState() {
    _loadRiveFile();
    _listPages = [
      VendorBasicInformation(
        onCallBack: (isPrev) {
          _updatePage();
        },
      ),
      VendorAddressInformation(
        onCallBack: (isPrev) {
          _updatePage(isPrev: isPrev);
        },
      ),
      // VendorLocationInformation(
      //   onCallBack: (isPrev) {
      //     _updatePage(isPrev: isPrev);
      //   },
      // ),
      VendorFinish(
        onCallBack: (isPrev) {
          _updatePage(isPrev: isPrev);
        },
      ),
    ];
    super.initState();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _artboard?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var titles = [
      S.of(context).basicInformation,
      S.of(context).storeAddress,
      S.of(context).storeLocation,
      ''
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.background,
              leading: const SizedBox(width: 50),
              title: Text(
                titles[_currentSlide - 1],
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed: () => widget.onFinish(),
                  child: Text(S.of(context).skip),
                ),
              ],
            ),
            body: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  // physics: const NeverScrollableScrollPhysics(),
                  children: _listPages!,
                  onPageChanged: (page) {
                    setState(() {
                      _prevSlide = _currentSlide;
                      _currentSlide = page + 1;
                    });
                  },
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            _currentSlide.toString(),
                          ),
                        ),
                        Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: _prevSlide / _listPages!.length,
                              end: _currentSlide / _listPages!.length,
                            ),
                            duration: const Duration(milliseconds: 200),
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              value: value,
                              backgroundColor: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          Consumer<VendorOnBoardingModel>(
            builder: (_, model, __) {
              if (model.state == VendorOnboardingState.loading) {
                return _buildLoadingWidget();
              }
              return const SizedBox();
            },
          )
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    final size = MediaQuery.of(context).size;
    final artboard = _artboard;
    final painter = _painter;
    return Container(
      width: size.width,
      height: size.height,
      color: Colors.black38,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: artboard == null || painter == null
              ? const Center(child: CircularProgressIndicator())
              : RiveArtboardWidget(
                  artboard: artboard,
                  painter: painter,
                ),
        ),
      ),
    );
  }
}

/// rive 0.14 dropped animation controllers and their completion listeners. A
/// non-looping animation instead reports that it has nothing left to advance.
final class _CompletionAwarePainter extends SingleAnimationPainter {
  _CompletionAwarePainter(super.animationName, {this.onCompleted});

  final VoidCallback? onCompleted;
  var _notified = false;

  @override
  bool advance(double elapsedSeconds) {
    final keepGoing = super.advance(elapsedSeconds);
    if (!keepGoing && !_notified) {
      _notified = true;
      onCompleted?.call();
    }
    return keepGoing;
  }
}
