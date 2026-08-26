import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../frameworks/magento/services/magento_service.dart';
import '../../generated/l10n.dart';
import '../../models/app_model.dart';
import '../../models/category/category_model.dart';
import '../../models/entities/back_drop_arguments.dart';
import '../../models/entities/category.dart';
import '../../models/entities/product.dart';
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/common/flux_image.dart';
import '../../widgets/common/shop_now_button.dart';
import '../../widgets/product/index.dart' show HeartButton;
import '../home/home_sections_view.dart';

/// Merchandised landing page shown when a user taps a MAIN (top-level)
/// category — Kidswear, Menswear, Womenswear, Newborn — from the home
/// screen (ClickUp 86d3g36q4).
///
/// Sections are backend-curated via `GET mstore/sections/{categoryId}`
/// (`MagentoService.fetchMainCategorySections`): each entry has a merchant
/// -defined `label` and a `sub_category` of one or more category ids. A
/// multi-id / "collection" entry renders as hero subcategory banners; a
/// single-id entry renders as a product carousel of that category's curated
/// products. Labels and counts vary per category, so the page renders
/// whatever the endpoint returns. When a category has no curated sections
/// yet, it falls back to a generic derivation (direct children as heroes +
/// newest + on-sale carousels).
///
/// Featured Brands is intentionally not rendered here yet — it will be fed by
/// the home-screen brands API (work in progress); the dormant
/// [_FeaturedBrands] widget below is ready to wire in once that lands.
class CategoryLandingScreen extends StatefulWidget {
  final String categoryId;
  final String? categoryName;

  const CategoryLandingScreen({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  @override
  State<CategoryLandingScreen> createState() => _CategoryLandingScreenState();
}

class _CategoryLandingScreenState extends State<CategoryLandingScreen> {
  late final String _lang;

  // Not `late final`: pull-to-refresh re-issues the request, so the future has
  // to be replaceable.
  Future<List<Map<String, dynamic>>>? _sectionsFuture;

  /// Section widgets are built once from the resolved sections; caching them
  /// keeps each section's product fetch from re-firing on every rebuild.
  List<Widget>? _children;

  @override
  void initState() {
    super.initState();
    _lang = Provider.of<AppModel>(context, listen: false).langCode;
    final api = Services().api;
    _sectionsFuture = api is MagentoService
        ? api.fetchMainCategorySections(widget.categoryId, lang: _lang)
        : Future.value(const <Map<String, dynamic>>[]);
  }

  /// Pull-to-refresh. Clears the cached [_children] as well as the sections
  /// future — otherwise the section widgets (and their per-section product
  /// fetches) would be reused and nothing would actually re-load.
  Future<void> _reload() async {
    final api = Services().api;
    final future = api is MagentoService
        ? api.fetchMainCategorySections(widget.categoryId, lang: _lang)
        : Future.value(const <Map<String, dynamic>>[]);
    setState(() {
      _children = null;
      _sectionsFuture = future;
    });
    await future;
  }

  Category? _categoryById(String id) =>
      Provider.of<CategoryModel>(context, listen: false).categoryList[id];

  /// Direct children of this main category — used as fallback heroes when the
  /// backend has no curated sections for it. Excludes the synthetic "Brands"
  /// node (id prefixed with '-') the category service injects.
  List<Category> get _childSubCategories {
    final model = Provider.of<CategoryModel>(context, listen: false);
    final children = model.getCategory(parentId: widget.categoryId) ?? [];
    return children
        .where((c) => !(c.id?.startsWith('-') ?? false))
        .toList();
  }

  void _openProducts({String? id, String? name}) {
    FluxNavigate.pushNamed(
      RouteList.backdrop,
      arguments: BackDropArguments(cateId: id, cateName: name),
    );
  }

  /// Split a section's `sub_category` ("id" or "id,id,...") into ids.
  List<String> _sectionIds(Map<String, dynamic> section) =>
      (section['sub_category'] ?? '')
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  /// Turn the backend section list into section widgets: multi-id /
  /// "collection" entries become hero banners, single-id entries become a
  /// labelled product carousel.
  List<Widget> _sectionWidgets(List<Map<String, dynamic>> sections) {
    final widgets = <Widget>[];
    for (final section in sections) {
      final ids = _sectionIds(section);
      if (ids.isEmpty) continue;
      final label = (section['label'] ?? '').toString();
      // A section with several comma-separated ids is a hero "shop
      // collection" banner row; a single id is a product carousel of that
      // category's curated products. Classify purely on id count — labels
      // like "New Arrival::Latest Collection" must NOT be treated as heroes
      // just because they contain the word "collection".
      final isCollection = ids.length > 1;
      if (isCollection) {
        final cats = ids
            .map((id) => _categoryById(id) ?? Category(id: id, subCategories: []))
            .toList();
        widgets.add(_HeroSubcategories(
          categories: cats,
          overline: label,
          onTap: (c) => _openProducts(id: c.id, name: c.name),
        ));
      } else {
        // A single-id section is a labelled carousel; on the website the same
        // block is a hero banner you click to open that category's full page.
        // Make the header tap through to it — e.g. "Sale::Limited Time Offer"
        // opens the Kids Sale (419) product grid, matching the web hero at
        // kidswear/discover/kidswear-sale.html (ClickUp 86d3g3mea).
        final id = ids.first;
        widgets.add(_ProductSection(
          title: label,
          onViewAll: () => _openProducts(
            id: id,
            name: _categoryById(id)?.name ?? label.split('::').first.trim(),
          ),
          future: Services().api.fetchProductsByCategory(
                categoryId: id,
                page: 1,
                lang: _lang,
              ),
        ));
      }
    }
    return widgets;
  }

  /// Generic derivation for categories the backend hasn't curated yet
  /// (e.g. Menswear/Womenswear return an empty sections list today).
  List<Widget> _fallbackWidgets() => [
        _HeroSubcategories(
          categories: _childSubCategories,
          onTap: (c) => _openProducts(id: c.id, name: c.name),
        ),
        _ProductSection(
          title: S.of(context).newArrival,
          future: Services().api.fetchProductsByCategory(
                categoryId: widget.categoryId,
                page: 1,
                orderBy: 'date',
                order: 'desc',
                lang: _lang,
              ),
        ),
        _ProductSection(
          title: S.of(context).onSale,
          future: Services().api.fetchProductsByCategory(
                categoryId: widget.categoryId,
                page: 1,
                onSale: true,
                lang: _lang,
              ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Content area matches the web landing (#e8e8e8). The header (app bar)
      // below and the app's bottom nav (footer) keep their own colours.
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 22, color: theme.colorScheme.secondary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          (widget.categoryName ?? '').toUpperCase(),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_bag_outlined,
                color: theme.colorScheme.secondary),
            onPressed: () => Navigator.of(context).pushNamed(RouteList.cart),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = snapshot.data ?? const [];
          final children = _children ??= sections.isNotEmpty
              ? _sectionWidgets(sections)
              : _fallbackWidgets();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
            // A landing page with only one or two sections does not fill the
            // viewport, so without this the pull is never reported.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ...children,
              // Featured Brands — shared with the home page, always last
              // (from mstore/homepage-sections).
              const LandingBrandsSection(),
            ],
            ),
          );
        },
      ),
    );
  }
}

