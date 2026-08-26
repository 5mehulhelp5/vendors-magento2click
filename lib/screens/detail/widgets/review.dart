import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/tools.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart' show Review, UserModel;
import '../../../services/index.dart';
import '../../../widgets/common/start_rating.dart';
import '../../base_screen.dart';
import 'index.dart';

class Reviews extends StatefulWidget {
  final String? productId;
  final bool allowRating;
  final bool showYourRatingOnly;

  const Reviews(
    this.productId, {
    this.allowRating = true,
    this.showYourRatingOnly = false,
  });

  @override
  BaseScreen<Reviews> createState() => _StateReviews();
}

class _StateReviews extends BaseScreen<Reviews> {
  final services = Services();
  List<Review>? reviews;

  @override
  void afterFirstLayout(BuildContext context) {
    getListReviews(context);
  }

  void getListReviews(BuildContext context) {
    final userModel = Provider.of<UserModel>(context, listen: false);

    // "Your reviews" (e.g. the box on a completed order) comes from the
    // customer's own feed — the only one that carries their identity and their
    // still-pending reviews — narrowed to this product. Everywhere else shows
    // the public approved feed for the product.
    if (widget.showYourRatingOnly && !userModel.loggedIn) {
      setState(() => reviews = <Review>[]);
      return;
    }
    final request = widget.showYourRatingOnly
        ? services.api.getMyReviews(token: userModel.user?.cookie)
        : services.api.getReviews(widget.productId);
    if (request == null) {
      setState(() => reviews = <Review>[]);
      return;
    }

    request.then((onValue) {
      var reviewList = onValue.data;
      if (widget.showYourRatingOnly) {
        reviewList =
            reviewList?.where((r) => r.sku == widget.productId).toList();
      }
      if (mounted) {
        setState(() {
          reviews = reviewList;
        });
      }
    }).catchError((e) {
      // Show the empty state instead of an endless spinner on failure.
      if (mounted) {
        setState(() {
          reviews = <Review>[];
        });
      }
    });
  }

