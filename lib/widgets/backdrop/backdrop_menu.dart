import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:inspireui/widgets/expandable/expansion_widget.dart';
import 'package:jumping_dot/jumping_dot.dart';

import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/entities/filter_sorty_by.dart';
import '../../models/index.dart'
    show
        AppModel,
        BlogModel,
        CategoryFilterModel,
        CategoryModel,
        FilterAttributeModel,
        ProductModel;
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../services/index.dart';
import 'filters/category_menu.dart';
import 'filters/container_filter.dart';
import 'filters/filter_option_item.dart';
import 'filters/listing_menu.dart';
import 'filters/tag_menu.dart';

class BackdropMenu extends StatefulWidget {
  final Function({
    dynamic minPrice,
    dynamic maxPrice,
    String? categoryId,
    String? categoryName,
    String? tagId,
    dynamic listingLocationId,
    FilterSortBy? sortBy,
  })? onFilter;
  final String? categoryId;
  final String? tagId;
  final String? listingLocationId;
  final bool showCategory;
  final bool showPrice;
  final bool isUseBlog;
  final bool isBlog;
  final ScrollController? controller;
  final double? minPrice;
  final double? maxPrice;
  final FilterSortBy? sortBy;
  final bool showSort;
  final bool showLayout;

  const BackdropMenu({
    Key? key,
    this.onFilter,
    this.categoryId,
    this.tagId,
    this.showCategory = true,
    this.showPrice = true,
    this.isBlog = false,
    this.isUseBlog = false,
    this.listingLocationId,
    this.controller,
    this.minPrice,
    this.maxPrice,
    this.sortBy,
    this.showSort = true,
    this.showLayout = true,
  }) : super(key: key);

  @override
  State<BackdropMenu> createState() => _BackdropMenuState();
}

class _BackdropMenuState extends State<BackdropMenu> {
  double minPrice = 0.0;
  double maxPrice = 0.0;
  // The RangeSlider's outer bound. Defaults to kMaxPriceFilter so an
  // already-applied filter can still be widened upward (the currently
  // loaded product list only reflects the filtered subset in that case, so
  // it can't tell us the true catalog max). When no filter is applied yet,
  // this is tightened to the current list's real max in initState so the
  // slider fills the track instead of only occupying a sliver of it.
  double _sliderMaxBound = kMaxPriceFilter;
  String? currentSlug;
  String? _categoryId = '-1';
  FilterSortBy? _currentSortBy;

  String? get currency => Provider.of<AppModel>(context).currency;

  Map<String, dynamic> get currencyRate =>
      Provider.of<AppModel>(context, listen: false).currencyRate;

  FilterAttributeModel get filterAttr =>
      Provider.of<FilterAttributeModel>(context, listen: false);

  ProductModel get productModel =>
      Provider.of<ProductModel>(context, listen: false);

  String? get categoryId =>
      _categoryId ??
      Provider.of<ProductModel>(context, listen: false).categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    _currentSortBy = widget.sortBy;

    if (widget.minPrice != null || widget.maxPrice != null) {
      minPrice = widget.minPrice ?? 0;
      maxPrice = widget.maxPrice ?? 0;
    } else {
      // No price filter has been applied yet — default the slider to the
      // actual price range of the currently loaded products instead of
      // 0.00-0.00, which reads as broken/empty.
      final prices = productModel.productsList
              ?.map((p) => double.tryParse(p.price ?? ''))
              .whereType<double>()
              .where((p) => p > 0)
              .toList() ??
          [];
      if (prices.isNotEmpty) {
        minPrice = prices.reduce((a, b) => a < b ? a : b).clamp(0, kMaxPriceFilter);
        maxPrice = prices.reduce((a, b) => a > b ? a : b).clamp(0, kMaxPriceFilter);
        // Safe here because nothing is filtered yet, so the loaded list is
        // the full unfiltered catalog for this category/search — its max is
        // a true ceiling, not just the top of an already-narrowed range.
        if (maxPrice > 0) {
          _sliderMaxBound = maxPrice;
        }
      }
    }

