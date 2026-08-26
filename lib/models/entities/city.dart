class City {
  String? id;
  String? name;

  /// For a governorate (City.cityConfig): the Magento core region this
  /// City/Region-Manager entry maps to. `name` is the extension's Arabic
  /// `states_name`; [regionName] is Magento's `region.region` (English) and
  /// [regionId] its `region_id`. An address created on the website stores the
  /// English region name in `address.state`, so matching also against
  /// [regionName]/[regionId] lets it resolve to the right governorate instead
  /// of leaving the dropdown empty (86d3tkj56 #2).
  String? regionName;
  String? regionId;

  City({this.id, this.name});

  City.fromConfig(dynamic parsedJson) {
    if (parsedJson is Map) {
      id = parsedJson['id'];
      name = parsedJson['name'];
    }
    if (parsedJson is String) {
      id = parsedJson;
      name = parsedJson;
    }
  }

  City.cityConfig(dynamic parsedJson) {
    if (parsedJson is Map) {
      id = parsedJson['entity_id'];
      name = parsedJson['states_name'];
      regionName = parsedJson['region_name']?.toString();
      regionId = parsedJson['region_id']?.toString();
    }
    if (parsedJson is String) {
      id = parsedJson;
      name = parsedJson;
    }
  }

  City.zoneConfig(dynamic parsedJson) {
    if (parsedJson is Map) {
      id = parsedJson['entity_id'];
      name = parsedJson['cities_name'];
    }
    if (parsedJson is String) {
      id = parsedJson;
      name = parsedJson;
    }
  }
}
