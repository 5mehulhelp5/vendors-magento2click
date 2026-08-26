import 'dart:async';
import 'dart:convert';
import 'dart:io' as file;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart'
    show clearDiskCachedImage, clearMemoryImageCache;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../generated/l10n.dart';
import '../../services/index.dart' show ServerConfig, ConfigType;
import '../config.dart' show kAdvanceConfig;
import '../constants.dart' show isAndroid, kDefaultImage;
import 'image_resize.dart' show kSize;

export './image_resize.dart';

class ImageTools {
  static String prestashopImage(String url, [kSize? size = kSize.medium]) {
    if (url.contains('?')) {
      switch (size) {
        case kSize.large:
          return url.replaceFirst('?', '/large_default?');
        case kSize.small:
          return url.replaceFirst('?', '/small_default?');
        default: // kSize.medium
          return url.replaceFirst('?', '/medium_default?');
      }
    }
    switch (size) {
      case kSize.large:
        return '$url/large_default';
      case kSize.small:
        return '$url/small_default';
      default: // kSize.medium
        return '$url/medium_default';
    }
  }

  static final _regexImageShopify = RegExp('(?:[-_]?[0-9]+x[0-9]+)+');

  static String shopifyImage(String url, [kSize? size = kSize.medium]) {
    var lastIndex = url.lastIndexOf('_');
    lastIndex = lastIndex == -1 ? 0 : lastIndex;
    return url.replaceFirstMapped(_regexImageShopify, (match) {
      switch (size) {
        case kSize.large:
          return '_3500x3500';
        case kSize.small:
          return '_1000x1000';
        default: // kSize.medium
          return '_2000x2000';
      }
    }, lastIndex);
  }

  static String? formatImage(String? url, [kSize? size = kSize.medium]) {
    if (ServerConfig().type == ConfigType.presta) {
      return prestashopImage(url!, size);
    }

    if (ServerConfig().isShopify) {
      return shopifyImage(url!, size);
    }

    if (ServerConfig().isCacheImage ?? kAdvanceConfig.kIsResizeImage) {
      // A Magento `/media/catalog/product/cache/<hash>/…` URL is already a
      // resized rendition. There is no `-medium` sibling *of a rendition*, and
      // Magento answers a missing media file with HTTP 200 + the store
      // placeholder rather than a 404 — so appending the suffix here does not
      // fail loudly, it silently swaps the product photo for the placeholder.
      // Hand these back untouched (86d3x5ex6).
      if (url != null && url.contains('/media/catalog/product/cache/')) {
        return url;
      }
      var pathWithoutExt = p.withoutExtension(url!);
      var ext = p.extension(url);
      String? imageURL = url;

      if (ext == '.jpeg') {
        imageURL = url;
      } else {
        switch (size) {
          case kSize.large:
            imageURL = '$pathWithoutExt-large$ext';
            break;
          case kSize.small:
            imageURL = '$pathWithoutExt-small$ext';
            break;
          default: // kSize.medium:e
            imageURL = '$pathWithoutExt-medium$ext';
            break;
        }
      }

      // printLog('[🏞Image Caching] $imageURL');
      return imageURL;
    } else {
      return url;
    }
  }

  static NetworkImage networkImage(String? url, [kSize size = kSize.medium]) {
    return NetworkImage(formatImage(url, size) ?? kDefaultImage);
  }

