import 'package:flutter/material.dart';

import '../base_config.dart';

/// Vantage client configuration.
class VantageConfig extends BaseClientConfig {
  const VantageConfig()
    : super(
        brandName: 'Vantage',
        appTitle: 'Vantage',
        // Match auth UI + Android vantage flavor (blue primary + light background).
        primaryColor: const Color(0xFF124CE7),
        secondaryColor: const Color(0xFFEFF2FA),
        accentColor: const Color(0xFF124CE7),
        logoSvgPath: 'logo.svg',
        splashLogoPath: 'splash_logo.svg',
        appIconPath: 'app_icon.png',
        // Keep same APIs (per requirement) unless overridden later.
        apiBaseUrl: 'https://demo.tenaxcode.com/api/',
        websocketUrl: 'wss://demo.tenaxcode.com/trade-engine',
        chartBaseUrl: 'https://demo.tenaxcode.com',
      );
}
