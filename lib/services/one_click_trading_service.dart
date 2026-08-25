import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OneClickTradingService {
  static const String _oneClickTradingKey = 'one_click_trading_enabled';
  static OneClickTradingService? _instance;

  // Singleton pattern
  static OneClickTradingService get instance {
    _instance ??= OneClickTradingService._();
    return _instance!;
  }

  OneClickTradingService._();

  /// Broadcasts state changes so every screen showing a One-Click toggle
  /// (settings, chart, etc.) stays in sync without having to re-read
  /// SharedPreferences on every rebuild. Seeded lazily from prefs on the
  /// first read via [isOneClickTradingEnabled].
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  bool _seeded = false;

  // Get current One Click Trading state
  Future<bool> isOneClickTradingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_oneClickTradingKey) ?? true; // default enabled
      if (!_seeded || enabledNotifier.value != v) {
        enabledNotifier.value = v;
        _seeded = true;
      }
      return v;
    } catch (e) {
      print('Error getting One Click Trading state: $e');
      return enabledNotifier.value;
    }
  }

  // Set One Click Trading state
  Future<void> setOneClickTradingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_oneClickTradingKey, enabled);
      enabledNotifier.value = enabled;
      _seeded = true;
      print('One Click Trading ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      print('Error setting One Click Trading state: $e');
    }
  }

  // Clear One Click Trading preference (reset to default = true)
  Future<void> clearOneClickTradingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_oneClickTradingKey);
      enabledNotifier.value = true;
      _seeded = true;
      print('One Click Trading preference cleared');
    } catch (e) {
      print('Error clearing One Click Trading preference: $e');
    }
  }
}
