import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../common/constants.dart';
import '../../models/entities/fstore_notification_item.dart';

abstract class NotificationService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void setIsInitialized() {
    _isInitialized = true;
  }

  NotificationService() {
    // var initSetting = const InitializationSettings(
    //   android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    //   iOS: IOSInitializationSettings(),
    // );
    //
    // flutterLocalNotificationsPlugin.initialize(initSetting,
    //     onSelectNotification: (String? payload) async {
    //   /// Handle payload here
    // });

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> requestNotificationPermission() async {
    // Android 13+ only
    if (await ph.Permission.notification.isDenied) {
      await ph.Permission.notification.request();
    }

    // iOS-specific
    final iosResult = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // macOS-specific
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  final channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  late final NotificationDelegate delegate;

  void init({
    /// OneSignal only
    String? externalUserId,
    required NotificationDelegate notificationDelegate,
  });

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return false;
    }

    /// Case unknown - First time open the app
    var status = await ph.Permission.notification.request();
    if (status.isGranted) {
      // Permission granted
    } else {
      // Permission denied
    }

    return status.isGranted;
  }

  Future<bool> isGranted() async {
    if (kIsWeb) return false;
    // Use .status (a pure check) not .request() — this is called to reflect the
    // current permission state (e.g. syncing the settings toggle) and must not
    // pop the OS permission prompt. The explicit opt-in still uses
    // requestPermission().
    final status = await ph.Permission.notification.status;
    return status.isGranted;
  }

  void disableNotification();

  void enableNotification();

  void setExternalId(String? userId);

  void removeExternalId();
}

mixin NotificationDelegate {
  void onMessage(FStoreNotificationItem notification);

  void onMessageOpenedApp(FStoreNotificationItem notification);
}
