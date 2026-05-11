/// Type of notification (for styling)
enum NotificationType {
  success,
  error,
  info,
  warning,
  loading,
}

/// Status of a notification
enum NotificationStatus {
  loading, // API call in progress
  success, // API call succeeded
  error, // API call failed
}

/// Model representing an app-wide notification
/// Supports both trading notifications and generic messages
class AppNotification {
  final String id;
  final NotificationType type;
  final NotificationStatus status;
  final DateTime timestamp;
  
  // Generic message fields
  final String? title;
  final String? message;
  
  // Trading-specific fields (for chart screen compatibility)
  final String? symbol;
  final String? tradeType; // "buy" or "sell"
  final double? volume;
  
  // Error message if status is error
  final String? errorMessage;

  AppNotification({
    required this.id,
    required this.type,
    required this.status,
    DateTime? timestamp,
    this.title,
    this.message,
    this.symbol,
    this.tradeType,
    this.volume,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a generic message notification
  factory AppNotification.generic({
    required String id,
    required NotificationType type,
    required NotificationStatus status,
    String? title,
    required String message,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id,
      type: type,
      status: status,
      title: title,
      message: message,
      errorMessage: errorMessage,
      timestamp: timestamp,
    );
  }

  /// Create a trading notification (for chart screen compatibility)
  factory AppNotification.trading({
    required String id,
    required String symbol,
    required String tradeType,
    required double volume,
    required NotificationStatus status,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id,
      type: NotificationType.info, // Trading notifications default to info
      status: status,
      symbol: symbol,
      tradeType: tradeType,
      volume: volume,
      errorMessage: errorMessage,
      timestamp: timestamp,
    );
  }

  /// Check if this is a trading notification
  bool get isTradingNotification => symbol != null && tradeType != null && volume != null;

  /// Check if this is a generic message notification
  bool get isGenericNotification => message != null;

  /// Create a copy of this notification with updated fields
  AppNotification copyWith({
    String? id,
    NotificationType? type,
    NotificationStatus? status,
    DateTime? timestamp,
    String? title,
    String? message,
    String? symbol,
    String? tradeType,
    double? volume,
    String? errorMessage,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      message: message ?? this.message,
      symbol: symbol ?? this.symbol,
      tradeType: tradeType ?? this.tradeType,
      volume: volume ?? this.volume,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    if (isTradingNotification) {
      return 'AppNotification(id: $id, type: $type, status: $status, symbol: $symbol, tradeType: $tradeType, volume: $volume)';
    } else {
      return 'AppNotification(id: $id, type: $type, status: $status, title: $title, message: $message)';
    }
  }
}

