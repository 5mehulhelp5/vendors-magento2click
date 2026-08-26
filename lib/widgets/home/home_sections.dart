import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/constants.dart';
import '../../generated/l10n.dart';
import '../../models/entities/home_section.dart';
import '../common/flux_image.dart';
import '../common/shop_now_button.dart';

/// Shared section heading for the home / Featured-Brands blocks: a small grey
/// uppercase kicker, a Playfair-serif title, a short accent underline, and an
/// optional description paragraph.
class HomeSectionHeading extends StatelessWidget {
  final String? subtitle;
  final String? title;
  final String? content;
  final Color accentColor;

  const HomeSectionHeading({
    super.key,
    this.subtitle,
    this.title,
    this.content,
    this.accentColor = const Color(0xFF3D5AFE),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((subtitle ?? '').isNotEmpty) ...[
            Text(
              subtitle!.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A8A),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if ((title ?? '').isNotEmpty)
            Text(
              title!,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                height: 1.15,
                color: const Color(0xFF111111),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if ((content ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              content!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-bleed hero banner (`type: banner`): kicker + serif title + description
/// + frosted CTA over a dark-gradient image.
class HomeBannerHero extends StatelessWidget {
  final HomeSection section;
  final VoidCallback onTap;

  const HomeBannerHero({super.key, required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FluxImage(
              imageUrl: section.imageUrl ?? kDefaultImage,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Color(0x33000000),
                    Color(0x22000000),
                    Color(0x99000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if ((section.subtitle ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        section.subtitle!.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    section.title ?? '',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  if ((section.content ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      section.content!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ShopNowButton(
                    label: section.buttonLabel,
                    showArrow: false,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Shop by Category" block: a heading + stacked full-width image cards
/// (`type: category`).
class ShopByCategorySection extends StatelessWidget {
  final List<HomeSection> categories;
  final void Function(HomeSection) onTap;

  const ShopByCategorySection({
    super.key,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        HomeSectionHeading(title: S.of(context).shopByCategory),
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _CategoryCard(section: c, onTap: () => onTap(c)),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final HomeSection section;
  final VoidCallback onTap;

  const _CategoryCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.15,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FluxImage(
                imageUrl: section.imageUrl ?? kDefaultImage,
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1.0],
                    colors: [Color(0x11000000), Color(0xA6000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      section.title ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((section.content ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        section.content!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ShopNowButton(
                      label: section.buttonLabel,
                      showArrow: false,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Featured Brands" block (`type: brands`) — shared by the home and
/// main-category screens, rendered last. White rounded logo cards.
class FeaturedBrandsSection extends StatelessWidget {
  final HomeSection section;
  final void Function(HomeBrand) onTap;

  /// Opens the full brands listing ("Shop All Brands"). The CTA is hidden when
  /// this is null.
  final VoidCallback? onShopAll;

  const FeaturedBrandsSection({
    super.key,
    required this.section,
    required this.onTap,
    this.onShopAll,
  });

  @override
  Widget build(BuildContext context) {
    if (section.brands.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        HomeSectionHeading(
          subtitle: section.subtitle,
          title: section.title,
          content: section.content,
        ),
        for (final b in section.brands)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BrandCard(
              name: b.name,
              logoUrl: b.logoUrl,
              onTap: () => onTap(b),
            ),
          ),
        if (onShopAll != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ShopAllBrandsButton(onTap: onShopAll!),
          ),
      ],
    );
  }
}

/// The website's `.brands-cta` pill, closing the Featured Brands block: a
/// near-black (#111827) full-radius button with centred white uppercase
/// 12px/700 text and wide (2.4px) letter-spacing.
class ShopAllBrandsButton extends StatelessWidget {
  final VoidCallback onTap;

  const ShopAllBrandsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 34),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          // Arabic has no case, so toUpperCase() only affects the English copy
          // — matching the site's `text-transform: uppercase`.
          S.of(context).shopAllBrands.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
      ),
    );
  }
}

/// White rounded logo card — shared by the Featured Brands block and the All
/// Brands screen. Takes primitives so it works for both the homepage `brands`
/// section (HomeBrand) and the `mstore/shopbrands` tiles (ShopBrand).
class BrandCard extends StatelessWidget {
  final String? name;
  final String? logoUrl;
  final VoidCallback onTap;

  const BrandCard({
    super.key,
    required this.name,
    required this.logoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Logo sits in a fixed 170px-wide box, letterboxed to a consistent
            // height so different aspect ratios share the same baseline.
            SizedBox(
              height: 64,
              width: 170,
              child: (logoUrl ?? '').isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 30,
                        color: Color(0xFFBDBDBD),
                      ),
                    )
                  : FluxImage(imageUrl: logoUrl!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              (name ?? '').toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
