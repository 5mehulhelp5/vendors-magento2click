import 'dart:developer' as devtools show log;
import 'package:flutter/foundation.dart' show kDebugMode;

extension Log on Object {
  /// Debug-only, like printLog. This was ungated, so every caller — including
  /// ones that stringify auth tokens, whole login response bodies and
  /// password-reset URLs — wrote to the device log in RELEASE builds too.
  void log() {
    if (kDebugMode) devtools.log(toString());
  }
}
