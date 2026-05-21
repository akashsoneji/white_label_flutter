class CrmSettingsModel {
  final CrmSettingsMeta? meta;
  final CrmSettingsCompany? company;
  final CrmAgreements agreements;
  final List<CrmDisclaimer> disclaimers;
  final CrmMobileAppDetails? mobileAppDetails;

  const CrmSettingsModel({
    this.meta,
    this.company,
    required this.agreements,
    this.disclaimers = const [],
    this.mobileAppDetails,
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

  const CrmMobileAppDetails({
    this.appName = '',
    this.appVersion = '',
    this.isUnderMaintenance = false,
    this.isForceUpdate = false,
    this.updateUrlIos = '',
    this.updateUrlAndroid = '',
  });

  factory CrmMobileAppDetails.fromJson(Map<String, dynamic> json) {
    return CrmMobileAppDetails(
      appName: json['app_name']?.toString() ?? '',
      appVersion: json['app_version']?.toString() ?? '',
      isUnderMaintenance: json['is_under_maintenance'] == true,
      isForceUpdate: json['is_force_update'] == true,
      updateUrlIos: json['update_url_ios']?.toString() ?? '',
      updateUrlAndroid: json['update_url_android']?.toString() ?? '',
    );
  }
}
