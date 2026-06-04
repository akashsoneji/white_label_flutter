import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/services/language_service.dart';
import '../../constants/color.dart';
import '../../constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import '../../models/order_types.dart';
import '../../utils/precision_helper.dart';
import '../../utils/app_logger.dart';
import '../../services/symbol_details_cache_service.dart';
import 'package:get/get.dart';
import '../../widgets/app_switch_tile.dart';
import 'dart:async';

class PendingOrderContent extends StatefulWidget {
  final ValueNotifier<int> selectedPendingOrderType;
  final ValueNotifier<String> selectedOrderType;
  final ValueNotifier<double> limitPrice;
  final ValueNotifier<double> openPrice;
  final ValueNotifier<double> distance;
  final ValueNotifier<bool> whenPriceIsEnabled;
  final ValueNotifier<bool> takeProfitEnabled;
  final ValueNotifier<bool> stopLossEnabled;
  final ValueNotifier<double> takeProfitPrice;
  final ValueNotifier<double> stopLossPrice;
  final TextEditingController takeProfitController;
  final TextEditingController stopLossController;
  final TextEditingController limitPriceController;
  final VoidCallback onPlaceOrder;
  final String selectedSymbol;
  final bool isLoading;
  final Function(double) onVolumeChanged;

  const PendingOrderContent({
    Key? key,
    required this.selectedPendingOrderType,
    required this.selectedOrderType,
    required this.limitPrice,
    required this.openPrice,
    required this.distance,
    required this.whenPriceIsEnabled,
    required this.takeProfitEnabled,
    required this.stopLossEnabled,
    required this.takeProfitPrice,
    required this.stopLossPrice,
    required this.takeProfitController,
    required this.stopLossController,
    required this.limitPriceController,
    required this.onPlaceOrder,
    required this.selectedSymbol,
    this.isLoading = false,
    required this.onVolumeChanged,
  }) : super(key: key);

  @override
  State<PendingOrderContent> createState() => _PendingOrderContentState();
}

class _PendingOrderContentState extends State<PendingOrderContent> {
  late ChartSocketController chartSocketController;
  late AccountController accountController;
  final TradingController tradingController = Get.find<TradingController>();

  // Live price data
  double? currentBidPrice;
  double? currentAskPrice;
  double volume = 0.01;
  int currentDigits = 5; // Default to 5 decimal places

  // Dropdown selection state - will sync with parent's ValueNotifier

  // TextEditingController for volume input
  late TextEditingController volumeController;
  late FocusNode volumeFocusNode;

  // Flag to track manual price editing
  bool isManuallyEditingPrice = false;
  bool isManuallyEditingTakeProfit = false;
  bool isManuallyEditingStopLoss = false;

  // Key to force FutureBuilder rebuild when TP/SL values change
  int _pnlCalculationKey = 0;
  Timer? _pnlUpdateTimer; // Debounce timer for P&L updates

  // ValueNotifiers for targeted P&L updates (prevents full widget rebuild)
  final ValueNotifier<int> _tpPnLUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _slPnLUpdateNotifier = ValueNotifier<int>(0);

  // Cache last known P&L values to prevent text disappearing during recalculation
  Map<String, dynamic>? _lastTPPnL;
  Map<String, dynamic>? _lastSLPnL;

  // Get current digits from API
  int _getCurrentDigits() {
    final priceData = chartSocketController.getCurrentPrice();
    if (priceData != null && priceData.containsKey('digits')) {
      return int.tryParse(priceData['digits'].toString()) ?? 5;
    }
    return 5; // Default fallback
  }

  // ── Lot-size limits from the active MT5 account ────────────────────
  double get _minLot => 0.01; // Hardcoded to prevent jump to 1.0
  double get _maxLot => accountController.activeMT5Account?.maxLotSize ?? 100.0;

  // Android-style price adjustment using pip values
  void _adjustPrice(bool isIncrease) {
    // Set current symbol and update pip values
    tradingController.setCurrentSymbol(widget.selectedSymbol);

    // Get current market prices
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();

    if (currentBidPrice != null && currentAskPrice != null) {
      tradingController.updateMarketPrices(currentBidPrice!, currentAskPrice!);
    }

    // Convert dropdown selection to OrderType enum
    OrderType orderType;
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    switch (selectedOrderTypeStr) {
      case 'Buy Limit':
        orderType = OrderType.buyLimit;
        break;
      case 'Sell Limit':
        orderType = OrderType.sellLimit;
        break;
      default:
        orderType = OrderType.buyLimit;
        break;
    }

    // Log price adjustment
    AppLogger.trading(
      'Price adjustment: ${isIncrease ? '+' : '-'} pip for ${orderType.displayName}',
    );

    // Use Android-style price adjustment
    final currentPrice = widget.limitPrice.value.toString();
    final newPrice = tradingController.adjustPriceByPip(
      currentPrice,
      isIncrease,
      orderType,
    );

    // Update the price
    final newPriceValue = double.tryParse(newPrice) ?? widget.limitPrice.value;
    widget.limitPrice.value = newPriceValue;
    widget.limitPriceController.text = PrecisionHelper.formatPrice(
      newPriceValue,
      decimals: currentDigits,
    );

    isManuallyEditingPrice = true;

    // Recalculate SL/TP based on new price
    _recalculateTPSL();
  }

