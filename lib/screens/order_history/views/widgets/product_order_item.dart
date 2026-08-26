// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inspireui/inspireui.dart';
import '../../../../common/config.dart';
import '../../../../common/constants.dart';
import '../../../../common/tools.dart';
import '../../../../generated/l10n.dart';
import '../../../../models/entities/store_delivery_date.dart';
import '../../../../models/index.dart';
import '../../../../services/index.dart';
import '../../../detail/widgets/review.dart';
import '../../../index.dart';

class ProductOrderItem extends StatefulWidget {
  final String orderId;
  final OrderStatus orderStatus;
  final ProductItem product;
  final List<StoreDeliveryDate>? storeDeliveryDates;
  final String? currencyCode;
  final bool disableReview;

  /// For prestashop.
  final int index;

  const ProductOrderItem(
      {super.key,
      required this.orderId,
      required this.orderStatus,
      required this.product,
      this.storeDeliveryDates,
      this.currencyCode,
      this.index = 0,
      this.disableReview = false});

  @override
  BaseScreen<ProductOrderItem> createState() => _StateProductOrderItem();
}

class _StateProductOrderItem extends BaseScreen<ProductOrderItem> {
  Product? product;
  late String imageFeatured = kDefaultImage;
  bool isLoading = true;
  String? deliveryDate = null;

  /// Ordered configurable options as localized {'name': label, 'value': label}
  /// pairs (86d3tkhgz #3), resolved from widget.product.configurableOptionIds.
  List<Map<String, dynamic>> _resolvedOptions = [];

