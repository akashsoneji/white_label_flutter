import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/referral_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Receives universal links / App Links from the native side
/// (MainActivity on Android, DeepLinkPlugin in AppDelegate.swift on iOS) and
/// acts on them once the app has left splash/auth-check.
///
/// Links never trigger money actions: they only save a referral code, prefill
/// registration or bring the app to the front. A no-op for flavors without
/// `deepLink.host` in their brand.yaml.
class DeepLinkService extends GetxService {
  static const MethodChannel _methods = MethodChannel('app/deeplink');
  static const EventChannel _events = EventChannel('app/deeplink/events');

  StreamSubscription<dynamic>? _subscription;
  Uri? _pendingLink;

  Future<DeepLinkService> init() async {
    if (!FlavorConfig.instance.isDeepLinkEnabled) return this;

    String? initialLink;
    try {
      initialLink = await _methods.invokeMethod<String>('getInitialLink');
    } on PlatformException catch (e) {
      debugPrint('DeepLinkService: initial link unavailable: $e');
    } on MissingPluginException {
      return this;
    }
    if (initialLink != null) _accept(initialLink);

    _subscription = _events.receiveBroadcastStream().listen(
      (event) => _accept(event as String?),
      onError: (Object e) => debugPrint('DeepLinkService: link stream error: $e'),
    );

    if (initialLink == null) unawaited(_claimDeferredIfLoggedOut());
    return this;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  /// Hooked to GetMaterialApp.routingCallback: runs the pending link as soon
  /// as the app reaches a real screen (home when logged in, login/get-started
  /// when logged out).
  void onRouteChanged(String? route) {
    if (_pendingLink == null || _isStartupRoute(route)) return;
    final link = _pendingLink!;
    _pendingLink = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle(link));
  }

  void _accept(String? raw) {
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !_isTrusted(uri)) {
      debugPrint('DeepLinkService: ignored link $raw');
      return;
    }
    if (_isStartupRoute(Get.currentRoute)) {
      _pendingLink = uri;
      return;
    }
    _handle(uri);
  }

  bool _isTrusted(Uri uri) {
    final config = FlavorConfig.instance;
    if (uri.scheme != 'https' || !config.deepLinkHosts.contains(uri.host)) return false;
    return FlavorConfig.deepLinkPaths
        .any((prefix) => uri.path == prefix || uri.path.startsWith('$prefix/'));
  }

  static bool _isStartupRoute(String? route) =>
      route == null ||
      route.isEmpty ||
      route == '/' ||
      route == AppPages.SPLASH ||
      route == '/AuthCheckScreen';

  Future<void> _handle(Uri uri) async {
    final code = _referralCodeFrom(uri);
    if (code == null) {
      // /app, /reset-password, /verify-email: opening the app is the action.
      return;
    }

    if (await _isLoggedIn()) {
      CustomToastService.showInfo(
        message: TranslationUtils.tr('deeplink_referral_already_registered'),
      );
      return;
    }

    await Get.find<ReferralService>().save(
      code,
      source: ReferralSource.link,
      clickId: uri.queryParameters['click_id'],
    );
    if (Get.currentRoute != AppPages.CREATE_ACCOUNT) {
      Get.toNamed(AppPages.CREATE_ACCOUNT);
    }
  }

  /// `/ref/<code>` or `/register?ref=<code>`.
  static String? _referralCodeFrom(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? code;
    if (segments.length >= 2 && segments.first == 'ref') {
      code = segments[1];
    } else if (segments.isNotEmpty && segments.first == 'register') {
      code = uri.queryParameters['ref'] ?? uri.queryParameters['ref_code'];
    }
    return ReferralService.isValidCode(code) ? code!.trim() : null;
  }

  Future<void> _claimDeferredIfLoggedOut() async {
    if (await _isLoggedIn()) return;
    try {
      await Get.find<ReferralService>().claimDeferredOnce();
    } catch (e) {
      debugPrint('DeepLinkService: deferred claim failed: $e');
    }
  }

  static Future<bool> _isLoggedIn() async {
    if (Get.isRegistered<AuthController>() && Get.find<AuthController>().isAuthenticated) {
      return true;
    }
    final token = await SecureStorageService.getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