  /// Drops the cached bytes behind these product images, so the next paint
  /// downloads them again.
  ///
  /// Pull-to-refresh already busts the catalog cache, but that holds the
  /// product *JSON*. The image bytes live in a second, independent cache keyed
  /// by URL — and replacing a photo on the backend does not change its URL. So
  /// a refresh re-fetched the JSON, got the same URL back, and the widget
  /// repainted from the old bytes: the picture never updated. Worse, once the
  /// store placeholder has been cached against a URL it stays there, so a
  /// product whose images the backend has since generated keeps showing blank
  /// on that device until the entry is evicted (86d3x5ex6).
  ///
  /// Only for an explicit refresh — it costs a re-download of exactly the
  /// images being refreshed, which is what the shopper just asked for.
  ///
  /// Takes `dynamic` deliberately. The product list arrives from a
  /// `CancelableOperation` declared without a type argument, so the list — and
  /// therefore `.map((p) => p.imageFeature)` over it — is statically dynamic.
  /// Declaring `Iterable<String?>` here compiled fine and then threw
  /// "MappedListIterable<Product, dynamic> is not a subtype of
  /// Iterable<String?>" at runtime, inside the try block that loads products:
  /// the list came back empty and every search showed "No Product". Anything
  /// that is not a usable URL is skipped below instead.
  static Future<void> evictProductImages(Iterable<dynamic> urls) async {
    final targets = <String>{};
    for (final url in urls) {
      if (url is! String || !url.startsWith('http')) continue;
      // Widgets request a resized sibling rather than the URL itself, so the
      // original is not the key any of them actually cached under.
      targets.add(url);
      for (final size in kSize.values) {
        final resized = formatImage(url, size);
        if (resized != null && resized.isNotEmpty) targets.add(resized);
      }
    }
    if (targets.isEmpty) return;
    for (final target in targets) {
      try {
        await clearDiskCachedImage(target);
      } catch (_) {
        // No entry for this variant is the normal case (nothing ever requested
        // that size). A refresh must never fail over it.
      }
    }
    // Decoded bitmaps are keyed by the provider's full config — cacheWidth
    // differs per widget — so there is no dependable per-URL memory eviction.
    // Drop them and let the visible ones decode again.
    clearMemoryImageCache();
    _refreshGeneration++;
  }

  /// Incremented every time [evictProductImages] runs; [ImageResize] mixes it
  /// into the widget key of each product image.
  ///
  /// Emptying the caches is not enough on its own. The URL does not change
  /// when the photo behind it does, so after a refresh the rebuilt widget
  /// carries an ImageProvider equal to the old one — Flutter then keeps the
  /// already-attached ImageStream and never re-resolves, so the picture on
  /// screen stays the old one even though the bytes have just been deleted and
  /// the next resolve would fetch the new file. Verified on device: a
  /// pull-to-refresh removed 8 entries from the disk cache while the visible
  /// image did not change.
  ///
  /// Changing the key forces a fresh element, and its resolve then misses both
  /// caches and downloads again. Doing it this way rather than by appending a
  /// cache-buster to the URL keeps the cache keyed by the real URL, so the
  /// re-downloaded bytes are still reused everywhere else in the app.
  static int _refreshGeneration = 0;

  static int get refreshGeneration => _refreshGeneration;

