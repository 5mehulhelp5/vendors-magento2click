class RegexUtils {
  /// RFC 5322 compliant regex (https://stackoverflow.com/a/201378/19622959 or http://emailregex.com/)
  static const String email =
      r'''(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])''';

  static const String alphabetic = r'^[0-9]+$';

  static const String alphanumeric = r'^[a-zA-Z0-9]+$';

  /// contains only alphanumeric, dot & space character
  static const String name = r'^[a-zA-Z0-9. ]*$';

  static const String numeric = r'^[0-9]+$';

  static const String fileNameFromUrl = r'(?:[^/][\d\w\.-]+)$(?<=\.\w{3,4})';
  static const String url =
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})';

  /// begin with one letter, contains only alphanumeric
  /// and only one dot or underscore in a row (not accept at the end)
  static const String username = r'^[a-zA-Z]((?:[_.]?[a-zA-Z0-9]+){6,50})$';

  /// contains only alphanumeric
  /// with selected special character & length from 8-25
  static const String password = r'^[a-zA-Z0-9.\-_!@#$%]{8,50}$';

  static bool check(String text, String pattern, {bool caseSensitive = true}) {
    return RegExp(pattern, caseSensitive: caseSensitive).hasMatch(text);
  }
}
