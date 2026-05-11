import 'dart:async';
import 'package:crm_app/screens/trading/view_models/chart_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/services/audio_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:get/get.dart';

/// Model for trade request in the queue
class TradeRequest {
  final String type; // "buy" or "1" (sell)
  final String symbol;
  final double volume;
  final String mt5Account;
  final DateTime timestamp;
  final String? notificationId; // ID for chart screen notifications
  final void Function(
    String notificationId,
    String symbol,
    String type,
    double volume,
    bool isSuccess,
    String? errorMessage,
  )?
  onTradeComplete; // Callback for chart screen

  TradeRequest({
    required this.type,
    required this.symbol,
    required this.volume,
    required this.mt5Account,
    DateTime? timestamp,
    this.notificationId,
    this.onTradeComplete,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'TradeRequest(type: $type, symbol: $symbol, volume: $volume, timestamp: ${timestamp.toIso8601String()})';
  }
}

/// Service to manage queue of trade requests for one-click trading
/// Processes trades sequentially in the background without blocking UI
class OneClickTradingQueueService {
  static OneClickTradingQueueService? _instance;
  static OneClickTradingQueueService get instance {
    _instance ??= OneClickTradingQueueService._();
    return _instance!;
  }

  OneClickTradingQueueService._();

  final List<TradeRequest> _tradeQueue = [];
  bool _isProcessing = false;
  ChartController? _chartController;
  AccountController? _accountController;

  /// Initialize the service with required controllers
  void initialize({
    required ChartController chartController,
    required AccountController accountController,
  }) {
    _chartController = chartController;
    _accountController = accountController;
  }