  /// cache avatar for the chat
  static CachedNetworkImage getCachedAvatar(String avatarUrl) {
    return CachedNetworkImage(
      imageUrl: avatarUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

  static BoxFit boxFit(
    String? fit, {
    BoxFit? defaultValue,
  }) {
    switch (fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'scaleDown':
        return BoxFit.scaleDown;
      case 'cover':
        return BoxFit.cover;
      default:
        return defaultValue ?? BoxFit.cover;
    }
  }

  static Future<file.File> writeToFile(Uint8List? data,
      {String? fileName}) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    var filePath = '$tempPath/${fileName ?? 'file_01'}.jpeg';
    var f = file.File(filePath);
    if (data != null) {
      await f.writeAsBytes(data);
    }
    return f;
  }

  static Future<String> compressImage(dynamic image) async {
    var base64 = '';
    //const quality = 60;

    /// Disable cause the build issue on Flutter 2.2
    /// https://github.com/OpenFlutter/flutter_image_compress/issues/180

    if (image is AssetEntity && isAndroid) {
      var file = await image.file;
      if (file?.path != null) {
        final compressedFile = await FlutterImageCompress.compressWithFile(
          file!.path,
        );
        if (compressedFile != null) {
          return base64Encode(compressedFile);
        }
      }
    }

    if (image is AssetEntity || image is file.File) {
      Uint8List? byteData;

      if (image is AssetEntity) {
        byteData = await image.originBytes;
      } else if (image is file.File) {
        byteData = await image.readAsBytes();
      }

      if (byteData != null) {
        final tmpFile = await writeToFile(byteData);

        final compressedFile = await FlutterImageCompress.compressWithFile(
          tmpFile.path,
        );
        if (compressedFile != null) {
          base64 += base64Encode(compressedFile);
        }
      }
    }

    if (image is XFile) {
      final compressedFile = await FlutterImageCompress.compressWithFile(
        image.path,
      );
      //final bytes = compressedFile.readAsBytesSync();
      if (compressedFile != null) {
        base64 += base64Encode(compressedFile);
      }
    }

    if (image is String) {
      if (image.contains('http')) {
        base64 += image;
      }
    }
    return base64;
  }

  static Future<String> compressAndConvertImagesForUploading(
      List<dynamic> images) async {
    var base64 = StringBuffer();
    for (final image in images) {
      base64
        ..write(await compressImage(image))
        ..write(',');
    }
    return base64.toString();
  }

  /// Like [compressAndConvertImagesForUploading] but returns one base64 string
  /// per image instead of a single comma-joined blob — the shape the reviews
  /// upload API expects (`images: string[]`).
  static Future<List<String>> compressImagesForUpload(
      List<dynamic> images) async {
    final result = <String>[];
    for (final image in images) {
      final encoded = await compressImage(image);
      if (encoded.isNotEmpty) {
        result.add(encoded);
      }
    }
    return result;
  }
}

/// The picker ships its own strings and defaults to Chinese, which leaked into
/// the UI as a stray "预览" next to the Confirm button. Base each delegate on
/// the language the app is actually in and keep Confirm on our own l10n.
class CustomAssetPickerTextDelegate extends EnglishAssetPickerTextDelegate {
  CustomAssetPickerTextDelegate({required this.context});

  final BuildContext context;

  @override
  String get confirm => S.of(context).confirm;
}

class CustomArabicAssetPickerTextDelegate extends ArabicAssetPickerTextDelegate {
  CustomArabicAssetPickerTextDelegate({required this.context});

  final BuildContext context;

  @override
  String get confirm => S.of(context).confirm;
}

AssetPickerTextDelegate _pickerTextDelegate(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar'
      ? CustomArabicAssetPickerTextDelegate(context: context)
      : CustomAssetPickerTextDelegate(context: context);
}

class ImagePicker {
  static Future<List> select(BuildContext context, {int maxFiles = 1}) async {
    final isGranted = await checkGrantedPermission();
    if (!isGranted) {
      showDialogRequestPermission(context);
      return [];
    }
    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
          maxAssets: maxFiles,
          textDelegate: _pickerTextDelegate(context)),
    );
    return result ?? [];
  }

  static Future<bool> checkGrantedPermission() async {
    final permissionState = await PhotoManager.requestPermissionExtend();
    return permissionState.isAuth;
  }

  static Future<Uint8List?>? getByteData(dynamic image) {
    if (image is AssetEntity) {
      return image.originBytes;
    }
    return null;
  }

  static Widget getThumbnail(dynamic image,
      {double width = 100, double height = 100}) {
    if (image is AssetEntity) {
      return AssetEntityImage(
        image,
        width: width,
        height: height,
      );
    }
    return const SizedBox();
  }

  static bool isAsset(dynamic image) => image is AssetEntity;

  static void showDialogRequestPermission(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: Text(S.current.notice),
          content: Text(S.current.pleaseAllowAccessCameraGallery),
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                Future.delayed(
                  const Duration(milliseconds: 200),
                  PhotoManager.openSetting,
                );
              },
              child: Text(S.current.ok),
            ),
            CupertinoDialogAction(
              child: Text(S.current.cancel),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
