/// Status of a chart trading notification
enum NotificationStatus {
  loading, // API call in progress
  success, // API call succeeded
  error, // API call failed
}

/// Model representing a trading notification on the chart screen
class ChartNotification {
  final String id;
  final String symbol;
  final String type; // "buy" or "sell"
  final double volume;
  final NotificationStatus status;
  final DateTime timestamp;
  final String? errorMessage; // Error message if status is error

  ChartNotification({
    required this.id,
    required this.symbol,
    required this.type,
    required this.volume,
    required this.status,
    DateTime? timestamp,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy of this notification with updated status
  ChartNotification copyWith({
    String? id,
    String? symbol,
    String? type,
    double? volume,
    NotificationStatus? status,
    DateTime? timestamp,
    String? errorMessage,
  }) {
    return ChartNotification(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      volume: volume ?? this.volume,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'ChartNotification(id: $id, symbol: $symbol, type: $type, volume: $volume, status: $status)';
  }
}
