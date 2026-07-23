import 'package:country_picker/country_picker.dart';

class RiyadexCountry {
  final String iso2;
  final String countryId;
  final String name;
  final String? dialCode;
  final String tier;
  final String registration;
  final List<String> requiredFields;
  final List<String> optionalFields;

  RiyadexCountry({
    required this.iso2,
    required this.countryId,
    required this.name,
    this.dialCode,
    required this.tier,
    required this.registration,
    required this.requiredFields,
    required this.optionalFields,
  });

  factory RiyadexCountry.fromJson(Map<String, dynamic> json) {
    final iso = json['iso2'] as String? ?? '';
    String? finalDialCode = json['dial_code'] as String?;
    if (finalDialCode == null && iso.isNotEmpty) {
      try {
        final c = CountryService().findByCode(iso);
        if (c != null) finalDialCode = '+${c.phoneCode}';
      } catch (_) {}
    }
    
    return RiyadexCountry(
      iso2: iso,
      countryId: json['country_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dialCode: finalDialCode,
      tier: json['tier'] as String? ?? 'full',
      registration: json['registration'] as String? ?? 'open',
      requiredFields: (json['required_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      optionalFields: (json['optional_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class RiyadexGeoRule {
  final String blockedMessage;

  RiyadexGeoRule({required this.blockedMessage});

  factory RiyadexGeoRule.fromJson(Map<String, dynamic> json) {
    return RiyadexGeoRule(
      blockedMessage: json['blocked_message'] as String? ??
          'Sorry, our services are not available in this country.',
    );
  }
}

class RiyadexConfigData {
  final RiyadexGeoRule geoRule;

  RiyadexConfigData({required this.geoRule});

  factory RiyadexConfigData.fromJson(Map<String, dynamic> json) {
    final geoRuleJson = json['geo_rule'] as Map<String, dynamic>? ?? {};
    return RiyadexConfigData(
      geoRule: RiyadexGeoRule.fromJson(geoRuleJson),
    );
  }
}

class RiyadexCountriesResponse {
  final bool status;
  final RiyadexConfigData? config;
  final List<RiyadexCountry> countries;

  RiyadexCountriesResponse({
    required this.status,
    this.config,
    required this.countries,
  });

  factory RiyadexCountriesResponse.fromJson(Map<String, dynamic> json) {
    final configJson = json['config'] as Map<String, dynamic>?;
    final countriesList = json['countries'] as List<dynamic>? ?? [];

    return RiyadexCountriesResponse(
      status: json['status'] as bool? ?? false,
      config: configJson != null ? RiyadexConfigData.fromJson(configJson) : null,
      countries: countriesList
          .map((e) => RiyadexCountry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RiyadexGeoLocation {
  final String countryCode;
  final String countryName;

  RiyadexGeoLocation({
    required this.countryCode,
    required this.countryName,
  });

  factory RiyadexGeoLocation.fromJson(Map<String, dynamic> json) {
    return RiyadexGeoLocation(
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
    );
  }
}