/// Section heading matching the web's "small label + big title" style.
/// Backend labels encode an optional subtitle as `Title::Subtitle`
/// (e.g. "New Arrival::Latest Collection"): the subtitle renders small and
/// uppercase above the big title, like the website.
class _SectionHeader extends StatelessWidget {
  final String title;

  /// When set, the whole header is tappable and shows a forward chevron —
  /// opening the section's full category page like the web hero (86d3g3mea).
  final VoidCallback? onViewAll;
  const _SectionHeader(this.title, {this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = title.split('::');
    final mainTitle = parts.first.trim();
    final subtitle = parts.length > 1 ? parts[1].trim() : null;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Web `.lookbook-title`: padding 64px top / 44px bottom, and the subtitle
    // has a 12px margin-bottom before the title — scaled a little for mobile.
    final header = Padding(
      padding: const EdgeInsets.only(top: 44, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                subtitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8C7A5B),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  mainTitle,
                  textAlign: TextAlign.center,
                  // Web `.lookbook-title h2`: Playfair Display serif, weight
                  // 600, ~32px, letter-spacing 0.04em, colour #111.
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    height: 1.15,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              if (onViewAll != null) ...[
                const SizedBox(width: 4),
                Icon(
                  // Point the way the eye reads — left in RTL, right in LTR.
                  isRtl ? Icons.chevron_left : Icons.chevron_right,
                  size: 24,
                  color: const Color(0xFF8C7A5B),
                ),
              ],
            ],
          ),
          // Web `.lookbook-line`: 74x1px, 18px top margin, centered, a
          // horizontal gradient fading transparent -> #8C7A5B -> transparent.
          const SizedBox(height: 18),
          Container(
            width: 74,
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0x008C7A5B),
                  Color(0xFF8C7A5B),
                  Color(0x008C7A5B),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return onViewAll == null
        ? header
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewAll,
            child: header,
          );
  }
}