  /// The submit form lives in a modal bottom sheet rather than inline. Inline,
  /// the comment field sat deep inside a collapsible tab (ClipRect + Align)
  /// within the product page's scroll view and above a pinned Add-to-Bag bar,
  /// across nested Scaffolds — so when the keyboard opened the field scrolled
  /// out of view and the typed text only showed once the keyboard closed
  /// (86d3g53dk #10). A modal sheet renders in the root overlay, above all of
  /// that, sees the real keyboard inset, and stays above the keyboard so the
  /// text is visible as it is typed.
  void _openReviewComposer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Root navigator so the sheet is a full-screen overlay (above any nested
      // tab navigator) and reads the real keyboard inset.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewComposer(
        productId: widget.productId,
        onSubmitted: () {
          if (mounted) {
            getListReviews(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRatingAllowed =
        (Provider.of<UserModel>(context).loggedIn) && (widget.allowRating);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        reviews == null
            ? SizedBox(height: 80, child: kLoadingWidget(context))
            : (reviews!.isEmpty
                ? (widget.showYourRatingOnly
                    ? const SizedBox()
                    : SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(S.of(context).noReviews),
                        ),
                      ))
                : Column(
                    children: <Widget>[
                      for (var i = 0; i < reviews!.length; i++)
                        renderItem(context, reviews![i])
                    ],
                  )),
        if (isRatingAllowed)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openReviewComposer(context),
                icon: const Icon(Icons.rate_review_outlined, size: 20),
                label: Text(S.of(context).writeReview),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget renderItem(BuildContext context, Review review) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(2.0)),
      margin: const EdgeInsets.only(bottom: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Own not-yet-approved review (only surfaces in the "your reviews"
            // feed); tell the customer it isn't public yet.
            if (review.status == 'pending')
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top,
                        size: 12, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        S.of(context).reviewPendingApproval,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (kAdvanceConfig.enableRating)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(review.name!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  SmoothStarRating(
                      label: const Text(''),
                      allowHalfRating: true,
                      starCount: 5,
                      rating: review.rating,
                      size: 12.0,
                      color: theme.primaryColor,
                      borderColor: theme.primaryColor,
                      spacing: 0.0),
                ],
              ),
            const SizedBox(height: 10),
            Text(review.review!,
                style: const TextStyle(color: kGrey600, fontSize: 14)),
            const SizedBox(height: 4),
            if (review.images.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    review.images.length,
                    (i) => InkWell(
                      onTap: () {
                        showDialog<void>(
                            context: context,
                            builder: (BuildContext context) {
                              // Review photos are final URLs with no server
                              // resize variants — skip the -large rewrite.
                              return ImageGalery(
                                  images: review.images,
                                  index: i,
                                  resize: false);
                            });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ImageResize(
                          url: review.images[i],
                          fit: BoxFit.cover,
                          height: 80.0,
                          width: 80.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(timeago.format(review.createdAt),
                style: const TextStyle(color: kGrey400, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// The rating + comment form, shown inside a modal bottom sheet. Padding by
/// `viewInsets.bottom` keeps the field docked just above the keyboard, so the
/// text is visible in real time as the customer types (86d3g53dk #10).
class _ReviewComposer extends StatefulWidget {
  final String? productId;
  final VoidCallback onSubmitted;

  const _ReviewComposer({
    required this.productId,
    required this.onSubmitted,
  });

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  final services = Services();
  final comment = TextEditingController();
  double rating = 0.0;
  bool _isSending = false;
  String? _error;
  List<dynamic> _images = [];

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  void updateRating(double index) {
    setState(() {
      rating = index;
      _error = null;
    });
  }

  Future<void> _chooseImages() async {
    try {
      final selected = await ImagePicker.select(context, maxFiles: 5);
      if (selected.isEmpty) {
        return;
      }
      _images = selected;
    } catch (e) {
      printLog('review image picker error: $e');
      _images = [];
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Magento's messages arrive as `Exception: <server message>`; show the
  /// customer the message, not the wrapper.
  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _send() async {
    if (rating == 0.0) {
      setState(() => _error = S.of(context).ratingFirst);
      return;
    }
    if (comment.text.trim().isEmpty) {
      setState(() => _error = S.of(context).commentFirst);
      return;
    }
    final user = Provider.of<UserModel>(context, listen: false).user;
    if (user == null) {
      return;
    }

    // Capture what we need before the await so we never touch a context that
    // may have been torn down (the sheet is popped on success).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successMessage = kAdvanceConfig.enableApprovedReview
        ? S.of(context).reviewSent
        : S.of(context).reviewPendingApproval;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'review': comment.text.trim(),
        'reviewer': user.name,
        'reviewer_email': user.email,
        'rating': rating,
        'status': kAdvanceConfig.enableApprovedReview ? 'approved' : 'hold',
      };
      if (_images.isNotEmpty) {
        data['images'] = await ImageTools.compressImagesForUpload(_images);
      }
      await services.api.createReview(
        productId: widget.productId,
        data: data,
        token: user.cookie,
      );

      // Refresh the list behind the sheet, tell the customer, then close.
      widget.onSubmitted();
      Tools.showSnackBar(messenger, successMessage);
      navigator.pop();
    } catch (e) {
      // Keep the sheet open with everything the customer typed and surface the
      // server's own message inline (a snackbar would sit behind the keyboard).
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = _errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      S.of(context).productRating,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (kAdvanceConfig.enableRating)
                    SmoothStarRating(
                      label: const Text(''),
                      allowHalfRating: true,
                      onRatingChanged: updateRating,
                      starCount: 5,
                      rating: rating,
                      size: 28.0,
                      color: theme.primaryColor,
                      borderColor: theme.primaryColor,
                      spacing: 0.0,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(15, 5, 15, 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: TextField(
                  autofocus: true,
                  enabled: !_isSending,
                  controller: comment,
                  maxLines: 4,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium,
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },

                  /// The container already draws the box; the field's own
                  /// underline on top of it reads as a half-drawn box.
                  decoration: InputDecoration(
                    hintText: S.of(context).writeComment,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(
                          _images.length,
                          (index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5.0),
                                child: ImagePicker.getThumbnail(
                                  _images[index],
                                  width: 100,
                                  height: 100,
                                ),
                              )),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _isSending ? null : _chooseImages,
                  ),
                  Container(
                    height: 40.0,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(6.0)),
                    child: Center(
                      child: _isSending
                          ? const SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.0,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : GestureDetector(
                              onTap: _send,
                              child: Text(
                                S.of(context).send,
                                style: theme.textTheme.labelLarge!
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
