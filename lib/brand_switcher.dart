import 'package:flutter/material.dart';
import 'flavor_config.dart';

/// Brand Switcher Utility
/// This class provides easy methods to switch between different brands
/// and get their configurations.
class BrandSwitcher {
  /// Tenax-only: ensure Tenax config is active.
  static void switchToTenax() {
    FlavorConfig.tenax;
    debugPrint('🎨 Switched to Tenax brand');
    debugPrint('   Primary Color: ${FlavorConfig.instance.primaryColor}');
    debugPrint('   App Name: ${FlavorConfig.instance.appName}');
  }

  /// Get current brand info
  static void printCurrentBrand() {
    debugPrint('🎯 Current Brand: ${FlavorConfig.instance.appName}');
    debugPrint('   Primary Color: ${FlavorConfig.instance.primaryColor}');
    debugPrint('   Secondary Color: ${FlavorConfig.instance.secondaryColor}');
    debugPrint('   Accent Color: ${FlavorConfig.instance.accentColor}');
    debugPrint('   App Title: ${FlavorConfig.instance.appTitle}');
  }

  static bool get isTenax => FlavorConfig.instance.flavor == Flavor.tenax;

  /// Get current brand name
  static String get currentBrandName => FlavorConfig.instance.appName;

  /// Get current brand color
  static Color get currentBrandColor => FlavorConfig.instance.primaryColor;

  /// Get all brand colors for current brand
  static Map<String, Color> get currentBrandColors => {
    'primary': FlavorConfig.instance.primaryColor,
    'secondary': FlavorConfig.instance.secondaryColor,
    'accent': FlavorConfig.instance.accentColor,
  };

  /// Quick brand switching with hot reload
  static void quickSwitchBrand() {
    switchToTenax();
    debugPrint('🔄 Tenax-only: brand switch is a no-op');
  }
}
