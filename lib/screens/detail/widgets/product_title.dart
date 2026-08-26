import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:magentoegypt/common/extensions.dart';
import 'package:magentoegypt/models/entities/paging_response.dart';
import 'package:magentoegypt/models/entities/product_review.dart';
import 'package:provider/provider.dart';
import 'package:quiver/strings.dart';

import '../../../common/config.dart';
import '../../../common/tools.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart'
    show AppModel, Product, ProductModel, ProductVariation;
import '../../../modules/dynamic_layout/helper/countdown_timer.dart';
import '../../../services/index.dart';
import '../../../widgets/common/start_rating.dart';
import '../../../widgets/product/index.dart' show SaleProgressBar;
import '../../base_screen.dart';

class ProductTitle extends StatefulWidget {
  final Product? product;

  const ProductTitle(this.product);

  @override
  BaseScreen<ProductTitle> createState() => _ProductTitleState();
}

class _ProductTitleState extends BaseScreen<ProductTitle> {
  var regularPrice;
  bool onSale = false;
  int sale = 100;
  String? price;
  ProductVariation? productVariation;
  String? dateOnSaleTo;

  @override
  void afterFirstLayout(BuildContext context) async {
    getProductPrice();
  }

  // ignore: always_declare_return_types
  getProductPrice() {
    try {
      regularPrice = productVariation != null
          ? productVariation!.regularPrice
          : widget.product!.regularPrice;
      onSale = productVariation != null
          ? productVariation!.onSale ?? false
          : widget.product!.onSale ?? false;
      price = productVariation != null &&
              (productVariation?.price?.isNotEmpty ?? false)
          ? productVariation!.price
          : isNotBlank(widget.product!.price)
              ? widget.product!.price
              : widget.product!.regularPrice;

      /// update the Sale price
      if (onSale) {
        price = productVariation != null
            ? productVariation!.salePrice
            : isNotBlank(widget.product!.salePrice)
                ? widget.product!.salePrice
                : widget.product!.price;
        dateOnSaleTo = productVariation != null
            ? productVariation!.dateOnSaleTo
            : widget.product!.dateOnSaleTo;
      }

      if (onSale && regularPrice.isNotEmpty && double.parse(regularPrice) > 0) {
        sale = (100 - (double.parse(price!) / double.parse(regularPrice)) * 100)
            .toInt();
      }
    } catch (e, trace) {
      printError(e, trace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    productVariation = Provider.of<ProductModel>(context).selectedVariation;
    getProductPrice();

    final currency = Provider.of<AppModel>(context).currency;
    final currencyRate = Provider.of<AppModel>(context).currencyRate;
    final dateOnSaleTo = DateTime.tryParse(productVariation?.dateOnSaleTo ??
            widget.product!.dateOnSaleTo ??
            '')
        ?.millisecondsSinceEpoch;
    final countDown =
        (dateOnSaleTo ?? 0) - DateTime.now().millisecondsSinceEpoch;
    var isShowCountDown =
        kSaleOffProduct.showCountDown && dateOnSaleTo != null && countDown > 0;

    var isSaleOff = (onSale &&
            widget.product!.type != 'grouped' &&
            widget.product!.type != 'variable') ||
        (onSale &&
            widget.product!.isVariableProduct &&
            productVariation != null);

    /// Same two routes as on the card: the "before" price is struck through
    /// above the current price (keyed on `original_price`) and again below it
    /// (keyed on `isSaleOff`). Catalog-price-rule discounts set both, so show
    /// the upper one only.
    final showsOriginalAbove = widget.product?.original_price != null &&
        !isEqual(widget.product?.price ?? '',
            widget.product?.original_price ?? '');

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        //if (widget.product!.vendor != null)
        Row(
          children: <Widget>[
            Text(
              widget.product?.vendor ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.product?.name ?? '',
                style: Theme.of(context).textTheme.headlineSmall!,
              ),
            ),
            if (isSaleOff)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                margin: const EdgeInsets.only(left: 4, top: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  S.of(context).sale('$sale'),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
          ],
        ),
        // const SizedBox(height: 10),
        ReviewsStarRating(
          product: widget.product!,
        ),
        const SizedBox(height: 10),
        if(widget.product?.original_price != null &&
            !isEqual(widget.product?.price ?? '',widget.product?.original_price ?? ''))
          Text(
            '${ PriceTools.getOriginalPriceProduct(
                widget.product, currencyRate, currency,
                onSale: true)!}',
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              decoration: TextDecoration.combine(
                  [TextDecoration.lineThrough]),
            )
                .apply(fontSizeFactor: 0.8),
          ),
// product price
        Services().widget.renderDetailPrice(context, widget.product!, price),