  /// Add a trade request to the queue
  /// Returns immediately without waiting for API call
  /// [onTradeComplete] callback is called when trade completes (for chart screen notifications)
  /// [notificationId] optional ID to use for notifications (if not provided, one will be generated)
  /// Returns the notification ID if callback is provided
  String? enqueueTrade({
    required String type,
    required String symbol,
    required double volume,
    String? mt5Account,
    String? notificationId,
    void Function(
      String notificationId,
      String symbol,
      String type,
      double volume,
      bool isSuccess,
      String? errorMessage,
    )?
    onTradeComplete,
  }) {
    // Get MT5 account if not provided
    String account = '';
    if (mt5Account != null && mt5Account.isNotEmpty) {
      account = mt5Account;
    } else if (_accountController != null) {
      final activeAccount = _accountController!.activeMT5Account;
      if (activeAccount != null) {
        account = activeAccount.metaAccountNumber;
      }
    }

    if (account.isEmpty) {
      print('⚠️ OneClickTradingQueueService: No MT5 account available');
      if (onTradeComplete != null) {
        // If callback provided, we need a notification ID even for error
        final errorId = DateTime.now().millisecondsSinceEpoch.toString();
        onTradeComplete(
          errorId,
          symbol,
          type,
          volume,
          false,
          'No trading account available',
        );
      } else {
        CustomToastService.showError(
          message: 'No trading account available',
          duration: const Duration(seconds: 2),
        );
      }
      return null;
    }

    // Use provided notification ID or generate one if callback is provided
    String? finalNotificationId = notificationId;
    if (finalNotificationId == null && onTradeComplete != null) {
      finalNotificationId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final tradeRequest = TradeRequest(
      type: type,
      symbol: symbol,
      volume: volume,
      mt5Account: account,
      notificationId: finalNotificationId,
      onTradeComplete: onTradeComplete,
    );

    _tradeQueue.add(tradeRequest);
    print(
      '📥 OneClickTradingQueueService: Trade enqueued. Queue size: ${_tradeQueue.length}',
    );
    print('   Trade: $tradeRequest');

    // Start processing if not already processing
    if (!_isProcessing) {
      _processQueue();
    }

    return finalNotificationId;
  }

  /// Process the queue sequentially in the background
  Future<void> _processQueue() async {
    if (_isProcessing) {
      print('⏸️ OneClickTradingQueueService: Already processing, skipping');
      return;
    }

    if (_tradeQueue.isEmpty) {
      print('✅ OneClickTradingQueueService: Queue is empty');
      return;
    }

    _isProcessing = true;
    print(
      '🚀 OneClickTradingQueueService: Starting queue processing. Queue size: ${_tradeQueue.length}',
    );

    // Process each trade in the queue sequentially
    while (_tradeQueue.isNotEmpty) {
      final tradeRequest = _tradeQueue.removeAt(0);
      print('🔄 OneClickTradingQueueService: Processing trade: $tradeRequest');
      print('   Remaining in queue: ${_tradeQueue.length}');

      try {
        // Execute trade in background
        await _executeTrade(tradeRequest);
      } catch (e) {
        print('❌ OneClickTradingQueueService: Error processing trade: $e');
        // Show error notification
        final typeText =
            tradeRequest.type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';

        // Use callback if provided, otherwise use toast
        if (tradeRequest.onTradeComplete != null &&
            tradeRequest.notificationId != null) {
          tradeRequest.onTradeComplete!(
            tradeRequest.notificationId!,
            tradeRequest.symbol,
            tradeRequest.type,
            tradeRequest.volume,
            false,
            e.toString(),
          );
        } else {
          CustomToastService.showError(
            message:
                '$typeText ${tradeRequest.symbol} ${tradeRequest.volume} failed: $e',
            duration: const Duration(seconds: 3),
          );
        }
      }

      // Small delay between trades to avoid overwhelming the API
      if (_tradeQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isProcessing = false;
    print('✅ OneClickTradingQueueService: Queue processing completed');
  }

  /// Execute a single trade request
  Future<void> _executeTrade(TradeRequest tradeRequest) async {
    if (_chartController == null) {
      print('❌ OneClickTradingQueueService: ChartController not initialized');
      return;
    }

    try {
      print('📞 OneClickTradingQueueService: Calling placeTradeOrder API...');

      // Call API - this will run in background
      // Skip sound in chart controller since we'll play one-click sound here
      final result = await _chartController!.placeTradeOrder(
        mt5Account: tradeRequest.mt5Account,
        symbol: tradeRequest.symbol,
        volume: tradeRequest.volume,
        type: tradeRequest.type,
        priceSl: "",
        priceTp: "",
        price: "",
        skipSound: true, // Skip default sound, we'll play one-click sound
      );

      // Process result and show notification
      if (result['success'] == true) {
        // Play one-click trade success sound for rapid trading
        try {
          await AudioService.playOneClickTradeSuccessSound();
        } catch (e) {
          print(
            '⚠️ OneClickTradingQueueService: Error playing one-click trade success sound: $e',
          );
        }

        // Show success notification
        final typeText =
            tradeRequest.type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';
        final message =
            '${tradeRequest.symbol} $typeText ${tradeRequest.volume} done';

        // Use callback if provided, otherwise use toast
        if (tradeRequest.onTradeComplete != null &&
            tradeRequest.notificationId != null) {
          tradeRequest.onTradeComplete!(
            tradeRequest.notificationId!,
            tradeRequest.symbol,
            tradeRequest.type,
            tradeRequest.volume,
            true,
            null,
          );
        } else {
          // Show toast notification (CustomToastService handles UI thread)
          CustomToastService.showSuccess(
            message: message,
            duration: const Duration(seconds: 2),
            position: SnackPosition.TOP,
          );
        }

        print('✅ OneClickTradingQueueService: Trade successful: $message');
      } else {
        // Show error notification
        final errorMessage = result['error'] ?? 'Failed to place order';
        final typeText =
            tradeRequest.type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';

        // Use callback if provided, otherwise use toast
        if (tradeRequest.onTradeComplete != null &&
            tradeRequest.notificationId != null) {
          tradeRequest.onTradeComplete!(
            tradeRequest.notificationId!,
            tradeRequest.symbol,
            tradeRequest.type,
            tradeRequest.volume,
            false,
            errorMessage,
          );
        } else {
          // Show toast notification (CustomToastService handles UI thread)
          CustomToastService.showError(
            message:
                '$typeText ${tradeRequest.symbol} ${tradeRequest.volume}: $errorMessage',
            duration: const Duration(seconds: 3),
            position: SnackPosition.TOP,
          );
        }

        print('❌ OneClickTradingQueueService: Trade failed: $errorMessage');
      }
    } catch (error) {
      print(
        '❌ OneClickTradingQueueService: Exception during trade execution: $error',
      );

      // Show error notification
      final typeText =
          tradeRequest.type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';

      // Use callback if provided, otherwise use toast
      if (tradeRequest.onTradeComplete != null &&
          tradeRequest.notificationId != null) {
        tradeRequest.onTradeComplete!(
          tradeRequest.notificationId!,
          tradeRequest.symbol,
          tradeRequest.type,
          tradeRequest.volume,
          false,
          'Failed to place order: $error',
        );
      } else {
        // Show toast notification (CustomToastService handles UI thread)
        CustomToastService.showError(
          message:
              '$typeText ${tradeRequest.symbol} ${tradeRequest.volume}: Failed to place order',
          duration: const Duration(seconds: 3),
          position: SnackPosition.TOP,
        );
      }

      rethrow; // Re-throw to be caught by _processQueue
    }
  }

  /// Get current queue size
  int get queueSize => _tradeQueue.length;

  /// Check if queue is processing
  bool get isProcessing => _isProcessing;

  /// Clear the queue (useful for cleanup or reset)
  void clearQueue() {
    _tradeQueue.clear();
    print('🗑️ OneClickTradingQueueService: Queue cleared');
  }

  /// Dispose the service
  void dispose() {
    clearQueue();
    _isProcessing = false;
    _chartController = null;
    _accountController = null;
  }
}
