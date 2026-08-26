import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:inspireui/inspireui.dart' show AutoHideKeyboard;
import 'package:magentoegypt/ajstoreui/widgets/app_bar/appbar_title.dart';
import 'package:magentoegypt/models/SearchResponse.dart';
import 'package:magentoegypt/services/base_services.dart';
import 'package:provider/provider.dart';
import '../../common/constants.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart'
    show BackDropArguments, Category, CategoryModel, CartModel, Product;
import '../../menu/maintab_delegate.dart';
import '../../modules/dynamic_layout/tabbar/tabbar_icon.dart';
import '../../routes/flux_navigate.dart';
import '../../services/services.dart';
import '../../widgets/common/tree_view.dart';
import '../common/app_bar_mixin.dart';
import '../index.dart' show SearchBox, SubItem, CartScreenArgument;
import '../products/widgets/category_menu.dart';

class CategorySearch extends StatefulWidget {
  bool isNavigation = false;
  String isComingFrom = "";
  String? newCategoryId = "";
  String selectedId = "";
  String selectedCategoryName = "";
   CategorySearch({super.key,this.isNavigation = false,this.isComingFrom = "",this.newCategoryId});

  @override
  State<StatefulWidget> createState() => _CategorySearchState();
}

class _CategorySearchState<T> extends State<CategorySearch> with AppBarMixin {
  final _searchFieldNode = FocusNode();
  final _searchFieldController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<Category> categories = [];
  int selectedTabIndex = 0;
  String? _keyword;
  SearchResponse? searchResponse;

  @override
  void initState() {
    super.initState();
    screenScrollController = _scrollController;
    final categoryModel = Provider.of<CategoryModel>(context, listen: false);

  }

  @override
  void dispose() {
    _searchFieldNode.dispose();
    _searchFieldController.dispose();
    super.dispose();
  }

  int _searchRequestId = 0;

  Future<void> _onSearchTextChange(String value) async {
    // Every keystroke gets its own request id. When an async response comes
    // back we only apply it if no newer keystroke (including clearing the
    // field) has happened since — otherwise a slow response for an earlier,
    // now-stale keyword can land after the field was cleared and make the old
    // results reappear.
    final requestId = ++_searchRequestId;
    if (value.isEmpty) {
      searchResponse = null;
      if (mounted) setState(() {});
      return;
    }
    final result = await Services().api.searchProductsResult(value);
    if (!mounted || requestId != _searchRequestId) return;
    searchResponse = result;
    setState(() {

    });
    // setState(() {
    //   _keyword = value;
    // });

    // if (value.isEmpty) {
    //   setState(() {
    //     categories = [];
    //   });
    //   return;
    // }
    //
    // if (_searchFieldNode.hasFocus || value.isNotEmpty) {
    //   final categoryModel = Provider.of<CategoryModel>(context, listen: false);
    //   categories = categoryModel.categories!
    //       .where((e) => e.name!.toLowerCase().contains(value.toLowerCase()))
    //       .toList();
    //   setState(() {});
    // }
  }

