/// Date utility helper for UTC timezone operations
/// Ensures all dates in the app use UTC as the default timezone
class DateHelper {
  /// Get current time in UTC
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  /// Parse a date string and ensure it's treated as UTC
  /// If the string doesn't have timezone info, it's assumed to be UTC
  static DateTime parseUtc(String dateString) {
    try {
      // If already in ISO format with Z, parse directly
      if (dateString.contains('Z')) {
        return DateTime.parse(dateString);
      }
      
      // If it has a space instead of T, replace it
      String sanitized = dateString;
      if (sanitized.contains(' ') && !sanitized.contains('T')) {
        sanitized = sanitized.replaceFirst(' ', 'T');
      }
      
      // If no timezone info, add Z to indicate UTC
      if (!sanitized.contains('Z') && !sanitized.contains('+') && !sanitized.contains('-', 10)) {
        sanitized = sanitized.endsWith('Z') ? sanitized : '${sanitized}Z';
      }
      
      final parsed = DateTime.parse(sanitized);
      // Ensure it's in UTC
      return parsed.isUtc ? parsed : parsed.toUtc();
    } catch (e) {
      // Fallback: try parsing as is and convert to UTC
      try {
        final parsed = DateTime.parse(dateString);
        return parsed.isUtc ? parsed : parsed.toUtc();
      } catch (_) {
        // If all parsing fails, return current UTC time
        return nowUtc();
      }
    }
  }

  /// Format a DateTime to UTC string in format: YYYY-MM-DD HH:MM:SS
  static String formatUtcDateTime(DateTime dateTime) {
    // Ensure the DateTime is in UTC
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    
    return '$year-$month-$day $hour:$minute:$second';
  }

  /// Format a DateTime to UTC string in format: YYYY.MM.DD HH:MM:SS
  static String formatUtcHistoryTimestamp(DateTime dateTime) {
    // Ensure the DateTime is in UTC
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    
    return '$year.$month.$day $hour:$minute:$second';
  }

  /// Format an ISO date string to UTC display format: YYYY-MM-DD HH:MM:SS
  static String formatIsoStringToUtc(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';
    
    try {
      final dateTime = parseUtc(trimmed);
      return formatUtcDateTime(dateTime);
    } catch (_) {
      // Fallback: try to clean up the string
      final fallback = trimmed
          .replaceAll('T', ' ')
          .replaceAll('Z', '')
          .split('+')
          .first
          .split('.')
          .first
          .trim();
      return fallback.isEmpty ? trimmed : fallback;
    }
  }

  /// Format an ISO date string to UTC history format: YYYY.MM.DD HH:MM:SS
  static String formatIsoStringToUtcHistory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';
    
    try {
      final dateTime = parseUtc(trimmed);
      return formatUtcHistoryTimestamp(dateTime);
    } catch (_) {
      // Fallback: try to clean up the string
      try {
        final fallback = trimmed
            .replaceAll('T', ' ')
            .replaceAll('Z', '')
            .replaceAll('-', '.')
            .split('+')
            .first
            .split('.')
            .take(4)
            .join('.')
            .trim();
        return fallback.isEmpty ? trimmed : fallback;
      } catch (_) {
        return trimmed;
      }
    }
  }
}

