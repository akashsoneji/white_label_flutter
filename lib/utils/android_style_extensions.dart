import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

/// Extension methods to replicate Android functionality
extension AndroidStyleExtensions on String {
  /// Get decimal digits for price formatting (similar to Android getDecimalDigit)
  int getDecimalDigit() {
    if (isEmpty) return 5;
    final parts = split('.');
    return parts.length > 1 ? parts[1].length : 5;
  }

  /// Get pip value for price adjustments (similar to Android getPlusValue)
  double getPlusValue() {
    if (isEmpty) return 0.0001;
    final price = double.tryParse(this) ?? 0.0;

    // Determine pip value based on price range
    if (price >= 100) {
      return 0.01; // For prices >= 100 (like XAUUSD)
    } else if (price >= 10) {
      return 0.001; // For prices >= 10
    } else {
      return 0.0001; // For prices < 10 (like EURUSD)
    }
  }

  /// Get SL/TP pip value (similar to Android getSLTPPlusValue)
  double getSLTPPlusValue() {
    return getPlusValue();
  }

  /// Round off decimal places (similar to Android roundOffDecimal)
  String roundOffDecimal([int? decimals]) {
    final price = double.tryParse(this) ?? 0.0;
    final decimalPlaces = decimals ?? getDecimalDigit();

    return price.toStringAsFixed(decimalPlaces);
  }

  /// Remove suffix like .c (similar to Android removeSuffix)
  String removeSuffix() {
    return replaceAll('.c', '');
  }
}

/// Extension methods for UI state management (similar to Android makeVisible/makeGone)
extension VisibilityExtensions on Widget {
  Widget makeVisible() {
    return this;
  }

  Widget makeGone() {
    return SizedBox.shrink();
  }

  Widget makeInVisible() {
    return Opacity(opacity: 0.0, child: this);
  }
}

/// Extension methods for button state (similar to Android enableIt/disableIt)
extension ButtonStateExtensions on Widget {
  Widget enableIt() {
    return this;
  }

  Widget disableIt() {
    return Opacity(opacity: 0.5, child: AbsorbPointer(child: this));
  }
}

/// Extension methods for color changes (similar to Android changeColor)
extension ColorExtensions on Widget {
  Widget changeColor(Color color) {
    if (this is Container) {
      return Container(
        decoration: BoxDecoration(color: color),
        child: (this as Container).child,
      );
    }
    return this;
  }

  Widget changeTint(Color color) {
    if (this is Icon) {
      return Icon((this as Icon).icon, color: color, size: (this as Icon).size);
    }
    return this;
  }
}

/// Extension methods for text styling (similar to Android changeTypeFace)
extension TextStyleExtensions on Text {
  Text changeTypeFace(String fontFamily) {
    return Text(
      data ?? '',
      style:
          style?.copyWith(fontFamily: fontFamily) ??
          AppTextStyles.bodyText.copyWith(fontFamily: fontFamily),
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}

/// Utility class for Android-style operations
class AndroidStyleUtils {
  /// Show error toast (similar to Android errorToast)
  static void errorToast(BuildContext context, String message) {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showError(
        message: message,
      );
    }
  }

  /// Show success toast
  static void successToast(BuildContext context, String message) {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showSuccess(
        message: message,
      );
    }
  }

  /// Navigate to a route (similar to Android navigateTo)
  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  /// Get data from SharedPreferences (similar to Android getData)
  static String getData(String key, [String defaultValue = '']) {
    // This would integrate with your existing SharedPreferences implementation
    // For now, return default value
    return defaultValue;
  }

  /// Set data to SharedPreferences (similar to Android setData)
  static void setData(String key, String value) {
    // This would integrate with your existing SharedPreferences implementation
  }

  /// Deserialize JSON (similar to Android deserializeJson)
  static T deserializeJson<T>(String jsonString) {
    // This would integrate with your existing JSON serialization
    throw UnimplementedError('Implement JSON deserialization');
  }

  /// Track analytics (similar to Android trackAnalytics)
  static void trackAnalytics(BuildContext context, String screenName) {
    // This would integrate with your existing analytics implementation
    print('Analytics: Screen $screenName viewed');
  }
}

/// Constants similar to Android Constants class
class AndroidConstants {
  static const String webSocketToken = 'webSocketToken';
  static const String authKey = 'authKey';
  static const String activeMt5Balance = 'activeMt5Balance';
  static const String activeMt5Name = 'activeMt5Name';
  static const String activeMt5Leverage = 'activeMt5Leverage';
  static const String lastLotSize = 'lastLotSize';
  static const String scriptName = 'script_name';
  static const String CHART_URL = 'https://your-chart-url.com/';
}

/// Model classes similar to Android models
class PlaceOrderData {
  final String? orderNo;
  final String? tradeSymbol;
  final String? tradePrice;
  final String? lot;

  PlaceOrderData({this.orderNo, this.tradeSymbol, this.tradePrice, this.lot});

  factory PlaceOrderData.fromJson(Map<String, dynamic> json) {
    return PlaceOrderData(
      orderNo: json['order_no']?.toString(),
      tradeSymbol: json['trade_symbol']?.toString(),
      tradePrice: json['trade_price']?.toString(),
      lot: json['lot']?.toString(),
    );
  }
}

class BaseResponseNew {
  final String message;
  final bool status;
  final PlaceOrderData? data;

  BaseResponseNew({required this.message, required this.status, this.data});

  factory BaseResponseNew.fromJson(Map<String, dynamic> json) {
    return BaseResponseNew(
      message: json['message'] ?? '',
      status: json['status'] ?? false,
      data: json['data'] != null ? PlaceOrderData.fromJson(json['data']) : null,
    );
  }
}