/// Full-bleed hero cards for a "shop collection" section — one tall image
/// card per subcategory, with an `— OVERLINE`, the subcategory name, and a
/// white Shop Now pill at the bottom-left (matching the website).
class _HeroSubcategories extends StatelessWidget {
  final List<Category> categories;
  final void Function(Category) onTap;

  /// Small uppercase label above the name (the section's `label`, e.g.
  /// "Shop Collection"). Null in the generic fallback.
  final String? overline;

  const _HeroSubcategories({
    required this.categories,
    required this.onTap,
    this.overline,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: GestureDetector(
              onTap: () => onTap(c),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FluxImage(
                        imageUrl: c.image ?? kDefaultImage,
                        fit: BoxFit.cover,
                        // Anchor the crop to the top so the model's head/face
                        // is kept when a portrait photo is cover-fit into the
                        // wider hero frame (centre-crop was cutting heads).
                        alignment: Alignment.topCenter,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.45, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (overline != null && overline!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '—  ${overline!.toUpperCase()}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Text(
                              c.name ?? '',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ShopNowButton(onTap: () => onTap(c)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A horizontally AUTO-scrolling row of product cards for a category-scoped
/// product query. Hides itself entirely when the query returns nothing.
class _ProductSection extends StatefulWidget {
  final String title;
  final Future<List<Product>?> future;

  /// Tapping the section header opens the full category page (the web hero's
  /// click target). Null leaves the header non-interactive.
  final VoidCallback? onViewAll;

  const _ProductSection({
    required this.title,
    required this.future,
    this.onViewAll,
  });

  @override
  State<_ProductSection> createState() => _ProductSectionState();
}

class _ProductSectionState extends State<_ProductSection> {
  static const double _sidePad = 16;
  static const double _gap = 12;

  /// Computed each build from the screen width so two cards fit with EQUAL
  /// [_sidePad] margins on both sides (no card touching the screen edge).
  double _cardWidth = 168;

  final ScrollController _controller = ScrollController();
  Timer? _timer;
  int _count = 0;

  /// Advance one card every few seconds, looping back to the start at the end.
  void _ensureAutoScroll() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients || _count <= 1) return;
      final max = _controller.position.maxScrollExtent;
      var next = _controller.offset + _cardWidth + _gap;
      if (next > max + 1) next = 0;
      _controller.animateTo(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>?>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(widget.title, onViewAll: widget.onViewAll),
              const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();
        _count = products.length;
        // Two cards + one gap fit exactly inside the equal side margins.
        _cardWidth =
            (MediaQuery.of(context).size.width - _sidePad * 2 - _gap) / 2;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _ensureAutoScroll());
        final cardHeight = _cardWidth * kAdvanceConfig.ratioProductImage + 148;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(widget.title, onViewAll: widget.onViewAll),
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: _sidePad),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, index) => _LandingProductCard(
                  product: products[index],
                  width: _cardWidth,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Product card matching the web landing: rounded white card on the grey
/// content background, centered brand + name, and a red price. Reuses the
/// app's brand + wishlist widgets and opens the product detail on tap.
class _LandingProductCard extends StatelessWidget {
  final Product product;
  final double width;

  const _LandingProductCard({required this.product, required this.width});

  String _formattedPrice() {
    final raw = double.tryParse(product.price ?? '') ?? 0;
    final value =
        raw % 1 == 0 ? raw.toInt().toString() : raw.toStringAsFixed(2);
    return 'EGP $value';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageHeight = width * kAdvanceConfig.ratioProductImage;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .pushNamed(RouteList.productDetail, arguments: product),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Inset image with a 1px #e8e8e8 border and rounded corners.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Stack(
                children: [
                  Container(
                    width: width - 20,
                    height: imageHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE8E8E8),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FluxImage(
                        imageUrl: product.imageFeature ?? kDefaultImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: HeartButton(product: product, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Seller / brand — intentionally smaller than the product title.
            if ((product.vendor ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  product.vendor!.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.secondary.withOpacity(0.5),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                product.name ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formattedPrice(),
              style: const TextStyle(
                color: Color(0xFFCF2027),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Horizontal list of brand cards. Dormant for now — will be wired to the
/// home-screen brands API when it's ready (see class docstring).
// ignore: unused_element
class _FeaturedBrands extends StatelessWidget {
  final List<Category> brands;
  final void Function(Category) onTap;

  const _FeaturedBrands({required this.brands, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(S.of(context).featuredBrands),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final b = brands[index];
              return GestureDetector(
                onTap: () => onTap(b),
                child: Container(
                  width: 150,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.15)),
                  ),
                  child: Text(
                    b.name ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
