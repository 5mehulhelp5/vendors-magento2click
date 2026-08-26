import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils.dart';
import 'common_library_platform_interface.dart';

/// An implementation of [CommonLibraryPlatform] that uses method channels.
class MethodChannelCommonLibrary extends CommonLibraryPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.inspireui/common_library');

  @override
  Future<String?> initHttpClient() async {
    final result = await methodChannel.invokeMethod<String>(
      EncodeUtils.decode(
        'VUd4bFlYTmxJSFZ6WlNCMGFHVWdiR1ZuWVd3Z1RHbGpaVzV6WlNEd241bVA=',
      ),
    );
    return result;
  }
}
