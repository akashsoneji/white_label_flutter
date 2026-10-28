/// `GET user/app-settings`. Most switches arrive as the strings "0" / "1";
/// only "1" (or a real `true`) counts as ON.
///
/// Force update is NOT read from here: `crm-settings.mobile_app_details` is
/// the source of truth (the backend mirrors it into the legacy
/// `android_force_update` / `ios_force_update` keys for old app builds).
/// Web-only keys (`install_banner`, `app_link`, `windows_url`, ...) are
/// intentionally not parsed.
class AppSettingsModel {
  final String supportWhatsapp;
  final String supportPhone;
  final String supportEmail;
  final bool forceKycBeforeAccess;
  final bool demoContestMenuInsidePromotion;
  final String demoContestMenuLabel;
  final MaintenanceFlag portalMaintenance;
  final MaintenanceFlag depositMaintenance;
  final MaintenanceFlag withdrawalMaintenance;
  final MaintenanceFlag registrationMaintenance;
  final MaintenanceFlag ibWithdrawalMaintenance;
  final bool mobileOtpEnabled;
  final OtpPolicy otpPolicy;
  final ReverbSettings reverb;

  const AppSettingsModel({
    this.supportWhatsapp = '',
    this.supportPhone = '',
    this.supportEmail = '',
    this.forceKycBeforeAccess = false,
    this.demoContestMenuInsidePromotion = false,
    this.demoContestMenuLabel = '',
    this.portalMaintenance = MaintenanceFlag.off,
    this.depositMaintenance = MaintenanceFlag.off,
    this.withdrawalMaintenance = MaintenanceFlag.off,
    this.registrationMaintenance = MaintenanceFlag.off,
    this.ibWithdrawalMaintenance = MaintenanceFlag.off,
    this.mobileOtpEnabled = false,
    this.otpPolicy = const OtpPolicy(),
    this.reverb = const ReverbSettings(),
  });

  /// Mobile OTP may be offered only when both the global switch and the
  /// policy say a mobile channel exists.
  bool get isMobileOtpAvailable =>
      mobileOtpEnabled && otpPolicy.mobileAvailable;

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    MaintenanceFlag flag(String prefix) => MaintenanceFlag(
      isOn: isSettingOn(json['${prefix}_maintenance_mode']),
      message: _text(json['${prefix}_maintenance_message']),
    );

    return AppSettingsModel(
      supportWhatsapp: _text(json['support_whatsapp']),
      supportPhone: _text(json['support_phone']),
      supportEmail: _text(json['support_email']),
      forceKycBeforeAccess: isSettingOn(json['force_kyc_before_access']),
      demoContestMenuInsidePromotion: isSettingOn(
        json['demo_contest_menu_inside_promotion'],
      ),
      demoContestMenuLabel: _text(json['demo_contest_menu_label']),
      portalMaintenance: flag('portal'),
      depositMaintenance: flag('deposit'),
      withdrawalMaintenance: flag('withdrawal'),
      registrationMaintenance: flag('registration'),
      ibWithdrawalMaintenance: flag('ib_withdrawal'),
      mobileOtpEnabled: isSettingOn(json['mobile_otp_enabled']),
      otpPolicy: OtpPolicy.fromJson(_map(json['otp_policy'])),
      reverb: ReverbSettings.fromJson(_map(json['reverb'])),
    );
  }

  static const AppSettingsModel empty = AppSettingsModel();
}

/// "1" / true / 1 → ON. Everything else ("0", "", null, "true"-less) → OFF.
bool isSettingOn(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  if (value is String) return value.trim() == '1';
  return false;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class MaintenanceFlag {
  final bool isOn;
  final String message;

  const MaintenanceFlag({required this.isOn, this.message = ''});

  static const MaintenanceFlag off = MaintenanceFlag(isOn: false);
}

/// Where each action's OTP goes. Actions: registration, withdrawal,
/// internal_transfer, trader_transfer, mobile_change.
class OtpPolicy {
  final bool mobileAvailable;
  final bool kycRequireMobileVerified;
  final Map<String, OtpPolicyPoint> points;

  const OtpPolicy({
    this.mobileAvailable = false,
    this.kycRequireMobileVerified = false,
    this.points = const {},
  });

  OtpPolicyPoint pointFor(String action) =>
      points[action] ?? const OtpPolicyPoint();

  factory OtpPolicy.fromJson(Map<String, dynamic> json) {
    final rawPoints = _map(json['points']);
    return OtpPolicy(
      mobileAvailable: isSettingOn(json['mobile_available']),
      kycRequireMobileVerified: isSettingOn(
        json['kyc_require_mobile_verified'],
      ),
      points: {
        for (final entry in rawPoints.entries)
          entry.key: OtpPolicyPoint.fromJson(_map(entry.value)),
      },
    );
  }
}

class OtpPolicyPoint {
  final bool mobile;

  /// `email` or `mobile`.
  final String primary;

  const OtpPolicyPoint({this.mobile = false, this.primary = 'email'});

  factory OtpPolicyPoint.fromJson(Map<String, dynamic> json) {
    final primary = _text(json['primary']);
    return OtpPolicyPoint(
      mobile: isSettingOn(json['mobile']),
      primary: primary.isEmpty ? 'email' : primary,
    );
  }
}

/// Laravel Reverb (Pusher protocol) connection settings. Parsed only; the
/// app does not open this socket yet (needs a Pusher client SDK and the
/// token-based private-channel auth endpoint confirmed by the backend).
class ReverbSettings {
  final bool enabled;
  final String key;
  final String host;
  final int port;
  final String scheme;

  const ReverbSettings({
    this.enabled = false,
    this.key = '',
    this.host = '',
    this.port = 443,
    this.scheme = 'https',
  });

  bool get isUsable => enabled && key.isNotEmpty && host.isNotEmpty;

  factory ReverbSettings.fromJson(Map<String, dynamic> json) {
    final port = json['port'];
    return ReverbSettings(
      enabled: isSettingOn(json['enabled']),
      key: _text(json['key']),
      host: _text(json['host']),
      port: port is num ? port.toInt() : int.tryParse('$port') ?? 443,
      scheme: _text(json['scheme']).isEmpty ? 'https' : _text(json['scheme']),
    );
  }
}