    // Load the web-parity attribute filters (Brand/Colour/Size/Gender/…) for
    // the category this sheet was opened on. load() refreshes counts for the
    // current category and resets a stale selection if the category changed.
    //
    // The parity flag has to be recomputed here, not left to default: this
    // load runs *after* the one in ProductsScreen.initState, so omitting it
    // silently replaced the trimmed L2/L3 list with the full aggregation set
    // the moment the sheet was opened (86d3g3mea item 3).
    final lang = Provider.of<AppModel>(context, listen: false).langCode;
    final categories =
        Provider.of<CategoryModel>(context, listen: false).categoryList;
    Provider.of<CategoryFilterModel>(context, listen: false).load(
      widget.categoryId,
      lang,
      webParityOnly:
          CategoryFilterModel.webParityFor(categories, widget.categoryId),
    );
  }

  void _onFilter({
    String? categoryId,
    String? categoryName,
    String? tagId,
    listingLocationId,
  }) =>
      widget.onFilter!(
        minPrice: minPrice,
        maxPrice: maxPrice,
        sortBy: _currentSortBy,
        categoryId: categoryId,
        categoryName: categoryName ?? '',
        tagId: tagId,
        listingLocationId: listingLocationId ??
            Provider.of<ProductModel>(context, listen: false).listingLocationId,
      );

  List<Widget> renderLayout() {
    return [
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(left: 15),
        child: Text(
          S.of(context).layout,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      const SizedBox(height: 5.0),

      /// render layout
      Selector<AppModel, String>(
        selector: (context, AppModel _) => _.productListLayout,
        builder: (context, String selectLayout, _) {
          return Wrap(
            children: <Widget>[
              const SizedBox(width: 8),
              for (var item
                  in widget.isBlog ? kBlogListLayout : kProductListLayout)
                Tooltip(
                  message: item['layout']!,
                  child: GestureDetector(
                    onTap: () => Provider.of<AppModel>(context, listen: false)
                        .updateProductListLayout(item['layout']),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: ContainerFilter(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(
                          bottom: 15,
                          left: 8,
                          right: 8,
                          top: 15,
                        ),
                        isSelected: selectLayout == item['layout'],
                        child: Image.asset(
                          item['image']!,
                          color: selectLayout == item['layout']
                              ? (widget.isBlog
                                  ? Colors.white
                                  : Theme.of(context).primaryColor)
                              : Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                )
            ],
          );
        },
      ),
    ];
  }

  Widget renderPriceSlider() {
    var primaryColor = kAdvanceConfig.enableProductBackdrop
        ? Colors.white
        : Theme.of(context).primaryColor;

    return ExpansionWidget(
      showDivider: true,
      padding: const EdgeInsets.only(
        left: 15,
        right: 15,
        top: 15,
        bottom: 10,
      ),
      title: Text(
        // "Price" / "السعر" — matches the website's filter heading. Not
        // `byPrice`, which is also the sort-by chip label ("By Price").
        S.of(context).filterPrice,
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (minPrice != 0 || maxPrice != 0) ...[
              Text(
                PriceTools.getCurrencyFormatted(minPrice, currencyRate,
                    currency: currency)!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                ' - ',
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            Text(
              PriceTools.getCurrencyFormatted(maxPrice, currencyRate,
                  currency: currency)!,
              style: Theme.of(context).textTheme.titleLarge,
            )
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: primaryColor,
            inactiveTrackColor:
                Theme.of(context).primaryColorLight.withOpacity(0.5),
            activeTickMarkColor: Theme.of(context).primaryColorLight,
            inactiveTickMarkColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            overlayColor: primaryColor.withOpacity(0.2),
            thumbColor: primaryColor,
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: RangeSlider(
            min: 0.0,
            max: _sliderMaxBound,
            divisions: kFilterDivision,
            values: RangeValues(minPrice, maxPrice),
            onChanged: (RangeValues value) {
              EasyDebounce.cancel('slider');
              setState(() {
                minPrice = value.start;
                maxPrice = value.end;
              });
              EasyDebounce.debounce(
                'slider',
                const Duration(milliseconds: 1500),
                () {
                  productModel.setPrices(min: value.start, max: value.end);
                  _onFilter();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Web-parity layered-navigation filters (Brand, Colour, Size, Gender,
  /// Material, Pattern, Sleeve length, Style, Product Type, …). Options and
  /// counts come from GraphQL aggregations (via [CategoryFilterModel]); each
  /// attribute is a collapsible section of multi-select checkboxes. Toggling
  /// an option re-runs the product query with the new selection applied as a
  /// REST filter group.
  Widget renderCategoryAttributeFilters() {
    return Consumer<CategoryFilterModel>(
      builder: (context, model, child) {
        if (model.isLoading && model.attributes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (model.attributes.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final attr in model.attributes)
              ExpansionWidget(
                key: PageStorageKey('catfilter_${attr.label}'),
                showDivider: true,
                initiallyExpanded: false,
                padding: const EdgeInsets.only(
                  left: 15,
                  right: 15,
                  top: 15,
                  bottom: 10,
                ),
                title: Text(
                  attr.label,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                children: [
                  for (final opt in attr.options)
                    CheckboxListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Theme.of(context).primaryColor,
                      value: model.isSelected(opt.code, opt.value),
                      title: Text(
                        opt.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      secondary: Text(
                        '${opt.count}',
                        style:
                            Theme.of(context).textTheme.bodySmall!.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.5),
                                ),
                      ),
                      onChanged: (_) {
                        model.toggle(opt.code, opt.value);
                        _onFilter();
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget renderAttributes() {
    return Consumer<FilterAttributeModel>(
      builder: (context, value, child) {
        if (value.lstProductAttribute?.isNotEmpty ?? false) {
          var list = List<Widget>.generate(
            value.lstProductAttribute!.length,
            (index) {
              final item = value.lstProductAttribute![index];
              return FilterOptionItem(
                enabled: !value.isLoading,
                onTap: () {
                  currentSlug = item.slug;
                  value.getAttr(id: item.id);
                },
                title: item.name!.toUpperCase(),
                isValid: value.indexSelectedAttr != -1,
                selected: value.indexSelectedAttr == index,
              );
            },
          );
          return ExpansionWidget(
            showDivider: true,
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              top: 15,
              bottom: 10,
            ),
            title: Text(
              S.of(context).attributes,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    height: list.length > 4 ? 100 : 50,
                    margin: const EdgeInsets.only(left: 10.0),
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: GridView.count(
                      scrollDirection: Axis.horizontal,
                      childAspectRatio: 0.4,
                      shrinkWrap: true,
                      crossAxisCount: list.length > 4 ? 2 : 1,
                      children: list,
                    ),
                  ),
                  value.isFirstLoad
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.only(
                              top: 10.0,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.0,
                            ),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: value.indexSelectedAttr == -1 ||
                                  value.lstCurrentAttr.isEmpty
                              ? const SizedBox()
                              : Wrap(
                                  children: [
                                    ...List.generate(
                                      value.lstCurrentAttr.length,
                                      (index) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 5),
                                          child: FilterChip(
                                            selectedColor:
                                                Theme.of(context).primaryColor,
                                            backgroundColor: Theme.of(context)
                                                .primaryColorLight
                                                .withOpacity(0.3),
                                            label: Text(value
                                                .lstCurrentAttr[index].name!),
                                            selected: value
                                                .lstCurrentSelectedTerms[index],
                                            onSelected: (val) {
                                              value.updateAttributeSelectedItem(
                                                  index, val);
                                              _onFilter();
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    if (value.isLoadingMore)
                                      SizedBox(
                                        width: 70,
                                        height: 50,
                                        child: Center(
                                          child: JumpingDots(
                                            innerPadding: 2,
                                            radius: 6,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    if (!value.isLoadingMore && !value.isEnd)
                                      FilterChip(
                                        selectedColor:
                                            Theme.of(context).primaryColor,
                                        backgroundColor: Theme.of(context)
                                            .primaryColorLight
                                            .withOpacity(0.3),
                                        label: Text(S.of(context).more),
                                        selected: false,
                                        onSelected: (val) {
                                          value.getAttr(
                                              id: value
                                                  .lstProductAttribute![
                                                      value.indexSelectedAttr]
                                                  .id);
                                        },
                                      )
                                  ],
                                ),
                        ),
                ],
              )
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget renderFilterSortBy() {
    if (!widget.showSort) return const SizedBox();

    return Services().widget.renderFilterSortBy(
      context,
      filterSortBy: _currentSortBy,
      showDivider: widget.showLayout,
      isBlog: widget.isBlog,
      onFilterChanged: (filterSortBy) {
        setState(() {
          _currentSortBy = filterSortBy;
        });
        _onFilter();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (Layout.isDisplayDesktop(context))
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (Layout.isDisplayDesktop(context)) {
                        eventBus.fire(const EventOpenCustomDrawer());
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Icon(Icons.arrow_back_ios,
                        size: 22, color: Colors.white70),
                  ),
                ],
              ),
            ),

          //  if (widget.showLayout) ...renderLayout(),

          if ((!ServerConfig().isListingType)) renderFilterSortBy(),

          if (ServerConfig().isListingType)
            BackDropListingMenu(onFilter: _onFilter),

          // Order below mirrors the website's layered navigation:
          // Category → attributes → Price. Verified against
          // locafy.market/eg-en/kidswear/boys.html (Category, Brand, Colour,
          // Price) and .../boys/shoes.html (attributes then Price — a leaf
          // category has no Category block). Price used to sit directly under
          // Sort by, and Category at the very bottom. See ClickUp 86d3g3mea.
          if (widget.showCategory)
            CategoryMenu(
              onFilter: (category) => _onFilter(
                categoryId: category.id,
                categoryName: category.name,
              ),
            ),

          // Web-parity attribute filters (Brand, Colour, Size, Gender, …),
          // driven by GraphQL aggregations. Replaces the old no-op
          // renderAttributes() (which had no Magento backend). See
          // docs/qa-followups.md item 3.
          if (!ServerConfig().isListingType &&
              ServerConfig().type != ConfigType.shopify)
            renderCategoryAttributeFilters(),

          if (!ServerConfig().isListingType &&
              ServerConfig().type != ConfigType.shopify &&
              widget.showPrice) ...[
            renderPriceSlider(),
          ],

          /// filter by tags
          widget.isUseBlog
              ? const SizedBox()
              : BackDropTagMenu(
                  onChanged: (tagId) => _onFilter(tagId: tagId),
                ),

          /// render Apply button
          if (!ServerConfig().isListingType &&
              kAdvanceConfig.enableProductBackdrop)
            Padding(
              padding: const EdgeInsets.only(
                left: 15,
                right: 15,
                top: 5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ButtonTheme(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0.0,
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                        ),
                        onPressed: () {
                          _onFilter(
                            categoryId: categoryId,
                            tagId: Provider.of<ProductModel>(context,
                                    listen: false)
                                .tagId
                                .toString(),
                          );
                        },
                        child: Text(
                          S.of(context).apply,
                          style:
                              Theme.of(context).textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),

          const SizedBox(height: 70),
        ],
      ),
    );
  }
}
