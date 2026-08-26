import 'dart:async';
import 'dart:io' show HttpClient, SecurityContext;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:universal_platform/universal_platform.dart';
import 'app.dart';
import 'common/config.dart';
import 'common/constants.dart';
import 'data/boxes.dart';
import 'env.dart';
import 'frameworks/magento/services/magento_service.dart';
import 'services/dependency_injection.dart';
import 'services/locale_service.dart';
import 'services/services.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  printLog('Handling a background message ${message.messageId}');
}

/// Global fallback for widget-build errors.
///
/// Previously the app set `ErrorWidget.builder = (_) => const SizedBox()` from
/// inside a widget's build() (the custom tab bar), which silently turned ANY
/// build error anywhere into an invisible empty box. A single failed screen
/// then appeared as a blank white page, and a recurring build error read as a
/// hang — the "application freezes / all screens blank" bug.
///
/// Instead: always log the error, keep the informative red box in debug, and
/// in release show a neutral, fully self-contained fallback (its own
/// Directionality + explicit text style, so the fallback itself can never throw
/// and trigger an error loop). The tab bar stays alive, so the user can switch
/// tabs to recover instead of being stuck on a dead white screen.
Widget _globalErrorWidget(FlutterErrorDetails details) {
  printLog('🔴 Widget build error: ${details.exceptionAsString()}');
  if (!foundation.kReleaseMode) {
    return ErrorWidget(details.exception);
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: const Text(
        'Something went wrong.\nPlease go back and try again.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black54,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

void main() {
  final talker = TalkerFlutter.init();
  printLog('[main] ===== START main.dart =======');
  WidgetsFlutterBinding.ensureInitialized();

  /// Bound the decoded-image memory cache. List/card images are no longer
  /// evicted on scroll (see ImageResize.clearMemoryCacheWhenDispose), so cap
  /// RAM here instead: ~150 MB holds a few screens of right-sized bitmaps hot
  /// for smooth scroll-back while staying bounded on low-end devices.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB

  /// Configure the global build-error fallback ONCE, up front, so no widget
  /// can later mute the whole app's errors into a blank screen. See
  /// [_globalErrorWidget].
  ErrorWidget.builder = _globalErrorWidget;

  Services.getNotificationService().requestNotificationPermission();

  Configurations().setConfigurationValues(environment);

  /// Fix issue android sdk version 22 can not run the app.
  if (UniversalPlatform.isAndroid) {
    SecurityContext.defaultContext
        .setTrustedCertificatesBytes(Uint8List.fromList(isrgRootX1.codeUnits));
  }

  /// Hide status bar for splash screen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

  Provider.debugCheckInvalidValueType = null;
  var languageCode = kAdvanceConfig.defaultLanguage;

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runZonedGuarded(() async {
    /// Init Hive boxes.
    await initBoxes();

    if (!foundation.kIsWeb) {
      /// Enable network traffic logging.
      HttpClient.enableTimelineLogging = !foundation.kReleaseMode;

      /// Lock portrait mode.
      unawaited(SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]));
    }

    try {
      if (isMobile) {
        /// Init Firebase settings due to version 0.5.0+ requires to.
        /// Use await to prevent any usage until the initialization is completed.
        await Services().firebase.init();

        /// Don't let a slow Remote Config fetch hold the splash hostage. It
        /// usually returns fast (cached values within the fetch interval); on a
        /// stalled network, boot on the bundled/last-merged config and let RC
        /// apply next launch instead of blocking first paint indefinitely.
        await Configurations()
            .loadRemoteConfig()
            .timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    } catch (e) {
      printLog(e);
      // Loud on purpose. A failure here is not cosmetic: isEnabled stays false,
      // so DependencyInjection below binds the no-op NotificationServiceImpl
      // and push notifications stop working app-wide while the settings toggle
      // still reads ON. That silent downgrade is what made 86d3fh4g7 #1 so hard
      // to diagnose — the symptom surfaced in Settings, three layers from the
      // cause. Keep the app running (Firebase is not required to shop), but
      // make the consequence explicit in the log.
      printLog('🔴 Firebase init failed — push notifications will be DISABLED '
          '(no-op notification service). Cause: $e');
    }

    await DependencyInjection.inject();
    Services().setAppConfig(serverConfig);

    // Warm the brand id→label cache off the critical path. Profiling the PLP
    // showed the first product list blocked ~1.3s on this brand-attribute fetch
    // (awaited inline in the product parse; the parse itself is ~12ms). Priming
    // it here moves the cost into the splash/home window so the first product
    // grid opens on a warm cache. Fire-and-forget; MagentoService dedupes an
    // in-flight fetch, so a fast navigation shares this one call.
    final productApi = Services().api;
    if (productApi is MagentoService) {
      unawaited(productApi.getBrandLabels());
    }

    if (isMobile && kAdvanceConfig.autoDetectLanguage) {
      final lang = SettingsBox().languageCode;

      if (lang?.isEmpty ?? true) {
        languageCode = await LocaleService().getDeviceLanguage();
      } else {
        languageCode = lang.toString();
      }
    }

    if (serverConfig['type'] == 'vendorAdmin') {
      return runApp(Services()
          .getVendorAdminApp(languageCode: languageCode, isFromMV: false));
    }

    if (serverConfig['type'] == 'delivery') {
      return runApp(Services()
          .getDeliveryApp(languageCode: languageCode, isFromMV: false));
    }

    ResponsiveSizingConfig.instance.setCustomBreakpoints(
        const ScreenBreakpoints(desktop: 900, tablet: 600, watch: 100));

    runApp(App(languageCode: languageCode));
  }, (Object error, StackTrace stack) {
    talker.handle(error, stack, 'Uncaught app exception');
  });
}

// mariam@gmail.com
// mariam@123
//https://stg.locafy.market/fcm.php