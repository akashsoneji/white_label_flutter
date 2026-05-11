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

  // Get current One Click Trading state
  Future<bool> isOneClickTradingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_oneClickTradingKey) ?? true; // Default to enabled
    } catch (e) {
      print('Error getting One Click Trading state: $e');
      return true; // Default to enabled on error
    }
  }

  // Set One Click Trading state
  Future<void> setOneClickTradingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_oneClickTradingKey, enabled);
      print('One Click Trading ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      print('Error setting One Click Trading state: $e');
    }
  }

  // Clear One Click Trading preference (reset to false)
  Future<void> clearOneClickTradingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_oneClickTradingKey);
      print('One Click Trading preference cleared');
    } catch (e) {
      print('Error clearing One Click Trading preference: $e');
    }
  }
}
