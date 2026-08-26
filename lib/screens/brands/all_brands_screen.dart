import 'package:flutter/material.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../frameworks/magento/services/magento_service.dart';
import '../../generated/l10n.dart';
import '../../models/entities/back_drop_arguments.dart';
import '../../models/entities/category.dart' show ShopBrand;
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/common/webview.dart';
import '../../widgets/home/home_sections.dart' show BrandCard;

/// Native "All Brands" listing — the app's equivalent of the storefront's
/// `/shopbrand` page, opened from the Featured Brands block's "Shop All Brands"
/// CTA.
///
/// Tiles come from `GET mstore/shopbrands` (the same set the website lists).
/// Mirrors the website page's layout and functionality: a "Search a brand"
/// box and an A–Z alphabetical index (`0-9 A…Z All`) that narrow the grid.
/// Tapping a tile opens that brand's native product listing, filtered by the
/// brand attribute's `option_id` — mirroring the home block's brand cards — and
/// falls back to the storefront page when the id is missing.
class AllBrandsScreen extends StatefulWidget {
  const AllBrandsScreen({super.key});

  @override
  State<AllBrandsScreen> createState() => _AllBrandsScreenState();
}

class _AllBrandsScreenState extends State<AllBrandsScreen> {
  late final Future<List<ShopBrand>> _future;
  final TextEditingController _searchController = TextEditingController();

  /// Free-text query from the search box (lower-cased), or empty for none.
  String _query = '';

  /// Selected letter from the A–Z index, or null for "All". The sentinel
  /// [_digitsKey] selects brands whose name starts with a digit.
  String? _letter;

  static const String _digitsKey = '0-9';

  @override
  void initState() {
    super.initState();
    final api = Services().api;
    _future = api is MagentoService
        ? api.fetchShopBrands()
        : Future.value(const <ShopBrand>[]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBrand(ShopBrand brand) {
    final optionId = brand.optionId;
    if (optionId != null && optionId.isNotEmpty) {
      FluxNavigate.pushNamed(
        RouteList.backdrop,
        arguments: BackDropArguments(
          cateId: optionId,
          cateName: brand.name,
          brandImg: brand.image,
        ),
      );
      return;
    }
    // No brand option id (not every environment exposes one) — fall back to the
    // storefront brand page.
    final url = brand.url;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebView(url: url, title: brand.name)),
    );
  }

  /// The visible subset after applying the search box and the A–Z index.
  List<ShopBrand> _visible(List<ShopBrand> all) {
    return all.where((b) {
      final name = (b.name ?? '').trim();
      if (_query.isNotEmpty && !name.toLowerCase().contains(_query)) {
        return false;
      }
      if (_letter != null) {
        if (name.isEmpty) return false;
        final first = name[0].toUpperCase();
        if (_letter == _digitsKey) {
          if (!RegExp(r'[0-9]').hasMatch(first)) return false;
        } else if (first != _letter) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF111111),
        title: Text(
          S.of(context).allBrands,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
      ),
      body: FutureBuilder<List<ShopBrand>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: kLoadingWidget(context));
          }
          final brands = snapshot.data ?? const <ShopBrand>[];
          if (brands.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  S.of(context).dataEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final visible = _visible(brands);
          return Column(
            children: [
              _searchBox(context),
              _alphabetIndex(context, brands),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            S.of(context).dataEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final brand = visible[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: BrandCard(
                              name: brand.name,
                              logoUrl: brand.image,
                              onTap: () => _openBrand(brand),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The website's "Search a brand" field — a white, full-radius input.
  Widget _searchBox(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          hintText: S.of(context).searchABrand,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9A9A9A)),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9A9A9A)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// The website's alphabetical index: `0-9 A…Z All`. Only letters present in
  /// the data are tappable; the rest are shown dimmed, matching the site. The
  /// currently-selected key is highlighted; "All" clears the filter.
  Widget _alphabetIndex(BuildContext context, List<ShopBrand> all) {
    final available = <String>{};
    for (final b in all) {
      final name = (b.name ?? '').trim();
      if (name.isEmpty) continue;
      final first = name[0].toUpperCase();
      available.add(RegExp(r'[0-9]').hasMatch(first) ? _digitsKey : first);
    }

    final keys = <String>[
      _digitsKey,
      for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
        String.fromCharCode(c),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final k in keys)
              _indexChip(
                label: k,
                selected: _letter == k,
                enabled: available.contains(k),
                onTap: () => setState(() => _letter = _letter == k ? null : k),
              ),
            _indexChip(
              label: S.of(context).all,
              selected: _letter == null,
              enabled: true,
              onTap: () => setState(() => _letter = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indexChip({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final Color fg = selected
        ? Colors.white
        : enabled
            ? const Color(0xFF111111)
            : const Color(0xFFBDBDBD);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