        /// For variable product, hide regular price when loading product variation.
        if (isSaleOff) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (!showsOriginalAbove) ...[
                Text(
                  PriceTools.getCurrencyFormatted(
                    regularPrice,
                    currencyRate,
                    currency: currency,
                  )!,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
                const SizedBox(width: 10),
              ],
              if (isShowCountDown) ...[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    S.of(context).endsIn('').toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(
                          color: theme.colorScheme.secondary.withOpacity(0.9),
                        )
                        .apply(fontSizeFactor: 0.6),
                  ),
                ),
                CountDownTimer(
                  Duration(milliseconds: countDown),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
        ],
        Row(
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            if (kAdvanceConfig.enableRating &&
                widget.product!.averageRating != null)
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: SmoothStarRating(
                  allowHalfRating: true,
                  starCount: 5,
                  spacing: 0.0,
                  rating: widget.product!.averageRating,
                  size: 17.0,
                  label: Text(
                    ' (${widget.product!.ratingCount})',
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.8),
                        ),
                  ),
                ),
              ),
            const Spacer(),
            if (dateOnSaleTo != null && countDown > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: SaleProgressBar(
                  product: widget.product,
                  productVariation: productVariation,
                  width: 160,
                ),
              ),
          ],
        ),
      ],
    );
  }
  bool isEqual(String price,String original_price){
    try{
      var priceDouble = double.parse(price);
      var original_priceDouble = double.parse(original_price);
      return priceDouble == original_priceDouble;
    }on Exception catch (_) {
      return false;
    }
  }
}

class ReviewsStarRating extends StatefulWidget {
  final Product product;

  const ReviewsStarRating({super.key, required this.product});

  @override
  State<ReviewsStarRating> createState() => _ReviewsStarRatingState();
}

class _ReviewsStarRatingState extends State<ReviewsStarRating> {
  PagingResponse<ProductReview>? reviewData;
  var allRatings = <Ratings>[];
  bool isLoading = false;
  double averageRating = 0;

  @override
  void initState() {
    super.initState();
    getProductsReviews(); // Set the initial value of the counter to 42
  }

  Future<void> getProductsReviews() async {
    setState(() {
      isLoading = true;
    });

    try {
      var result = await Services()
          .api
          .getProductReviews(widget.product.sku); //'BAG202922'

      setState(() {
        reviewData = result;
        isLoading = false;
      });

      // get all Rating
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      'e]'.log();
    }
  }

  double calculateAverageRating(List<ProductReview> reviews) {
    var ratings = <Ratings>[];
    for (final review in reviews) {
      ratings.addAll(review.ratings ?? []);
    }

    setState(() {
      allRatings = ratings;
    });

    if (ratings.isEmpty) {
      return 0.0; // Return 0 if no ratings are available
    }

    var sum = 0.0;
    var count = 0;

    for (final rating in ratings) {
      // Prefer the precise 0-100 percent (÷20 → 0-5) over the whole-star
      // `value`, which is rounded and inflates/deflates the average.
      if (rating.percent != null) {
        sum += rating.percent! / 20.0;
        count++;
      } else if (rating.value != null) {
        sum += rating.value!;
        count++;
      }
    }

    if (count == 0) {
      return 0.0; // Return 0 if no valid ratings are available
    }
    setState(() {
      averageRating = sum / count;
    });
    return sum / count; // Calculate the average rating
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: getPadding(left: 2, top: 9),
      child: isLoading
          ? const LinearProgressIndicator()
          : (reviewData?.data?.length ?? 0) < 0
              ? const SizedBox.shrink()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: getPadding(top: 2, left: 5),
                      child: Text(
                        '${calculateAverageRating(reviewData?.data ?? [])}/${allRatings.length}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: AppStyle.txtBarlowMedium15.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                    if (averageRating > 0)
                      CustomImageView(
                        svgPath: ImageConstant.imgStarAmber700,
                        height: getSize(20),
                        width: getSize(20),
                        margin: getMargin(left: 8),
                      ),
                    (averageRating > 1)
                        ? CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          )
                        : CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            color: Colors.grey,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          ),
                    (averageRating > 2)
                        ? CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          )
                        : CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            color: Colors.grey,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          ),
                    (averageRating > 3)
                        ? CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          )
                        : CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            color: Colors.grey,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          ),
                    (averageRating > 4)
                        ? CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          )
                        : CustomImageView(
                            svgPath: ImageConstant.imgStarAmber700,
                            color: Colors.grey,
                            height: getSize(20),
                            width: getSize(20),
                            margin: getMargin(left: 4),
                          ),
                    const Spacer(),
                    // InkWell(
                    //   onTap: () {
                    //     getProductsReviews();
                    //   },
                    //   child:

                    Padding(
                      padding: getPadding(top: 1, bottom: 4),
                      child: (reviewData?.data?.length ?? 0) > 1
                          ? Text(
                              '(${reviewData?.data?.length}  ${S.of(context).reviews})',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                              style: AppStyle.txtCaption.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              '(${reviewData?.data?.length}  ${S.of(context).review})',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                              style: AppStyle.txtCaption.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                    ),
                    // ),
                  ],
                ),
    );
  }
}
