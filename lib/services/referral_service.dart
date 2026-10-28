import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/api_service.dart';

/// How a referral code reached the app. Values match `referral_source` in
/// docs/DEEP_LINKING_BACKEND_SPEC.md §8.
enum ReferralSource { link, playReferrer, serverMatch }

extension on ReferralSource {
  String get apiValue => switch (this) {
        ReferralSource.link => 'link',
        ReferralSource.playReferrer => 'play_referrer',
        ReferralSource.serverMatch => 'server_match',
      };
}

class PendingReferral {
  final String code;
  final String source;
  final String? clickId;
  final DateTime savedAt;

  const PendingReferral({
    required this.code,
    required this.source,
    required this.savedAt,
    this.clickId,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'source': source,
        'click_id': clickId,
        'saved_at': savedAt.toIso8601String(),
      };

  static PendingReferral? fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    final savedAt = DateTime.tryParse(json['saved_at'] as String? ?? '');
    if (code == null || savedAt == null) return null;
    return PendingReferral(
      code: code,
      source: json['source'] as String? ?? 'link',
      clickId: json['click_id'] as String?,
      savedAt: savedAt,
    );
  }
}

/// Holds the referral code that came from a deep link, the Play install
/// referrer or the deferred server match, until registration consumes it.
/// A no-op for flavors without deep linking.
class ReferralService extends GetxService {
  static const MethodChannel _channel = MethodChannel('app/deeplink');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'deeplink_pending_referral';
  static const String _claimAttemptedKey = 'deeplink_deferred_claim_attempted';
  static const Duration _expiry = Duration(days: 30);
  static final RegExp _validCode = RegExp(r'^[A-Za-z0-9_-]{1,30}$');

  /// The pending referral, or null. Screens listen to it so a link opened
  /// while the register screen is visible still fills the field.
  final Rxn<PendingReferral> pending = Rxn<PendingReferral>();

  Future<ReferralService> init() async {
    if (!FlavorConfig.instance.isDeepLinkEnabled) return this;
    pending.value = await _load();
    return this;
  }

  static bool isValidCode(String? code) =>
      code != null && _validCode.hasMatch(code.trim());

  Future<void> save(
    String code, {
    required ReferralSource source,
    String? clickId,
  }) async {
    if (!isValidCode(code)) return;
    final referral = PendingReferral(
      code: code.trim(),
      source: source.apiValue,
      clickId: (clickId != null && clickId.length <= 64) ? clickId : null,
      savedAt: DateTime.now(),
    );
    pending.value = referral;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(referral.toJson()));
    } catch (e) {
      debugPrint('ReferralService: could not persist referral: $e');
    }
  }

  /// Call after registration succeeds so the code is not reused.
  Future<void> clear() async {
    pending.value = null;
    try {
      await _storage.delete(key: _storageKey);
    } catch (e) {
      debugPrint('ReferralService: could not clear referral: $e');
    }
  }

  /// Extra registration fields from spec §8; empty when the code in the form
  /// is not the one this service supplied (the user typed their own).
  Map<String, dynamic> registrationFieldsFor(String enteredCode) {
    final referral = pending.value;
    if (referral == null || referral.code != enteredCode.trim()) return const {};
    return {
      'referral_source': referral.source,
      if (referral.clickId != null) 'referral_click_id': referral.clickId,
    };
  }

  /// First launch after install only: recover a referral from the Play
  /// install referrer (Android) or the backend's deferred match. Runs once
  /// per install and only when no referral is known yet.
  Future<void> claimDeferredOnce() async {
    if (!FlavorConfig.instance.isDeepLinkEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_claimAttemptedKey) ?? false) return;
    await prefs.setBool(_claimAttemptedKey, true);
    if (pending.value != null) return;

    if (await _claimFromInstallReferrer()) return;
    await _claimFromServer();
  }

  Future<bool> _claimFromInstallReferrer() async {
    try {
      final raw = await _channel.invokeMethod<String>('getInstallReferrer');
      if (raw == null || raw.isEmpty) return false;
      final params = Uri.splitQueryString(raw);
      final code = params['ref_code'];
      if (!isValidCode(code)) return false;
      await save(code!, source: ReferralSource.playReferrer, clickId: params['click_id']);
      await _reportAttribution(code, params['click_id'], ReferralSource.playReferrer);
      return true;
    } on PlatformException catch (e) {
      debugPrint('ReferralService: install referrer unavailable: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _claimFromServer() async {
    Map<String, dynamic> device = const {};
    try {
      device = Map<String, dynamic>.from(
        await _channel.invokeMethod<Map<Object?, Object?>>('getDeviceInfo') ?? const {},
      );
    } on PlatformException catch (e) {
      debugPrint('ReferralService: device info unavailable: $e');
    } on MissingPluginException {
      return;
    }

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final ratio = view.devicePixelRatio;
    final response = await ApiService.post(
      endpoint: ApiConstants.deepLinkDeferredClaim,
      data: {
        'brand': FlavorConfig.instance.flavor.name,
        'platform': device['platform'] ?? defaultTargetPlatform.name,
        'os_version': device['osVersion'],
        'device_model': device['model'],
        'language': device['language'],
        'timezone': device['timezone'],
        'screen_w': (view.physicalSize.width / ratio).round(),
        'screen_h': (view.physicalSize.height / ratio).round(),
        'pixel_ratio': ratio,
      },
    );
    if (!response.success || response.data is! Map) return;
    final data = response.data as Map;
    final code = data['code'] as String?;
    if (!isValidCode(code)) return;
    await save(code!, source: ReferralSource.serverMatch, clickId: data['click_id'] as String?);
  }

  Future<void> _reportAttribution(String code, String? clickId, ReferralSource source) async {
    if (clickId == null) return;
    await ApiService.post(
      endpoint: ApiConstants.deepLinkAttribution,
      data: {
        'brand': FlavorConfig.instance.flavor.name,
        'click_id': clickId,
        'code': code,
        'source': source.apiValue,
      },
    );
  }

  Future<PendingReferral?> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return null;
      final referral = PendingReferral.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (referral == null || DateTime.now().difference(referral.savedAt) > _expiry) {
        await _storage.delete(key: _storageKey);
        return null;
      }
      return referral;
    } catch (e) {
      debugPrint('ReferralService: could not read referral: $e');
      return null;
    }
  }
}
