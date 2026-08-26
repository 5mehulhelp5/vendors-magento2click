import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

import '../config.dart' show kAdvanceConfig;
import '../constants.dart' show kCacheImageWidth, kEmptyColor, kIsWeb;
import '../tools.dart';

// ignore: camel_case_types
enum kSize { small, medium, large }

class ImageResize extends StatelessWidget {
  final String? url;
  final kSize? size;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final String? tag;
  final double offset;
  final bool isResize;
  final bool hidePlaceHolder;
  final bool forceWhiteBackground;
  final String kImageProxy;

  const ImageResize({
    Key? key,
    this.url,
    this.size,
    this.width,
    this.height,
    this.fit,
    this.tag,
    this.isResize = false,
    this.hidePlaceHolder = false,
    this.offset = 0.0,
    this.forceWhiteBackground = false,
    this.kImageProxy = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var width = this.width ?? 200;
    var ratioImage = kAdvanceConfig.ratioProductImage;
    var height = this.height ?? width * ratioImage;

    if (url?.isEmpty ?? true) {
      return FutureBuilder<bool>(
        future: Future.delayed(const Duration(seconds: 10), () => false),
        initialData: true,
        builder: (context, snapshot) {
          final showSkeleton = snapshot.data!;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: showSkeleton
                ? Skeleton(
                    width: width,
                    height: height,
                  )
                : SizedBox(
                    width: width,
                    height: height,
                    child: const Icon(Icons.error_outline),
                  ),
          );
        },
      );
    }

    if (kIsWeb) {
      /// temporary fix on CavansKit https://github.com/flutter/flutter/issues/49725
      var imageURL = isResize ? ImageTools.formatImage(url, size) : url;

      var imageProxy = '$kImageProxy${width}x,q50/';
      if (kImageProxy.isEmpty) {
        /// this image proxy is use for demo purpose, please make your own one
        imageProxy = 'https://cors.mstore.io/';
      }

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: FadeInImage.memoryNetwork(
          image: '$imageProxy$imageURL',
          fit: fit,
          width: width,
          height: height,
          placeholder: kTransparentImage,
        ),
      );
    }

    // Decode at the display width in physical pixels (aspect ratio preserved
    // via a single dimension), replacing the old ×2.5 guess that over-decoded
    // on low-DPI screens and under-decoded on high-DPI ones.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (this.width != null && this.width! > 0)
        ? (this.width! * devicePixelRatio).round()
        : kCacheImageWidth;

    final resolvedUrl = isResize ? ImageTools.formatImage(url, size)! : url!;

    // The "-small"/"-medium"/"-large" sibling only exists once the backend's
    // resize job has processed the file. A photo uploaded or swapped in the
    // admin has none until then, and the request is a hard 404 — which used to
    // paint the empty box below, so the product page showed a blank frame in
    // the carousel while the original was sitting there perfectly fine
    // (86d3x5ex6). Cards avoid this by using Magento's on-demand rendition,
    // but that is not an option here: renditions only exist for images
    // carrying a role, and a carousel is mostly the extra shots that carry
    // none — measured 17 of 37 gallery files resolving, the rest returning the
    // store placeholder. So fall back to the original file, which always
    // exists. It costs a bigger download, but only for the images the resize
    // job has not caught up with yet.
    final image = _build(context, resolvedUrl,
        cacheWidth: cacheWidth,
        fallbackUrl: resolvedUrl != url ? url : null);

    if (forceWhiteBackground && url!.toLowerCase().endsWith('.png')) {
      return Container(
        color: Colors.white,
        child: image,
      );
    }

    return image;
  }

  Widget _build(
    BuildContext context,
    String resolvedUrl, {
    required int cacheWidth,
    String? fallbackUrl,
  }) {
    var width = this.width ?? 200;
    var ratioImage = kAdvanceConfig.ratioProductImage;
    var height = this.height ?? width * ratioImage;

    return ExtendedImage.network(
      resolvedUrl,
      // A pull-to-refresh empties the image caches, but the URL is unchanged so
      // the rebuilt widget's provider still compares equal and Flutter keeps
      // the stream it already resolved — the old photo stays on screen. Mixing
      // the refresh generation into the key gives a fresh element, whose
      // resolve misses the (now empty) caches and downloads the new file
      // (86d3x5ex6).
      key: ValueKey('$resolvedUrl#${ImageTools.refreshGeneration}'),
      width: width,
      height: height,
      fit: fit,
      cache: true,
      // Ask the CDN for WebP: it content-negotiates a ~40% smaller webp of the
      // -small/-medium/-large variant when available, else returns the original
      // format unchanged. Flutter decodes webp natively.
      headers: const {'Accept': 'image/webp'},
      timeRetry: const Duration(milliseconds: 500),
      // Keep the decoded bitmap in the (capped) image cache when a row scrolls
      // off, so scrolling back doesn't re-decode and stutter. Memory stays
      // bounded by PaintingBinding.imageCache (see main.dart).
      clearMemoryCacheWhenDispose: false,
      cacheWidth: cacheWidth,
      enableLoadState: false,
      alignment: Alignment(
        (offset >= -1 && offset <= 1)
            ? offset
            : (offset > 0)
                ? 1.0
                : -1.0,
        0.0,
      ),
      loadStateChanged: (ExtendedImageState state) {
        Widget? widget;
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            widget = hidePlaceHolder
                ? const SizedBox()
                : Skeleton(
                    width: width,
                    height: height,
                  );
            break;
          case LoadState.completed:
            return state.completedWidget;
          // return ImageFade(
          //   image: state.imageProvider,
          //   width: width,
          //   height: height,
          //   fit: fit ?? BoxFit.scaleDown,
          //   alignment: Alignment(
          //     (offset >= -1 && offset <= 1)
          //         ? offset
          //         : (offset > 0)
          //             ? 1.0
          //             : -1.0,
          //     0.0,
          //   ),
          //   duration: const Duration(milliseconds: 250),
          // );
          case LoadState.failed:
            // Retry once on the un-suffixed original before giving up, so a
            // missing resized variant does not leave an empty frame. The
            // fallback is built with fallbackUrl null, so a genuine dead image
            // still lands on the placeholder below instead of looping.
            if (fallbackUrl != null) {
              return _build(context, fallbackUrl, cacheWidth: cacheWidth);
            }
            widget = Container(
              width: width,
              height: height,
              color: const Color(kEmptyColor),
            );
            break;
        }
        return widget;
      },
    );
  }
}
