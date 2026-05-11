import 'package:flutter/material.dart';

/// Base configuration template for all clients
/// DO NOT USE DIRECTLY - extend this class in client-specific configs
class BaseClientConfig {
  // Branding
  final String brandName;
  final String appTitle;

  // Colors
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  // Asset paths (relative to clients/{client}/assets/)
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
    required this.secondaryColor,
    required this.accentColor,
    required this.logoSvgPath,
    required this.splashLogoPath,
    required this.appIconPath,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.chartBaseUrl,
  });

  /// Get the full asset path for a client asset
  String getAssetPath(String clientName, String assetPath) {
    return 'assets/clients/$clientName/$assetPath';
  }
}
