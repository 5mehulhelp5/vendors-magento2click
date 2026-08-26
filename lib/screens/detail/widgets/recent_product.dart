import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n.dart';
import '../../../models/index.dart';
import '../../../modules/dynamic_layout/config/index.dart';
import '../../../modules/dynamic_layout/product/product_recent_placeholder.dart';
import '../../../services/index.dart';
import '../../../widgets/product/product_card_view.dart';

class RecentProducts extends StatelessWidget {
  final Product? excludeProduct;

  const RecentProducts({
    super.key,
    this.excludeProduct,
  });

  @override
  Widget build(BuildContext context) {
    final products = List.from(context.select((RecentModel _) => _.products));
    if (excludeProduct != null) {
      products.removeWhere((item) => item.id == excludeProduct?.id);
    }
    if (products.length < 3) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(
            vertical: 18.0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ),
          child: Text(
            S.of(context).recentlyViewed,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (ServerConfig().isBuilder)
          ProductRecentPlaceholder()
        else
          LayoutBuilder(
            builder: (context, constraint) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // Cards carry a variable number of swatch/size rows, so they
              // have different natural heights and ended up staggered
              // (86d3wchq2). Same fix as the related products list
              // (86d3r0k6x): IntrinsicHeight sizes the row to the tallest
              // card and `stretch` makes every card take that height, so
              // tops and bottoms line up.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (Product item in products)
                      ProductCard(
                        item: item,
                        width: constraint.maxWidth * 0.35,
                        config: ProductConfig.empty(),
                      )
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