  // Android-style SL adjustment using pip values
  // ignore: unused_element
  void _adjustSL(bool isIncrease) {
    if (!widget.stopLossEnabled.value) return;

    // Set current symbol and update pip values
    tradingController.setCurrentSymbol(widget.selectedSymbol);

    // Get current market prices
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();

    if (currentBidPrice != null && currentAskPrice != null) {
      tradingController.updateMarketPrices(currentBidPrice!, currentAskPrice!);
    }

    // Convert dropdown selection to OrderType enum
    OrderType orderType;
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    switch (selectedOrderTypeStr) {
      case 'Buy Limit':
        orderType = OrderType.buyLimit;
        break;
      case 'Sell Limit':
        orderType = OrderType.sellLimit;
        break;
      default:
        orderType = OrderType.buyLimit;
        break;
    }

    // Use Android-style SL adjustment
    final currentSL = widget.stopLossPrice.value.toString();
    final entryPrice = widget.limitPrice.value.toString();
    final newSL = tradingController.adjustSLTPByPip(
      currentSL,
      isIncrease,
      orderType,
      entryPrice,
    );

    // Update the SL
    final newSLValue = double.tryParse(newSL) ?? widget.stopLossPrice.value;
    widget.stopLossPrice.value = newSLValue;
    widget.stopLossController.text = PrecisionHelper.formatPrice(
      newSLValue,
      decimals: currentDigits,
    );

    isManuallyEditingStopLoss = true;
  }

  // Android-style TP adjustment using pip values
  // ignore: unused_element
  void _adjustTP(bool isIncrease) {
    if (!widget.takeProfitEnabled.value) return;

    // Set current symbol and update pip values
    tradingController.setCurrentSymbol(widget.selectedSymbol);

    // Get current market prices
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();

    if (currentBidPrice != null && currentAskPrice != null) {
      tradingController.updateMarketPrices(currentBidPrice!, currentAskPrice!);
    }

    // Convert dropdown selection to OrderType enum
    OrderType orderType;
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    switch (selectedOrderTypeStr) {
      case 'Buy Limit':
        orderType = OrderType.buyLimit;
        break;
      case 'Sell Limit':
        orderType = OrderType.sellLimit;
        break;
      default:
        orderType = OrderType.buyLimit;
        break;
    }

    // Use Android-style TP adjustment
    final currentTP = widget.takeProfitPrice.value.toString();
    final entryPrice = widget.limitPrice.value.toString();
    final newTP = tradingController.adjustSLTPByPip(
      currentTP,
      isIncrease,
      orderType,
      entryPrice,
    );

    // Update the TP
    final newTPValue = double.tryParse(newTP) ?? widget.takeProfitPrice.value;
    widget.takeProfitPrice.value = newTPValue;
    widget.takeProfitController.text = PrecisionHelper.formatPrice(
      newTPValue,
      decimals: currentDigits,
    );

    isManuallyEditingTakeProfit = true;
  }

