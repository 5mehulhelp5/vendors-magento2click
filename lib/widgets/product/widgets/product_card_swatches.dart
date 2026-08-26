import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart' show HexColor;

import '../../../models/entities/ProdcutOptionAttribute.dart';
import '../../../models/entities/product.dart';

/// Variant preview shown on a product grid card, below the price:
///  - colour options as circular product-image thumbnails (the variant photo),
///  - size options as small outlined chips.
/// Both come from extension_attributes.swatches; renders nothing for the part
/// a product doesn't have (e.g. a size-only product shows just the size chips).
class ProductCardSwatches extends StatelessWidget {
  final Product product;
  final int maxColors;
  final int maxSizes;

  const ProductCardSwatches({
    super.key,
    required this.product,
    // Bounded so the preview never wraps past the card's reserved height:
    // colours stay on one row, sizes on at most two — the rest collapse to a
    // "+N" chip. See the height budget in product_list.dart.
    this.maxColors = 3,
    this.maxSizes = 4,
  });

  /// The colour attribute — visual swatches (swatch_type color/image), 2+ opts.
  ConfigurableSwatch? _colorSwatch() {
    for (final s in product.swatches ?? const <ConfigurableSwatch>[]) {
      final isColor = s.attributeCode == 'all_color' ||
          s.options
              .any((o) => o.swatchType == 'color' || o.swatchType == 'image');
      if (isColor && s.options.length > 1) {
        return s;
      }
    }
    return null;
  }

  /// The size attribute — text swatches (swatch_type text), 2+ opts.
  ConfigurableSwatch? _sizeSwatch() {
    for (final s in product.swatches ?? const <ConfigurableSwatch>[]) {
      final isText = s.options.isNotEmpty &&
          s.options.every((o) => o.swatchType == 'text' || o.swatchType == null);
      if (isText && s.options.length > 1) {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorSwatch();
    final size = _sizeSwatch();
    if (color == null && size == null) {
      return const SizedBox.shrink();
    }
    // When both rows show, cap the sizes harder so a colour row + size chips
    // stay within the card's reserved height (never more than ~3 rows total).
    final sizeLimit = color != null ? 3 : maxSizes;
    final rows = <Widget>[
      if (color != null) _colorRow(context, color),
      if (size != null) _sizeRow(context, size, sizeLimit),
    ];
    // Space only *between* rows — the gap above (price↔chips) is owned by the
    // card so the price keeps balanced top/bottom spacing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }

  Widget _colorRow(BuildContext context, ConfigurableSwatch swatch) {
    final options = swatch.options
        .where((o) =>
            (o.productImage?.isNotEmpty ?? false) ||
            (o.swatchValue?.isNotEmpty ?? false))
        .toList();
    final shown = options.take(maxColors).toList();
    final extra = options.length - shown.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final o in shown) _colorCircle(context, o),
        if (extra > 0) _moreLabel(context, extra),
      ],
    );
  }

  Widget _colorCircle(BuildContext context, SwatchOption option) {
    final border = Border.all(
      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
    );
    final imageUrl = (option.productImage?.isNotEmpty ?? false)
        ? option.productImage
        : ((option.swatchValue?.contains('http') ?? false)
            ? option.swatchValue
            : null);
    if (imageUrl != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, border: border),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: const {'Accept': 'image/webp'},
            fit: BoxFit.cover,
            // Small circular swatch — cache on disk and decode at display size
            // instead of re-downloading/decoding the full image each time.
            memCacheWidth: (40 * MediaQuery.devicePixelRatioOf(context)).round(),
            errorWidget: (_, __, ___) =>
                _hexFill(context, option.swatchValue),
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, border: border),
      child: ClipOval(child: _hexFill(context, option.swatchValue)),
    );
  }

  Widget _hexFill(BuildContext context, String? hex) => Container(
        color: (hex?.startsWith('#') ?? false) ? HexColor(hex!) : Colors.white,
      );

  Widget _sizeRow(BuildContext context, ConfigurableSwatch swatch, int limit) {
    final options =
        swatch.options.where((o) => (o.label?.isNotEmpty ?? false)).toList();
    final shown = options.take(limit).toList();
    final extra = options.length - shown.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in shown) _sizeChip(context, o.label!),
        if (extra > 0) _moreLabel(context, extra),
      ],
    );
  }

  Widget _sizeChip(BuildContext context, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        // Keep size labels left-to-right (e.g. "6 yrs") in the forced-RTL app.
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _moreLabel(BuildContext context, int extra) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '+$extra',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
}
