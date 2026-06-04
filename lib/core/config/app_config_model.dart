import 'package:flutter/material.dart';

class AppBrandingConfig {
  final String appName;
  final String appTitle;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? accentColor;
  final String? logoSvgPath;
  final String? splashLogoPath;

  const AppBrandingConfig({
    required this.appName,
    required this.appTitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.logoSvgPath,
    required this.splashLogoPath,
  });

  factory AppBrandingConfig.fromJson(Map<String, dynamic> json) {
    return AppBrandingConfig(
      appName: json['appName']?.toString() ?? '',
      appTitle: json['appTitle']?.toString() ?? '',
      primaryColor: _parseColor(json['primaryColor']),
      secondaryColor: _parseColor(json['secondaryColor']),
      accentColor: _parseColor(json['accentColor']),
      logoSvgPath: (json['logoSvgPath'] ?? '').toString().trim().isEmpty
          ? null
          : json['logoSvgPath'].toString().trim(),
      splashLogoPath: (json['splashLogoPath'] ?? '').toString().trim().isEmpty
          ? null
          : json['splashLogoPath'].toString().trim(),
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is int) return Color(value);
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    var hex = raw.replaceFirst('#', '').replaceFirst('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

class AppConfigModel {
  final AppBrandingConfig branding;
  final Map<String, bool> features;

  const AppConfigModel({required this.branding, required this.features});

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    final brandingRaw =
        json['branding'] is Map ? (json['branding'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final featuresRaw =
        json['features'] is Map ? (json['features'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    final features = <String, bool>{};
    for (final entry in featuresRaw.entries) {
      features[entry.key.toString()] = entry.value == true;
    }

    return AppConfigModel(
      branding: AppBrandingConfig.fromJson(brandingRaw),
      features: features,
    );
  }

  bool isFeatureEnabled(String key, {bool defaultValue = true}) {
    return features[key] ?? defaultValue;
  }
}

