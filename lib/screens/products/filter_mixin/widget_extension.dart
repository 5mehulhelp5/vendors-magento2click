part of 'products_filter_mixin.dart';

extension ProductsFilterMixinWidgetExtension on ProductsFilterMixin {
  Widget renderFilters(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _renderFilterTitle(context),
            const SizedBox(width: 5),
            const SizedBox(
              height: 44,
              child: VerticalDivider(
                width: 15,
                indent: 8,
                endIndent: 8,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 5),
            renderFilterButton(context),
            const SizedBox(width: 5),
          ],
        )
    );
  }

  /// The active layered-navigation filter chips (sort / attribute / tag /
  /// price / selected options), shown as a sticky bar under the search box.
  /// Collapses to nothing when no filter is applied so the PLP doesn't show an
  /// empty toolbar row. Chips stay LTR (brand names, prices) even in Arabic.
  /// Whether any filter is currently applied — the exact condition
  /// [renderActiveFilters] uses to decide whether to draw the chip bar.
  ///
  /// Exposed because the list layout hands its chip bar to `ProductList` as a
  /// *pinned* `SliverAppBar`, which reserves its 44px whether or not the child
  /// draws anything. Callers must skip the slot entirely when this is false,
  /// otherwise an empty bar sits under the search box.
  bool hasActiveFilters(CategoryFilterModel filterModel) {
    final hasSync = filterSortBy.displaySpecial != null ||
        filterSortBy.displayOrderBy != null ||
        getAttributeTerm(showName: true).isNotEmpty ||
        tagName.isNotEmpty ||
        (minPrice != null && maxPrice != null && maxPrice != 0);
    return hasSync || filterModel.hasSelection;
  }

  Widget renderActiveFilters(BuildContext context) {
    return Consumer<CategoryFilterModel>(
      builder: (context, filterModel, _) {
        if (!hasActiveFilters(filterModel)) {
          return const SizedBox.shrink();
        }
        return Container(
          alignment: Alignment.center,
          height: 44,
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 1),
                blurRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _renderFilterTitle(context),
          ),
        );
      },
    );
  }

  /// The "Filter" trigger that opens the filter bottom sheet. Extracted so the
  /// PLP can place it beside the search box while the active-filter chips stay
  /// in their own row ([renderActiveFilters]).
  Widget renderFilterButton(BuildContext context) {
    return CupertinoButton(
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.of(context).filter,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_down, size: 13,color: Theme.of(context).primaryColor,),
                ],
              ),
              onPressed: () => showModalBottomSheet(
                context: App.fluxStoreNavigatorKey.currentContext!,
                isScrollControlled: true,
                isDismissible: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Stack(
                  children: [
                    GestureDetector(
                      onTap: Navigator.of(context).pop,
                      child: Container(color: Colors.transparent),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.7,
                      minChildSize: 0.2,
                      maxChildSize: 0.9,
                      builder: (BuildContext context,
                          ScrollController scrollController) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15.0),
                                  topRight: Radius.circular(15.0),
                                ),
                                color: Theme.of(context).colorScheme.background,
                              ),
                              child: Stack(
                                children: [
                                  const DragHandler(),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: BackdropMenu(
                                      onFilter: onFilter,
                                      categoryId: categoryId,
                                      sortBy: filterSortBy,
                                      tagId: tagId,
                                      listingLocationId: listingLocationId,
                                      controller: scrollController,
                                      minPrice: minPrice,
                                      maxPrice: maxPrice,

                                      /// hide layout filter from Search screen
                                      showLayout: shouldShowLayout,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
  }

  Widget _renderFilterTitle(BuildContext context) {
    var attributeTerms = getAttributeTerm(showName: true);
    var attributeList =
        attributeTerms.isNotEmpty ? attributeTerms.split(',') : [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _renderFilterSortByTag(context),
          const SizedBox(width: 5),
          if (attributeList.isNotEmpty)
            for (int i = 0; i < attributeList.length; i++)
              FilterLabel(
                label: attributeList[i].toString(),
                onTap: () {
                  resetFilter();
                  onFilter();
                },
              ),
          if (tagName.isNotEmpty)
            FilterLabel(
              label: tagName.capitalize(),
              onTap: () {
                resetTag();
                onFilter(tagId: '');
              },
            ),
          if (minPrice != null && maxPrice != null && maxPrice != 0)
            FilterLabel(
              onTap: () {
                resetPrice();
                onFilter(minPrice: 0.0, maxPrice: 0.0);
              },
              label:
                  '${minPrice?.toStringAsFixed(0) ?? ''} - ${maxPrice?.toStringAsFixed(0) ?? ''}',
            ),

          /// Active layered-navigation attribute filters (Brand/Colour/Size/…),
          /// each removable — tapping clears just that option and re-runs the
          /// query. Rebuilds instantly on toggle via its own Consumer.
          Consumer<CategoryFilterModel>(
            builder: (context, filterModel, _) {
              if (!filterModel.hasSelection) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final opt in filterModel.selectedOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: FilterLabel(
                        label: opt.label,
                        onTap: () {
                          filterModel.toggle(opt.code, opt.value);
                          onFilter();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _renderFilterSortByTag(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (filterSortBy.displaySpecial != null)
          FilterLabel(
            label: filterSortBy.displaySpecial!,
            onTap: () {
              filterSortBy = filterSortBy.applyOnSale(null).applyFeatured(null);
              onFilter();
            },
            leading: filterSortBy.onSale ?? false
                ? Icon(
                    CupertinoIcons.tag_solid,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  )
                : Icon(
                    CupertinoIcons.star_circle_fill,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
          ),
        if (filterSortBy.displayOrderBy != null)
          FilterLabel(
            label: filterSortBy.displayOrderBy!,
            icon: filterSortBy.orderType == null
                ? null
                : (filterSortBy.orderType!.isAsc
                    ? Icon(
                        CupertinoIcons.sort_up,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.6),
                      )
                    : Icon(
                        CupertinoIcons.sort_down,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.6),
                      )),
            onTap: () {
              filterSortBy = filterSortBy.applyOrder(null).applyOrderBy(null);
              onFilter();
            },
          ),
      ],
    );
  }
}
