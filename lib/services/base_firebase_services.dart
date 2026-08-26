import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import '../models/entities/firebase_error_exception.dart';
import '../models/entities/user.dart';

class BaseFirebaseServices {
  /// check if the Firebase is enable or not
  bool get isEnabled => false;

  Future<void> init() async {}

  dynamic getCloudMessaging() {}

  dynamic getCurrentUser() => null;

  /// Login Firebase with social account
  void loginFirebaseApple({authorizationCode, identityToken}) {}

  void loginFirebaseFacebook({token}) {}

  void loginFirebaseGoogle({token}) {}

  void loginFirebaseEmail({email, password}) {}

  dynamic loginFirebaseCredential({credential}) {}

  dynamic getFirebaseCredential({verificationId, smsCode}) {}

  /// save user to firebase
  void saveUserToFirestore({user}) {}

  /// verify SMS login
  dynamic getFirebaseStream() {}

  Future<void> verifyPhoneNumber({
    phoneNumber,
    codeAutoRetrievalTimeout,
    codeSent,
    required void Function(String?) verificationCompleted,
    void Function(FirebaseErrorException error)? verificationFailed,
    forceResendingToken,
    Duration? timeout,
  }) async {}

  /// render Chat Screen
  Widget renderChatAuthScreen() => const SizedBox();

  Widget renderListChatScreen() => const SizedBox();

  Widget renderVendorListChatScreen({String? email}) => const SizedBox();

  Widget renderChatScreen({User? senderUser, receiverEmail, receiverName}) =>
      const SizedBox();

  /// load firebase remote config
  Future<bool> loadRemoteConfig() async => false;

  String getRemoteConfigString(String key) => '';

  Future<List<String>> getRemoteKeys() async => [];

  /// init Firebase Dynamic link
  void initDynamicLinkService(context) {}

  /// Share a product/page link through the native OS share sheet.
  ///
  /// Firebase Dynamic Links have been shut down, so instead of generating a
  /// dynamic link we simply share the item's canonical web URL (the product
  /// permalink) via share_plus. This is what every caller actually wants and
  /// it works on both the product detail page and the product list.
  /// Pass [context] wherever one is available: it anchors the share popover on
  /// iPad. See [_sharePositionOrigin].
  Future<void> shareDynamicLinkProduct({itemUrl, BuildContext? context}) async {
    final url = itemUrl?.toString().trim() ?? '';
    if (url.isEmpty) return;
    try {
      await Share.share(
        url,
        sharePositionOrigin: _sharePositionOrigin(context),
      );
    } catch (e) {
      // Previously this was fire-and-forget, so a platform failure surfaced as
      // nothing happening at all. Log it instead of losing it.
      debugPrint('[share] failed to open the share sheet: $e');
    }
  }

  /// Anchor rect for the share sheet, or null when it can't be determined.
  ///
  /// On iPad `UIActivityViewController` is presented as a popover and needs a
  /// non-empty source rect inside the presenting view. share_plus checks for
  /// this and returns a PlatformException *without presenting anything* when
  /// it's missing (see FLTSharePlusPlugin.m), so on an iPad build the share
  /// button silently did nothing — and this app ships for iPad
  /// (TARGETED_DEVICE_FAMILY = "1,2"). Ignored on iPhone and Android.
  ///
  /// Prefers the tapped widget's own bounds; falls back to a small rect at the
  /// centre of the screen, which is still inside the source view and non-empty.
  Rect? _sharePositionOrigin(BuildContext? context) {
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.maybeOf(context)?.size;
    if (size == null) return null;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  /// register new user with email and password
  void createUserWithEmailAndPassword({email, password}) {}

  Future<void> signOut() async {}

  Future<String?> getMessagingToken() async => '';

  List<NavigatorObserver> getMNavigatorObservers() =>
      const <NavigatorObserver>[];

  void deleteAccount() {}
}
