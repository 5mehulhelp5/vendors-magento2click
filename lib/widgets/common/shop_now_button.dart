import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

/// Reusable frosted-glass "Shop Now" call-to-action pill.
///
/// Matches the website's `.locafy-kids-split-cta`: a translucent white fill
/// (`rgba(255,255,255,.12)`) with a subtle white border, an 8px backdrop blur,
/// a full-pill radius, and a trailing circled arrow whose circle is a filled
/// `rgba(255,255,255,.18)` (`.locafy-kids-split-cta span`). The glassy fill
/// picks up whatever sits behind it, so it reads dark over dark photos and
/// light over light ones.
///
/// Used on the category-landing hero banners (86d3g36q4) and intended for
/// reuse on the home-screen banners.
class ShopNowButton extends StatelessWidget {
  final VoidCallback? onTap;

  /// Defaults to the localized "Shop Now".
  final String? label;

  /// Trailing circled arrow. On for the category-landing heroes; off for the
  /// home banner / shop-by-category CTAs which are text-only pills.
  final bool showArrow;

  const ShopNowButton({
    super.key,
    this.onTap,
    this.label,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? S.of(context).shopNow;

    final content = Container(
      padding: EdgeInsets.fromLTRB(18, 10, showArrow ? 11 : 18, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );

    // backdrop-filter: blur(8px) — frost the imagery behind the pill.
    final button = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: content,
      ),
    );

    if (onTap == null) return button;
    return GestureDetector(onTap: onTap, child: button);
  }
}