  @override
  void afterFirstLayout(BuildContext context) async {
    super.afterFirstLayout(context);

    // Resolve the ordered configurable options to localized "label: value"
    // pairs (e.g. "Size: 10 yrs"). Falls back to the value-only variant when
    // this yields nothing (86d3tkhgz #3).
    if (widget.product.configurableOptionIds.isNotEmpty) {
      final resolved = await Services()
          .api
          .resolveConfigurableOptions(widget.product.configurableOptionIds);
      if (mounted && resolved.isNotEmpty) {
        setState(() => _resolvedOptions = resolved);
      }
    }

    // Fetch the full product when we need its image OR its canonical review
    // sku. A completed order's review must target the configurable PARENT, but
    // the order line replaces the parent sku with the ordered CHILD sku (its
    // product_id still points at the parent), so resolve the parent here.
    final needsProduct = widget.product.featuredImage == null ||
        (widget.orderStatus == OrderStatus.completed && !widget.disableReview);
    if (needsProduct) {
      var productObj = await Services().api.getProduct(
            widget.product.productId,
          );
      if (productObj != null) {
        setState(() {
          product = productObj;
          imageFeatured = product!.imageFeature ??
              widget.product.featuredImage ??
              kDefaultImage;
        });
      } else {
        setState(() {
          imageFeatured = widget.product.featuredImage ?? kDefaultImage;
        });
      }
    } else {
      setState(() {
        imageFeatured = widget.product.featuredImage ?? kDefaultImage;
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  void navigateToProductDetail() async {
    if (product == null) {
      final productVal =
          await Services().api.getProduct(widget.product.productId);
      setState(() {
        product = productVal;
      });
    }
    await Navigator.of(context).pushNamed(
      RouteList.productDetail,
      arguments: product,
    );
  }

  Widget _buildItemDesc(String title, String content) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 3.0,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 8,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Spacer(),
          Text(
            content,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode =
        widget.currencyCode ?? Provider.of<AppModel>(context).currencyCode;
    var addonsOptions = {};
    if (widget.product.addonsOptions.isNotEmpty) {
      for (var element in widget.product.addonsOptions.keys) {
        addonsOptions[element] =
            Tools.getFileNameFromUrl(widget.product.addonsOptions[element]!);
      }
    }

    if (widget.storeDeliveryDates != null &&
        widget.storeDeliveryDates!.isNotEmpty) {
      var storeIndex = widget.storeDeliveryDates!
          .indexWhere((element) => element.storeId == widget.product.storeId);

      if (storeIndex != -1) {
        deliveryDate = widget.storeDeliveryDates![storeIndex].displayDDate;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: navigateToProductDetail,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'image-${widget.orderId}${widget.product.productId!}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.withOpacity(0.2),
                    child: isLoading
                        ? const Skeleton(
                            width: 80,
                            height: 80,
                          )
                        : ImageResize(
                            url: imageFeatured,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Bidi.stripHtmlIfNeeded(
                        widget.product.name!,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Selected configurable options as "label: value" (e.g.
                    // "Size: 10 yrs", "Color: Green"), resolved from the order's
                    // option ids and localized like the website (86d3tkhgz #3).
                    // Falls back to the value-only variant derived from the
                    // child line when the labels could not be resolved.
                    if (_resolvedOptions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: ProductOptions(prodOptions: _resolvedOptions),
                      )
                    else if (widget.product.variant?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          widget.product.variant!,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.75),
                                  ),
                        ),
                      ),
                    // SKU of the ordered product, shown like the website's order
                    // view (86d3tkhgz #4). On a configurable line this is the
                    // ordered child sku the order carries.
                    if (widget.product.sku?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${S.of(context).sku}: ${widget.product.sku}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            S
                                .of(context)
                                .qtyTotal(widget.product.quantity ?? ''),
                          ),
                        ),
                        if (widget.orderStatus == OrderStatus.completed)
                          if (!kPaymentConfig.enableShipping ||
                              !kPaymentConfig.enableAddress)
                            DownloadButton(widget.product.productId),
                      ],
                    ),
                    if (widget.product.prodOptions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ProductOptions(
                            prodOptions: widget.product.prodOptions),
                      ),
                    if (widget.product.storeName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.product.storeName ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        /// Review for completed order only.
        if (widget.orderStatus == OrderStatus.completed &&
            !widget.disableReview &&
            !isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Reviews(
              // Reviews attach to a SKU. For a configurable product the order
              // line carries the ordered CHILD sku, so a review would land on
              // the variant instead of the product page. `product` is fetched
              // by the line's product_id (which points at the configurable
              // PARENT), so its sku is the parent sku — use it, falling back to
              // the line sku (86d3rytm0: never the numeric product_id) if the
              // fetch failed. Gated on !isLoading so Reviews builds once with
              // the resolved sku instead of first querying the child.
              product?.sku ?? widget.product.sku ?? widget.product.productId,
              showYourRatingOnly: true,
            ),
          ),
        const SizedBox(height: 5),
        _buildItemDesc(
            S.of(context).itemTotal,
            PriceTools.getCurrencyFormatted(
              widget.product.total,
              null,
              currency: currencyCode,
            )!),
        if (deliveryDate != null) ...[
          const SizedBox(height: 2),
          _buildItemDesc(S.of(context).deliveryDate, deliveryDate!),
        ],

        const SizedBox(height: 10),
      ],
    );
  }
}

class DownloadButton extends StatefulWidget {
  final String? id;

  const DownloadButton(this.id, {super.key});

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final services = Services();
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      ),
      onPressed: isLoading
          ? null
          : () async {
              try {
                setState(() {
                  isLoading = true;
                });

                var product = await services.api.getProduct(widget.id);
                setState(() {
                  isLoading = false;
                });

                if (product?.files?.isEmpty ?? true) {
                  throw Exception(S.of(context).noFileToDownload);
                }

                await Tools.launchURL(product!.files!.first!);
              } catch (err) {
                Tools.showSnackBar(ScaffoldMessenger.of(context), '$err');
              } finally {
                if (isLoading) {
                  setState(() {
                    isLoading = false;
                  });
                }
              }
            },
      icon: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
              ),
            )
          : Icon(
              Icons.file_download,
              color: Theme.of(context).primaryColor,
            ),
      label: Text(
        S.of(context).download,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class ProductOptions extends StatelessWidget {
  final List<Map<String, dynamic>?> prodOptions;

  const ProductOptions({super.key, required this.prodOptions});

  @override
  Widget build(BuildContext context) {
    var list = <Widget>[];
    for (var option in prodOptions) {
      list.add(Row(
        children: [
          Text(option?['name'] + ':'),
          const SizedBox(width: 10.0),
          Text(option?['value']),
        ],
      ));
      list.add(const SizedBox(
        height: 5.0,
      ));
    }
    return Column(children: list);
  }
}
