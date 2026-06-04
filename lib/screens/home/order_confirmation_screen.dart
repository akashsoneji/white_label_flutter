import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../../routes/app_pages.dart';
import '../../constants/color.dart';
import '../../widgets/app_back_button.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String symbol;
  final String orderType; // "buy" or "sell" or "1" for sell
  final double volume;
  final double? price;
  final String? executionPrice; // Raw price string from API response
  final Function(int?)? onNavigateToTrade; // Accepts tab index parameter
  final bool isPlacing; // Flag to show loading state
  final String? positionId; // Position ID from API response
  final String? orderId; // Order ID from API response
  final int tabIndex; // Which tab to navigate to (0=Market, 1=Pending, 2=Close)

  const OrderConfirmationScreen({
    Key? key,
    required this.orderData,
    required this.symbol,
    required this.orderType,
    required this.volume,
    this.price,
    this.executionPrice,
    this.onNavigateToTrade,
    this.isPlacing = false,
    this.positionId,
    this.orderId,
    this.tabIndex = 0, // Default to Market tab
  }) : super(key: key);

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Timer? _autoNavigateTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 2;

  @override
  void initState() {
    super.initState();
    print('✅ OrderConfirmationScreen: Initialized');
    print('✅ OrderConfirmationScreen: Order data: ${widget.orderData}');
    print('✅ OrderConfirmationScreen: Is placing: ${widget.isPlacing}');

    // Only start countdown and auto-navigate if order is already placed
    if (!widget.isPlacing) {
      // Start countdown timer
      _startCountdown();

      // Auto-navigate after 2 seconds (but will be overridden by 30ms delay from chart screen)
      _autoNavigateTimer = Timer(const Duration(seconds: 2), () {
        print(
          '⏰ OrderConfirmationScreen: 2 seconds elapsed, auto-navigating...',
        );
        _navigateToTrade();
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _navigateToTrade() {
    if (!mounted) return;

    print('🚀 OrderConfirmationScreen: Starting navigation to trade screen...');

    // Cancel timers to prevent multiple navigations
    _autoNavigateTimer?.cancel();
    _countdownTimer?.cancel();

    // Store callback before removing screen (in case widget is disposed)
    final callback = widget.onNavigateToTrade;

    // Execute callback FIRST to switch to trade tab in TradingMainScreen
    // This ensures we navigate directly to trade screen without showing chart
    if (callback != null) {
      print(
        '🚀 OrderConfirmationScreen: Executing callback to switch to trade tab (index: ${widget.tabIndex})...',
      );
      try {
        callback(widget.tabIndex); // Pass tab index to navigate to correct tab
        print(
          '✅ OrderConfirmationScreen: Callback executed, switched to trade tab ${widget.tabIndex}',
        );
      } catch (e) {
        print('❌ OrderConfirmationScreen: Error executing callback: $e');
      }
    }

    // Then remove confirmation screen from navigation stack
    // Use Get.until() to go back to TradingMainScreen (which is now showing trade tab)
    Future.delayed(const Duration(milliseconds: 150), () {
      print(
        '🚀 OrderConfirmationScreen: Removing confirmation screen from stack...',
      );
      // Remove confirmation screen, go back to TradingMainScreen
      // This ensures we go directly to trade screen without showing chart
      Get.until((route) {
        // Go back until we reach TradingMainScreen (route name is '/trading')
        final routeName = route.settings.name;
        return routeName == Routes.TRADING;
      });
      print(
        '✅ OrderConfirmationScreen: Removed confirmation screen, now on trade screen',
      );
    });
  }

  @override
  void dispose() {
    _autoNavigateTimer?.cancel();
    _countdownTimer?.cancel();
    print('🗑️ OrderConfirmationScreen: Disposed');
    super.dispose();
  }

  String _getOrderTypeDisplay() {
    final type = widget.orderType.toLowerCase();
    if (type == 'buy' || type == '0' || type == '2' || type == '4') {
      return 'market buy';
    } else if (type == 'sell' || type == '1' || type == '3' || type == '5') {
      return 'market sell';
    }
    return 'market order';
  }

  String _getSymbolDisplay() {
    // Remove suffix if present (e.g., "EURUSD.c" -> "EURUSD")
    return widget.symbol.replaceAll(RegExp(r'\.\w+$'), '');
  }

  String _getSymbolDescription() {
    final symbol = _getSymbolDisplay();
    // Map common symbols to descriptions
    final descriptions = {
      'EURUSD': 'Euro vs US Dollar',
      'GBPUSD': 'British Pound vs US Dollar',
      'USDJPY': 'US Dollar vs Japanese Yen',
      'XAUUSD': 'Gold vs US Dollar',
      'ES35': 'ES35 Index',
    };
    return descriptions[symbol] ?? '$symbol Pair';
  }

  @override
  Widget build(BuildContext context) {
    // Get PositionID from response - prioritize positionId from arguments, then extract from orderData
    // API response structure: { "status": true, "message": "...", "data": { "order_id": 1002734, "position_id": 1002648, "deal": { "Price": 1.16028, "PositionID": 1002648, "Deal": 1002734 } } }
    // Handle both int and string types
    dynamic positionIdValue;

    // First try widget.positionId (passed from chart_screen)
    if (widget.positionId != null &&
        widget.positionId!.isNotEmpty &&
        widget.positionId != 'N/A') {
      positionIdValue = widget.positionId;
    } else {
      // Extract from orderData
      positionIdValue =
          widget.orderData['data']?['position_id'] ??
          widget.orderData['data']?['deal']?['PositionID'] ??
          widget.orderData['position_id'] ??
          widget.orderData['PositionID'];
    }

    final positionId =
        positionIdValue != null ? positionIdValue.toString() : 'N/A';

    // Use positionId as orderTicket for display (show PositionID)
    final orderTicket = positionId;

    // Get execution price from API response (ALWAYS extract fresh from orderData)
    // Priority: Extract directly from orderData > executionPrice > price (to avoid stale values)
    // Handle both double and string types
    final priceDisplay =
        widget.isPlacing
            ? 'Placing...' // Show loading state
            : (() {
              // ALWAYS extract fresh from orderData first (most reliable source)
              final orderDataPrice =
                  widget.orderData['data']?['deal']?['Price'] ??
                  widget.orderData['data']?['price'];

              if (orderDataPrice != null) {
                // Use price directly from API response (fresh data)
                return orderDataPrice is double
                    ? orderDataPrice.toString()
                    : orderDataPrice.toString();
              }

              // Fallback to executionPrice if orderData doesn't have it
              if (widget.executionPrice != null &&
                  widget.executionPrice!.isNotEmpty) {
                return widget.executionPrice!;
              }

              // Last fallback to widget.price (but this might be stale)
              if (widget.price != null) {
                return widget.price!;
              }

              return 'N/A';
            })();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  // Back button
                  AppBackButton(
                    onPressed: () => _navigateToTrade(),
                  ),
                  SizedBox(width: 12.w),
                  // Symbol and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.symbol,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 18.sp,
                              color: AppColors.icongrey,
                            ),
                          ],
                        ),
                        Text(
                          _getSymbolDescription(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Order confirmation content
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Show loading or success animation
                      widget.isPlacing
                          ? SizedBox(
                            width: 200.w,
                            height: 200.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          )
                          : SizedBox(
                            width: 200.w,
                            height: 200.h,
                            child: Lottie.asset(
                              'assets/animation/success.json',
                              fit: BoxFit.contain,
                              repeat: false,
                            ),
                          ),
                      SizedBox(height: 32.h),
                      // Order details
                      Text(
                        widget.isPlacing
                            ? 'Placing order...'
                            : '#$orderTicket ${_getOrderTypeDisplay()} ${widget.volume.toStringAsFixed(2)} ${widget.symbol} at',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Price - show actual execution price from API
                      Text(
                        priceDisplay.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color:
                              widget.isPlacing
                                  ? AppColors.textGrey
                                  : AppColors.textPrimary,
                        ),
                      ),
                      if (!widget.isPlacing) ...[
                        SizedBox(height: 8.h),
                        // Done status
                        Text(
                          'DONE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 32.h),
                        // Auto-navigate countdown
                        Text(
                          'Redirecting to trade screen in $_remainingSeconds seconds...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
