import '../utils/regex_utils.dart';

extension StringExtensions on String {
  bool get hasOnlyWhitespaces => trim().isEmpty && isNotEmpty;

  bool get isListView => this != 'horizontal';

  bool get isEmptyOrNull {
    // ignore: unnecessary_null_comparison
    if (this == null) {
      return true;
    }
    return isEmpty;
  }

  String toSpaceSeparated() {
    final value =
        replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ');
    return value;
  }

  String formatCopy() {
    return replaceAll('},', '\n},\n')
        .replaceAll('[{', '[\n{\n')
        .replaceAll(',"', ',\n"')
        .replaceAll('{"', '{\n"')
        .replaceAll('}]', '\n}\n]');
  }

  /// Whether this message describes a device that cannot reach the network at
  /// all, so the caller can offer the offline screen instead of a generic
  /// "something went wrong".
  ///
  /// The same failure reaches here spelled two ways. Anything routed through
  /// `httpGet` and its siblings is rewritten by `makeRequest` in
  /// utils/http_client.dart, which catches the SocketException and rethrows the
  /// literal 'No Internet Connection' — that is what every network call in this
  /// app actually produces. Only a caller that bypasses those helpers surfaces
  /// the exception itself, whose toString() reads
  /// `SocketException: Failed host lookup: '<host>' (OS Error: ...)`.
  ///
  /// Matching a substring rather than the whole string is deliberate: the
  /// models wrap the error in a sentence of their own before it gets here
  /// (ProductModel: 'There is an issue with the app ... $err').
  bool get isNoInternetError =>
      contains('No Internet Connection') ||
      contains('SocketException: Failed host lookup');

  bool get isURLImage => isNotEmpty && (contains('http') || contains('https'));

  Uri? toUri() => Uri.tryParse(this);

  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String upperCaseFirstChar() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.upperCaseFirstChar())
      .join(' ');

  RoutingData get getRoutingData {
    final uriData = Uri.parse(this);
    return RoutingData(
      queryParameters: uriData.queryParameters,
      route: uriData.path,
    );
  }

  bool get isEmail => validateEmail();
}

extension StringExt2 on String? {
  bool validateEmail() {
    final copy = this;
    if (copy == null || copy.isEmpty || copy.contains(' ')) {
      return false;
    }
    if(!copy.contains(".com")) {
      return false;
    }
    return RegexUtils.check(copy, RegexUtils.email, caseSensitive: false);
  }
}

class RoutingData {
  final String? route;
  final Map<String, String>? _queryParameters;

  RoutingData({
    this.route,
    Map<String, String>? queryParameters,
  }) : _queryParameters = queryParameters;

  String? getPram(String key) => _queryParameters![key];
}
