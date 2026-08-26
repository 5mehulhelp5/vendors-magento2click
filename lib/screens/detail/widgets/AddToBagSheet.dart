import 'package:flutter/material.dart';
import 'package:quiver/strings.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/tools/image_resize.dart';
import '../../../generated/l10n.dart';
import '../../../models/entities/product.dart';
import '../../../models/entities/product_variation.dart';
import '../../../services/services.dart';
import '../../../widgets/product/widgets/pricing.dart';
import '../../cart/cart_screen.dart';

class AddToBagSheet extends StatelessWidget {
  final Product? product;

  /// The variation that was added. Passed in explicitly because the modal
  /// route sits outside the page-local ProductModel provider — reading the
  /// provider here would get the global (empty) one and show the base price.
  final ProductVariation? variation;

   AddToBagSheet({super.key, required this.product, this.variation});

  @override
  Widget build(BuildContext context) {
    int sale = 100;
    String? price;
    bool onSale = false;

    ProductVariation? productVariation = variation;
   String? getProductPrice() {
      try {
        onSale = productVariation != null
            ? productVariation!.onSale ?? false
            : product!.onSale ?? false;
        price = productVariation != null &&
            (productVariation?.price?.isNotEmpty ?? false)
            ? productVariation!.price
            : isNotBlank(product!.price)
            ? product!.price
            : product!.regularPrice;

        /// update the Sale price
        if (onSale) {
          price = productVariation != null
              ? productVariation!.salePrice
              : isNotBlank(product!.salePrice)
              ? product!.salePrice
              : product!.price;
        }
      } catch (e, trace) {

      }
      return price;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // to balance the X icon space
               Text(
                S.of(context).addToCart,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Discount tag
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.grey.shade200,
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: const Text(
          //     'خصم 15% أقل',
          //     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          //   ),
          // ),

          const SizedBox(height: 16),

          // Product info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              SizedBox(
                height: 100,
                width: 60,
                child: ImageResize(
                  url: productVariation?.imageFeature ?? product?.imageFeature,
                  fit: BoxFit.contain,
                  isResize: true,
                  size: kSize.medium,
                  width: 60,
                  hidePlaceHolder: true,
                  forceWhiteBackground: kProductDetail.forceWhiteBackground,
                ),
              ),
              const SizedBox(width: 16),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full name, wrapping to as many lines as needed.
                    Text(
                      product?.name ?? "",
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Services().widget.renderDetailPrice(context, product!, getProductPrice()),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Add to bag button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  RouteList.cart,
                  arguments: CartScreenArgument(isBuyNow: true, isModal: false),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                S.of(context).goToShoppingCart,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

}