  @override
  Widget build(BuildContext context) {

    final categoryModel = Provider.of<CategoryModel>(context);

    // Get updated data when available
    final rootCategories = categoryModel.rootCategories ?? [];

    // Build tabs dynamically
    final List<String?> tabs = rootCategories.map((e) => e.name).toList();

    assert(debugCheckHasMaterialLocalizations(context));
    var theme = Theme.of(context);
    theme = Theme.of(context).copyWith(
      primaryColor: Colors.white,
      primaryIconTheme: theme.primaryIconTheme.copyWith(color: Colors.grey),
      primaryTextTheme: theme.textTheme,
    );
    final searchFieldLabel = MaterialLocalizations.of(context).searchFieldLabel;
    var routeName = isIos ? '' : searchFieldLabel;
    final suggest = searchResponse?.result
        ?.firstWhere((e) => e.code == 'suggest', orElse: () => Result(data: []));
    final products = searchResponse?.result
        ?.firstWhere((e) => e.code == 'product', orElse: () => Result(data: []));

    return Semantics(
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: routeName,
      child: renderScaffold(
        routeName: RouteList.categorySearch,
        backgroundColor: theme.colorScheme.background,
        resizeToAvoidBottomInset: false,
        // secondAppBar: AppBar(
        //   automaticallyImplyLeading: true,
        //   backgroundColor: theme.colorScheme.background,
        //   iconTheme: theme.primaryIconTheme,
        //   // textTheme: theme.primaryTextTheme,
        //   // brightness: theme.primaryColorBrightness,
        //   centerTitle: false,
        //   leadingWidth: 24,
        //   titleSpacing: 0,
        //   title: SearchBox(
        //     showQRCode: false,
        //     showSearchIcon: false,
        //     showCancelButton: false,
        //     autoFocus: true,
        //     controller: _searchFieldController,
        //     focusNode: _searchFieldNode,
        //     onChanged: _onSearchTextChange,
        //   ),
        // ),
        child: AutoHideKeyboard(
          child: Column(
            children: [
              // Always show the standard header (back button, current
              // category/search title, cart icon) — it must never be hidden,
              // regardless of how this screen was reached.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Always show the back arrow. It used to hide unless the
                  // screen was pushed (isNavigation) or drilled into a
                  // subcategory, so reaching Search via the bottom-nav tab —
                  // its own tab root — showed no arrow at all (86d3pngh1 #1).
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                    onPressed: () {
                      if (widget.selectedId.isNotEmpty) {
                        // Drilled into a subcategory — step back within the
                        // screen to the category list.
                        setState(() {
                          widget.selectedId = "";
                          widget.selectedCategoryName = "";
                        });
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      } else {
                        // Opened as the bottom-nav tab root — switch to the
                        // Home tab (the main screen).
                        MainTabControlDelegate.getInstance().tabAnimateTo(0);
                      }
                    },
                  ),
                  widget.selectedId.isNotEmpty &&
                          widget.selectedCategoryName.isNotEmpty
                      ? AppbarTitle(text: widget.selectedCategoryName)
                      : widget.isComingFrom == "categogies" ? Image.asset(
                    'assets/images/logo.png',
                    width: 150,
                    height: 50,
                  ):AppbarTitle(text: S.of(context).search),
                  Selector<CartModel, int>(
                    selector: (_, model) => model.totalCartQuantity,
                    builder: (context, totalCart, child) {
                      return IconButton(
                        icon: IconCart(icon: Icon(
                          CupertinoIcons.bag,
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                        ), totalCart: totalCart),
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            RouteList.cart,
                            arguments: CartScreenArgument(isBuyNow: true, isModal: false),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              if(widget.selectedId.isNotEmpty)...[
                // Drilled into a category (its subcategories are listed
                // below). This menu stays a plain list of subcategories — the
                // category's description belongs on its product page, not
                // here — but it keeps the search entry point from the level
                // above, which used to disappear on the way down.
                _buildSearchPill(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      reverseDuration: const Duration(milliseconds: 300),
                      // child: buildResult(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: getChildCategoryList(widget.selectedId),),
                    ),
                  ),
                ),
              ]
              else if(widget.isComingFrom == "categogies")...[
                _buildSearchPill(),
                Expanded(child: ProductCategoryMenu(
                  imageLayout: true,
                  enableSearchHistory:false,
                  newCategoryId: widget.newCategoryId,
                  onTap: (categoryId,categoryName) {
                    setState(() {
                     // widget.selectedId = categoryId ?? "";
                      Navigator.of(context).pushNamed(
                        RouteList.backdrop,
                        arguments: BackDropArguments(
                          cateId:categoryId,
                          cateName: categoryName,
                          hideDescription: true,
                        ),
                      );
                    });
                    // include = null;
                    // onFilter(categoryId: categoryId);
                  },
                ))]
              else ...[
                  /// 🔍 Rounded "Search" view
                  // 🔍 Search Field
                 Row(children: [
                   Expanded(child: Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: TextField(
                       controller: _searchFieldController,
                       focusNode: _searchFieldNode,
                       onChanged: _onSearchTextChange,
                       decoration: InputDecoration(
                         hintText:S.of(context).search, //'بحث',
                         prefixIcon: const Icon(Icons.search),
                         filled: true,
                         fillColor: Colors.grey.shade200,
                         contentPadding: const EdgeInsets.symmetric(vertical: 0),
                         border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(12),
                           borderSide: BorderSide.none,
                         ),
                       ),
                     ),
                   ),),
                   /// Cancel button
                   if(widget.isComingFrom == "homeSearch")
                   Padding(
                     padding: const EdgeInsets.only(right: 12),
                     child: TextButton(
                       onPressed: () {
                         Navigator.pop(context);
                       },
                       child: Text(
                         S.of(context).cancel, // or "Cancel"
                         style: const TextStyle(fontSize: 16),
                       ),
                     ),
                   ),
                 ],),
                  if(searchResponse != null) Expanded(child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// 🔵 Suggested
                        if ((suggest?.data ?? []).isNotEmpty)
                          SuggestSection(items: suggest!.data as List<SuggestItem>),

                        /// 🟦 Products (VERTICAL LIST)
                        if ((products?.data ?? []).isNotEmpty)
                          ProductSectionList(
                            items: products!.data as List<Product>,
                            totalCount: products.size,
                            searchKeyword: _searchFieldController.text,
                          ),
                      ],
                    ),
                  )) else ...[
                    // 👕 Dynamic Tabs in Horizontal Scroll View
                    SizedBox(
                      height: 45,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: List.generate(tabs.length, (index) {
                            final isSelected = selectedTabIndex == index;
                            return GestureDetector(
                              onTap: () => setState(() => selectedTabIndex = index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isSelected ? Colors.black : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  tabs[index]!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.grey,
                                    fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if(tabs.length>0)
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            reverseDuration: const Duration(milliseconds: 300),
                            // child: buildResult(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: getChildCategoryList(rootCategories[selectedTabIndex].id ?? ""),),
                          ),
                        ),
                      ),
                  ]
                ]
            ],
          ),
        ),
      ),
    );
  }

  /// Rounded "Search" entry point — tapping it opens the full search screen.
  /// Shown both on the category list and after drilling into a category.
  Widget _buildSearchPill() {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CategorySearch(isNavigation: true, isComingFrom: "homeSearch"),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(15),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              S.of(context).search,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildResult() {
    if ((_keyword?.isNotEmpty ?? false) && categories.isEmpty) {
      return Center(
        child: Text(S.of(context).notFound),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        var item = categories[index];
        return _SearchCategoryItem(category: item);
      },
      separatorBuilder: (context, index) => Divider(
        color: Colors.black.withOpacity(0.05),
      ),
    );
  }

  void close() {
    var currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
    Navigator.of(context).pop();
  }

  List<Category> getSubCategories(id) {
    final categoryModel = Provider.of<CategoryModel>(context, listen: false);
    return categoryModel.getCategory(parentId: id) ?? <Category>[];
  }

  void navigateToBackDrop(Category category) {
    //FluxNavigate
    Navigator.of(context).pushNamed(
      RouteList.backdrop,
      arguments: BackDropArguments(
        cateId: category.id,
        cateName: category.name,
        hideDescription: true,
      ),
    );
  }

  bool hasMatchingChild(String? parentId, String keyword) {
    for (var child in getSubCategories(parentId)) {
      if (child.name!
          .toLowerCase()
          .contains(keyword.toLowerCase())) {
        return true;
      }
      if (hasMatchingChild(child.id, keyword)) {
        return true;
      }
    }
    return false;
  }

  List<FlatCategoryItem> buildFlatCategoryList(
      String? parentId,
      int level,
      ) {
    final List<FlatCategoryItem> result = [];
    final keyword = (_keyword ?? "").toLowerCase();

    for (var cate in getSubCategories(parentId)) {
      final selfMatch = keyword.isEmpty ||
          cate.name!.toLowerCase().contains(keyword);

      final childMatch =
          keyword.isNotEmpty && hasMatchingChild(cate.id, keyword);

      // ❗ show parent if:
      // - keyword empty
      // - OR parent matches
      // - OR any child matches
      if (keyword.isNotEmpty && !selfMatch && !childMatch) {
        continue;
      }

      result.add(FlatCategoryItem(cate, level));

      // Only recurse if children exist
      result.addAll(
        buildFlatCategoryList(cate.id, level + 1),
      );
    }

    return result;
  }
  // List<FlatCategoryItem> buildFlatCategoryList(
  //     String? parentId,
  //     int level,
  //     ) {
  //   final List<FlatCategoryItem> result = [];
  //
  //   for (var cate in getSubCategories(parentId)) {
  //     // filter by keyword
  //     if ((_keyword ?? "").isNotEmpty &&
  //         !cate.name!
  //             .toLowerCase()
  //             .contains((_keyword ?? "").toLowerCase())) {
  //       continue;
  //     }
  //
  //     result.add(FlatCategoryItem(cate, level));
  //
  //     // add children immediately (NO expand logic)
  //     result.addAll(
  //       buildFlatCategoryList(cate.id, level + 1),
  //     );
  //   }
  //
  //   return result;
  // }

  Widget getChildCategoryList(String maincategoryId) {
    final flatList = buildFlatCategoryList(maincategoryId, 0);
    if ((_keyword ?? "").isNotEmpty) {
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var item in flatList)
          GestureDetector(
            onTap: () {
              if (getSubCategories(item.category.id).isEmpty) {
                Navigator.of(context).pushNamed(
                  RouteList.backdrop,
                  arguments: BackDropArguments(
                    cateId: item.category.id,
                    cateName: item.category.name,
                    hideDescription: true,
                  ),
                );
              }
            },
            child: SubItem(
              item.category,
              level: item.level,
              hasChild:
              getSubCategories(item.category.id).isNotEmpty,
            ),
          ),
      ],
    );
    } else {
      return ChildList(
        children: [
          for (var category in getSubCategories(maincategoryId))
            // Tapping the row/name always opens this category's own product
            // page; tapping the trailing arrow (only shown when it has
            // children) drills into its child categories instead.
            GestureDetector(
              onTap: () => navigateToBackDrop(category),
              child: SubItem(
                category,
                hasChild: getSubCategories(category.id).isNotEmpty,
                onArrowTap: (_) {
                  setState(() {
                    widget.selectedId = category.id ?? "";
                    widget.selectedCategoryName = category.name ?? "";
                  });
                },
              ),
            ),
        ],
      );
    }
  }
  List<Widget> buildCategories(String? parentId, int level) {
    final subCategories = getSubCategories(parentId);

    return [
      for (var cate in subCategories) ...[
        GestureDetector(
          onTap: () {
            if (getSubCategories(cate.id).isEmpty) {
              Navigator.of(context).pushNamed(
                RouteList.backdrop,
                arguments: BackDropArguments(
                  cateId: cate.id,
                  cateName: cate.name,
                  hideDescription: true,
                ),
              );
            }
          },
          child: SubItem(
            cate,
            level: level,
            hasChild: getSubCategories(cate.id).isNotEmpty,
          ),
        ),

        // Render children immediately (NO expand)
        ...buildCategories(cate.id, level + 1),
      ]
    ];
  }
}

