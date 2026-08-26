import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/entities/ProdcutOptionAttribute.dart' show SwatchOption;
import '../../models/entities/product.dart';

enum VariantLayout { inline, dropdown }

class BasicSelection extends StatelessWidget {
  final Product? product;
  final Map<String?, String?>? imageUrls;
  final List<String?> options;
  final String? value;
  final String? title;
  final String? type;
  final Function? onChanged;
  final VariantLayout? layout;

  /// Option label -> swatch value (hex color or image URL), when the
  /// backend ships swatches with the attribute options.
  final Map<String, String>? swatchCodes;

  /// Option label -> rich swatch (product image, hex, child ids) from
  /// extension_attributes.swatches.
  final Map<String, SwatchOption>? swatchOptions;

  const BasicSelection(
      {super.key,
        required this.product,
      required this.options,
      required this.title,
      required this.value,
      this.type,
      this.layout,
      this.onChanged,
      this.swatchCodes,
      this.swatchOptions,
      this.imageUrls});

  @override
  Widget build(BuildContext context) {
    var primaryColor = Theme.of(context).primaryColor;
    if (const ['option', 'dropdown'].contains(type)) {
      return OptionSelection(
        options: options,
        value: value,
        title: title,
        onChanged: onChanged,
      );
    }
    if (type == 'image') {
      return ImageSelection(
        imageUrls: imageUrls,
        options: options,
        value: value,
        title: title,
        onChanged: onChanged,
      );
    }

    /// Web-parity layout: attribute label above a wrap of selectable
    /// swatches ('color') or labeled rectangular boxes (default/'box').
    ///
    /// Colours render as product photos only when *every* option has one, so
    /// the row can never mix photo tiles with hex circles — that mix is what
    /// made a lone image-type swatch read as a stray empty box beside the
    /// real colours (86d3g53dk #7).
    final showOptionImages = type == 'color' &&
        options.isNotEmpty &&
        options.every((item) => item != null && _imageFor(item).isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              // ignore: prefer_single_quotes
              "${title![0].toUpperCase()}${title!.substring(1)}",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: <Widget>[
            for (final item in options)
              if (item != null)
                _buildOption(context, item, primaryColor, showOptionImages),
          ],
        ),
      ],
    );
  }

  /// The product photo for [item] — the variant's own image from the swatches
  /// payload, else the one resolved from the loaded variations. Empty when the
  /// option has no photo.
  String _imageFor(String item) {
    final swatch = swatchOptions?[item];
    if (swatch?.hasImage ?? false) {
      return swatch!.productImage!;
    }
    return imageUrls?[item] ?? '';
  }

  Widget _buildOption(
    BuildContext context,
    String item,
    Color primaryColor,
    bool showOptionImages,
  ) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final selected = item.toUpperCase() == (value ?? '').toUpperCase();

    if (type == 'color') {
      final swatch = swatchOptions?[item];
      final hex = (swatch?.isColor ?? false)
          ? swatch?.swatchValue
          : (swatchCodes?[item] ?? getColorCode(item));

      final imageUrl = showOptionImages ? _imageFor(item) : '';

      if (imageUrl.isNotEmpty) {
        return GestureDetector(
          onTap: () => onChanged?.call(item),
          child: Tooltip(
            message: item,
            verticalOffset: 24,
            preferBelow: false,
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  width: selected ? 2.0 : 1.0,
                  color: selected ? primaryColor : secondary.withOpacity(0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    httpHeaders: const {'Accept': 'image/webp'},
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    errorWidget: (_, __, ___) => Container(
                      color: (hex?.startsWith('#') ?? false)
                          ? HexColor(hex!)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Fallback: plain colour circle. An image-type swatch (whose value is a
      // small swatch PNG rather than a hex code) fills the same circle, so the
      // row stays one uniform shape instead of sprouting a stretched tile.
      final colorCode = hex ?? '#ffffff';
      final isHex = colorCode.startsWith('#');
      final isSwatchImage = colorCode.contains('http');
      return GestureDetector(
        onTap: () => onChanged?.call(item),
        child: Tooltip(
          message: item,
          verticalOffset: 24,
          preferBelow: false,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isHex ? HexColor(colorCode) : Colors.white,
              image: isSwatchImage
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(colorCode,
                          headers: const {'Accept': 'image/webp'}),
                      fit: BoxFit.cover,
                    )
                  : null,
              shape: BoxShape.circle,
              border: Border.all(
                width: selected ? 2.0 : 1.0,
                color: selected ? primaryColor : secondary.withOpacity(0.3),
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onChanged?.call(item),
      child: Container(
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? primaryColor : secondary.withOpacity(0.3),
          ),
        ),
        child: Text(
          item,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : secondary,
          ),
        ),
      ),
    );
  }

   String getColorCode(String item){
     String colorCode = "#ffffff";
     product?.productOptions?.forEach((element){
         if(element.label == item){
           colorCode = element.swatch?.value ?? "#ffffff";
         }
     });
     return colorCode;
  }
}

class OptionSelection extends StatelessWidget {
  final List<String?> options;
  final String? value;
  final String? title;
  final Function? onChanged;
  final VariantLayout? layout;

  const OptionSelection({
    super.key,
    required this.options,
    required this.value,
    this.title,
    this.layout,
    this.onChanged,
  });

  // ignore: always_declare_return_types
  showOptions(context) {
    showModalBottomSheet(
      context: context,
      // https://github.com/inspireui/support/issues/4814#issuecomment-684179116
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.85,
          initialChildSize: 0.5,
          snap: true,
          snapSizes: const [
            0.5,
            0.85,
          ],
          minChildSize: 0.25,
          builder: (BuildContext context, ScrollController scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    title: Text(
                      S.of(context).selectTheSize,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.8),
                          ),
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  for (final option in options)
                    ListTile(
                      onTap: () {
                        onChanged!(option);
                        Navigator.pop(context);
                      },
                      title: Text(
                        option!.replaceAll('&amp;', '&'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showOptions(context),
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  // ignore: prefer_single_quotes
                  "${title![0].toUpperCase()}${title!.substring(1)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Text(
                value!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: kGrey600)
            ],
          ),
        ),
      ),
    );
  }
}

class ColorSelection extends StatelessWidget {
  final List<String> options;
  final String value;
  final Function? onChanged;
  final VariantLayout? layout;

  const ColorSelection(
      {super.key,
      required this.options,
      required this.value,
      this.layout,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (layout == VariantLayout.dropdown) {
      return GestureDetector(
        onTap: () => showOptions(context),
        child: Container(
          decoration:
              BoxDecoration(border: Border.all(width: 1.0, color: kGrey200)),
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(S.of(context).color,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                        color: kNameToHex[value.toLowerCase()] != null
                            ? HexColor(kNameToHex[value.toLowerCase()]!)
                            : Colors.transparent)),
                const SizedBox(width: 5),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: kGrey600)
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 25,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            Center(
              child: Text(
                S.of(context).color,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 15.0),
            for (var item in options)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
                margin: const EdgeInsets.only(right: 20.0),
                decoration: BoxDecoration(
                  color: item == value
                      ? HexColor(kNameToHex[item.toLowerCase()]!)
                      : HexColor(kNameToHex[item.toLowerCase()]!)
                          .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                      width: 1.0,
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.5)),
                ),
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    onChanged!(item);
                  },
                  child: SizedBox(
                    height: 25,
                    width: 25,
                    child: item == value
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void showOptions(context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final option in options)
                ListTile(
                  onTap: () {
                    onChanged!(option);
                    Navigator.pop(context);
                  },
                  title: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3.0),
                        border: Border.all(
                            width: 1.0,
                            color: Theme.of(context).colorScheme.secondary),
                        color: HexColor(kNameToHex[option.toLowerCase()]!),
                      ),
                    ),
                  ),
                ),
              Container(
                height: 1,
                decoration: const BoxDecoration(color: kGrey200),
              ),
              ListTile(
                title: Text(
                  S.of(context).selectTheColor,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ImageSelection extends StatelessWidget {
  final Map<String?, String?>? imageUrls;
  final List<String?> options;
  final String? value;
  final String? title;
  final Function? onChanged;
  final VariantLayout? layout;

  const ImageSelection({
    super.key,
    required this.options,
    required this.value,
    this.title,
    this.layout,
    this.onChanged,
    this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final size = kProductDetail.attributeImagesSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  // ignore: prefer_single_quotes
                  "${title![0].toUpperCase()}${title!.substring(1)}",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 0.0,
          children: <Widget>[
            for (var item in options)
              GestureDetector(
                onTap: () => onChanged!(item),
                child: Tooltip(
                  message: HtmlUnescape().convert(item!),
                  preferBelow: false,
                  verticalOffset: 32,
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    child: Container(
                      width: size + 2,
                      height: size + 2,
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.0),
                        border: Border.all(
                          width: 1.0,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(
                                  item.toUpperCase() == value!.toUpperCase()
                                      ? 0.6
                                      : 0.3),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (imageUrls![item]?.isNotEmpty ?? false)
                            Positioned.fill(
                              child: ImageResize(
                                url: imageUrls![item],
                                height: size,
                                width: size,
                              ),
                            )
                          else
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  HtmlUnescape().convert(item),
                                ),
                              ),
                            ),
                          if (item.toUpperCase() == value!.toUpperCase())
                            Positioned.fill(
                              child: Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .background
                                    .withOpacity(0.6),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ],
    );
  }
}
