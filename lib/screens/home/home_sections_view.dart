import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart' show Skeleton;
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../frameworks/magento/services/magento_service.dart';
import '../../models/app_model.dart';
import '../../models/entities/back_drop_arguments.dart';
import '../../models/entities/home_section.dart';
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/common/webview.dart';
import '../../widgets/home/home_sections.dart';
import '../brands/all_brands_screen.dart';
import '../categories/categories_screen.dart' show HeaderAuthButtons;

/// Opens a curated category via the backdrop route — the route resolves a
/// main (top-level) category to the merchandised landing and everything else
/// to a product list.
void _openCategory(String? id, String? name) {
  if (id == null || id.isEmpty) return;
  FluxNavigate.pushNamed(
    RouteList.backdrop,
    arguments: BackDropArguments(cateId: id, cateName: name),
  );
}

Future<void> _openBrand(BuildContext context, HomeBrand brand) async {
  // Prefer a native brand product listing: resolve the brand's `option_id`
  // (via mstore/shopbrands, else a name match on mstore/brands) and open the
  // standard product screen, which filters by the `brand` attribute when the
  // id is a known brand option. Falls back to the storefront WebView when the
  // option id can't be resolved.
  final api = Services().api;
  String? optionId;
  if (api is MagentoService) {
    optionId = await api.resolveBrandOptionId(
      shopUrl: brand.shopUrl,
      name: brand.name,
    );
  }
  if (!context.mounted) return;
  if (optionId != null && optionId.isNotEmpty) {
    FluxNavigate.pushNamed(
      RouteList.backdrop,
      arguments: BackDropArguments(
        cateId: optionId,
        cateName: brand.name,
        brandImg: brand.logoUrl,
      ),
    );
    return;
  }
  final url = brand.shopUrl;
  if (url == null || url.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => WebView(url: url, title: brand.name)),
  );
}

/// "Shop All Brands" — the storefront's `/shopbrand` page, natively.
void _openAllBrands(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AllBrandsScreen()),
  );
}

Future<List<HomeSection>> _fetchSections(BuildContext context) {
  final api = Services().api;
  final lang = Provider.of<AppModel>(context, listen: false).langCode;
  return api is MagentoService
      ? api.fetchHomepageSections(lang: lang)
      : Future.value(const <HomeSection>[]);
}

/// Home content built from `mstore/homepage-sections`:
/// banner(s) -> shop-by-category -> featured brands.
class HomeSectionsView extends StatefulWidget {
  const HomeSectionsView({super.key});

  @override
  State<HomeSectionsView> createState() => _HomeSectionsViewState();
}

class _HomeSectionsViewState extends State<HomeSectionsView> {
  // Not `late final`: pull-to-refresh re-issues the request, so the future has
  // to be replaceable.
  Future<List<HomeSection>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSections(context);
  }

  /// Pull-to-refresh: re-fetch the homepage sections so banners, categories
  /// and featured brands changed in admin appear without restarting the app.
  Future<void> _reload() async {
    final future = _fetchSections(context);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: FutureBuilder<List<HomeSection>>(
        future: _future,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting;
          final sections = snapshot.data ?? const <HomeSection>[];
          final banners = sections.where((s) => s.isBanner).toList();
          final categories = sections.where((s) => s.isCategory).toList();
          final brands = sections.where((s) => s.isBrands).toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
            // The home sections rarely fill the viewport on a tall device (and
            // never do while the shimmer is up), so without this the pull is
            // not reported and the indicator never fires.
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Only the Login/Register buttons scroll away — the logo +
                // search header above (in CategoriesScreen) stays sticky.
                const HeaderAuthButtons(),
                if (loading)
                  const _HomeShimmer()
                else ...[
                  for (final b in banners)
                    HomeBannerHero(
                      section: b,
                      onTap: () => _openCategory(b.buttonCategoryId, b.title),
                    ),
                  ShopByCategorySection(
                    categories: categories,
                    onTap: (c) => _openCategory(c.buttonCategoryId, c.title),
                  ),
                  for (final br in brands)
                    FeaturedBrandsSection(
                      section: br,
                      onTap: (brand) => _openBrand(context, brand),
                      onShopAll: () => _openAllBrands(context),
                    ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer placeholder shown while the home sections load — mirrors the
/// hero + shop-by-category + brands layout.
class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  Widget _box(double height, {double radius = 14, EdgeInsets? margin}) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Skeleton(width: double.infinity, height: height),
      ),
    );
  }

  Widget _heading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: const [
          Skeleton(width: 120, height: 12),
          SizedBox(height: 12),
          Skeleton(width: 190, height: 26),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const hPad = EdgeInsets.symmetric(horizontal: 16);
    return Column(
      children: [
        _box(440, radius: 0),
        _heading(),
        _box(230, margin: hPad),
        const SizedBox(height: 16),
        _box(230, margin: hPad),
        _heading(),
        _box(140, margin: hPad),
        const SizedBox(height: 16),
        _box(140, margin: hPad),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Just the shared Featured Brands block, for appending to the main-category
/// landing page. Hides itself while loading / when there are no brands.
class LandingBrandsSection extends StatefulWidget {
  const LandingBrandsSection({super.key});

  @override
  State<LandingBrandsSection> createState() => _LandingBrandsSectionState();
}

class _LandingBrandsSectionState extends State<LandingBrandsSection> {
  late final Future<List<HomeSection>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSections(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeSection>>(
      future: _future,
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const [];
        final brands = sections.where((s) => s.isBrands).toList();
        if (brands.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final br in brands)
              FeaturedBrandsSection(
                section: br,
                onTap: (brand) => _openBrand(context, brand),
                onShopAll: () => _openAllBrands(context),
              ),
          ],
        );
      },
    );
  }
}
