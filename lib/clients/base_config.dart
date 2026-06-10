import 'package:flutter/material.dart';

/// Base configuration template for all clients
/// DO NOT USE DIRECTLY - extend this class in client-specific configs
class BaseClientConfig {
  // Branding
  final String brandName;
  final String appTitle;

  // Colors
  final Color primaryColor;
  final Color darkPrimaryColor;
  final Color secondaryColor;
  final Color accentColor;

  // Asset filenames copied from editable assets/brands/{client}/ into prepared
  // runtime assets/clients/{client}/ by scripts/prepare_flavor.dart.
  final String logoSvgPath;
  final String splashLogoPath;
  final String appIconPath;

  // URLs
  final String apiBaseUrl;
  final String websocketUrl;
  final String chartBaseUrl;

  const BaseClientConfig({
    required this.brandName,
    required this.appTitle,
    required this.primaryColor,
    Color? darkPrimaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.logoSvgPath,
    required this.splashLogoPath,
    required this.appIconPath,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.chartBaseUrl,
  }) : darkPrimaryColor = darkPrimaryColor ?? primaryColor;

  /// Get the full runtime asset path for a prepared client asset.
  String getAssetPath(String clientName, String assetPath) {
    return 'assets/clients/$clientName/$assetPath';
  }
}
