import 'package:flutter/material.dart';
import '../base_config.dart';

/// Tenax client configuration
class TenaxConfig extends BaseClientConfig {
  const TenaxConfig()
    : super(
        brandName: 'Tenax',
        appTitle: 'Tenax Code',
        primaryColor: const Color(0xFF4A0C54),
        secondaryColor: const Color(0xFFE8F5E8),
        accentColor: const Color(0xFF4A0C54),
        logoSvgPath: 'logo.svg',
        splashLogoPath: 'splash_logo.svg',
        appIconPath: 'app_icon.png',
        apiBaseUrl: 'https://demo.tenaxcode.com/api/',
        websocketUrl: 'wss://demo.tenaxcode.com/trade-engine',
        chartBaseUrl: 'https://demo.tenaxcode.com',
      );
}
