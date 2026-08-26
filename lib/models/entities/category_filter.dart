/// A single selectable option inside a category filter attribute — e.g. the
/// colour "Navy" under "Color", or "Dress on" under "Brand".
///
/// [value] is the Magento EAV option id (e.g. `766`) — the exact value the
/// REST product query filters on, identical in shape to how `brand` /
/// `category_id` are already filtered. [code] is the owning attribute's
/// `attribute_code`; it is carried on each option so that attributes merged
/// under one display label (e.g. the several category-specific
/// `*_producttype` codes all shown as "Product Type") still apply to the
/// correct field.
class CategoryFilterOption {
  final String code;
  final String label;
  final String value;
  final int count;

  const CategoryFilterOption({
    required this.code,
    required this.label,
    required this.value,
    required this.count,
  });
}

/// One filter attribute group shown in the product-listing filter panel
/// (e.g. "Color", "Size", "Brand"), sourced from the storefront GraphQL
/// `aggregations` for the current category.
///
/// Options coming from different `attribute_code`s that share the same
/// [label] are merged into a single group, mirroring the website (which
/// shows one "Product Type" even where the catalog splits it into
/// category-specific attribute codes).
class CategoryFilterAttribute {
  final String label;
  final List<CategoryFilterOption> options;

  const CategoryFilterAttribute({
    required this.label,
    required this.options,
  });
}
