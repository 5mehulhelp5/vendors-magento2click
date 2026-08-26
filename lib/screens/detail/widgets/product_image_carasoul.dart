import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/tools/image_tools.dart';
import '../../../models/entities/index.dart';
import '../../../models/product_model.dart';
import 'image_galery.dart';

class ProductImageCarasoul extends StatefulWidget {
  final Product product;
  final Function(int index)? onChange;
  final Function(
      BuildContext context,
      Widget pageView,
      PageController pageController,
      List<String> items,
      bool hasVideo)? customBuilder;

  const ProductImageCarasoul({
    Key? key,
    required this.product,
    this.onChange,
    this.customBuilder,
  }) : super(key: key);

  @override
  State<ProductImageCarasoul> createState() => _ProductImageCarasoulState();
}

class _ProductImageCarasoulState extends State<ProductImageCarasoul> {
  final PageController _pageController = PageController();

  Timer? _timer;
  int _lastInteraction = 0;

  Future<void> nextImage() async {
    if (!mounted || !_pageController.hasClients) {
      return;
    }

    /// Cancel if the page is scrolling.
    if (_pageController.page?.round() != _pageController.page) {
      return;
    }

    /// Cancel if user has touched the gallery within 3 seconds.
    if (DateTime.now().millisecondsSinceEpoch - 3000 <= _lastInteraction) {
      return;
    }

    /// Cancel if video is playing.
    if (hasVideo && _currentPage == 0) {
      return;
    }

    /// Next page if not ends..
    if (_currentPage + 1 < itemList.length) {
      return _pageController.goTo(_currentPage + 1);
    }

    /// Go to first page.
    return _pageController.goTo(0);
  }

  bool initialized = false;
  bool hasVideo = false;
  bool variationLoaded = false;

  late final String _videoUrl;
  final List<String> _images = [];
  final List<String> _variationImages = [];
  int sliderIndex = 1;

  int _currentPage = 0;

  List<String> get itemList => context.read<ProductModel>().variationsFeatureImages.length == 0 ? {
    if (hasVideo) _videoUrl,
    ..._images,
    ..._variationImages,
  }.toList():{
    if (hasVideo) _videoUrl,
    ...context.read<ProductModel>().variationsFeatureImages,
  }.toList();


 // List<String> get imagesList => {..._images, ..._variationImages}.toList();
 // List<String> get imagesList => context.read<ProductModel>().variationsFeatureImages;
  List<String> get imagesList => context.read<ProductModel>().variationsFeatureImages.length == 0 ?{
    ..._images, ..._variationImages}.toList(): context.read<ProductModel>().variationsFeatureImages;

  StreamSubscription? _subChangeSelectedVariation;

  void updateVariationImages(List<String> newImages) {
    if (!widget.product.isVariableProduct ||
        _variationImages.isNotEmpty ||
        newImages.isEmpty ||
        newImages.length == _variationImages.length) {
      return;
    }
    for (var url in newImages) {
      if (!_variationImages.contains(url)) {
        _variationImages.add(url);
      }
    }
    initialized = true;
    if (!mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) async {
      if (mounted) {
        afterFirstLayout(context);
      }
    });

    final url = widget.product.videoUrl;
    if (url != null && url.isNotEmpty) {
      _videoUrl = url.replaceAll('http://', 'https://');
      hasVideo = true;
    }

    _images.addAll(widget.product.images);

