import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../models/index.dart';
import 'item_category.dart';

class ProductCategoryMenu extends StatefulWidget {
  final bool enableSearchHistory;
  final String isComingFrom;
  final bool imageLayout;
  final String? newCategoryId;

  /// When non-null, the strip lists this parent's children — i.e. the current
  /// category's *siblings* — instead of the current category's own children,
  /// while still highlighting [newCategoryId]. Used by the home-banner →
  /// subcategory products page so a leaf still shows the "remaining
  /// subcategories" to switch between (ClickUp 86d3g3mea item 1).
  final String? siblingParentId;
  final Function(String?,String?)? onTap;

  const ProductCategoryMenu({
    super.key,
    this.enableSearchHistory = false,
    this.isComingFrom = "",
    this.imageLayout = false,
    this.newCategoryId,
    this.siblingParentId,
    this.onTap,
  });

  @override
  StateProductCategoryMenu createState() => StateProductCategoryMenu();
}

class StateProductCategoryMenu extends State<ProductCategoryMenu> {
  bool get categoryImageMenu => kAdvanceConfig.categoryImageMenu;

  Widget renderListCategories(List<Category> categories) {
    var categoryMenu = categoryImageMenu;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: Theme.of(context).colorScheme.background,
      constraints: const BoxConstraints(minHeight: 50),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: widget.isComingFrom == "product_screen" ?  Axis.horizontal:Axis.vertical,
          child: widget.isComingFrom == "product_screen" ?  Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              categories.length,
              (index) {
                var category = categories[index];
                var highlightColor = widget.newCategoryId == category.id
                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                    : Colors.transparent;
                return GestureDetector(
                  onTap: () => widget.onTap?.call(category.id,category.name!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(left: 5, top: 10, bottom: 4),
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        category.name!.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ): Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              categories.length,
                  (index) {
                var category = categories[index];
                return ItemCategory(
                  categoryId: category.id,
                  categoryName: category.name!,
                  categoryImage: categoryMenu && widget.imageLayout
                      ? category.image
                      : null,
                  newCategoryId: widget.newCategoryId,
                  onTap: widget.onTap,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableSearchHistory) {
      return const SizedBox(width: double.infinity);
    }

    return Consumer<CategoryModel>(builder: (context, categoryModel, child) {
      if (categoryModel.isLoading) {
        return Center(child: kLoadingWidget(context));
      }

      /// Two modes, chosen by the caller:
      ///
      /// - Default (Search, direct category taps): list this category's OWN
      ///   child categories — Boys -> Outwear / Homewear / Footwear / Underwear.
      ///   A leaf has no children, so the row disappears on its own, which is
      ///   what 86d3g43qr asks for ("tabs … removed from this page").
      /// - [siblingParentId] set (home-banner → subcategory flow): list that
      ///   parent's children — the current category's SIBLINGS — so a leaf
      ///   opened from a banner still shows "the remaining subcategories of the
      ///   main category" to switch between, matching the website (86d3g3mea
      ///   item 1). [newCategoryId] stays highlighted as the active one.
      final listParentId = widget.siblingParentId ?? widget.newCategoryId;
      final categories =
          getSubCategories(categoryModel.categories, listParentId) ??
              <Category>[];
      if (categories.isEmpty) {
        return const SizedBox(width: double.infinity);
      }
      return renderListCategories(categories);
    });
  }

  List<Category>? getSubCategories(categories, id) {
    return categories.where((o) => o.parent == id).toList();
  }
}
