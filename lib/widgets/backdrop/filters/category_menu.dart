import 'package:flutter/material.dart';
import 'package:inspireui/widgets/expandable/expansion_widget.dart';
import 'package:provider/provider.dart';

import '../../../common/constants.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart'
    show Category, CategoryModel, ProductModel;
import '../../common/tree_view.dart';
import 'category_item.dart';

class CategoryMenu extends StatefulWidget {
  final Function(Category category) onFilter;

  const CategoryMenu({
    Key? key,
    required this.onFilter,
  }) : super(key: key);

  @override
  State<CategoryMenu> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends State<CategoryMenu> {
  CategoryModel get category => Provider.of<CategoryModel>(context);

  String? get categoryId => Provider.of<ProductModel>(context).categoryId;

  String _categoryId = '0';

  /// The category this filter sheet was opened on — the root of the tree shown
  /// below. The website's layered navigation lists only the CURRENT category's
  /// children (e.g. Boys -> Outwear/Homewear/Footwear/Underwear) and omits the
  /// "Category" filter entirely on a leaf category, so we mirror that. It is
  /// captured once and stays fixed while the user selects a child, otherwise
  /// the tree would re-root (and vanish) mid-interaction (86d3g3mea/86d3g43qr).
  ///
  /// Null when there is no category context (e.g. the search screen), where we
  /// keep the previous behaviour of listing the whole tree from the roots.
  String? _rootCategoryId;

  // Store category id from parent to children
  List<String?> selectedCategoryTree = [];

  @override
  void initState() {
    final currentId =
        Provider.of<ProductModel>(context, listen: false).categoryId;
    _categoryId = currentId.toString();
    final root = currentId?.toString();
    _rootCategoryId =
        (root == null || root.isEmpty || root == 'null' || root == kEmptyCategoryID)
            ? null
            : root;
    super.initState();
  }

  bool hasChildren(categories, id) {
    if (categories == null) return false;

    return categories.where((o) => o.parent == id).isNotEmpty;
  }

  List<Category> getSubCategories(categories, id) {
    if (categories == null) return [];

    if (id == null) {
      return categories.where((item) => item.isRoot == true).toList();
    }

    return categories.where((o) => o.parent == id).toList();
  }

  void onTap(Category category) {
    final id = category.id.toString();
    if (id == _categoryId) {
      widget.onFilter(Category(id: kEmptyCategoryID, subCategories: []));
      selectedCategoryTree.clear();
      setState(() => _categoryId = kEmptyCategoryID);
      return;
    }

    var indexOfCate = selectedCategoryTree.indexOf(category.parent);
    if (indexOfCate != -1) {
      selectedCategoryTree.removeRange(
          indexOfCate, selectedCategoryTree.length);
    } else {
      selectedCategoryTree.clear();
    }
    widget.onFilter(category);
    setState(() => _categoryId = id);
  }

  List<Parent> _getCategoryItems(
    List<Category>? categories, {
    String? id,
    required Function onFilter,
    int level = 1,
  }) {
    var subTree = <Parent>[];

    for (var category in getSubCategories(categories, id)) {
      var subCategories = _getCategoryItems(
        categories,
        id: category.id,
        onFilter: widget.onFilter,
        level: level + 1,
      );

      if (category.id == _categoryId ||
          selectedCategoryTree.contains(category.id)) {
        selectedCategoryTree.insert(0, category.parent);
      }

      subTree.add(Parent(
        parent: CategoryItem(
          category,
          hasChild: hasChildren(categories, category.id),
          isSelected: category.id == _categoryId,
          isParentOfSelected: selectedCategoryTree.contains(category.id),
          onTap: () => onTap(category),
          level: level,
        ),
        childList: ChildList(
          children: [
            if (hasChildren(categories, category.id))
              CategoryItem(
                category,
                isParent: true,
                isSelected: category.id == _categoryId,
                onTap: () => onTap(category),
                level: level + 1,
              ),
            ...subCategories,
          ],
        ),
      ));
    }

    return subTree;
  }

  Widget getTreeView({required List<Category> categories}) {
    return TreeView(
      parentList: _getCategoryItems(
        categories,
        // Root the tree at the current category so we list its children, the
        // way the website's layered navigation does. Null (search) still falls
        // back to the roots inside getSubCategories().
        id: _rootCategoryId,
        onFilter: widget.onFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<CategoryModel, List<Category>>(
      selector: (_, model) => model.categories ?? [],
      builder: (context, categories, child) {
        // Website parity: a leaf category has no "Category" filter at all —
        // only its attribute filters (Brand, Colour, Price, …).
        if (_rootCategoryId != null &&
            !hasChildren(categories, _rootCategoryId)) {
          return const SizedBox.shrink();
        }
        return ExpansionWidget(
          showDivider: true,
          padding: const EdgeInsets.only(
            left: 15,
            right: 15,
            top: 15,
            bottom: 5,
          ),
          title: Text(
            // "Category" / "فئة" — matches the website's filter heading.
            // Not `byCategory`, which the sidebar still uses.
            S.of(context).filterCategory,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: getTreeView(categories: categories),
            ),
          ],
        );
      },
    );
  }
}
