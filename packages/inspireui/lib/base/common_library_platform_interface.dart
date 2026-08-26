import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'common_library_method_channel.dart';

abstract class CommonLibraryPlatform extends PlatformInterface {
  /// Constructs a CommonLibraryPlatform.
  CommonLibraryPlatform() : super(token: _token);

  static final Object _token = Object();

  static CommonLibraryPlatform _instance = MethodChannelCommonLibrary();

  /// The default instance of [CommonLibraryPlatform] to use.
  ///
  /// Defaults to [MethodChannelCommonLibrary].
  static CommonLibraryPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CommonLibraryPlatform] when
  /// they register themselves.
  static set instance(CommonLibraryPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> initHttpClient() {
    throw UnimplementedError('initHttpClient() has not been implemented.');
  }
}
