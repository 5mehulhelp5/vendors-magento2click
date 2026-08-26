
class ProdcutOptionAttribute {
  Swatch? swatch;
  String? label;
  String? value;

  ProdcutOptionAttribute({this.swatch, this.label, this.value});

  ProdcutOptionAttribute.fromJson(Map<String, dynamic> json) {
    swatch =
    json['swatch'] != null ? new Swatch.fromJson(json['swatch']) : null;
    label = json['label'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.swatch != null) {
      data['swatch'] = this.swatch!.toJson();
    }
    data['label'] = this.label;
    data['value'] = this.value;
    return data;
  }
}

/// A configurable attribute's swatch set from extension_attributes.swatches
/// (e.g. attribute_code "all_color" / label "Color").
class ConfigurableSwatch {
  String? attributeCode;
  String? label;
  List<SwatchOption> options;

  ConfigurableSwatch({this.attributeCode, this.label, this.options = const []});

  ConfigurableSwatch.fromJson(Map json)
      : options = ((json['options'] as List?) ?? [])
            .whereType<Map>()
            .map((o) => SwatchOption.fromJson(o))
            .toList() {
    attributeCode = json['attribute_code']?.toString();
    label = json['label']?.toString();
  }
}

/// One selectable option within a [ConfigurableSwatch].
class SwatchOption {
  String? value; // option value id (matches ProductAttribute option value)
  String? label; // "Blue", "4 yrs"
  String? swatchType; // color | image | text
  String? swatchValue; // hex color, image URL, or label text
  String? productImage; // the variant's product image (CDN URL)
  List<int> productIds; // child products carrying this option

  SwatchOption({
    this.value,
    this.label,
    this.swatchType,
    this.swatchValue,
    this.productImage,
    this.productIds = const [],
  });

  SwatchOption.fromJson(Map json)
      : productIds = ((json['product_ids'] as List?) ?? [])
            .map((e) => int.tryParse('$e'))
            .whereType<int>()
            .toList() {
    value = json['value']?.toString();
    label = json['label']?.toString();
    swatchType = json['swatch_type']?.toString();
    swatchValue = json['swatch_value']?.toString();
    productImage = json['product_image']?.toString();
  }

  bool get isColor => swatchType == 'color';
  bool get hasImage => (productImage?.isNotEmpty ?? false);
}

class Swatch {
  String? type;
  String? value;

  Swatch({this.type, this.value});

  Swatch.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['value'] = this.value;
    return data;
  }
}