class _SearchCategoryItem extends StatelessWidget {
  final Category category;

  const _SearchCategoryItem({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        RouteList.backdrop,
        arguments: BackDropArguments(
          cateId: category.id,
          cateName: category.name,
          hideDescription: true,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        child: Row(
          children: <Widget>[
            Container(
              width: 100,
              height: 80,
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: CachedNetworkImageProvider(category.image!,
                        headers: const {'Accept': 'image/webp'}),
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(category.name!,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class FlatCategoryItem {
  final Category category;
  final int level;

  FlatCategoryItem(this.category, this.level);
}

class SuggestSection extends StatelessWidget {
  final List<SuggestItem> items;

  const SuggestSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header("SUGGESTED"),
        Container(
          color: Colors.grey.shade200,
          child: Column(
            children: items.map((e) {
              return ListTile(
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(text: e.title ?? ''),
                      TextSpan(
                        text: " (${e.numResults})",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  // open e.url
                  Navigator.of(context).pushNamed(
                    RouteList.backdrop,
                    arguments: BackDropArguments(
                      searchText:e.title
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class ProductSectionList extends StatelessWidget {
  final List<Product> items;
  final int? totalCount;
  final String? searchKeyword;

  const ProductSectionList({
    super.key,
    required this.items,
    this.totalCount,
    this.searchKeyword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          totalCount != null ? "PRODUCTS ($totalCount)" : "PRODUCTS",
          trailing: (searchKeyword?.isNotEmpty ?? false)
              ? GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(
                    RouteList.backdrop,
                    arguments: BackDropArguments(searchText: searchKeyword),
                  ),
                  child: Text(
                    S.of(context).seeAll,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : null,
        ),

        ListView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // 🔥 important
          itemBuilder: (context, index) {
            return ProductListTile(product: items[index]);
          },
        ),
      ],
    );
  }
}

class ProductListTile extends StatelessWidget {
  final Product product;

  const ProductListTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        var productObj = await Services().api
            .getProduct(product.id);
        FluxNavigate.pushNamed(
          RouteList.productDetail,
          arguments: productObj,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🖼️ IMAGE
            SizedBox(
              width: 90,
              height: 90,
              child: CachedNetworkImage(
                imageUrl: product.imageFeature ?? '',
                httpHeaders: const {'Accept': 'image/webp'},
                fit: BoxFit.contain,
                memCacheWidth: 270,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),

            const SizedBox(width: 10),

            /// 📄 DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    product.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),

                  Text(product.price ?? ''),

                  if (_plainTextFromHtml(product.description).isNotEmpty)
                    Text(
                      _plainTextFromHtml(product.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

/// The search autocomplete returns `description` as a short, truncated
/// fragment. PageBuilder products lead with a `<style>` block, so that
/// fragment is often raw CSS like `#html-body [data-pb-style=...]{justify-...`
/// with no closing tag. Strip any real `<style>`/`<script>`/tags, then drop
/// the result entirely if it still looks like CSS/markup rather than prose —
/// so the search card shows a clean description or nothing, never raw code.
String _plainTextFromHtml(String? htmlData) {
  if (htmlData == null || htmlData.isEmpty) return '';
  try {
    final document = html_parser.parse(htmlData);
    document.querySelectorAll('style, script').forEach((e) => e.remove());
    final text =
        (document.body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    // Leftover CSS/markup fragment (truncated PageBuilder style, stray tag) —
    // not something worth showing to the shopper.
    if (text.isEmpty ||
        text.contains('#html-body') ||
        text.contains('data-pb-style') ||
        text.contains('{') ||
        text.contains('}') ||
        text.contains('<')) {
      return '';
    }
    return text;
  } catch (_) {
    return '';
  }
}

Widget _header(String title, {Widget? trailing}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: Colors.blue,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}