class CrmSettingsModel {
  final CrmSettingsMeta? meta;
  final CrmSettingsCompany? company;
  final CrmAgreements agreements;
  final List<CrmDisclaimer> disclaimers;
  final CrmMobileAppDetails? mobileAppDetails;
  final CrmFinancialSettings financialSettings;
  final CrmTradingSettings tradingSettings;
  final bool allowDuplicateMobileRegistration;

  const CrmSettingsModel({
    this.meta,
    this.company,
    required this.agreements,
    this.disclaimers = const [],
    this.mobileAppDetails,
    this.financialSettings = const CrmFinancialSettings(),
    this.tradingSettings = const CrmTradingSettings(),
    this.allowDuplicateMobileRegistration = false,
  });

  factory CrmSettingsModel.fromJson(Map<String, dynamic> json) {
    final agreementsJson =
        json['agreements'] is Map
            ? Map<String, dynamic>.from(json['agreements'] as Map)
            : <String, dynamic>{};

    return CrmSettingsModel(
      meta:
          json['meta'] is Map
              ? CrmSettingsMeta.fromJson(
                Map<String, dynamic>.from(json['meta'] as Map),
              )
              : null,
      company:
          json['company'] is Map
              ? CrmSettingsCompany.fromJson(
                Map<String, dynamic>.from(json['company'] as Map),
              )
              : null,
      agreements: CrmAgreements.fromJson(agreementsJson),
      disclaimers:
          (json['disclaimers'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => CrmDisclaimer.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      mobileAppDetails:
          json['mobile_app_details'] is Map
              ? CrmMobileAppDetails.fromJson(
                Map<String, dynamic>.from(json['mobile_app_details'] as Map),
              )
              : null,
      financialSettings:
          json['financial_settings'] is Map
              ? CrmFinancialSettings.fromJson(
                Map<String, dynamic>.from(json['financial_settings'] as Map),
              )
              : const CrmFinancialSettings(),
      tradingSettings:
          json['trading_settings'] is Map
              ? CrmTradingSettings.fromJson(
                Map<String, dynamic>.from(json['trading_settings'] as Map),
              )
              : const CrmTradingSettings(),
      allowDuplicateMobileRegistration:
          json['registration_settings'] is Map &&
          (json['registration_settings']
                  as Map)['allow_duplicate_mobile_registration'] ==
              true,
    );
  }
}

/// Admin "Trading Settings". `web_trading_url_mode == "app"` means the app's
/// own terminal; any other mode opens `web_trading_custom_url`.
class CrmTradingSettings {
  final String mt5ServerTimezone;
  final bool webTradingEnabled;
  final String webTradingUrlMode;
  final String webTradingCustomUrl;

  const CrmTradingSettings({
    this.mt5ServerTimezone = 'UTC',
    this.webTradingEnabled = true,
    this.webTradingUrlMode = 'app',
    this.webTradingCustomUrl = '',
  });

  bool get usesInAppTerminal => webTradingUrlMode == 'app';

  factory CrmTradingSettings.fromJson(Map<String, dynamic> json) {
    final timezone = json['mt5_server_timezone']?.toString().trim() ?? '';
    final mode = json['web_trading_url_mode']?.toString().trim() ?? '';
    return CrmTradingSettings(
      mt5ServerTimezone: timezone.isEmpty ? 'UTC' : timezone,
      // Missing key keeps trading visible; only an explicit false hides it.
      webTradingEnabled: json['web_trading_enabled'] != false,
      webTradingUrlMode: mode.isEmpty ? 'app' : mode,
      webTradingCustomUrl:
          json['web_trading_custom_url']?.toString().trim() ?? '',
    );
  }
}

/// Admin "Financial Settings" switches. They only drive the UI; the backend
/// re-checks every rule. Missing keys default to `false`.
class CrmFinancialSettings {
  final bool internalTransferOtpRequired;
  final bool depositCreditToWalletOnly;
  final bool withdrawalDeductFromWalletOnly;
  final bool internalTransferApprovalRequired;
  final bool ibCommissionToWalletTransferEnabled;

  const CrmFinancialSettings({
    this.internalTransferOtpRequired = false,
    this.depositCreditToWalletOnly = false,
    this.withdrawalDeductFromWalletOnly = false,
    this.internalTransferApprovalRequired = false,
    this.ibCommissionToWalletTransferEnabled = false,
  });

  factory CrmFinancialSettings.fromJson(Map<String, dynamic> json) {
    return CrmFinancialSettings(
      internalTransferOtpRequired:
          json['internal_transfer_otp_required'] == true,
      depositCreditToWalletOnly: json['deposit_credit_to_wallet_only'] == true,
      withdrawalDeductFromWalletOnly:
          json['withdrawal_deduct_from_wallet_only'] == true,
      internalTransferApprovalRequired:
          json['internal_transfer_approval_required'] == true,
      ibCommissionToWalletTransferEnabled:
          json['ib_commission_to_wallet_transfer_enabled'] == true,
    );
  }
}

class CrmSettingsMeta {
  final String? crmSettingsPublicUrl;
  final String? mobileAppDetailsPublicUrl;

  const CrmSettingsMeta({this.crmSettingsPublicUrl, this.mobileAppDetailsPublicUrl});

  factory CrmSettingsMeta.fromJson(Map<String, dynamic> json) {
    return CrmSettingsMeta(
      crmSettingsPublicUrl: json['crm_settings_public_url']?.toString(),
      mobileAppDetailsPublicUrl: json['mobile_app_details_public_url']?.toString(),
    );
  }
}

class CrmSettingsCompany {
  final String name;
  final String email;
  final String phone;
  final String supportEmail;
  final String supportPhone;
  final String supportWhatsapp;
  final String copyright;

  const CrmSettingsCompany({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.supportWhatsapp = '',
    this.copyright = '',
  });

  factory CrmSettingsCompany.fromJson(Map<String, dynamic> json) {
    return CrmSettingsCompany(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      supportEmail: json['support_email']?.toString() ?? '',
      supportPhone: json['support_phone']?.toString() ?? '',
      supportWhatsapp: json['support_whatsapp']?.toString() ?? '',
      copyright: json['copyright']?.toString() ?? '',
    );
  }
}

class CrmAgreements {
  final CrmAgreementItem ibTerms;
  final CrmAgreementItem termsConditions;
  final CrmAgreementItem privacyPolicy;

  const CrmAgreements({
    required this.ibTerms,
    required this.termsConditions,
    required this.privacyPolicy,
  });

  factory CrmAgreements.fromJson(Map<String, dynamic> json) {
    return CrmAgreements(
      ibTerms: CrmAgreementItem.fromJson(
        json['ib_terms'] is Map
            ? Map<String, dynamic>.from(json['ib_terms'] as Map)
            : const {},
        fallbackKey: 'ib_terms',
        fallbackLabel: 'IB Terms and Conditions',
      ),
      termsConditions: CrmAgreementItem.fromJson(
        json['terms_conditions'] is Map
            ? Map<String, dynamic>.from(json['terms_conditions'] as Map)
            : const {},
        fallbackKey: 'terms_conditions',
        fallbackLabel: 'Terms & Conditions',
      ),
      privacyPolicy: CrmAgreementItem.fromJson(
        json['privacy_policy'] is Map
            ? Map<String, dynamic>.from(json['privacy_policy'] as Map)
            : const {},
        fallbackKey: 'privacy_policy',
        fallbackLabel: 'Privacy Policy',
      ),
    );
  }

  CrmAgreementItem? byKey(String key) {
    switch (key) {
      case 'ib_terms':
        return ibTerms;
      case 'terms_conditions':
        return termsConditions;
      case 'privacy_policy':
        return privacyPolicy;
      default:
        return null;
    }
  }
}

class CrmAgreementItem {
  final String key;
  final String label;
  final String type;
  final String url;
  final bool available;

  const CrmAgreementItem({
    required this.key,
    required this.label,
    this.type = '',
    this.url = '',
    this.available = false,
  });

  factory CrmAgreementItem.fromJson(
    Map<String, dynamic> json, {
    required String fallbackKey,
    required String fallbackLabel,
  }) {
    return CrmAgreementItem(
      key: json['key']?.toString() ?? fallbackKey,
      label: json['label']?.toString() ?? fallbackLabel,
      type: json['type']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      available: json['available'] == true,
    );
  }

  bool get hasUrl => url.trim().isNotEmpty;

  bool get canOpen => available && hasUrl;
}

class CrmDisclaimer {
  final String key;
  final String text;

  const CrmDisclaimer({required this.key, required this.text});

  factory CrmDisclaimer.fromJson(Map<String, dynamic> json) {
    return CrmDisclaimer(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

class CrmMobileAppDetails {
  final String appName;
  final String appVersion;
  final bool isUnderMaintenance;
  final bool isForceUpdate;
  final String updateUrlIos;
  final String updateUrlAndroid;
  final String laterDate;
  final String releaseNotes;
  final List<CrmPlatformItem> platforms;

  const CrmMobileAppDetails({
    this.appName = '',
    this.appVersion = '',
    this.isUnderMaintenance = false,
    this.isForceUpdate = false,
    this.updateUrlIos = '',
    this.updateUrlAndroid = '',
    this.laterDate = '',
    this.releaseNotes = '',
    this.platforms = const [],
  });

  /// Platforms with a link, in admin `sort_order`.
  List<CrmPlatformItem> get visiblePlatforms {
    final items = platforms.where((p) => p.url.isNotEmpty).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  factory CrmMobileAppDetails.fromJson(Map<String, dynamic> json) {
    return CrmMobileAppDetails(
      appName: json['app_name']?.toString() ?? '',
      appVersion: json['app_version']?.toString() ?? '',
      isUnderMaintenance: json['is_under_maintenance'] == true,
      isForceUpdate: json['is_force_update'] == true,
      updateUrlIos: json['update_url_ios']?.toString() ?? '',
      updateUrlAndroid: json['update_url_android']?.toString() ?? '',
      laterDate: json['later_date']?.toString().trim() ?? '',
      releaseNotes: json['release_notes']?.toString().trim() ?? '',
      platforms:
          (json['platforms'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => CrmPlatformItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
    );
  }
}

class CrmPlatformItem {
  final String slug;
  final String name;
  final String description;
  final String imageUrl;
  final String url;
  final int sortOrder;

  const CrmPlatformItem({
    this.slug = '',
    this.name = '',
    this.description = '',
    this.imageUrl = '',
    this.url = '',
    this.sortOrder = 0,
  });

  factory CrmPlatformItem.fromJson(Map<String, dynamic> json) {
    final order = json['sort_order'];
    return CrmPlatformItem(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString().trim() ?? '',
      url: json['url']?.toString().trim() ?? '',
      sortOrder: order is num ? order.toInt() : int.tryParse('$order') ?? 0,
    );
  }
}
