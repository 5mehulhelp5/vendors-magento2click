import '../common/config.dart';
import '../common/constants.dart';
import '../frameworks/magento/services/magento_mixin.dart';
import '../modules/firebase/firebase_notification_service.dart';
import '../modules/firebase/firebase_service.dart';
import 'chat/all_chat_services.dart';
import 'notification/notification_service.dart';
import 'notification/notification_service_impl.dart';
import 'service_config.dart';

export 'base_remote_config.dart';

class Services
    with
        ConfigMixin,
        MagentoMixin
         {
  static final Services _instance = Services._internal();

  factory Services() => _instance;

  Services._internal();

  /// using BaseFirebaseServices when disable the Firebase
  // final firebase = BaseFirebaseServices();
  final firebase = FirebaseServices();

  /// using AdvertisementService when disable the Advertisement
  // final AdvertisementService advertisement = AdvertisementService();
  //final AdvertisementService advertisement = AdvertisementServiceImpl();

  final ChatServices chatServices = ChatServices();

  /// Get notification Service
  static NotificationService getNotificationService() {
    NotificationService notificationService = NotificationServiceImpl();
    if (isIos || isAndroid) {
        if (_instance.firebase.isEnabled) {
          notificationService = FirebaseNotificationService();
        }
    }
    return notificationService;
  }
}