    if (kProductDetail.showSelectedImageVariant) {
      _subChangeSelectedVariation =
          eventBus.on<EventChangeSelectedVariation>().listen((event) {
        if (!mounted) {
          return;
        }

        /// Skip first time when variation loaded.
        if (!variationLoaded) {
          variationLoaded = true;
          return;
        }

        final image = event.productVariation?.imageFeature;
        _pageController.goToUrl(image, itemList);
      });
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    _subChangeSelectedVariation?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) {
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        nextImage();
      },
    );
  }

  void _cancelTimer() {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }
  }

  @override
  void didUpdateWidget(ProductImageCarasoul oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kProductDetail.autoPlayGallery) {
      _startTimer();
    } else {
      _cancelTimer();
    }
  }

  void afterFirstLayout(BuildContext context) {
    print(context.read<ProductModel>().variationsFeatureImages.length);
    if (widget.product.isVariableProduct) {
      updateVariationImages(
          context.read<ProductModel>().variationsFeatureImages);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      updateVariationImages(
          context.select((ProductModel _) => _.variationsFeatureImages));
    }

    if (itemList.isEmpty) {
      return const SizedBox();
    }

    final size = MediaQuery.of(context).size;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: itemList.length,
      onPageChanged: (index) {
        _currentPage = index;
        widget.onChange?.call(index);
        setState(() {});
      },
      itemBuilder: (BuildContext context, int index) {

        return GestureDetector(
          onTap: () => _onShowGallery(context, index),
          child: Hero(
            tag: 'slider_hero_tag_${itemList[index]}',
            child: ImageResize(
              url: itemList[index],
              fit: ImageTools.boxFit(kProductDetail.boxFit),
              size: kSize.large,
              width: size.width,
              hidePlaceHolder: true,
              forceWhiteBackground: kProductDetail.forceWhiteBackground,
            ),
          ),
        );
      },
    );

    if (widget.customBuilder != null) {
      return widget.customBuilder?.call(
        context,
        pageView,
        _pageController,
        itemList,
        hasVideo,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CarouselSlider.builder(
            options: CarouselOptions(
                // Portrait box sized to the catalog's 2:3 images so
                // BoxFit.contain shows them full and large like the website.
                height: (size.width - 32) * kAdvanceConfig.ratioProductImage,
                initialPage: 0,
                autoPlay: true,
                viewportFraction: 1.0,
                enableInfiniteScroll: false,
                scrollDirection: Axis.horizontal,
                onPageChanged: (index, reason) {
                  sliderIndex = index;
                  setState(() {});
                }),
            itemCount: imagesList.length,
            itemBuilder: (context, index, realIndex) {

              return GestureDetector(
                onTap: () => _onShowGallery(context, index),
                child: Hero(
                  tag: 'slider_hero_tag_${imagesList[index]}',
                  child: ImageResize(
                    url: imagesList[index],
                    fit: ImageTools.boxFit(kProductDetail.boxFit),
                    size: kSize.large,
                    width: size.width,
                    hidePlaceHolder: true,
                    forceWhiteBackground: kProductDetail.forceWhiteBackground,
                  ),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            height: getVerticalSize(10),
            margin: getMargin(top: 15),
            child: AnimatedSmoothIndicator(
              activeIndex: sliderIndex,
              count: imagesList.length,
              axisDirection: Axis.horizontal,
              effect: ScrollingDotsEffect(
                spacing: 10,
                activeDotColor: Colors.black,
                dotColor: Colors.grey,
                dotHeight: 1.5,
                // Dots share the width between them, so a product with many
                // images drives this negative — which trips an assertion in
                // SmoothPageIndicator and replaces the whole product page with
                // an error box in debug builds. A configurable parent carries
                // every variant's images, so it hits this easily.
                dotWidth:
                    ((size.width / imagesList.length) - 15).clamp(2.0, 60.0),
              ),
            ),
          ),
        ),
      ],
    );

    //   return FlexibleSpaceBar(
    //     background: Stack(
    //       children: [
    //         Positioned.fill(
    //           top: kProductDetail.marginTop,
    //           child: Listener(
    //             onPointerDown: (_) => _updateLastInteraction(),
    //             onPointerMove: (_) => _updateLastInteraction(),
    //             onPointerHover: (_) => _updateLastInteraction(),
    //             child: pageView,
    //           ),
    //         ),
    //         if (kProductDetail.showImageGallery &&
    //             kProductDetail.sliderIndicatorType == SliderIndicatorType.number)
    //           Positioned(
    //             bottom: 0.0,
    //             left: 0.0,
    //             child: ClipRRect(
    //               child: BackdropFilter(
    //                 filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
    //                 child: Container(
    //                   height: 55,
    //                   width: size.width,
    //                   color: Colors.transparent,
    //                 ),
    //               ),
    //             ),
    //           ),
    //         if (_currentPage != 0 && kProductDetail.sliderShowGoBackButton)
    //           Positioned(
    //             bottom: 4.0,
    //             left: 2.0,
    //             child: GestureDetector(
    //               onTap: () {
    //                 _pageController.goTo(0);
    //                 widget.onChange?.call(0);
    //               },
    //               child: Padding(
    //                 padding: const EdgeInsets.symmetric(
    //                   vertical: 10,
    //                   horizontal: 4,
    //                 ),
    //                 child: Icon(
    //                   CupertinoIcons.arrow_left_square_fill,
    //                   color: Theme.of(context).primaryColor,
    //                   size: 25,
    //                 ),
    //               ),
    //             ),
    //           ),
    //         if (kProductDetail.sliderIndicatorType ==
    //             SliderIndicatorType.number) ...[
    //           Positioned(
    //             bottom: 8.0,
    //             right: 4.0,
    //             child: Container(
    //               decoration: BoxDecoration(
    //                 color: Colors.white12,
    //                 borderRadius: BorderRadius.circular(6.0),
    //               ),
    //               padding:
    //                   const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
    //               child: Text(
    //                 '${_currentPage + 1}/${itemList.length}',
    //                 style: TextStyle(
    //                   color: Theme.of(context).primaryColor,
    //                   fontWeight: FontWeight.w700,
    //                 ),
    //               ),
    //             ),
    //           ),
    //         ],
    //         if (kProductDetail.showImageGallery) ...[
    //           Positioned(
    //             bottom: 4.0,
    //             left: 44,
    //             child: ProductImageThumbnail(
    //               itemList: itemList,
    //               onSelect: ({required int index, bool? fullScreen}) {
    //                 if (fullScreen ?? false) {
    //                   _onShowGallery(context, index);
    //                 }
    //                 _pageController.goTo(index);
    //               },
    //               selectIndex: _currentPage,
    //             ),
    //           )
    //         ],
    //         if (!kProductDetail.showImageGallery &&
    //             kProductDetail.sliderIndicatorType == SliderIndicatorType.dot)
    //           Positioned(
    //             bottom: 16.0,
    //             right: 16.0,
    //             left: 16.0,
    //             child: SmoothPageIndicator(
    //               controller: _pageController,
    //               count: itemList.length,
    //               effect: const ScrollingDotsEffect(
    //                 dotWidth: 5.0,
    //                 dotHeight: 5.0,
    //                 spacing: 15.0,
    //                 fixedCenter: true,
    //                 dotColor: Colors.black45,
    //                 activeDotColor: Colors.white,
    //               ),
    //             ),
    //           ),
    //       ],
    //     ),
    //   );
  }

  void _updateLastInteraction() {
    _lastInteraction = DateTime.now().millisecondsSinceEpoch;
  }

  void _onShowGallery(BuildContext context, [index = 0]) {
    Navigator.push(
      context,
      PageRouteBuilder(pageBuilder: (context, __, ___) {
        return ImageGalery(
          images: imagesList,
          index: hasVideo ? index - 1 : index,
          heroTagPrefix: 'slider_hero_tag_',
        );
      }),
    );
  }
}

extension on PageController {
  Future<void> goTo(int page) {
    return animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void goToUrl(String? url, List<String> urls) {
    if (url == null || urls.isEmpty) {
      return;
    }

    final index = urls.indexOf(url);
    if (index == -1) {
      return;
    }
    animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}