  void _recalculateTPSL() {
    if (widget.limitPrice.value > 0) {
      final entryPrice = widget.limitPrice.value;
      final percentageValue = entryPrice * 0.0115; // 1.15% - Android default

      // Convert dropdown selection to OrderType enum
      OrderType orderType;
      final selectedOrderTypeStr = widget.selectedOrderType.value;
      switch (selectedOrderTypeStr) {
        case 'Buy Limit':
          orderType = OrderType.buyLimit;
          break;
        case 'Sell Limit':
          orderType = OrderType.sellLimit;
          break;
        case 'Buy Stop':
          orderType = OrderType.buyStop;
          break;
        case 'Sell Stop':
          orderType = OrderType.sellStop;
          break;
        default:
          orderType = OrderType.buyLimit;
          break;
      }

      // Only update Take Profit if user hasn't manually edited it
      if (widget.takeProfitEnabled.value && !isManuallyEditingTakeProfit) {
        if (orderType.isBuyOrder) {
          // Buy orders - Take Profit ABOVE entry price
          widget.takeProfitPrice.value = entryPrice + percentageValue;
        } else {
          // Sell orders - Take Profit BELOW entry price
          widget.takeProfitPrice.value = entryPrice - percentageValue;
        }
        widget.takeProfitController.text = PrecisionHelper.formatPrice(
          widget.takeProfitPrice.value,
          decimals: currentDigits,
        );
      }

      // Only update Stop Loss if user hasn't manually edited it
      if (widget.stopLossEnabled.value && !isManuallyEditingStopLoss) {
        if (orderType.isBuyOrder) {
          // Buy orders - Stop Loss BELOW entry price
          widget.stopLossPrice.value = entryPrice - percentageValue;
        } else {
          // Sell orders - Stop Loss ABOVE entry price
          widget.stopLossPrice.value = entryPrice + percentageValue;
        }
        widget.stopLossController.text = PrecisionHelper.formatPrice(
          widget.stopLossPrice.value,
          decimals: currentDigits,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Get controllers
    chartSocketController = Get.find<ChartSocketController>();
    accountController = Get.find<AccountController>();

    // Initialize limit price controller
    currentDigits = _getCurrentDigits(); // Get digits before initializing
    widget.limitPriceController.text = PrecisionHelper.formatPrice(
      widget.limitPrice.value,
      decimals: currentDigits,
    );

    // Initialize volume controller
    volumeController = TextEditingController(
      text: PrecisionHelper.formatVolume(volume),
    );
    volumeFocusNode = FocusNode();

    // Initialize selectedOrderType from parent's ValueNotifier
    // This will be used for display, but parent's ValueNotifier is the source of truth

    // Add listener to limit price controller for real-time TP/SL recalculation
    widget.limitPriceController.addListener(() {
      final text = widget.limitPriceController.text;
      if (text.isNotEmpty) {
        final newPrice = PrecisionHelper.parseDouble(text);
        if (newPrice > 0) {
          widget.limitPrice.value = newPrice;
          // Recalculate TP/SL when limit price changes
          _recalculateTPSL();
        }
      }
    });

    // Initialize with current prices
    _updatePrices();

    // Listen to price updates
    chartSocketController.priceStream.listen((priceData) {
      if (mounted) {
        setState(() {
          _updatePrices();
        });
      }
    });

    // Listen to order type changes
    widget.selectedPendingOrderType.addListener(() {
      if (mounted) {
        setState(() {
          isManuallyEditingPrice = false; // Reset flag when order type changes
          isManuallyEditingTakeProfit = false; // Reset TP manual editing
          isManuallyEditingStopLoss = false; // Reset SL manual editing
          _updatePrices();
        });
      }
    });
  }

  void _updatePrices() {
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();
    currentDigits = _getCurrentDigits(); // Update digits from API

    // Only update limit price if user is not manually editing
    if (!isManuallyEditingPrice) {
      // Update limit price based on current order type from dropdown
      final orderType = widget.selectedOrderType.value;
      if (orderType == 'Sell Limit') {
        // Sell orders - use bid price
        widget.limitPrice.value = currentBidPrice ?? 3673.90;
        widget.limitPriceController.text = PrecisionHelper.formatPrice(
          widget.limitPrice.value,
          decimals: currentDigits,
        );
      } else {
        // Buy Limit - use ask price
        widget.limitPrice.value = currentAskPrice ?? 3674.16;
        widget.limitPriceController.text = PrecisionHelper.formatPrice(
          widget.limitPrice.value,
          decimals: currentDigits,
        );
      }
    }

    // Always update Take Profit and Stop Loss based on entry price (limit price for all dropdown order types)
    // All dropdown order types (Buy Limit, Sell Limit) use limit price as entry price
    final entryPrice = widget.limitPrice.value;
    final orderType = widget.selectedOrderType.value;

    if (entryPrice > 0) {
      // Calculate 1.15% of the entry price for TP/SL
      final percentageValue = entryPrice * 0.0115; // 1.15%

      // Only update Take Profit if user hasn't manually edited it
      if (widget.takeProfitEnabled.value && !isManuallyEditingTakeProfit) {
        if (orderType == 'Sell Limit') {
          // Sell orders - Take Profit BELOW entry price (profit when price drops)
          widget.takeProfitPrice.value = entryPrice - percentageValue;
        } else {
          // Buy Limit - Take Profit ABOVE entry price (profit when price rises)
          widget.takeProfitPrice.value = entryPrice + percentageValue;
        }
        // Update the text field
        widget.takeProfitController.text = PrecisionHelper.formatPrice(
          widget.takeProfitPrice.value,
          decimals: currentDigits,
        );
      }

      // Only update Stop Loss if user hasn't manually edited it
      if (widget.stopLossEnabled.value && !isManuallyEditingStopLoss) {
        if (orderType == 'Sell Limit') {
          // Sell orders - Stop Loss ABOVE entry price (safety net above)
          widget.stopLossPrice.value = entryPrice + percentageValue;
        } else {
          // Buy Limit - Stop Loss BELOW entry price (safety net below)
          widget.stopLossPrice.value = entryPrice - percentageValue;
        }
        // Update the text field
        widget.stopLossController.text = PrecisionHelper.formatPrice(
          widget.stopLossPrice.value,
          decimals: currentDigits,
        );
      }
    }
  }

  /// Get symbol details from cache
  Future<Map<String, dynamic>?> _getSymbolDetails(String symbol) async {
    try {
      final activeAccount = accountController.activeMT5Account;
      final accountNumber = activeAccount?.metaAccountNumber ?? '0';

      return await SymbolDetailsCacheService.getSymbolDetails(
        symbol,
        accountNumber,
      );
    } catch (e) {
      print('PendingOrderContent: Error getting symbol details from cache: $e');
      return null;
    }
  }

  /// Calculate potential profit if Take Profit is hit
  /// Returns Map with 'pnl' and 'digits' for formatting
  /// Uses limit price as entry price for pending orders
  Future<Map<String, dynamic>?> _calculateTakeProfitPnL() async {
    if (!widget.takeProfitEnabled.value ||
        widget.takeProfitController.text.isEmpty) {
      return null;
    }

    final tpPrice = PrecisionHelper.parseDouble(
      widget.takeProfitController.text,
    );
    if (tpPrice <= 0) return null;

    // Use limit price as entry price for pending orders
    final entryPrice = widget.limitPrice.value;
    if (entryPrice <= 0) return null;

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.selectedSymbol);
    if (symbolDetails == null) {
      print(
        'PendingOrderContent: Symbol details not found in cache for ${widget.selectedSymbol}',
      );
      return null;
    }

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'PendingOrderContent: Invalid contract size for ${widget.selectedSymbol}',
      );
      return null;
    }

    final currentVolume = volume;

    // Determine if it's a Buy or Sell order from selectedOrderType
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    final isBuy = selectedOrderTypeStr == 'Buy Limit';

    double priceDiff;
    if (isBuy) {
      // Buy Limit: profit when price goes up (TP > Entry)
      priceDiff = tpPrice - entryPrice;
    } else {
      // Sell Limit: profit when price goes down (Entry > TP)
      priceDiff = entryPrice - tpPrice;
    }

    final pnl = priceDiff * currentVolume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;

    return {'pnl': pnl, 'digits': digits};
  }

