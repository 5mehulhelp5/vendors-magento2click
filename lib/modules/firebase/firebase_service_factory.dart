/// Service
import 'firebase_auth_service.dart';
/// Implement service
import 'impl/firebase_auth/firebase_auth_service_impl.dart';

class FirebaseServiceFactory {
  static T? create<T>() {
    switch (T) {
      case FirebaseAuthService:
        return FirebaseAuthServiceImpl() as T;
      default:
        return null;
    }
  }
}
