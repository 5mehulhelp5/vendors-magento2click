import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart' show Product, Review, UserModel;
import '../../services/index.dart';
import '../../widgets/common/start_rating.dart';
import '../common/app_bar_mixin.dart';
import '../detail/widgets/image_galery.dart';

/// The signed-in customer's own reviews across all products (My Account →
/// My Reviews). Reads the `self`-scoped reviews feed via [Services.api]'s
/// getMyReviews — includes pending / not-approved so the shopper can see a
/// review's moderation state — and resolves product name + thumbnail per SKU
/// in one lookup for context.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> with AppBarMixin {
  final services = Services();

  /// null while the first load is in flight; a list (possibly empty) after.
  List<Review>? _reviews;
  Map<String, ({String name, String? image})> _products = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final user = Provider.of<UserModel>(context, listen: false).user;
    try {
      final res = await services.api.getMyReviews(token: user?.cookie);
      final list = res?.data ?? <Review>[];
      // Resolve product name + thumbnail for every reviewed SKU in one call.
      final skus = list
          .map((r) => r.sku)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      final products = skus.isEmpty
          ? <String, ({String name, String? image})>{}
          : await services.api.getReviewedProductInfo(skus);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _products = products;
      });
    } catch (e) {
      printLog('MyReviews load error: $e');
      if (mounted) {
        setState(() => _reviews = <Review>[]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return renderScaffold(
      routeName: RouteList.myReviews,
      secondAppBar: AppBar(
        title: Text(
          S.of(context).myReviews,
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_sharp,
            color: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_reviews == null) {
      return Center(child: kLoadingWidget(context));
    }
    if (_reviews!.isEmpty) {
      // Keep it scrollable so pull-to-refresh works from the empty state too.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Text(
                S.of(context).noReviews,
                style: const TextStyle(color: kGrey600),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        // Without this a short list (fewer reviews than fill the screen) never
        // reports an overscroll, so the RefreshIndicator above never fires.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12.0),
        itemCount: _reviews!.length,
        itemBuilder: (context, index) => _reviewCard(_reviews![index]),
      ),
    );
  }

  /// Open the reviewed product's detail page. The feed carries only the SKU,
  /// so fetch the full product first (admin-token search) behind a brief
  /// loader; if it's gone from the catalog, say so instead of navigating.
  Future<void> _openProduct(Review review) async {
    final sku = review.sku;
    if (sku == null || sku.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: kLoadingWidget(context)),
    );
    Product? product;
    try {
      product = await services.api.getProductBySku(sku);
    } catch (_) {
      product = null;
    }
    navigator.pop(); // dismiss the loader
    if (!mounted) return;
    if (product == null) {
      Tools.showSnackBar(messenger, S.of(context).notFound);
      return;
    }
    navigator.pushNamed(RouteList.productDetail, arguments: product);
  }

  Widget _reviewCard(Review review) {
    final theme = Theme.of(context);
    final product = review.sku != null ? _products[review.sku] : null;
    final productName = (product?.name.isNotEmpty ?? false)
        ? product!.name
        : (review.sku ?? '');

    return GestureDetector(
      onTap: () => _openProduct(review),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product?.image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: ImageResize(
                        url: product!.image,
                        // Use the app's -small/-medium resize backend (the
                        // Magento resize cache serves a placeholder here).
                        isResize: true,
                        size: kSize.small,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: kGrey400),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (kAdvanceConfig.enableRating)
                    SmoothStarRating(
                      label: const Text(''),
                      allowHalfRating: true,
                      starCount: 5,
                      rating: review.rating ?? 0.0,
                      size: 16.0,
                      color: theme.primaryColor,
                      borderColor: theme.primaryColor,
                      spacing: 0.0,
                    ),
                  const Spacer(),
                  _statusChip(review.status),
                ],
              ),
              if ((review.review ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.review!,
                  style: const TextStyle(color: kGrey600, fontSize: 14),
                ),
              ],
              if (review.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < review.images.length; i++)
                        InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => ImageGalery(
                              images: review.images,
                              index: i,
                              resize: false,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ImageResize(
                              url: review.images[i],
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                timeago.format(review.createdAt),
                style: const TextStyle(color: kGrey400, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A small status pill for the customer's own review. Approved reviews carry
  /// no pill; pending / not-approved are called out so the shopper knows why a
  /// review isn't public yet.
  Widget _statusChip(String? status) {
    final theme = Theme.of(context);
    final String label;
    final Color color;
    switch (status) {
      case 'pending':
        label = S.of(context).reviewPending;
        color = theme.colorScheme.secondary;
        break;
      case 'not_approved':
        label = S.of(context).reviewNotApproved;
        color = theme.colorScheme.error;
        break;
      default:
        return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.0, color: color)),
    );
  }
}