  /// Calculate potential loss if Stop Loss is hit
  /// Returns Map with 'pnl' and 'digits' for formatting
  /// Uses limit price as entry price for pending orders
  Future<Map<String, dynamic>?> _calculateStopLossPnL() async {
    if (!widget.stopLossEnabled.value ||
        widget.stopLossController.text.isEmpty) {
      return null;
    }

    final slPrice = PrecisionHelper.parseDouble(widget.stopLossController.text);
    if (slPrice <= 0) return null;

    // Use limit price as entry price for pending orders
    final entryPrice = widget.limitPrice.value;
    if (entryPrice <= 0) return null;

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.selectedSymbol);
    if (symbolDetails == null) {
      print(
        'PendingOrderContent: Symbol details not found in cache for ${widget.selectedSymbol}',
      );
      return null;
    }

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'PendingOrderContent: Invalid contract size for ${widget.selectedSymbol}',
      );
      return null;
    }

    final currentVolume = volume;

    // Determine if it's a Buy or Sell order from selectedOrderType
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    final isBuy = selectedOrderTypeStr == 'Buy Limit';

    double priceDiff;
    if (isBuy) {
      // Buy Limit: loss when price goes down (Entry > SL)
      priceDiff = entryPrice - slPrice;
    } else {
      // Sell Limit: loss when price goes up (SL > Entry)
      priceDiff = slPrice - entryPrice;
    }

    final pnl = priceDiff * currentVolume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;

    return {'pnl': pnl, 'digits': digits};
  }

  // Calculate required margin
  // ignore: unused_element
  double _calculateRequiredMargin() {
    final currentPrice =
        widget.selectedPendingOrderType.value == 0
            ? currentBidPrice
            : currentAskPrice;

    if (currentPrice == null) return 0.0;

    // Simple margin calculation - adjust based on your broker's requirements
    return currentPrice * volume * 0.01; // 1% margin
  }

  // Get free margin
  // ignore: unused_element
  double _getFreeMargin() {
    final activeAccount = accountController.activeMT5Account;
    if (activeAccount == null) return 0.0;

    // This should come from your account data
    return 20007.19; // Placeholder - replace with actual free margin
  }

  // Validate Stop Loss
  // ignore: unused_element
  String? _validateStopLoss() {
    if (!widget.stopLossEnabled.value) return null;

    // Use limit price for limit orders, current market price for market orders
    final entryPrice =
        widget.whenPriceIsEnabled.value
            ? widget.limitPrice.value
            : (widget.selectedPendingOrderType.value == 0
                ? currentBidPrice
                : currentAskPrice);

    if (entryPrice == null) return null;

    if (widget.selectedPendingOrderType.value == 0) {
      // Sell Limit - Stop Loss should be ABOVE entry price (safety net above)
      if (widget.stopLossPrice.value <= entryPrice) {
        return 'Stop Loss should be above entry price ${PrecisionHelper.formatPrice(entryPrice, decimals: currentDigits)}';
      }
    } else {
      // Buy Limit - Stop Loss should be BELOW entry price (safety net below)
      if (widget.stopLossPrice.value >= entryPrice) {
        return 'Stop Loss should be below entry price ${PrecisionHelper.formatPrice(entryPrice, decimals: currentDigits)}';
      }
    }

    return null;
  }

  // Validate Take Profit
  // ignore: unused_element
  String? _validateTakeProfit() {
    if (!widget.takeProfitEnabled.value) return null;

    // Use limit price for limit orders, current market price for market orders
    final entryPrice =
        widget.whenPriceIsEnabled.value
            ? widget.limitPrice.value
            : (widget.selectedPendingOrderType.value == 0
                ? currentBidPrice
                : currentAskPrice);

    if (entryPrice == null) return null;

    if (widget.selectedPendingOrderType.value == 0) {
      // Sell Limit - Take Profit should be BELOW entry price (profit when price drops)
      if (widget.takeProfitPrice.value >= entryPrice) {
        return 'Take Profit should be below entry price ${PrecisionHelper.formatPrice(entryPrice, decimals: currentDigits)}';
      }
    } else {
      // Buy Limit - Take Profit should be ABOVE entry price (profit when price rises)
      if (widget.takeProfitPrice.value <= entryPrice) {
        return 'Take Profit should be above entry price ${PrecisionHelper.formatPrice(entryPrice, decimals: currentDigits)}';
      }
    }

    return null;
  }

  // Validate Limit Price
  // Note: Basic validation only - backend will handle strict validation and return errors
  // ignore: unused_element
  String? _validateLimitPrice() {
    // Only validate if "When price is" toggle is ON
    if (!widget.whenPriceIsEnabled.value) return null;

    final currentPrice =
        widget.selectedPendingOrderType.value == 0
            ? currentBidPrice
            : currentAskPrice;

    if (currentPrice == null) return null;

    // Round both prices to currentDigits precision for accurate comparison
    final roundedLimitPrice = PrecisionHelper.round(
      widget.limitPrice.value,
      decimals: currentDigits,
    );
    final roundedCurrentPrice = PrecisionHelper.round(
      currentPrice,
      decimals: currentDigits,
    );

    if (widget.selectedPendingOrderType.value == 0) {
      // Sell Limit - Limit price should be above current price
      if (roundedLimitPrice <= roundedCurrentPrice) {
        return 'Sell Limit price should be above ${PrecisionHelper.formatPrice(currentPrice, decimals: currentDigits)}';
      }
    } else {
      // Buy Limit - Limit price should be below current price
      if (roundedLimitPrice >= roundedCurrentPrice) {
        return 'Buy Limit price should be below ${PrecisionHelper.formatPrice(currentPrice, decimals: currentDigits)}';
      }
    }

    return null;
  }

  // Check if order is valid for placement
  // Note: Price validation is shown as warning but doesn't block button - backend will validate
  bool _isOrderValid() {
    // Basic checks: price and volume must be positive
    if (widget.limitPrice.value <= 0) return false;
    if (volume <= 0) return false;

    // For market orders (toggle OFF), only check SL/TP validation if enabled
    if (!widget.whenPriceIsEnabled.value) {
      // Market orders - only validate SL/TP if enabled (but don't block, just warn)
      // Backend will handle validation
      return true;
    }

    // For limit orders (toggle ON), allow placement - backend will validate
    // Price validation message is shown but doesn't block the button
    // Only validate SL/TP if enabled (but don't block, backend will handle)
    return true;
  }

  @override
  void dispose() {
    _pnlUpdateTimer?.cancel();
    _tpPnLUpdateNotifier.dispose();
    _slPnLUpdateNotifier.dispose();
    // Remove listeners to prevent memory leaks
    widget.selectedPendingOrderType.removeListener(() {});
    volumeController.dispose();
    volumeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Type Dropdown
              _buildOrderTypeDropdown(),

              SizedBox(height: 14.h),

              // Quantity Section
              _buildQuantitySection(),

              SizedBox(height: 12.h),

              // Monetary Equivalent
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text(
              //       'Monetary equivalent',
              //       style: AppTextStyles.label.copyWith(
              //         fontSize: 14.sp,
              //         fontWeight: FontWeight.w400,
              //         color: AppColors.textGrey,
              //       ),
              //     ),
              //     ValueListenableBuilder<double>(
              //       valueListenable: widget.openPrice,
              //       builder: (context, price, child) {
              //         return Text(
              //           '\$${PrecisionHelper.formatPnL(price)}',
              //           style: AppTextStyles.label.copyWith(
              //             fontSize: 14.sp,
              //             fontWeight: FontWeight.w400,
              //           ),
              //         );
              //       },
              //     ),
              //   ],
              // ),

              // SizedBox(height: 16.h),

              // When Price Is Toggle
              _buildSwitchTile(
                'When Price Is',
                widget.whenPriceIsEnabled,
                onChanged: (value) {
                  widget.whenPriceIsEnabled.value = value;
                },
              ),

              // Open Price Input - Only show when toggle is ON
              ValueListenableBuilder<bool>(
                valueListenable: widget.whenPriceIsEnabled,
                builder: (context, isEnabled, child) {
                  if (!isEnabled) return SizedBox.shrink();
                  return Column(
                    children: [
                      _buildOpenPriceInput(),
                      // Error message for Limit Price - wrapped in ValueListenableBuilder for real-time updates
                      // ValueListenableBuilder<double>(
                      //   valueListenable: widget.limitPrice,
                      //   builder: (context, price, child) {
                      //     final validationError = _validateLimitPrice();
                      //     if (validationError == null) return SizedBox.shrink();
                      //     return Padding(
                      //       padding: EdgeInsets.symmetric(
                      //         horizontal: 16.w,
                      //         vertical: 4.h,
                      //       ),
                      //       child: Text(
                      //         validationError,
                      //         style: AppTextStyles.label.copyWith(
                      //           fontSize: 12.sp,
                      //           color: AppColors.red,
                      //         ),
                      //       ),
                      //     );
                      //   },
                      // ),
                    ],
                  );
                },
              ),

              // SizedBox(height: 16.h),

              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text(
              //       'Distance',
              //       style: AppTextStyles.label.copyWith(
              //         fontSize: 14.sp,
              //         fontWeight: FontWeight.w400,
              //         color: AppColors.textGrey,
              //       ),
              //     ),
              //     ValueListenableBuilder<double>(
              //       valueListenable: widget.distance,
              //       builder: (context, distanceValue, child) {
              //         return Text(
              //           '${PrecisionHelper.formatPrice(distanceValue)} points',
              //           style: AppTextStyles.label.copyWith(
              //             fontSize: 14.sp,
              //             fontWeight: FontWeight.w400,
              //           ),
              //         );
              //       },
              //     ),
              //   ],
              // ),
              // SizedBox(height: 16.h),
              SizedBox(height: 16.h),

              // Stop Loss and Take Profit with Switches
              _buildStopLossTakeProfitWithSwitches(),

              SizedBox(height: 16.h),

              // Place Order Button
              ValueListenableBuilder<double>(
                valueListenable: widget.limitPrice,
                builder: (context, price, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.whenPriceIsEnabled,
                    builder: (context, isConditional, child) {
                      final isValid = _isOrderValid();
                      final isButtonEnabled = isValid && !widget.isLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 40.h,
                        child: ElevatedButton(
                          onPressed:
                              isButtonEnabled ? widget.onPlaceOrder : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 2,
                          ),
                          child:
                              widget.isLoading
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20.w,
                                        height: 20.h,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.whiteColor,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Text(
                                        'Processing...',
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.whiteColor,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Text(
                                    isValid
                                        ? 'Place pending order'
                                        : 'Fix validation errors',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.whiteColor,
                                    ),
                                  ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Extra padding for keyboard
              SizedBox(
                height:
                    MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom + 20.h
                        : 20.h,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity (lots)',
          style: AppTextStyles.label.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 25.w,
                height: 25.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      final next = double.parse(
                        (volume - 0.01).toStringAsFixed(2),
                      );
                      volume = next < _minLot ? _minLot : next;
                      volumeController.text = PrecisionHelper.formatVolume(
                        volume,
                      );
                      widget.onVolumeChanged(volume);
                    });
                  },
                  icon: Icon(Icons.remove, size: 20.h, color: Colors.grey[600]),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: volumeController,
                    focusNode: volumeFocusNode,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final text = newValue.text;
                        if (text.isEmpty) return newValue;

                        // Prevent '00', '01' etc. (allow '0', '0.' only)
                        if (text.length > 1 &&
                            text.startsWith('0') &&
                            !text.startsWith('0.')) {
                          return oldValue;
                        }

                        final newDouble = double.tryParse(text);
                        if (newDouble == null) return oldValue;
                        if (newDouble > _maxLot) return oldValue;

                        return newValue;
                      }),
                    ],

                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: 'Enter lots',
                      hintStyle: AppTextStyles.label.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.textGrey,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) return;
                      // Free typing — just sync volume, no mid-keystroke clamping.
                      final newVolume = PrecisionHelper.parseDouble(value);
                      if (newVolume > 0) {
                        setState(() {
                          volume = newVolume;
                          widget.onVolumeChanged(volume);
                        });
                      }
                    },
                    onEditingComplete: () {
                      // Clamp to [_minLot, _maxLot] when user leaves the field.
                      final parsed = double.tryParse(volumeController.text);
                      final clamped =
                          (parsed == null || parsed <= 0)
                              ? _minLot
                              : parsed.clamp(_minLot, _maxLot);
                      setState(() {
                        volume = double.parse(clamped.toStringAsFixed(2));
                        widget.onVolumeChanged(volume);
                      });
                      volumeController.text = volume.toStringAsFixed(2);
                      volumeFocusNode.unfocus();
                    },
                  ),
                ),
              ),
              Container(
                width: 25.w,
                height: 25.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      final next = double.parse(
                        (volume + 0.01).toStringAsFixed(2),
                      );
                      volume = next > _maxLot ? _maxLot : next;
                      volumeController.text = volume.toStringAsFixed(2);
                      widget.onVolumeChanged(volume);
                    });
                  },
                  icon: Icon(Icons.add, size: 20.h, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenPriceInput() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 2.h),
      child: Container(
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: 11.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Minus button
            Container(
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.icongrey),
              ),
              width: 24.w,
              child: IconButton(
                onPressed: () {
                  _adjustPrice(false); // Decrease price by pip
                },
                icon: Icon(Icons.remove, size: 18.h, color: AppColors.icongrey),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),

            // Price input field
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    Get.find<LanguageService>().tr('pending_order_price'),
                    style: AppTextStyles.labelOnTradeQuantity,
                  ),
                  TextField(
                    controller: widget.limitPriceController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelOnTradeQuantityDigit,
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      isManuallyEditingPrice = true; // User is manually editing
                      final newPrice = PrecisionHelper.parseDouble(value);
                      if (newPrice > 0) {
                        widget.limitPrice.value = newPrice;
                        // Trigger setState to ensure UI rebuilds for real-time validation
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),

            // Plus button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              width: 24.w,
              height: 24.h,
              child: IconButton(
                onPressed: () {
                  _adjustPrice(true); // Increase price by pip
                },
                icon: Icon(Icons.add, size: 18.h, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    ValueNotifier<bool> valueNotifier, {
    required Function(bool) onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: valueNotifier,
      builder: (context, value, child) {
        return AppSwitchTile(title: title, value: value, onChanged: onChanged);
      },
    );
  }

  Widget _buildStopLossTakeProfitWithSwitches() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Take Profit with Switch
          _buildSwitchTile(
            'Take Profit',
            widget.takeProfitEnabled,
            onChanged: (value) {
              widget.takeProfitEnabled.value = value;
              isManuallyEditingTakeProfit = false;
              if (value) {
                _recalculateTPSL();
              }
              if (mounted) {
                setState(() {
                  _pnlCalculationKey++;
                });
              }
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.takeProfitEnabled,
            builder: (context, enabled, child) {
              if (!enabled) return SizedBox.shrink();
              return Column(
                children: [
                  _buildPriceInput(
                    'Take Profit',
                    widget.takeProfitController,
                    widget.takeProfitPrice.value,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _tpPnLUpdateNotifier,
                    builder: (context, value, child) {
                      return FutureBuilder<Map<String, dynamic>?>(
                        key: ValueKey('tp_pnl_${_pnlCalculationKey}_$value'),
                        future: _calculateTakeProfitPnL(),
                        builder: (context, snapshot) {
                          // Use cached value during recalculation to prevent text disappearing
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildPnLDisplay(
                              'Potential Profit at TP',
                              _lastTPPnL,
                              isProfit: true,
                            );
                          }
                          // Cache the new value
                          if (snapshot.hasData && snapshot.data != null) {
                            _lastTPPnL = snapshot.data;
                          }
                          return _buildPnLDisplay(
                            'Potential Profit at TP',
                            snapshot.data ?? _lastTPPnL,
                            isProfit: true,
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 4.h),

          // Stop Loss with Switch
          _buildSwitchTile(
            'Stop Loss',
            widget.stopLossEnabled,
            onChanged: (value) {
              widget.stopLossEnabled.value = value;
              isManuallyEditingStopLoss = false;
              if (value) {
                _recalculateTPSL();
              }
              if (mounted) {
                setState(() {
                  _pnlCalculationKey++;
                });
              }
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.stopLossEnabled,
            builder: (context, enabled, child) {
              if (!enabled) return SizedBox.shrink();
              return Column(
                children: [
                  _buildPriceInput(
                    'Stop Loss',
                    widget.stopLossController,
                    widget.stopLossPrice.value,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _slPnLUpdateNotifier,
                    builder: (context, value, child) {
                      return FutureBuilder<Map<String, dynamic>?>(
                        key: ValueKey('sl_pnl_${_pnlCalculationKey}_$value'),
                        future: _calculateStopLossPnL(),
                        builder: (context, snapshot) {
                          // Use cached value during recalculation to prevent text disappearing
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildPnLDisplay(
                              'Potential Loss at SL',
                              _lastSLPnL,
                              isProfit: false,
                            );
                          }
                          // Cache the new value
                          if (snapshot.hasData && snapshot.data != null) {
                            _lastSLPnL = snapshot.data;
                          }
                          return _buildPnLDisplay(
                            'Potential Loss at SL',
                            snapshot.data ?? _lastSLPnL,
                            isProfit: false,
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Get price increment based on symbol
  double _getPriceIncrement() {
    if (widget.selectedSymbol.contains('JPY')) {
      return 0.01;
    } else if (widget.selectedSymbol.contains('XAU') ||
        widget.selectedSymbol.contains('GOLD')) {
      return 0.01;
    } else if (widget.selectedSymbol.contains('XAG') ||
        widget.selectedSymbol.contains('SILVER')) {
      return 0.001;
    } else {
      return 0.0001;
    }
  }

  String _formatPrice(double value) {
    return PrecisionHelper.formatPrice(value, decimals: currentDigits);
  }

  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
    double defaultValue,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 20.w,
            height: 20.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: IconButton(
              onPressed: () {
                final currentValue =
                    double.tryParse(controller.text) ?? defaultValue;
                final priceIncrement = _getPriceIncrement();
                final newValue = (currentValue - priceIncrement).clamp(
                  0.0,
                  double.infinity,
                );
                setState(() {
                  controller.text = _formatPrice(newValue);
                  if (label == 'Take Profit') {
                    widget.takeProfitPrice.value = newValue;
                  } else if (label == 'Stop Loss') {
                    widget.stopLossPrice.value = newValue;
                  }
                  // Force FutureBuilder to rebuild by incrementing key
                  _pnlCalculationKey++;
                });
              },
              icon: Icon(Icons.remove, size: 10.h, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ),
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (value) {
                  // Mark as manually editing to prevent auto-updates from datafeed
                  if (label == 'Take Profit') {
                    isManuallyEditingTakeProfit = true;
                  } else if (label == 'Stop Loss') {
                    isManuallyEditingStopLoss = true;
                  }

                  // Update the price value when text changes (without setState to avoid keyboard closing and focus loss)
                  final price =
                      double.tryParse(value.replaceAll(',', '')) ?? 0.0;
                  if (price > 0) {
                    if (label == 'Take Profit') {
                      widget.takeProfitPrice.value = price;
                    } else if (label == 'Stop Loss') {
                      widget.stopLossPrice.value = price;
                    }
                  }

                  // Debounce P&L calculation to update in real-time while typing
                  // Only update the specific field's P&L, not the entire widget tree
                  _pnlUpdateTimer?.cancel();
                  _pnlUpdateTimer = Timer(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      // Update only the specific P&L widget, not the entire form
                      if (label == 'Take Profit') {
                        _tpPnLUpdateNotifier.value++;
                      } else if (label == 'Stop Loss') {
                        _slPnLUpdateNotifier.value++;
                      }
                    }
                  });
                },
                onEditingComplete: () {
                  // Just update P&L when user finishes editing
                  if (mounted) {
                    setState(() {
                      _pnlCalculationKey++;
                    });
                  }
                  // Clear manual editing flag
                  if (label == 'Take Profit') {
                    isManuallyEditingTakeProfit = false;
                  } else if (label == 'Stop Loss') {
                    isManuallyEditingStopLoss = false;
                  }
                },
              ),
            ),
          ),
          Container(
            width: 20.w,
            height: 20.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary),
            ),
            child: IconButton(
              onPressed: () {
                final currentValue =
                    double.tryParse(controller.text) ?? defaultValue;
                final priceIncrement = _getPriceIncrement();
                final newValue = currentValue + priceIncrement;
                setState(() {
                  controller.text = _formatPrice(newValue);
                  if (label == 'Take Profit') {
                    widget.takeProfitPrice.value = newValue;
                  } else if (label == 'Stop Loss') {
                    widget.stopLossPrice.value = newValue;
                  }
                  // Force FutureBuilder to rebuild by incrementing key
                  _pnlCalculationKey++;
                });
              },
              icon: Icon(Icons.add, size: 10.h, color: AppColors.primary),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnLDisplay(
    String label,
    Map<String, dynamic>? pnlData, {
    required bool isProfit,
  }) {
    if (pnlData == null || pnlData['pnl'] == null) {
      return SizedBox(height: 20.h); // Fixed height to prevent layout shifts
    }

    final pnl = (pnlData['pnl'] as num).toDouble();
    final digits = (pnlData['digits'] as int?) ?? 2;

    // Format P&L with symbol-specific digits
    final formattedPnL =
        '\$${PrecisionHelper.formatPnL(pnl, decimals: digits)}';
    final isPositive = pnl >= 0;

    // For TP: positive = profit (green), negative = loss (red)
    // For SL: ALWAYS show in red (it's always a loss)
    final color =
        isProfit
            ? (isPositive ? AppColors.success : AppColors.error)
            : AppColors.error; // SL is always a loss, always show in red

    return Padding(
      padding: EdgeInsets.only(top: 8.h, left: 12.w, right: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label - static, never rebuilds
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
          // Value - only this part updates, with fixed width to prevent layout shifts
          SizedBox(
            width: 100.w, // Fixed width to prevent layout shifts
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                formattedPnL,
                key: ValueKey(
                  formattedPnL,
                ), // Key forces rebuild when value changes
                textAlign: TextAlign.end,
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeDropdown() {
    return GestureDetector(
      onTap: () => _showOrderTypeBottomSheet(),
      child: Container(
        height: 46.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.border),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: widget.selectedOrderType,
              builder: (context, orderType, child) {
                return Text(
                  orderType,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.icongrey,
              size: 24.h,
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderTypeBottomSheet() {
    final List<String> options = ['Buy Limit', 'Sell Limit'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      margin: EdgeInsets.only(top: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Title
                    Text(
                      'Select Order Type',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 15.h),
                    // Options Buttons
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected =
                          widget.selectedOrderType.value == option;
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.w),
                            child: GestureDetector(
                              onTap: () {
                                // Update parent's ValueNotifier
                                widget.selectedOrderType.value = option;
                                // Update selectedPendingOrderType based on dropdown selection
                                if (option == 'Buy Limit') {
                                  widget.selectedPendingOrderType.value = 1;
                                } else if (option == 'Sell Limit') {
                                  widget.selectedPendingOrderType.value = 0;
                                }
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Center(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (index < options.length - 1) SizedBox(height: 8.h),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
