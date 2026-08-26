import 'package:flutter/material.dart';

import '../../../common/config.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart' show Product;
import '../../../widgets/common/index.dart';
import '../../../widgets/product/widgets/product_html_content.dart';
import 'additional_information.dart';

class ProductDescription extends StatelessWidget {
  final Product? product;

  const ProductDescription(this.product);

  bool get enableBrand => kProductDetail.showBrand;


  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 15),
        if (product!.description != null && product!.description!.isNotEmpty)
          ExpansionInfo(
            title: S.of(context).details,
            // titleWidget: Container(
            //   height: 50,
            //   padding: const EdgeInsets.only(left: 3),
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(3),
            //     color: Theme.of(context).primaryColor,
            //   ),
            //   child: Center(
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Text(
            //           S.of(context).description,
            //           style: const TextStyle(
            //             color: Colors.white,
            //             fontWeight: FontWeight.bold,
            //             fontSize: 16,
            //           ),
            //         ),
            //         const Icon(
            //           Icons.keyboard_arrow_up,
            //           color: Colors.white,
            //           size: 20,
            //         )
            //       ],
            //     ),
            //   ),
            // ),
            expand: true,
            children: <Widget>[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // Rendered as HTML, not flattened to text: the description is
                // Page Builder markup, and stripping it to a string dropped
                // every image and video before they reached the screen.
                child: ProductHtmlContent(
                  product!.description!,
                  textColor: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        if (product!.infors.isNotEmpty)
          ExpansionInfo(
            expand: true,
            title: S.of(context).additionalInformation,
            children: <Widget>[
              AdditionalInformation(
                listInfo: product!.infors,
              ),
            ],
          ),
      ],
    );
  }

}
