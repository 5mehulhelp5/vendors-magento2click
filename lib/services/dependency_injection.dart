import 'package:get_it/get_it.dart';
// Enable Audio feature
// import '../modules/audio/services/audio_handler.dart';
import 'index.dart' show NotificationService, Services;
import 'location_service.dart';


GetIt injector = GetIt.instance;

class DependencyInjection {
  static Future<void> inject() async {
    injector.allowReassignment = true;
    final locationService = LocationService();
    injector.registerSingleton<LocationService>(locationService);

    var notificationService = Services.getNotificationService();
    injector.registerSingleton<NotificationService>(notificationService);

    /// Enable Audio feature
    // if (kBlogDetail['enableAudioSupport'] ?? false) {
    //   injector.registerSingleton<AudioHandler>(await initAudioService());
    // }
  }
}
