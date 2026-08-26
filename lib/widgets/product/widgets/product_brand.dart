import 'package:flutter/material.dart';

import '../../../models/entities/product.dart';

class ProductBrand extends StatelessWidget {
  final Product product;
  const ProductBrand({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final brand = product.vendor;
    if (brand == null || brand.isEmpty) return const SizedBox();

    return Text(
      brand.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context)
          .textTheme
          .bodySmall!
          .copyWith(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          )
          .apply(fontSizeFactor: 0.85),
    );
  }
}
