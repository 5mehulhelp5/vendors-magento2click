
import 'entities/product.dart';

class SearchResponse {
  List<Result>? result;

  SearchResponse({this.result});

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      result: json['result'] != null
          ? List<Result>.from(json['result'].map((x) => Result.fromJson(x)))
          : [],
    );
  }
}

class Result {
  String? code;
  List<dynamic>? data;
  int? size;
  String? url;

  Result({this.code, this.data, this.size, this.url});

  factory Result.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedData = [];

    if (json['code'] == 'suggest') {
      parsedData = json['data'] != null
          ? List<SuggestItem>.from(
          json['data'].map((x) => SuggestItem.fromJson(x)))
          : [];
    } else if (json['code'] == 'product') {
      parsedData = json['data'] != null
          ? List<Product>.from(
          json['data'].map((x) => Product.fromSearchJson(x)))
          : [];
    }

    return Result(
      code: json['code'],
      data: parsedData,
      size: json['size'],
      url: json['url'],
    );
  }


}

class SuggestItem {
  String? title;
  String? numResults;
  String? url;

  SuggestItem({this.title, this.numResults, this.url});

  factory SuggestItem.fromJson(Map<String, dynamic> json) {
    return SuggestItem(
      title: json['title'],
      numResults: json['num_results'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "num_results": numResults,
      "url": url,
    };
  }
}