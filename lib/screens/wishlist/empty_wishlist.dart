import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';

import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart' show Product;
import '../../services/service_config.dart';
import '../../services/services.dart';
import '../../widgets/product/dialog_add_to_cart.dart';
import '../../widgets/product/widgets/pricing.dart';

class EmptyWishlist extends StatelessWidget {
  final VoidCallback onShowHome;
  final VoidCallback onSearchForItem;

  const EmptyWishlist({
    required this.onShowHome,
    required this.onSearchForItem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 80),
          Image.asset(
            'assets/images/empty_wishlist.png',
            width: 120,
            height: 120,
            color: Theme.of(context).primaryColor.withOpacity(0.8),
          ),
          const SizedBox(height: 20),
          Text(
            S.of(context).noFavoritesYet,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Text(S.of(context).emptyWishlistSubtitle,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center),
          // const SizedBox(height: 30),
          // Row(
          //   children: [
          //     Expanded(
          //       child: ButtonTheme(
          //         height: 45,
          //         child: ElevatedButton(
          //           style: ElevatedButton.styleFrom(
          //             foregroundColor: Colors.white,
          //             backgroundColor: Theme.of(context).primaryColor,
          //           ),
          //           onPressed: onShowHome,
          //           child: Text(
          //             S.of(context).startShopping.toUpperCase(),
          //           ),
          //         ),
          //       ),
          //     )
          //   ],
          // ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ButtonTheme(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      backgroundColor: kGrey200,
                    ),
                    onPressed: onSearchForItem,
                    child: Text(S.of(context).searchForItems.toUpperCase()),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class WishlistItem extends StatelessWidget {
  const WishlistItem({required this.product, this.onAddToCart, this.onRemove});

  final Product product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onRemove;

  /// Every tile is laid out identically so the rows line up: the image takes
  /// whatever vertical space is left, and the name, price and button occupy
  /// fixed-height slots. Previously the name (1-2 lines) and the price (1 line,
  /// or 2 when there is a strike-through original) changed the tile's height,
  /// so the ADD TO CART buttons sat at different heights — and the content
  /// overflowed the grid cell by ~30px, which in a release build silently
  /// clips instead of showing the debug stripes (86d3rtbnp).
  /// Read by the wishlist grid to size each cell — keep the two in step.
  static const double nameHeight = 36;
  static const double priceHeight = 46;

  /// Slots grow with the system font scale so larger text still fits; the
  /// grid applies the identical clamp when sizing the cell.
  static double textScaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  @override
  Widget build(BuildContext context) {
    final localTheme = Theme.of(context);
    final scale = textScaleOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: AppDecoration.outlineBluegray50019.copyWith(
        borderRadius: BorderRadiusStyle.roundedBorder4,
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            RouteList.productDetail,
            arguments: product,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            key: ValueKey(product.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flexible, so the tile absorbs any leftover height here rather
              // than pushing the button out of the cell.
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ImageResize(
                        url: product.imageFeature,
                        size: kSize.medium,
                      ),
                    ),
                    Positioned(
                      top: -8,
                      left: -8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onRemove,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: nameHeight * scale,
                child: Text(
                  product.name ?? '',
                  style: localTheme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: priceHeight * scale,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ProductPricing(product: product, hide: false),
                ),
              ),
              if (Services().widget.enableShoppingCart(product) &&
                  !ServerConfig().isListingType)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: localTheme.primaryColor,
                    minimumSize: const Size.fromHeight(40),
                    maximumSize: const Size(double.infinity, 40),
                    padding: EdgeInsets.zero,
                  ),
                  // Use the wishlist screen's type-aware handler (simple -> add
                  // directly, configurable -> open product page). Fall back to
                  // the add-to-cart dialog if no handler was supplied.
                  onPressed: onAddToCart ??
                      () => DialogAddToCart.show(context, product: product),
                  child: (product.isPurchased && product.isDownloadable!)
                      ? Text(S.of(context).download.toUpperCase())
                      : Text(
                          S.of(context).addToCart.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
