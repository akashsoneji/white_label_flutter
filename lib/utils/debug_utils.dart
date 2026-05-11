import 'package:flutter/foundation.dart';

class DebugUtils {
  static void log(String message) {
    if (kDebugMode) {
      print('DEBUG: $message');
    }
  }

  static void logError(String message) {
    if (kDebugMode) {
      print('ERROR: $message');
    }
  }

  static void logInfo(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }
  }
}
