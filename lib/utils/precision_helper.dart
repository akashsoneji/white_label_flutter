/// Utility class for handling floating point precision issues
/// This solves common problems like 0.019999999999999997 instead of 0.02
class PrecisionHelper {
  /// Round a double to specified decimal places
  ///
  /// [value] - The double value to round
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.round(0.019999999999999997, 2) returns 0.02
  /// PrecisionHelper.round(1.23456789, 3) returns 1.235
  static double round(double value, {int decimals = 2}) {
    // ✅ FIX: Guard against NaN / Infinity AND clamp decimals to a sane range
    // so the multiplier loop can't overflow to Infinity (which would then make
    // `value * multiplier` NaN and crash `.round()` with "Infinity or NaN toInt").
    if (value.isNaN || value.isInfinite) return 0.0;
    final int safeDecimals = decimals.clamp(0, 12);

    double multiplier = 1.0;
    for (int i = 0; i < safeDecimals; i++) {
      multiplier *= 10.0;
      if (multiplier.isInfinite) {
        // Overflow protection — bail out and return 0.0 instead of poisoning
        // downstream arithmetic with Infinity.
        return 0.0;
      }
    }

    final double scaled = value * multiplier;
    if (scaled.isNaN || scaled.isInfinite) return 0.0;
    return scaled.round() / multiplier;
  }

  /// Format a double for display with proper precision
  ///
  /// [value] - The double value to format
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.format(0.019999999999999997) returns "0.02"
  /// PrecisionHelper.format(1.0) returns "1.00"
  static String format(double value, {int decimals = 2}) {
    return round(value, decimals: decimals).toStringAsFixed(decimals);
  }

  /// Format volume for trading (usually 2 decimal places)
  ///
  /// [volume] - The volume value to format
  ///
  /// Example:
  /// PrecisionHelper.formatVolume(0.019999999999999997) returns "0.02"
  static String formatVolume(double volume) {
    return format(volume, decimals: 2);
  }

  /// Format price for trading (usually 2-5 decimal places based on instrument)
  ///
  /// [price] - The price value to format
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.formatPrice(3856.123456) returns "3856.12"
  static String formatPrice(double price, {int decimals = 5}) {
    return format(price, decimals: decimals);
  }

  /// Format percentage for display
  ///
  /// [value] - The percentage value to format
  /// [decimals] - Number of decimal places (default: 1)
  ///
  /// Example:
  /// PrecisionHelper.formatPercentage(50.123456) returns "50.1%"
  static String formatPercentage(double value, {int decimals = 1}) {
    return "${format(value, decimals: decimals)}%";
  }

  /// Format money for display
  ///
  /// [value] - The money value to format
  ///
  /// Example:
  /// PrecisionHelper.formatMoney(123.456) returns "123.46"
  static String formatMoney(double value) {
    return format(value, decimals: 2);
  }

  /// Format profit/loss for display
  ///
  /// [value] - The P&L value to format
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.formatPnL(-3.123456) returns "-3.12"
  static String formatPnL(double value, {int decimals = 2}) {
    return format(value, decimals: decimals);
  }

  /// Safe double parsing with precision fix
  ///
  /// [value] - The value to parse (String, double, or int)
  /// [decimals] - Number of decimal places to round to (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.parseDouble("0.019999999999999997") returns 0.02
  /// PrecisionHelper.parseDouble(1.23456789) returns 1.23
  static double parseDouble(dynamic value, {int decimals = 2}) {
    if (value == null) return 0.0;

    double parsedValue = 0.0;

    if (value is double) {
      parsedValue = value;
    } else if (value is int) {
      parsedValue = value.toDouble();
    } else if (value is String) {
      parsedValue = double.tryParse(value) ?? 0.0;
    }

    return round(parsedValue, decimals: decimals);
  }

  /// Calculate percentage with precision fix
  ///
  /// [part] - The part value
  /// [total] - The total value
  /// [decimals] - Number of decimal places (default: 1)
  ///
  /// Example:
  /// PrecisionHelper.calculatePercentage(0.02, 0.04) returns 50.0
  static double calculatePercentage(
    double part,
    double total, {
    int decimals = 1,
  }) {
    if (total == 0) return 0.0;
    return round((part / total) * 100, decimals: decimals);
  }

  /// Clamp value between min and max with precision fix
  ///
  /// [value] - The value to clamp
  /// [min] - Minimum value
  /// [max] - Maximum value
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.clamp(0.019999999999999997, 0.01, 1.0) returns 0.02
  static double clamp(
    double value,
    double min,
    double max, {
    int decimals = 2,
  }) {
    double clampedValue = value.clamp(min, max);
    return round(clampedValue, decimals: decimals);
  }

  /// Check if two doubles are equal within precision tolerance
  ///
  /// [a] - First value
  /// [b] - Second value
  /// [tolerance] - Tolerance for comparison (default: 0.001)
  ///
  /// Example:
  /// PrecisionHelper.isEqual(0.02, 0.019999999999999997) returns true
  static bool isEqual(double a, double b, {double tolerance = 0.001}) {
    return (a - b).abs() < tolerance;
  }

  /// Fix common floating point issues in calculations
  ///
  /// [value] - The value to fix
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Example:
  /// PrecisionHelper.fixFloatingPoint(0.1 + 0.2) returns 0.3 (instead of 0.30000000000000004)
  static double fixFloatingPoint(double value, {int decimals = 2}) {
    return round(value, decimals: decimals);
  }
}

/// Extension methods for easier usage
extension PrecisionExtension on double {
  /// Round this double to specified decimal places
  double toPrecision(int decimals) =>
      PrecisionHelper.round(this, decimals: decimals);

  /// Format this double for display
  String toFormattedString({int decimals = 2}) =>
      PrecisionHelper.format(this, decimals: decimals);

  /// Format this double as volume
  String toVolumeString() => PrecisionHelper.formatVolume(this);

  /// Format this double as price
  String toPriceString({int decimals = 2}) =>
      PrecisionHelper.formatPrice(this, decimals: decimals);

  /// Format this double as percentage
  String toPercentageString({int decimals = 1}) =>
      PrecisionHelper.formatPercentage(this, decimals: decimals);

  /// Format this double as P&L
  String toPnLString({int decimals = 2}) =>
      PrecisionHelper.formatPnL(this, decimals: decimals);

  /// Check if this double equals another within tolerance
  bool isEqualTo(double other, {double tolerance = 0.001}) =>
      PrecisionHelper.isEqual(this, other, tolerance: tolerance);
}
