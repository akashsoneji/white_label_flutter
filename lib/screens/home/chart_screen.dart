import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/chart_controller.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/flavor_config.dart';
import 'dart:convert';

import 'package:intl/intl.dart';
import '../../constants/color.dart';
import '../../constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_chart_layout.dart';
import 'package:crm_app/widgets/vantage/vantage_symbol_dropdown.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import '../../services/trading_websocket_service.dart';
import '../../widgets/price_alert_dialog.dart';
import '../../widgets/account_header_widget.dart';
import '../../services/price_alert_service.dart';
import '../../services/price_alert_monitor_service.dart';
import '../../services/audio_service.dart';
import '../../utils/precision_helper.dart';
import '../../models/order_types.dart';
import '../../utils/app_logger.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/app_switch_tile.dart';
import '../../routes/app_pages.dart';
import 'dashboard_screen.dart';
import 'pending_order_content.dart';
import 'pending_order_screen.dart';
import '../../services/one_click_trading_service.dart';
import '../../services/one_click_trading_queue_service.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import '../../services/symbol_selection_service.dart';
import 'search_instruments_screen.dart';
import '../../services/symbol_details_cache_service.dart';
import '../../services/theme_service.dart';

class ChartScreen extends StatefulWidget {
  final Function(int?)?
  onNavigateToTrade; // Optional tab parameter: null = Market (0), or specify tab index
  final Function(int)? onNavigateToTab; // Bottom navigation index (0..4)

  const ChartScreen({super.key, this.onNavigateToTrade, this.onNavigateToTab});

  // Static method to set symbol from instruments screen
  static void setSelectedSymbol(String symbol) {
    print("🚀 ChartScreen: setSelectedSymbol called with: $symbol");
    try {
      final selectionService =
          Get.isRegistered<SymbolSelectionService>()
              ? Get.find<SymbolSelectionService>()
              : Get.put(SymbolSelectionService(), permanent: true);
      selectionService.setSymbol(symbol);
      _selectedSymbolNotifier.value = symbol;
      print("🚀 ChartScreen: Symbol successfully set to: $symbol");
    } catch (e) {
      print("🚨 ChartScreen: Error setting symbol: $e");
    }
  }

  // Static ValueNotifier to handle symbol changes
  static final ValueNotifier<String> _selectedSymbolNotifier = ValueNotifier(
    'XAUUSD',
  );

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> with WidgetsBindingObserver {
  final LanguageService languageService = Get.find<LanguageService>();
  double volume = 0.01;
  String selectedTimeframe = '15s';
  String selectedChartType = 'Candlestick';
  String selectedSymbol = ''; // Dynamic - will be set from instruments data

  // Used for chart backend feed mapping (`datafeed_symbol`).
  // Populated via SymbolDetailsCacheService for the active account.
  String _datafeedSymbolForSelected = '';
  String _lastSymbolForDatafeedLookup = '';
  bool _isFetchingDatafeedSymbol = false;
  String _lastDebugPrintedChartUrl = '';

  bool useTradingView = true;
  final ValueNotifier<String> selectedPriceType = ValueNotifier('Asset Price');

  late TextEditingController _volumeController;
  late TextEditingController _takeProfitController;
  late TextEditingController _stopLossController;
  late TextEditingController _limitPriceController;
  late TextEditingController distanceController;
  VoidCallback? _distanceListener;

  // Get controllers
  final AccountController accountController = Get.find<AccountController>();
  final InstrumentsController instrumentsController =
      Get.find<InstrumentsController>();
  late ChartSocketController chartSocketController;
  late ChartController chartController;
  late AppNotificationController notificationController;
  late SymbolSelectionService symbolSelectionService;

  Map<String, dynamic>? realTimePrice;
  bool isLoading = true;
  bool _isPlacingOrder = false; // Prevent multiple order executions
  String? errorMessage;

  // Trading Order Bottom Sheet State with ValueNotifier
  final ValueNotifier<int> _selectedOrderTab = ValueNotifier(
    0,
  ); // 0: Market Order, 1: Pending Order
  final ValueNotifier<int> _selectedPendingOrderType = ValueNotifier(
    1,
  ); // 0: Sell Limit/Sell Stop, 1: Buy Limit/Buy Stop
  // Selected order type from dropdown (Buy Limit, Sell Limit, Buy Stop, Sell Stop)
  final ValueNotifier<String> _selectedOrderType = ValueNotifier('Buy Limit');

  final ValueNotifier<double> _openPrice = ValueNotifier(1.15505);
  final ValueNotifier<double> _distance = ValueNotifier(40.0);
  final ValueNotifier<bool> _takeProfitEnabled = ValueNotifier(false);
  final ValueNotifier<bool> _stopLossEnabled = ValueNotifier(false);
  final ValueNotifier<bool> _advanceSettingsEnabled = ValueNotifier(false);
  final ValueNotifier<bool> _trailingStopEnabled = ValueNotifier(false);
  final ValueNotifier<bool> _orderExpirationEnabled = ValueNotifier(false);
  final ValueNotifier<DateTime> _orderExpirationDate = ValueNotifier(
    DateTime.now(),
  );
  final ValueNotifier<DateTime> _orderExpirationTime = ValueNotifier(
    DateTime.now(),
  );
  final ValueNotifier<bool> _breakEvenEnabled = ValueNotifier(false);
  final ValueNotifier<double> _takeProfitPrice = ValueNotifier(1.15550);
  final ValueNotifier<double> _stopLossPrice = ValueNotifier(1.15448);
  final ValueNotifier<bool> _whenPriceIsEnabled = ValueNotifier(false);

  // Real-time price validation
  final ValueNotifier<String?> _limitPriceError = ValueNotifier(null);
  final ValueNotifier<String?> _stopLossError = ValueNotifier(null);
  final ValueNotifier<String?> _takeProfitError = ValueNotifier(null);
  final ValueNotifier<double> _limitPrice = ValueNotifier(1.15505);

  // ✅ PERFORMANCE OPTIMIZATION: Reactive price variables
  // Changed from double? to Rx<double?> to avoid full widget rebuilds
  // Now only price text widgets update, not the entire screen
  final Rx<double?> currentBidPrice = Rx<double?>(null);
  final Rx<double?> currentAskPrice = Rx<double?>(null);

  // Stream subscriptions to be cancelled on dispose
  StreamSubscription<dynamic>? _priceStreamSubscription1;
  StreamSubscription<dynamic>? _priceStreamSubscription2;
  Timer? _tradesInjectDebounce;
  String _lastTradesSignature = '';

  // GetX reactive listener worker to be disposed
  Worker? _instrumentsWorker;

  // GlobalKey to access WebView state for explicit symbol updates
  final GlobalKey<ChartInAppWebViewState> _webViewKey =
      GlobalKey<ChartInAppWebViewState>();

  // Helper method to remove symbol suffixes (.c, .r, etc.)
  // IMPORTANT: Use this ONLY for display and chart iframe
  // NEVER use this for order placement or socket events - they need original symbol (as received)
  //
  // Handles both cases:
  // - Symbol WITH suffix: "EURUSD.c" → returns "EURUSD" (for display)
  // - Symbol WITHOUT suffix: "EURUSD" → returns "EURUSD" (unchanged)
  String _removeSymbolSuffix(String symbol) {
    // If symbol has suffix (contains '.'), remove it for display
    // If symbol has no suffix, return as-is
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol; // No suffix, return original
  }

  // Get current digits from WebSocket price data
  // Returns the number of decimal places to use for price formatting
  // Defaults to 5 if digits cannot be retrieved (most forex pairs use 5)
  int _getCurrentDigits() {
    final priceData = chartSocketController.getCurrentPrice();
    if (priceData != null && priceData.containsKey('digits')) {
      final digits = int.tryParse(priceData['digits'].toString()) ?? 5;
      return digits;
    }
    return 5; // Default fallback for most forex pairs
  }

  // Helper methods for instrument list display (same as instruments screen)

  List<TextSpan> _buildPriceTextSpans(dynamic price, Color color, int digits) {
    // Keep only 4 digits after decimal
    String priceStr = PrecisionHelper.formatPrice(price, decimals: digits);

    // Split into integer + decimal parts
    int dotIndex = priceStr.indexOf(".");
    String firstPart = priceStr; // default full number
    String secondPart = "";

    if (dotIndex != -1) {
      firstPart = priceStr.substring(0, dotIndex + 1); // number + "."
      secondPart = priceStr.substring(dotIndex + 1); // 4 decimals
    }

    // Decide color (example rule)
    // Color color = price % 2 == 0 ? Colors.green : Colors.red;

    return [
      TextSpan(
        text: firstPart,
        style: TextStyle(
          fontSize: 12.sp,
          color: color,
          fontWeight: FontWeight.normal,
        ),
      ),
      if (secondPart.isNotEmpty)
        TextSpan(
          text: secondPart,
          style: TextStyle(
            fontSize: 16.sp,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];
  }

  // List<TextSpan> _buildPriceTextSpans(dynamic price, Color color, int digits) {
  //   // Keep only specified digits after decimal
  //   String priceStr = PrecisionHelper.formatPrice(price, decimals: digits);

  //   // Split into integer + decimal parts
  //   int dotIndex = priceStr.indexOf(".");
  //   String firstPart = priceStr; // default full number
  //   String secondPart = "";

  //   if (dotIndex != -1) {
  //     firstPart = priceStr.substring(0, dotIndex + 1); // number + "."
  //     secondPart = priceStr.substring(dotIndex + 1); // decimals
  //   }

  //   return [
  //     TextSpan(
  //       text: firstPart,
  //       style: TextStyle(
  //         fontSize: 14,
  //         color: color,
  //         fontWeight: FontWeight.normal,
  //       ),
  //     ),
  //     if (secondPart.isNotEmpty)
  //       TextSpan(
  //         text: secondPart,
  //         style: TextStyle(
  //           fontSize: 20,
  //           color: color,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //   ];
  // }

  String _formatSpreadDiff(double spreadDiff) {
    // Convert to string and remove leading zeros and decimal point
    String formatted = spreadDiff.toString();

    // Remove leading zeros and decimal point
    // For example: 0.00003 -> 3, 0.03 -> 3, 0.0012 -> 12
    if (formatted.contains('.')) {
      // Split by decimal point
      List<String> parts = formatted.split('.');
      String integerPart = parts[0];
      String decimalPart = parts[1];

      // If integer part is 0, remove it and leading zeros from decimal part
      if (integerPart == '0') {
        // Remove leading zeros from decimal part
        String trimmedDecimal = decimalPart.replaceFirst(RegExp(r'^0+'), '');
        return trimmedDecimal.isEmpty ? '0' : trimmedDecimal;
      } else {
        // If integer part is not 0, return it
        return integerPart;
      }
    }

    return formatted;
  }

  @override
  void initState() {
    super.initState();

    try {
      print('🚀 ChartScreen: Initializing...');

      symbolSelectionService =
          Get.isRegistered<SymbolSelectionService>()
              ? Get.find<SymbolSelectionService>()
              : Get.put(SymbolSelectionService(), permanent: true);
      selectedSymbol =
          symbolSelectionService.currentSymbol.isNotEmpty
              ? symbolSelectionService.currentSymbol
              : 'XAUUSD';
      ChartScreen._selectedSymbolNotifier.value = selectedSymbol;
      _loadPersistedSymbol();

      // Add lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      // Initialize chart socket controller (like instrument controller)
      if (Get.isRegistered<ChartSocketController>()) {
        chartSocketController = Get.find<ChartSocketController>();
        print('🚀 ChartScreen: Using existing ChartSocketController');
      } else {
        chartSocketController = Get.put(ChartSocketController());
        print('🚀 ChartScreen: Created new ChartSocketController');
      }

      // Initialize chart controller (like instrument controller)
      if (Get.isRegistered<ChartController>()) {
        chartController = Get.find<ChartController>();
        print('🚀 ChartScreen: Using existing ChartController');
      } else {
        chartController = Get.put(ChartController());
        print('🚀 ChartScreen: Created new ChartController');
      }

      // Initialize One Click Trading Queue Service
      OneClickTradingQueueService.instance.initialize(
        chartController: chartController,
        accountController: accountController,
      );
      print('🚀 ChartScreen: OneClickTradingQueueService initialized');

      // Initialize App Notification Controller (global)
      if (Get.isRegistered<AppNotificationController>()) {
        notificationController = Get.find<AppNotificationController>();
        print('🚀 ChartScreen: Using existing AppNotificationController');
      } else {
        notificationController = Get.put(
          AppNotificationController(),
          permanent: true,
        );
        print('🚀 ChartScreen: Created new AppNotificationController');
      }

      // ✅ PERFORMANCE OPTIMIZATION: Lazy-load Symbols WebSocket
      // Ensure symbols WebSocket is connected when chart screen opens
      if (Get.isRegistered<TradingWebSocketService>()) {
        final wsService = Get.find<TradingWebSocketService>();
        wsService.ensureSymbolsConnected();
        print('🚀 ChartScreen: Requested symbols WebSocket connection');
      }

      // Listen to symbol changes from instruments screen
      ChartScreen._selectedSymbolNotifier.addListener(
        _onSymbolChangedFromInstruments,
      );

      // Listen to price stream updates
      _listenToPriceUpdates();

      // Initialize with cached or first available instrument from socket data
      _initializeWithFirstInstrument();

      _volumeController = TextEditingController(
        text: PrecisionHelper.formatVolume(volume),
      );
      _takeProfitController = TextEditingController(
        text: PrecisionHelper.formatPrice(_takeProfitPrice.value),
      );
      _stopLossController = TextEditingController(
        text: PrecisionHelper.formatPrice(_stopLossPrice.value),
      );
      _limitPriceController = TextEditingController(
        text: PrecisionHelper.formatPrice(
          _limitPrice.value,
          decimals: _getCurrentDigits(),
        ),
      );
      distanceController = TextEditingController(
        text: PrecisionHelper.formatPrice(_distance.value),
      );

      // Add listener to sync distance controller with value notifier
      _distanceListener = () {
        if (distanceController.text !=
            PrecisionHelper.formatPrice(_distance.value)) {
          distanceController.text = PrecisionHelper.formatPrice(
            _distance.value,
          );
        }
      };
      _distance.addListener(_distanceListener!);

      _loadMockData();
      _initializePriceAlertService();

      // Initialize real-time price data
      _initializePrices();
      _setupPriceListener();

      // Listen to open positions changes for chart injection
      // Use 'ever' from GetX to react to every change in the reactive list
      // Use tradingController as it has the marketPositions list
      final tradingController = Get.find<TradingController>();
      ever(tradingController.marketPositionsRx, (_) {
        _updateTradesOnChart();
      });

      // Also trigger initial update if positions exist
      if (tradingController.marketPositions.isNotEmpty) {
        // Slight delay to ensure WebView is ready (handled by retry in method if needed)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _updateTradesOnChart();
        });
      }
    } catch (e) {
      print('🚀 ChartScreen: Error in initState: $e');
      // Fallback initialization
      _volumeController = TextEditingController(text: '0.02');
      _takeProfitController = TextEditingController(text: '0.00');
      _stopLossController = TextEditingController(text: '0.00');
      _limitPriceController = TextEditingController(text: '0.00000');
      distanceController = TextEditingController(text: '0.00');

      // Don't set hardcoded symbol - let it be dynamic from instruments
      // Symbol will be set from instruments data when available
    }
  }

  /// Inject open trades into the WebView Chart
  void _updateTradesOnChart() {
    if (!mounted || _webViewKey.currentState == null) return;

    try {
      final tradingController = Get.find<TradingController>();
      final positions = tradingController.marketPositions;

      // Debounce frequent socket updates (especially when 100-200+ positions update in batches)
      // to avoid UI jank and "stuck" transitions between tabs.
      _tradesInjectDebounce?.cancel();
      _tradesInjectDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted || _webViewKey.currentState == null) return;

        // Build a lightweight signature first; skip inject if nothing meaningful changed.
        // (orderId + PnL + entry/current prices are enough for chart markers)
        final sb = StringBuffer();
        for (final p in positions) {
          sb
            ..write(p.orderId)
            ..write('|')
            ..write(p.profitLoss)
            ..write('|')
            ..write(p.entryPrice)
            ..write('|')
            ..write(p.currentPrice)
            ..write(';');
        }
        final signature = sb.toString();
        if (signature == _lastTradesSignature) return;
        _lastTradesSignature = signature;

        // Serialize only necessary data for the chart
        final tradesList =
            positions
                .map(
                  (p) => {
                    'id': p.orderId,
                    'symbol': p.symbol,
                    'price': double.tryParse(p.entryPrice) ?? 0.0,
                    'type': p.action.toLowerCase(),
                    'volume': p.volume,
                    'sl': double.tryParse(p.stopLoss) ?? 0.0,
                    'tp': double.tryParse(p.takeProfit) ?? 0.0,
                    'profit': p.profitLoss,
                    'accountId': p.accountId,
                  },
                )
                .toList();

        final jsonString = jsonEncode(tradesList);
        _webViewKey.currentState?.updateNativeTrades(jsonString);
      });
    } catch (e) {
      print('❌ Error injecting trades to chart: $e');
    }
  }

  void _loadPersistedSymbol() {
    Future.microtask(() async {
      await symbolSelectionService.ensureDefault();
      final loadedSymbol = symbolSelectionService.currentSymbol;

      if (!mounted || loadedSymbol.isEmpty) return;

      if (loadedSymbol != selectedSymbol) {
        _handleSymbolChange(loadedSymbol);
      } else if (ChartScreen._selectedSymbolNotifier.value != loadedSymbol) {
        ChartScreen._selectedSymbolNotifier.value = loadedSymbol;
      }
    });
  }

  // Initialize real-time prices
  void _initializePrices() {
    final priceData = chartSocketController.getCurrentPrice();
    if (priceData != null) {
      currentBidPrice.value = chartSocketController.getBidPrice();
      currentAskPrice.value = chartSocketController.getAskPrice();

      // Initialize limit price based on current order type
      if (_selectedPendingOrderType.value == 0) {
        // Sell Limit
        _limitPrice.value = currentBidPrice.value ?? 1.15498;
      } else {
        // Buy Limit
        _limitPrice.value = currentAskPrice.value ?? 1.15514;
      }
    }
  }

  // Setup price listener for real-time updates
  void _setupPriceListener() {
    _priceStreamSubscription1
        ?.cancel(); // Cancel previous subscription if exists
    _priceStreamSubscription1 = chartSocketController.priceStream.listen((
      priceData,
    ) {
      if (mounted) {
        // ✅ PERFORMANCE OPTIMIZATION: Direct reactive updates (no setState)
        // This prevents full widget rebuild - only Obx widgets update
        currentBidPrice.value = chartSocketController.getBidPrice();
        currentAskPrice.value = chartSocketController.getAskPrice();
        _validateLimitPrice();
        _validateStopLoss();
        _validateTakeProfit();
      }
    });
  }

  // Validation methods
  void _validateLimitPrice() {
    final limitPrice = _limitPrice.value;
    final selectedType = _selectedPendingOrderType.value;

    if (selectedType == 0) {
      // Sell Limit
      if (currentBidPrice.value != null &&
          limitPrice <= currentBidPrice.value!) {
        _limitPriceError.value =
            'Sell Limit should be above current price ${PrecisionHelper.formatPrice(currentBidPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _limitPriceError.value = null;
      }
    } else {
      // Buy Limit
      if (currentAskPrice.value != null &&
          limitPrice >= currentAskPrice.value!) {
        _limitPriceError.value =
            'Buy Limit should be below current price ${PrecisionHelper.formatPrice(currentAskPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _limitPriceError.value = null;
      }
    }
  }

  void _validateStopLoss() {
    if (!_stopLossEnabled.value) return;

    final stopLossPrice = _stopLossPrice.value;
    final selectedType = _selectedPendingOrderType.value;

    if (selectedType == 0) {
      // Sell Limit
      if (currentBidPrice.value != null &&
          stopLossPrice <= currentBidPrice.value!) {
        _stopLossError.value =
            'Stop Loss should be above current price ${PrecisionHelper.formatPrice(currentBidPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _stopLossError.value = null;
      }
    } else {
      // Buy Limit
      if (currentAskPrice.value != null &&
          stopLossPrice >= currentAskPrice.value!) {
        _stopLossError.value =
            'Stop Loss should be below current price ${PrecisionHelper.formatPrice(currentAskPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _stopLossError.value = null;
      }
    }
  }

  void _validateTakeProfit() {
    if (!_takeProfitEnabled.value) return;

    final takeProfitPrice = _takeProfitPrice.value;
    final selectedType = _selectedPendingOrderType.value;

    if (selectedType == 0) {
      // Sell Limit
      if (currentAskPrice.value != null &&
          takeProfitPrice >= currentAskPrice.value!) {
        _takeProfitError.value =
            'Take Profit should be below current price ${PrecisionHelper.formatPrice(currentAskPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _takeProfitError.value = null;
      }
    } else {
      // Buy Limit
      if (currentBidPrice.value != null &&
          takeProfitPrice <= currentBidPrice.value!) {
        _takeProfitError.value =
            'Take Profit should be above current price ${PrecisionHelper.formatPrice(currentBidPrice.value!, decimals: _getCurrentDigits())}';
      } else {
        _takeProfitError.value = null;
      }
    }
  }

  // Order placement method
  Future<void> _placePendingOrder() async {
    // Prevent multiple simultaneous calls
    if (_isPlacingOrder) {
      print('⚠️ Order placement already in progress, ignoring duplicate call');
      return;
    }

    // Silently clamp volume to account limits before sending to API.
    // User requested 0.01 min lot floor to prevent auto-jump to 1.0.
    volume = volume.clamp(0.01, _maxLot);
    _volumeController.text = volume.toStringAsFixed(2);

    final activeAccount = accountController.activeMT5Account;
    if (activeAccount == null) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: languageService.tr('chart_no_active_account'),
        );
      }
      return;
    }

    // Set flag to prevent multiple clicks
    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Get the trading controller
      final TradingController tradingController = Get.find<TradingController>();

      // Set current symbol and prices
      // IMPORTANT: Use original symbol WITH suffix
      tradingController.setCurrentSymbol(
        selectedSymbol,
      ); // Original symbol with suffix

      // Determine order type based on current selection
      OrderType orderType;
      if (_whenPriceIsEnabled.value) {
        // Conditional orders (Buy Limit/Sell Limit)
        if (_selectedPendingOrderType.value == 0) {
          orderType = OrderType.sellLimit; // Sell Limit
        } else {
          orderType = OrderType.buyLimit; // Buy Limit
        }
      } else {
        // Market orders
        if (_selectedPendingOrderType.value == 0) {
          orderType = OrderType.sellMarket; // Sell Market
        } else {
          orderType = OrderType.buyMarket; // Buy Market
        }
      }

      // Prepare order parameters - format to avoid floating point precision issues
      final volumeStr = volume.toString();

      // Get decimal digits from price data (default 5 for forex)
      final priceData = chartSocketController.getCurrentPrice();
      final decimals =
          priceData != null && priceData.containsKey('digits')
              ? (int.tryParse(priceData['digits'].toString()) ?? 5)
              : 5;

      // Format values properly to avoid floating point errors like 1.1367749999999999
      // Read from controller first (user's entered value), fallback to ValueNotifier
      final limitPriceControllerValue = _limitPriceController.text.trim();
      final limitPriceFromController =
          limitPriceControllerValue.isNotEmpty
              ? double.tryParse(limitPriceControllerValue)
              : null;

      final price =
          _whenPriceIsEnabled.value
              ? PrecisionHelper.formatPrice(
                PrecisionHelper.parseDouble(
                  (limitPriceFromController != null &&
                          limitPriceFromController > 0)
                      ? limitPriceControllerValue
                      : _limitPrice.value.toString(),
                  decimals: decimals,
                ),
                decimals: decimals,
              )
              : null;

      final takeProfit =
          _takeProfitEnabled.value
              ? PrecisionHelper.formatPrice(
                PrecisionHelper.parseDouble(
                  _takeProfitPrice.value.toString(),
                  decimals: decimals,
                ),
                decimals: decimals,
              )
              : null;

      final stopLoss =
          _stopLossEnabled.value
              ? PrecisionHelper.formatPrice(
                PrecisionHelper.parseDouble(
                  _stopLossPrice.value.toString(),
                  decimals: decimals,
                ),
                decimals: decimals,
              )
              : null;

      // Log the order attempt
      AppLogger.order('''
Placing Order:
- Symbol: $selectedSymbol
- Type: ${orderType.value}
- Volume: $volumeStr
- Price: ${price ?? 'Market'}
- Take Profit: ${takeProfit ?? 'None'}
- Stop Loss: ${stopLoss ?? 'None'}
- MT5 Account: ${activeAccount.metaAccountNumber}
      ''');

      // Place the order using TradingController
      // IMPORTANT: Use original symbol WITH suffix for order placement
      final success = await tradingController.placeTradeOrder(
        symbol:
            selectedSymbol, // Original symbol with suffix (e.g., "EURUSD.c")
        volume: volumeStr,
        orderType: orderType,
        price: price,
        takeProfit: takeProfit,
        stopLoss: stopLoss,
        mt5Account: activeAccount.metaAccountNumber,
      );

      if (success) {
        // Close the bottom sheet immediately (don't wait)
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        // Navigate to trade screen immediately (no delay)
        if (widget.onNavigateToTrade != null) {
          // Pass tab index 1 (Pending) since this is a pending order
          widget.onNavigateToTrade!(1);
        }

        // Show success message (non-blocking)
        CustomToastService.showSuccess(
          title: 'Success',
          message: 'Order placed successfully',
        );

        // Pre-connect WebSocket in background (non-blocking, fire and forget)
        // This ensures instant pending order updates when user switches to Pending tab
        if (Get.isRegistered<TradingWebSocketService>()) {
          final wsService = Get.find<TradingWebSocketService>();
          wsService.ensurePendingOrdersConnection().catchError((e) {
            if (kDebugMode) {
              print(
                'Chart Screen: Error ensuring pending orders connection: $e',
              );
            }
          });
        }

        // Refresh the chart data (non-blocking)
        chartSocketController.forceReconnect();
      } else {
        // Show error message from TradingController
        final errorMessage = tradingController.errorMessage;
        CustomToastService.showError(
          title: 'Error',
          message:
              errorMessage.isNotEmpty ? errorMessage : 'Failed to place order',
        );
      }
    } catch (e) {
      AppLogger.error('Exception in _placePendingOrder: $e', error: e);
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to place order: $e',
      );
    } finally {
      // Always reset the flag
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  void _onSymbolChangedFromInstruments() {
    final newSymbol = ChartScreen._selectedSymbolNotifier.value;
    print('🔄 ChartScreen: Symbol changed from $selectedSymbol to $newSymbol');

    if (newSymbol != selectedSymbol && mounted) {
      print('🔄 CHART SYMBOL CHANGE PROCESS:');
      print('🎯 New Symbol: $newSymbol');
      print('📡 Current Symbol: $selectedSymbol');
      print('🔌 Socket Connected: ${chartSocketController.isConnected.value}');

      // Use the unified symbol change handler
      _handleSymbolChange(newSymbol);
    }
  }

  // Unified method to handle symbol changes from any source
  void _handleSymbolChange(String newSymbol) {
    if (!mounted || newSymbol == selectedSymbol) {
      return;
    }

    print('🔄 CHART SYMBOL CHANGE PROCESS:');
    print('🎯 New Symbol: $newSymbol');
    print('📡 Current Symbol: $selectedSymbol');
    print('🔌 Socket Connected: ${chartSocketController.isConnected.value}');

    setState(() {
      selectedSymbol = newSymbol;
    });
    symbolSelectionService.setSymbol(newSymbol);
    if (ChartScreen._selectedSymbolNotifier.value != newSymbol) {
      ChartScreen._selectedSymbolNotifier.value = newSymbol;
    }

    // Change symbol in socket controller (this will handle disconnect/reconnect)
    _changeChartSymbol(newSymbol);

    // Explicitly trigger WebView update after setState completes
    // Use post-frame callback to ensure widget tree has updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _webViewKey.currentState != null) {
        print('📊 Explicitly updating WebView with symbol: $selectedSymbol');
        // Remove suffix for chart display
        String chartSymbol = selectedSymbol;
        if (chartSymbol.contains('.')) {
          chartSymbol = chartSymbol.substring(0, chartSymbol.lastIndexOf('.'));
        }
        _webViewKey.currentState?.updateSymbol(chartSymbol);
      } else {
        print('⚠️ WebView not ready yet, will update via didUpdateWidget');
        // If WebView isn't ready, schedule another attempt
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && _webViewKey.currentState != null) {
            String chartSymbol = selectedSymbol;
            if (chartSymbol.contains('.')) {
              chartSymbol = chartSymbol.substring(
                0,
                chartSymbol.lastIndexOf('.'),
              );
            }
            _webViewKey.currentState?.updateSymbol(chartSymbol);
          }
        });
      }
    });

    print('✅ ChartScreen: Updated selectedSymbol to $selectedSymbol');
  }

  // Listen to price updates from socket
  void _listenToPriceUpdates() {
    _priceStreamSubscription2
        ?.cancel(); // Cancel previous subscription if exists
    _priceStreamSubscription2 = chartSocketController.priceStream.listen((
      priceData,
    ) {
      if (mounted) {
        //dev.log('Chart: Received price update: $priceData');
        setState(() {
          realTimePrice = priceData;
        });
      }
    });
  }

  // Change chart symbol and update socket
  Future<void> _changeChartSymbol(String newSymbol) async {
    try {
      //dev.log('🔄 CHANGING CHART SYMBOL:');
      //dev.log('🎯 New Symbol: $newSymbol');
      //dev.log(
      // '📡 Current Connection: ${chartSocketController.isConnected.value}',
      // );
      //dev.log(
      // '📊 Current Symbol in Controller: ${chartSocketController.currentSymbol.value}',
      // );

      // Use the improved changeSymbol method
      // IMPORTANT: Pass original symbol WITH suffix to socket controller
      await chartSocketController.changeSymbol(
        newSymbol,
      ); // newSymbol already has suffix

      //dev.log('✅ Chart symbol changed successfully to $newSymbol');
      //dev.log(
      // '📡 New Connection Status: ${chartSocketController.isConnected.value}',
      // );
      //dev.log(
      // '📊 New Symbol in Controller: ${chartSocketController.currentSymbol.value}',
      // );
    } catch (e) {
      //dev.log('❌ Chart: Error changing symbol: $e');
      //dev.log('🔍 Error details: ${e.toString()}');
    }
  }

  Future<void> _initializePriceAlertService() async {
    try {
      await PriceAlertService().initialize();
      // Initialize the monitoring service
      Get.put(PriceAlertMonitorService());
    } catch (e) {
      print('Failed to initialize price alert service: $e');
    }
  }

  void _loadMockData() {
    setState(() {
      isLoading = false;
    });
  }

  void _showPriceAlertDialog() {
    final currentPrice = chartSocketController.getMarketPrice() ?? 1.14252;

    // Get digits from socket data
    final priceData = chartSocketController.getCurrentPrice();
    final digits =
        priceData != null && priceData.containsKey('digits')
            ? (int.tryParse(priceData['digits'].toString()) ?? 5)
            : 5;

    print(
      "Chart: Showing price alert dialog for ${selectedSymbol} at price ${currentPrice} with ${digits} digits",
    );

    // Hide keyboard first to prevent dialog visibility issues
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true, // Ensure dialog is visible above keyboard
      builder:
          (context) => PriceAlertDialog(
            symbol: selectedSymbol,
            currentPrice: currentPrice,
            digits: digits, // Pass digits from socket
          ),
    );
  }

  void _onSymbolChanged(String newSymbol) {
    print('🔄 ChartScreen: _onSymbolChanged called with $newSymbol');
    // Use the unified symbol change handler
    _handleSymbolChange(newSymbol);
  }

  /// Get the flag SVG path based on the instrument symbol
  /// Extracts currency code from symbol (e.g., EURUSD -> EUR)
  /// Returns path like 'assets/svg/flags/eurusd.svg'
  String _getFlagPath(String symbol) {
    // Remove suffix if present (e.g., EURUSD.c -> EURUSD)
    String cleanSymbol =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    // Return path with full symbol lowercase
    return 'assets/svg/flags/${cleanSymbol.toLowerCase()}.svg';
  }

  /// Build flag icon widget with error handling
  Widget _buildFlagIcon(String symbol) {
    final flagPath = _getFlagPath(symbol);

    return FutureBuilder<String?>(
      future: _checkAssetExists(flagPath),
      builder: (context, snapshot) {
        // If asset exists, show SVG
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: SvgPicture.asset(
                flagPath,
                width: 32.w,
                height: 32.h,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        // If asset doesn't exist or error occurred, show fallback
        return _buildFallbackFlag();
      },
    );
  }

  /// Check if asset exists by trying to load it
  Future<String?> _checkAssetExists(String assetPath) async {
    try {
      await DefaultAssetBundle.of(context).load(assetPath);
      return assetPath;
    } catch (e) {
      return null;
    }
  }

  /// Build fallback flag image widget
  Widget _buildFallbackFlag() {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Image.asset(
            'assets/image/noflag.jpeg',
            width: 32.w,
            height: 32.h,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Image.asset(
                  'assets/image/no_flag_icon.png',
                  width: 32.w,
                  height: 32.h,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    _priceStreamSubscription1?.cancel();
    _priceStreamSubscription2?.cancel();
    _tradesInjectDebounce?.cancel();

    // Dispose GetX reactive listener worker
    _instrumentsWorker?.dispose();

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Remove symbol change listener
    ChartScreen._selectedSymbolNotifier.removeListener(
      _onSymbolChangedFromInstruments,
    );

    // Dispose controllers
    _volumeController.dispose();
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _limitPriceController.dispose();
    distanceController.dispose();

    // Dispose ValueNotifiers
    _selectedPendingOrderType.dispose();
    _selectedOrderType.dispose();

    // Remove distance listener
    if (_distanceListener != null) {
      _distance.removeListener(_distanceListener!);
    }

    // Note: Don't delete ChartSocketController here as it might be used elsewhere
    // The controller will be automatically disposed when no longer referenced

    // Clear notifications on dispose
    // Notifications are managed globally, no need to clear here

    super.dispose();
  }

  // Handle app lifecycle changes (simplified like instrument controller)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        //dev.log('Chart Screen: App resumed - checking socket connection');
        if (!chartSocketController.isConnected.value) {
          //dev.log('Chart Screen: Reconnecting socket on app resume');
          chartSocketController.handleAppRestart();
        }
        break;
      case AppLifecycleState.paused:
        //dev.log('Chart Screen: App paused - socket may disconnect');
        break;
      case AppLifecycleState.detached:
        //dev.log('Chart Screen: App detached - closing socket');
        chartSocketController.resetController();
        break;
      case AppLifecycleState.inactive:
        //dev.log('Chart Screen: App inactive');
        break;
      case AppLifecycleState.hidden:
        //dev.log('Chart Screen: App hidden');
        break;
    }
  }

  // Handle when screen becomes visible (when navigating via bottom nav or becoming active)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('📊 Chart Screen: Dependencies changed - ensuring socket is active');

    // Always honor cached/session symbol first
    final cachedSymbol = symbolSelectionService.currentSymbol;
    if (selectedSymbol.isEmpty && cachedSymbol.isNotEmpty && mounted) {
      setState(() {
        selectedSymbol = cachedSymbol;
      });
    }

    // ✅ FIX: Check if symbol was changed from instruments screen (via ValueNotifier)
    // If ValueNotifier has a symbol different from current, use it (from instrument screen)
    final notifierSymbol = ChartScreen._selectedSymbolNotifier.value;
    if (notifierSymbol.isNotEmpty &&
        notifierSymbol != selectedSymbol &&
        mounted) {
      print(
        '📊 Chart Screen: Detected symbol change from ValueNotifier (from instrument screen): $notifierSymbol',
      );
      _handleSymbolChange(notifierSymbol);
      return; // Symbol changed, socket will be initialized in _handleSymbolChange
    }

    // ✅ FIX: If no symbol from instrument screen and selectedSymbol is empty, use XAUUSD default
    if (selectedSymbol.isEmpty && mounted) {
      final defaultSymbol =
          cachedSymbol.isNotEmpty
              ? cachedSymbol
              : ChartScreen._selectedSymbolNotifier.value;
      if (defaultSymbol.isNotEmpty) {
        print(
          '📊 Chart Screen: No symbol set, using default cached/notifier: $defaultSymbol',
        );
        setState(() {
          selectedSymbol = defaultSymbol;
        });
      }
    }

    // Get instruments controller for dynamic symbol initialization
    final instrumentsController = Get.find<InstrumentsController>();

    // Dynamic symbol initialization: Check if we have valid instruments data
    bool isSymbolFromInstruments = false;
    if (instrumentsController.allInstruments.isNotEmpty) {
      // Check if current symbol exists in instruments list (valid symbol)
      isSymbolFromInstruments = instrumentsController.allInstruments.any(
        (instrument) => instrument.symbol == selectedSymbol,
      );

      // ✅ FIX: If symbol is empty or not found in instruments, use preferred instrument
      // Only when user hasn't made a selection in this session
      if ((selectedSymbol.isEmpty || !isSymbolFromInstruments) &&
          !symbolSelectionService.hasUserSelection) {
        final preferredInstrument = _findPreferredInstrument(
          instrumentsController.allInstruments,
        );
        print(
          '📊 Chart: Updating symbol dynamically from instruments: ${preferredInstrument.symbol}',
        );
        setState(() {
          selectedSymbol = preferredInstrument.symbol;
        });
        symbolSelectionService.setSymbol(preferredInstrument.symbol);
        isSymbolFromInstruments = true;
      }
    } else {
      // Instruments not loaded yet - ensure Instruments WebSocket is running
      if (!instrumentsController.isConnected.value) {
        print('📊 Chart: Starting Instruments WebSocket to get symbol data');
        instrumentsController.startWebSocket();
      }
    }

    // ✅ FIX: Initialize socket if we have a valid symbol
    // This ensures socket connects/subscribes even when navigating from bottom nav
    if (selectedSymbol.isNotEmpty) {
      print('📊 Chart: Initializing socket for symbol: $selectedSymbol');
      chartSocketController.initializeSocketForSymbol(selectedSymbol);
    } else {
      print('📊 Chart: Waiting for instruments to load...');
      // The _initializeWithFirstInstrument() will handle this via ever() listener
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Ensure DashboardController WebSocket is initialized in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (Get.isRegistered<DashboardController>()) {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.ensureWebSocketInitialized();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Chart Screen: Error ensuring WebSocket initialization: $e');
        }
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isLargeScreen = screenWidth > 600;

    // Calculate navigation bar height dynamically
    final navBarHeight =
        45.h + // Item height
        16.h + // Internal vertical padding (8.h * 2)
        8.h + // Outer bottom padding
        MediaQuery.of(context).padding.bottom; // Safe area

    if (FlavorConfig.isVantage()) {
      final primary = FlavorConfig.instance.primaryColor;
      final baseBg = AppColors.background;
      final chartFlex = isSmallScreen ? 16 : (isLargeScreen ? 20 : 18);

      return VantageChartLayout(
        titleWidget: Obx(
          () => VantageSymbolDropdown(
            selectedSymbol: selectedSymbol,
            favorites: instrumentsController.favoriteInstruments.toList(),
            formatLabel: _removeSymbolSuffix,
            onSymbolSelected: _onSymbolChanged,
            onEmptyTap:
                () => _openSearchInstrumentsSheet(
                  onSymbolPicked: _onSymbolChanged,
                ),
          ),
        ),
        actions: [_buildTradeHistoryButton(compact: true)],
        backgroundColor: baseBg,
        primaryColor: primary,
        chartFlex: chartFlex,
        chart: _buildChartArea(),
        controlDock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVantageQuantityAndActionsRow(),
            SizedBox(height: 8.h),
            _buildVantageBuySellRow(),
          ],
        ),
        overlay: _buildNotificationStack(),
      );
    }

    return _buildDefaultScaffold(
      context: context,
      navBarHeight: navBarHeight,
      isSmallScreen: isSmallScreen,
      isLargeScreen: isLargeScreen,
    );
  }

  Widget _buildDefaultScaffold({
    required BuildContext context,
    required double navBarHeight,
    required bool isSmallScreen,
    required bool isLargeScreen,
  }) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  flex:
                      isSmallScreen
                          ? 3
                          : isLargeScreen
                          ? 4
                          : 3,
                  child: _buildChartArea(),
                ),
                _buildVolumeInputScreen(context, true),
                _buildTradingControls(),
                _buildInteractiveIcons(),
                SizedBox(height: navBarHeight + 8.h),
              ],
            ),
            _buildNotificationStack(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    final symbolSelector = GestureDetector(
      onTap: () => _showSymbolSelector(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8.w : 12.w,
          vertical: isSmallScreen ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackGround,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Text(
              _removeSymbolSuffix(selectedSymbol),
              style: AppTextStyles.label.copyWith(
                fontSize: isSmallScreen ? 12.sp : 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.w),
            // // Chart socket connection status indicator
            // Obx(() {
            //   if (chartSocketController.isReconnecting.value) {
            //     return SizedBox(
            //       width: 12.w,
            //       height: 12.h,
            //       child: CircularProgressIndicator(
            //         strokeWidth: 2,
            //         valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            //       ),
            //     );
            //   } else if (chartSocketController.isConnected.value) {
            //     return Container(
            //       width: 8.w,
            //       height: 8.h,
            //       decoration: BoxDecoration(
            //         color: AppColors.green,
            //         shape: BoxShape.circle,
            //       ),
            //     );
            //   } else {
            //     return GestureDetector(
            //       onTap: () => chartSocketController.manualReconnect(),
            //       child: Container(
            //         width: 8.w,
            //         height: 8.h,
            //         decoration: BoxDecoration(
            //           color: AppColors.red,
            //           shape: BoxShape.circle,
            //         ),
            //       ),
            //     );
            //   }
            // }),
            // SizedBox(width: 4.w),
            Icon(
              Icons.keyboard_arrow_down,
              size: isSmallScreen ? 14.h : 16.h,
              color: AppColors.textGrey,
            ),
          ],
        ),
      ),
    );

    // ✅ Get floating P&L from trading controller
    final tradingController = Get.find<TradingController>();

    return Obx(() {
      final double? floatingProfit =
          tradingController.accountInfoRx.value?.profit;

      if (FlavorConfig.isVantage()) {
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                AppBackButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      Get.back();
                    }
                  },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(
                      () => VantageSymbolDropdown(
                        selectedSymbol: selectedSymbol,
                        favorites:
                            instrumentsController.favoriteInstruments.toList(),
                        formatLabel: _removeSymbolSuffix,
                        onSymbolSelected: _onSymbolChanged,
                        onEmptyTap:
                            () => _openSearchInstrumentsSheet(
                              onSymbolPicked: _onSymbolChanged,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return AccountHeaderWidget(
        showSearchIcon: false,
        rightWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTradeHistoryButton(),
            SizedBox(width: 8.w),
            symbolSelector,
          ],
        ),
        floatingProfit: floatingProfit, // ✅ ADD: Show floating P&L
      );
    });
  }

  void _navigateToTradeHistory() {
    if (widget.onNavigateToTrade != null) {
      widget.onNavigateToTrade!(2);
    }
  }

  Widget _buildTradeHistoryButton({bool compact = false}) {
    final size = compact ? 40.0 : 38.0;
    final borderRadius = compact ? 14.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 8.w : 0),
      child: Tooltip(
        message: languageService.tr('trade_history'),
        child: InkWell(
          onTap: _navigateToTradeHistory,
          borderRadius: BorderRadius.circular(borderRadius.r),
          child: SizedBox(
            height: size.h,
            width: size.w,
            child: Center(
              child: Icon(
                Icons.manage_history_rounded,
                color: AppColors.primary,
                size: 24.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartArea() {
    final displaySymbol = _removeSymbolSuffix(selectedSymbol);
    final ThemeService? themeService =
        Get.isRegistered<ThemeService>() ? Get.find<ThemeService>() : null;

    // Always pass only light/dark to the chart URL.
    // If user selected System in MoreScreen, resolve it to current platform brightness.
    final String themeParam = themeService != null
        ? (themeService.isDarkResolved ? 'dark' : 'light')
        : (AppColors.isDarkMode ? 'dark' : 'light');

    // Dynamic lookup: if symbol changed, try to fetch cached `datafeed_symbol`
    // for the active account. Must be non-blocking (no await in build).
    if (selectedSymbol.isNotEmpty &&
        selectedSymbol != _lastSymbolForDatafeedLookup &&
        !_isFetchingDatafeedSymbol) {
      final symbolToLookup = selectedSymbol;
      _lastSymbolForDatafeedLookup = selectedSymbol;
      _datafeedSymbolForSelected = '';
      _isFetchingDatafeedSymbol = true;

      Future(() async {
        final accountNumber =
            accountController.activeMT5Account?.metaAccountNumber;
        if (accountNumber == null) {
          if (!mounted) return;
          setState(() {
            _datafeedSymbolForSelected = '';
            _isFetchingDatafeedSymbol = false;
          });
          return;
        }

        final accountNumberStr = accountNumber.toString();
        final ok = await SymbolDetailsCacheService.ensureCached(
          accountNumberStr,
        );
        if (!mounted) return;

        if (!ok) {
          setState(() {
            _datafeedSymbolForSelected = '';
            _isFetchingDatafeedSymbol = false;
          });
          return;
        }

        final details = await SymbolDetailsCacheService.getSymbolDetails(
          symbolToLookup,
          accountNumberStr,
        );
        if (!mounted) return;

        final resolvedDatafeedSymbol =
            (details?['datafeed_symbol'] ?? '').toString();

        // Avoid applying stale results if symbol changed during fetch.
        if (symbolToLookup != _lastSymbolForDatafeedLookup) return;

        setState(() {
          // If API value isn't available, fallback to display symbol.
          _datafeedSymbolForSelected =
              resolvedDatafeedSymbol.isNotEmpty ? resolvedDatafeedSymbol : '';
          _isFetchingDatafeedSymbol = false;
        });
      });
    }

    final effectiveDatafeedSymbol =
        _datafeedSymbolForSelected.isNotEmpty
            ? _datafeedSymbolForSelected
            : displaySymbol;

    final chartUrl =
        '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$effectiveDatafeedSymbol&theme=$themeParam';

    if (kDebugMode && chartUrl != _lastDebugPrintedChartUrl) {
      _lastDebugPrintedChartUrl = chartUrl;
      debugPrint('📈 Chart URL: $chartUrl');
    }
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4, // Responsive height
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,

      // margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ChartInAppWebView(
        key: _webViewKey,
        symbol: selectedSymbol,
        // Removed ValueKey to allow didUpdateWidget to handle symbol changes
        // This enables JavaScript-based updates instead of full widget recreation
        url: chartUrl,
      ),
    );
  }

  /// Build notification stack overlay (only shown when one-click trading is enabled)
  /// NOTE: Notifications are now handled globally via AppNotificationStack in main.dart
  /// This method is kept for backward compatibility but returns empty widget
  Widget _buildNotificationStack() {
    // Notifications are now shown globally via AppNotificationStack
    // No need for chart-specific notification stack
    return const SizedBox.shrink();
  }

  // Helper method to find XAUUSD or fallback to first instrument
  ListElement _findPreferredInstrument(List<ListElement> instruments) {
    if (instruments.isEmpty) {
      throw StateError(
        'Cannot find preferred instrument: instruments list is empty',
      );
    }

    // First, try to find XAUUSD with suffix (.c, .r, etc.)
    var xauusd = instruments.firstWhere((instrument) {
      final symbol = instrument.symbol.toUpperCase();
      return symbol == 'XAUUSD.C' ||
          symbol == 'XAUUSD.R' ||
          symbol.startsWith('XAUUSD.');
    }, orElse: () => instruments.first);

    // If found XAUUSD (not the first instrument), return it
    if (xauusd.symbol.toUpperCase().contains('XAUUSD')) {
      return xauusd;
    }

    // If not found, try XAUUSD without suffix
    xauusd = instruments.firstWhere(
      (instrument) => instrument.symbol.toUpperCase() == 'XAUUSD',
      orElse: () => instruments.first,
    );

    // Return XAUUSD if found, otherwise first instrument
    return xauusd.symbol.toUpperCase() == 'XAUUSD' ? xauusd : instruments.first;
  }

  // Initialize chart with first available instrument from socket data
  // Prioritizes XAUUSD on first run, falls back to first instrument
  void _initializeWithFirstInstrument() {
    final instrumentsController = Get.find<InstrumentsController>();

    // If we already have a cached symbol (default or user-selected), use it.
    final cachedSymbol = symbolSelectionService.currentSymbol;
    if (cachedSymbol.isNotEmpty) {
      if (selectedSymbol != cachedSymbol && mounted) {
        setState(() {
          selectedSymbol = cachedSymbol;
        });
      }
      chartSocketController.initializeSocketForSymbol(selectedSymbol);
      return;
    }

    //dev.log('🔵 INITIALIZING CHART WITH FIRST INSTRUMENT:');
    //dev.log(
    // '📊 Available instruments: ${instrumentsController.allInstruments.length}',
    // );
    //dev.log(
    // '📋 Instruments list: ${instrumentsController.allInstruments.map((e) => e.symbol).toList()}',
    // );

    // Wait for instruments data to be available
    if (instrumentsController.allInstruments.isNotEmpty) {
      final preferredInstrument = _findPreferredInstrument(
        instrumentsController.allInstruments,
      );
      //dev.log('🎯 Preferred instrument: ${preferredInstrument.symbol}');
      //dev.log('💰 Preferred instrument bid: ${preferredInstrument.bid}');
      //dev.log('💰 Preferred instrument ask: ${preferredInstrument.ask}');

      setState(() {
        selectedSymbol = preferredInstrument.symbol;
      });

      //dev.log('✅ Selected symbol set to: $selectedSymbol');

      // Initialize socket for the preferred instrument
      //dev.log('🔌 Initializing socket for preferred instrument: $selectedSymbol');
      chartSocketController.initializeSocketForSymbol(selectedSymbol);
    } else {
      //dev.log('⏳ No instruments available yet, waiting...');
      //dev.log('🔄 Setting up listener for instruments updates...');

      // If no instruments available yet, listen for updates
      _instrumentsWorker?.dispose(); // Dispose previous worker if exists
      _instrumentsWorker = ever(instrumentsController.allInstruments, (
        List<ListElement> instruments,
      ) {
        //dev.log(
        // '🔄 Instruments list updated: ${instruments.length} instruments',
        // );
        //dev.log(
        // '📋 New instruments: ${instruments.map((e) => e.symbol).toList()}',
        // );

        // Dynamic initialization: Check if current symbol is valid in instruments
        bool isSymbolValid = instruments.any(
          (instrument) => instrument.symbol == selectedSymbol,
        );

        // If instruments loaded and symbol is empty or invalid, use preferred instrument
        if (instruments.isNotEmpty &&
            (selectedSymbol.isEmpty || !isSymbolValid)) {
          final preferredInstrument = _findPreferredInstrument(instruments);
          //dev.log(
          // '🎯 Instruments loaded, using preferred: ${preferredInstrument.symbol}',
          // );
          //dev.log('💰 Preferred instrument bid: ${preferredInstrument.bid}');
          //dev.log('💰 Preferred instrument ask: ${preferredInstrument.ask}');

          if (mounted) {
            setState(() {
              selectedSymbol = preferredInstrument.symbol;
            });
          }

          //dev.log('✅ Selected symbol set to: $selectedSymbol');

          // Initialize socket for the preferred instrument
          //dev.log(
          // '🔌 Initializing socket for preferred instrument: $selectedSymbol',
          // );
          chartSocketController.initializeSocketForSymbol(selectedSymbol);
        }
      });
    }
  }

  // Helper function to get flag emoji for symbol
  // String _getFlagForSymbol(String symbol) {
  //   // Currency pairs
  //   if (symbol.contains('EUR')) return '🇪🇺';
  //   if (symbol.contains('USD')) return '🇺🇸';
  //   if (symbol.contains('GBP')) return '🇬🇧';
  //   if (symbol.contains('JPY')) return '🇯🇵';
  //   if (symbol.contains('CHF')) return '🇨🇭';
  //   if (symbol.contains('CAD')) return '🇨🇦';
  //   if (symbol.contains('AUD')) return '🇦🇺';
  //   if (symbol.contains('NZD')) return '🇳🇿';

  //   // Metals
  //   if (symbol.contains('XAU')) return '🥇';
  //   if (symbol.contains('XAG')) return '🥈';

  //   // Indices
  //   if (symbol.contains('AU200')) return '🇦🇺';
  //   if (symbol.contains('DE40')) return '🇩🇪';
  //   if (symbol.contains('ES35')) return '🇪🇸';
  //   if (symbol.contains('EU50')) return '🇪🇺';
  //   if (symbol.contains('FR40')) return '🇫🇷';
  //   if (symbol.contains('HK50')) return '🇭🇰';

  //   // Crypto
  //   if (symbol.contains('BTC')) return '₿';
  //   if (symbol.contains('ETH')) return 'Ξ';

  //   // Default
  //   return '📈';
  // }

  void _openSearchInstrumentsSheet({void Function(String)? onSymbolPicked}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppColors.tradeBackgroundCenterColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            child: SearchInstrumentsScreen(
              onNavigateToChart: (symbol) {
                Navigator.of(sheetContext).pop();
                if (onSymbolPicked != null) {
                  onSymbolPicked(symbol);
                } else {
                  _onSymbolChanged(symbol);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showSymbolSelector() {
    if (!FlavorConfig.isVantage()) {
      _openSearchInstrumentsSheet();
      return;
    }

    final favorites = instrumentsController.favoriteInstruments.toList();
    if (favorites.isEmpty) {
      _openSearchInstrumentsSheet(onSymbolPicked: _onSymbolChanged);
      return;
    }

  }

  Widget _buildInteractiveIcons() {
    final isVantage = FlavorConfig.isVantage();

    // Tenax/default: keep the old (original) look.
    if (!isVantage) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Get.to(
                    () => PendingOrderScreen(
                      symbol: selectedSymbol,
                      onNavigateToTrade: widget.onNavigateToTrade,
                    ),
                  );
                },
                child: SizedBox(
                  height: 52.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7.r),
                      color: AppColors.primary,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Text(
                          languageService.tr('chart_pending_order_header'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelOnTradeButton,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            GestureDetector(
              onTap: () {
                _showPriceAlertDialog();
              },
              child: Container(
                height: 52.h,
                width: 45.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7.r),
                  color: AppColors.cardBackGround,
                ),
                child: Icon(Icons.notifications, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Get.to(
                  () => PendingOrderScreen(
                    symbol: selectedSymbol,
                    onNavigateToTrade: widget.onNavigateToTrade,
                  ),
                );
              },
              child: SizedBox(
                height: 40.h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        Color.alphaBlend(
                          AppColors.accent.withOpacity(0.35),
                          AppColors.primary,
                        ),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pending_actions_rounded,
                          size: 18.sp,
                          color: AppColors.whiteColor,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            languageService.tr('chart_pending_order_header'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelOnTradeButton,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),

          GestureDetector(
            onTap: () {
              _showPriceAlertDialog();
            },
            child: Container(
              height: 40.h,
              width: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: AppColors.whiteColor,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: AppColors.primary,
                size: 19.sp,
              ),
              // child: SvgPicture.asset(
              //   "assets/svg/chart_screen_icon/bell_icon.svg",
              //   color: AppColors.primary,
              // ),
            ),
          ),
          // SizedBox(width: 8.w),

          // Debug info button
          // GestureDetector(
          //   onTap: () {
          //     _showPriceDebugInfo();
          //   },
          //   child: Container(
          //     height: 45.h,
          //     width: 45.w,
          //     alignment: Alignment.center,
          //     decoration: BoxDecoration(
          //       borderRadius: BorderRadius.circular(7.r),
          //       color: Colors.blue,
          //     ),
          //     child: Icon(Icons.info, color: AppColors.whiteColor, size: 20.sp),
          //   ),
          // ),
          // SizedBox(width: 8.w),
          // // Test alert button
          // GestureDetector(
          //   onTap: () {
          //     _testPriceAlert();
          //   },
          //   child: Container(
          //     height: 45.h,
          //     width: 45.w,
          //     alignment: Alignment.center,
          //     decoration: BoxDecoration(
          //       borderRadius: BorderRadius.circular(7.r),
          //       color: Colors.orange,
          //     ),
          //     child: Icon(Icons.bug_report, color: AppColors.whiteColor, size: 20.sp),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildVantageQuantityAndActionsRow() {
    final primary = AppColors.isDarkMode ? Colors.white : FlavorConfig.instance.primaryColor;
    final baseBg = AppColors.background;

    Widget iconChip({
      required IconData icon,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          height: 40.h,
          width: 40.w,
          child: Center(
            child: Icon(icon, size: 20.sp, color: primary),
          ),
        ),
      );
    }

    final qtyPill = Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          _buildVantageQtyButton(
            icon: Icons.remove,
            onTap: () {
              setState(() {
                final next = double.parse((volume - 0.01).toStringAsFixed(2));
                volume = next < _minLot ? _minLot : next;
                _volumeController.text = volume.toStringAsFixed(2);
              });
            },
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: _volumeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty) return newValue;
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
              style: AppTextStyles.labelOnTradeQuantityDigit.copyWith(
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
                hintText: '0.01',
                hintStyle: AppTextStyles.labelOnTradeQuantityDigit.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                ),
              ),
              onChanged: (value) {
                final newVolume = double.tryParse(value);
                if (newVolume != null && newVolume > 0) {
                  setState(() => volume = newVolume);
                }
              },
              onEditingComplete: () {
                FocusScope.of(context).unfocus();
                final parsed = double.tryParse(_volumeController.text);
                final clamped =
                    (parsed == null || parsed <= 0)
                        ? _minLot
                        : parsed.clamp(_minLot, _maxLot);
                setState(() {
                  volume = double.parse(clamped.toStringAsFixed(2));
                });
                _volumeController.text = volume.toStringAsFixed(2);
              },
            ),
          ),
          SizedBox(width: 8.w),
          _buildVantageQtyButton(
            icon: Icons.add,
            onTap: () {
              setState(() {
                final next = double.parse((volume + 0.01).toStringAsFixed(2));
                volume = next > _maxLot ? _maxLot : next;
                _volumeController.text = volume.toStringAsFixed(2);
              });
            },
          ),
        ],
      ),
    );

    final actionsPill = Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconChip(
            icon: Icons.pending_actions_rounded,
            onTap: () {
              Get.to(
                () => PendingOrderScreen(
                  symbol: selectedSymbol,
                  onNavigateToTrade: widget.onNavigateToTrade,
                ),
              );
            },
          ),
          Container(
            width: 1,
            height: 20.h,
            color: primary.withOpacity(0.10),
          ),
          iconChip(
            icon: Icons.notifications_active_rounded,
            onTap: _showPriceAlertDialog,
          ),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(child: qtyPill),
        SizedBox(width: 10.w),
        actionsPill,
      ],
    );
  }

  Widget _buildVantageQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final primary = AppColors.isDarkMode ? Colors.white : FlavorConfig.instance.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        height: 28.h,
        width: 28.w,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: primary.withOpacity(0.16)),
        ),
        child: Center(
          child: Icon(icon, size: 18.sp, color: primary),
        ),
      ),
    );
  }

  Widget _buildVantageBuySellRow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final primary = AppColors.isDarkMode ? Colors.white : FlavorConfig.instance.primaryColor;

    // Prices from chart socket controller
    final bidPrice = chartSocketController.getBidPrice()?.toString() ?? '0';
    final askPrice = chartSocketController.getAskPrice()?.toString() ?? '0';
    final difference = chartSocketController.getDifference()?.toString() ?? '0';

    Widget sideButton({
      required String label,
      required String price,
      required List<Color> colors,
      required VoidCallback onTap,
    }) {
      final isBuy = label == 'BUY';
      final textColor = (isBuy && AppColors.isDarkMode) ? const Color(0xFF1E1E1E) : Colors.white;
      final subTextColor = (isBuy && AppColors.isDarkMode)
          ? const Color(0xFF1E1E1E).withOpacity(0.8)
          : Colors.white.withOpacity(0.92);

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          height: 44.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(
                    fontSize: isSmallScreen ? 12.sp : 15.sp,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.05,
                  ),
                ),
                Text(
                  price,
                  style: AppTextStyles.button.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spreadChip = SizedBox(
      width: 50.w,
      height: 44.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: primary.withOpacity(0.16)),
        ),
        child: Center(
          child: Text(
            difference,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelOnTradeDifference.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 12.sp,
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: sideButton(
            label: 'SELL',
            price: bidPrice,
            colors: const [
              AppColors.chartRed1,
              AppColors.chartRed2,
            ],
            onTap: () async {
              // Preserve original behavior by delegating to the existing control.
              // Trigger the same sell flow by calling the existing widget handler.
              // (We reuse the same onTap logic by using the existing method.)
              // ignore: unnecessary_statements
              await Future.microtask(() {});
              // Call the original SELL flow by reusing the existing method widget.
              // This keeps logic unchanged and only swaps UI.
              await _onTapSell();
            },
          ),
        ),
        SizedBox(width: 10.w),
        spreadChip,
        SizedBox(width: 10.w),
        Expanded(
          child: sideButton(
            label: 'BUY',
            price: askPrice,
            colors: [
              primary,
              Color.alphaBlend(Colors.black.withOpacity(0.10), primary),
            ],
            onTap: () async {
              await _onTapBuy();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onTapSell() async {
    // Reuse the existing SELL flow by calling the same code path.
    // This method contains only the previously-inline logic (moved unchanged).
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    // NOTE: `isSmallScreen` kept to avoid accidental behavior changes (used in UI only before).
    // ignore: unused_local_variable
    final _ = isSmallScreen;
    // --- BEGIN: extracted from existing SELL onTap (unchanged) ---
    if (accountController.mt5Accounts.isEmpty ||
        accountController.activeMT5Account == null) {
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 3);
      } else {
        Get.to(() => DashboardScreen());
      }
      return;
    }
    setState(() {
      volume = volume.clamp(_minLot, _maxLot);
      _volumeController.text = volume.toStringAsFixed(2);
    });
    final oneClickService = OneClickTradingService.instance;
    final isOneClickEnabled = await oneClickService.isOneClickTradingEnabled();

    if (isOneClickEnabled) {
      final notificationId = notificationController.addTradingNotification(
        symbol: selectedSymbol,
        type: "1",
        volume: volume,
      );
      OneClickTradingQueueService.instance.enqueueTrade(
        type: "1",
        symbol: selectedSymbol,
        volume: volume,
        notificationId: notificationId,
        onTradeComplete: (
          id,
          symbol,
          type,
          volume,
          isSuccess,
          errorMessage,
        ) {
          notificationController.updateTradingNotificationStatus(
            id: id,
            isSuccess: isSuccess,
            errorMessage: errorMessage,
          );
        },
      );
      return;
    }

    if (_isPlacingOrder) return;
    if (_isPlacingOrder) return;

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final result = await chartController.placeTradeOrder(
        mt5Account: "${accountController.activeMT5Account?.metaAccountNumber}",
        symbol: "$selectedSymbol",
        volume: volume,
        type: "1",
        priceSl: "",
        priceTp: "",
        price: "",
      );

      if (result['success'] == true) {
        final orderData = result['orderData'] as Map<String, dynamic>?;
        final responseData = orderData?['data'] as Map<String, dynamic>?;
        final deal = responseData?['deal'] as Map<String, dynamic>?;

        final positionIdValue =
            responseData?['position_id'] ?? deal?['PositionID'];
        final positionId =
            positionIdValue != null ? positionIdValue.toString() : 'N/A';

        final orderIdValue = responseData?['order_id'] ?? deal?['Deal'];
        final orderId = orderIdValue != null ? orderIdValue.toString() : 'N/A';

        final priceValue = deal?['Price'] ?? responseData?['price'];
        final executionPrice =
            priceValue != null ? priceValue.toString() : null;

        final symbolFromResponse = deal?['Symbol']?.toString() ?? selectedSymbol;

        final executionPriceDouble =
            executionPrice != null ? double.tryParse(executionPrice) : null;

        Get.toNamed(
          Routes.ORDER_CONFIRMATION,
          arguments: {
            'orderData': orderData ?? {},
            'symbol': symbolFromResponse,
            'orderType': '1',
            'volume': volume,
            'price': executionPriceDouble,
            'executionPrice': executionPrice,
            'positionId': positionId,
            'orderId': orderId,
            'tabIndex': 0,
            'onNavigateToTrade': widget.onNavigateToTrade,
            'isPlacing': false,
          },
        );

        await Future.delayed(const Duration(milliseconds: 30));
        if (widget.onNavigateToTrade != null) {
          widget.onNavigateToTrade!(0);
        }
      } else {
        CustomToastService.showError(
          title: 'Error',
          message: result['error'] ?? 'Failed to place order',
        );
      }
    } catch (error) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to place order: $error',
      );
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
    }
    // --- END: extracted ---
  }

  Future<void> _onTapBuy() async {
    // Extracted from existing BUY onTap (kept unchanged).
    if (accountController.mt5Accounts.isEmpty ||
        accountController.activeMT5Account == null) {
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 3);
      } else {
        Get.to(() => DashboardScreen());
      }
      return;
    }
    setState(() {
      volume = volume.clamp(_minLot, _maxLot);
      _volumeController.text = volume.toStringAsFixed(2);
    });
    final oneClickService = OneClickTradingService.instance;
    final isOneClickEnabled = await oneClickService.isOneClickTradingEnabled();

    if (isOneClickEnabled) {
      final notificationId = notificationController.addTradingNotification(
        symbol: selectedSymbol,
        type: "buy",
        volume: volume,
      );
      OneClickTradingQueueService.instance.enqueueTrade(
        type: "buy",
        symbol: selectedSymbol,
        volume: volume,
        notificationId: notificationId,
        onTradeComplete: (
          id,
          symbol,
          type,
          volume,
          isSuccess,
          errorMessage,
        ) {
          notificationController.updateTradingNotificationStatus(
            id: id,
            isSuccess: isSuccess,
            errorMessage: errorMessage,
          );
        },
      );
      return;
    }

    if (_isPlacingOrder) return;
    if (_isPlacingOrder) return;

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final result = await chartController.placeTradeOrder(
        mt5Account: "${accountController.activeMT5Account?.metaAccountNumber}",
        symbol: "$selectedSymbol",
        volume: volume,
        type: "buy",
        priceSl: "",
        priceTp: "",
        price: "",
      );

      if (result['success'] == true) {
        final orderData = result['orderData'] as Map<String, dynamic>?;
        final responseData = orderData?['data'] as Map<String, dynamic>?;
        final deal = responseData?['deal'] as Map<String, dynamic>?;

        final positionIdValue =
            responseData?['position_id'] ?? deal?['PositionID'];
        final positionId =
            positionIdValue != null ? positionIdValue.toString() : 'N/A';

        final orderIdValue = responseData?['order_id'] ?? deal?['Deal'];
        final orderId = orderIdValue != null ? orderIdValue.toString() : 'N/A';

        final priceValue = deal?['Price'] ?? responseData?['price'];
        final executionPrice =
            priceValue != null ? priceValue.toString() : null;

        final symbolFromResponse = deal?['Symbol']?.toString() ?? selectedSymbol;

        final executionPriceDouble =
            executionPrice != null ? double.tryParse(executionPrice) : null;

        Get.toNamed(
          Routes.ORDER_CONFIRMATION,
          arguments: {
            'orderData': orderData ?? {},
            'symbol': symbolFromResponse,
            'orderType': 'buy',
            'volume': volume,
            'price': executionPriceDouble,
            'executionPrice': executionPrice,
            'positionId': positionId,
            'orderId': orderId,
            'tabIndex': 0,
            'onNavigateToTrade': widget.onNavigateToTrade,
            'isPlacing': false,
          },
        );

        await Future.delayed(const Duration(milliseconds: 30));
        if (widget.onNavigateToTrade != null) {
          widget.onNavigateToTrade!(0);
        }
      } else {
        CustomToastService.showError(
          title: 'Error',
          message: result['error'] ?? 'Failed to place order',
        );
      }
    } catch (error) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to place order: $error',
      );
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  Widget _buildTradingControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVantage = FlavorConfig.isVantage();
    final primary = AppColors.isDarkMode ? Colors.white : FlavorConfig.instance.primaryColor;

    // Get real-time prices from chart socket controller
    final bidPrice = chartSocketController.getBidPrice()?.toString() ?? '0';
    final askPrice = chartSocketController.getAskPrice()?.toString() ?? '0';
    final difference = chartSocketController.getDifference()?.toString() ?? '0';

    // print('🔵 CHART TRADING CONTROLS:');
    // print('💰 Bid Price: $bidPrice');
    // print('💰 Ask Price: $askPrice');
    // print('🎯 Symbol: $selectedSymbol');
    // print('📊 Real-time Price Data: $realTimePrice');
    // print('📊 Current Price Data: $currentPriceData');
    // print('🔌 WebSocket Connected: ${chartSocketController.isConnected.value}');
    // print(
    //   '📡 Current Symbol in Controller: ${chartSocketController.currentSymbol.value}',
    // );

    // // Try to get the model data
    // final priceDataModel = chartSocketController.getCurrentPriceDataModel();
    // if (priceDataModel != null) {
    //   print('📊 Model Data: $priceDataModel');
    //   print('💰 Model Bid: ${priceDataModel.bid}');
    //   print('💰 Model Ask: ${priceDataModel.ask}');
    //   print('📊 Model Spread: ${priceDataModel.calculatedSpread}');
    // } else {
    //   print('❌ No model data available');
    // }

    final sideFlex = isVantage ? 1 : 3;
    final midFlex = 1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        children: [
          // SELL
          Expanded(
            flex: sideFlex,
            child: GestureDetector(
              onTap: () async {
                    // If no active trading account exists, redirect user to Dashboard to open/select one.
                    if (accountController.mt5Accounts.isEmpty ||
                        accountController.activeMT5Account == null) {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 3);
                      } else {
                        Get.to(() => DashboardScreen());
                      }
                      return;
                    }
                    // Silently clamp volume before placing order.
                    setState(() {
                      volume = volume.clamp(_minLot, _maxLot);
                      _volumeController.text = volume.toStringAsFixed(2);
                    });
                    // Check if One Click Trading is enabled
                    final oneClickService = OneClickTradingService.instance;
                    final isOneClickEnabled =
                        await oneClickService.isOneClickTradingEnabled();

                    if (isOneClickEnabled) {
                      // Add notification immediately with loading status
                      final notificationId = notificationController
                          .addTradingNotification(
                            symbol: selectedSymbol,
                            type: "1",
                            volume: volume,
                          );

                      // Use queue service for background processing
                      // This allows multiple rapid taps without blocking
                      // Pass the notification ID so callback uses the same ID
                      OneClickTradingQueueService.instance.enqueueTrade(
                        type: "1",
                        symbol: selectedSymbol,
                        volume: volume,
                        notificationId: notificationId,
                        onTradeComplete: (
                          id,
                          symbol,
                          type,
                          volume,
                          isSuccess,
                          errorMessage,
                        ) {
                          // Update notification status when trade completes
                          notificationController
                              .updateTradingNotificationStatus(
                                id: id,
                                isSuccess: isSuccess,
                                errorMessage: errorMessage,
                              );
                        },
                      );
                      return; // Exit immediately, trade will process in background
                    }

                    // Original flow - show confirmation screen
                    // Prevent multiple taps only when one-click is disabled
                    if (_isPlacingOrder) return;

                    // Original flow - show confirmation screen
                    // Prevent multiple taps
                    if (_isPlacingOrder) return;

                    // Update UI to show button is pressed (instant feedback)
                    setState(() {
                      _isPlacingOrder = true;
                    });

                    try {
                      // Call API first - no confirmation screen until success
                      final result = await chartController.placeTradeOrder(
                        mt5Account:
                            "${accountController.activeMT5Account?.metaAccountNumber}",
                        symbol: "${selectedSymbol}",
                        volume: volume,
                        type: "1",
                        priceSl: "",
                        priceTp: "",
                        price: "",
                      );

                      if (result['success'] == true) {
                        // Order successful - extract data from API response
                        // API response structure:
                        // {
                        //   "status": true,
                        //   "success": true,
                        //   "message": "Order placed successfully",
                        //   "data": {
                        //     "order_id": 653491,
                        //     "position_id": 674696,
                        //     "deal": {
                        //       "Price": 4194.33,
                        //       "Symbol": "XAUUSD",
                        //       "Volume": 100,
                        //       ...
                        //     }
                        //   }
                        // }
                        final orderData =
                            result['orderData'] as Map<String, dynamic>?;
                        final responseData =
                            orderData?['data'] as Map<String, dynamic>?;
                        final deal =
                            responseData?['deal'] as Map<String, dynamic>?;

                        // Extract position_id from data.position_id
                        final positionIdValue =
                            responseData?['position_id'] ?? deal?['PositionID'];
                        final positionId =
                            positionIdValue != null
                                ? positionIdValue.toString()
                                : 'N/A';

                        // Extract order_id from data.order_id
                        final orderIdValue =
                            responseData?['order_id'] ?? deal?['Deal'];
                        final orderId =
                            orderIdValue != null
                                ? orderIdValue.toString()
                                : 'N/A';

                        // Extract execution price from deal.Price (ONLY from API response)
                        final priceValue =
                            deal?['Price'] ?? responseData?['price'];
                        final executionPrice =
                            priceValue != null ? priceValue.toString() : null;

                        // Extract symbol from deal.Symbol or use selectedSymbol
                        final symbolFromResponse =
                            deal?['Symbol']?.toString() ?? selectedSymbol;

                        // Convert execution price to double (ONLY from API, no fallback to old prices)
                        final executionPriceDouble =
                            executionPrice != null
                                ? double.tryParse(executionPrice)
                                : null;

                        // If price is missing from API, log error but don't use old cached price
                        if (executionPriceDouble == null &&
                            executionPrice != null) {
                          print(
                            '⚠️ Warning: Could not parse execution price: $executionPrice',
                          );
                        }

                        // Show confirmation screen with actual data from API response
                        Get.toNamed(
                          Routes.ORDER_CONFIRMATION,
                          arguments: {
                            'orderData': orderData ?? {},
                            'symbol': symbolFromResponse,
                            'orderType': '1', // Sell order
                            'volume': volume, // Use the volume that was placed
                            'price': executionPriceDouble,
                            'executionPrice': executionPrice,
                            'positionId': positionId,
                            'orderId': orderId,
                            'tabIndex': 0, // Market tab
                            'onNavigateToTrade': widget.onNavigateToTrade,
                            'isPlacing': false,
                          },
                        );

                        // After 30ms, navigate to trade screen
                        await Future.delayed(Duration(milliseconds: 30));

                        if (widget.onNavigateToTrade != null) {
                          widget.onNavigateToTrade!(0); // Market tab
                        }
                      } else {
                        // API validation error - show error and stay on chart screen
                        CustomToastService.showError(
                          title: 'Error',
                          message: result['error'] ?? 'Failed to place order',
                        );
                        // Stay on chart screen - don't navigate
                      }
                    } catch (error) {
                      CustomToastService.showError(
                        title: 'Error',
                        message: 'Failed to place order: $error',
                      );
                      // Stay on chart screen - don't navigate
                    } finally {
                      setState(() {
                        _isPlacingOrder = false;
                      });
                    }
                  },
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 100),
                opacity: _isPlacingOrder ? 0.5 : 1.0,
                child: SizedBox(
                  height: isVantage ? 42.h : 48.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isVantage ? null : AppColors.error,
                      borderRadius: BorderRadius.circular(isVantage ? 16.r : 8.r),
                      gradient:
                          isVantage
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.chartRed1,
                                  Color.alphaBlend(
                                    Colors.black.withOpacity(0.10),
                                    AppColors.chartRed1,
                                  ),
                                ],
                              )
                              : null,
                      boxShadow:
                          isVantage
                              ? [
                                BoxShadow(
                                  color: AppColors.chartRed1.withOpacity(
                                    0.22,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SELL',
                            style: AppTextStyles.button.copyWith(
                              fontSize: isSmallScreen ? 12.sp : 16.sp,
                              fontWeight: FontWeight.w700,
                              color:
                                  isVantage
                                      ? Colors.white
                                      : AppTextStyles.button.color,
                            ),
                          ),
                          Text(
                            bidPrice,
                            style: AppTextStyles.button.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color:
                                  isVantage
                                      ? Colors.white.withOpacity(0.92)
                                      : AppTextStyles.button.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: isSmallScreen ? 8.w : 12.w),

          // SPREAD / DIFFERENCE (center)
          Expanded(
            flex: midFlex,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: 56.w),
              child: SizedBox(
                height: isVantage ? 42.h : 48.h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        isVantage
                            ? AppColors.whiteColor
                            : AppColors.tradeBackgroundCenterColor,
                    borderRadius: BorderRadius.circular(isVantage ? 16.r : 8.r),
                    border:
                        isVantage
                            ? Border.all(
                              color: AppColors.primary.withOpacity(0.12),
                            )
                            : null,
                    boxShadow:
                        isVantage
                            ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ]
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      difference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          isVantage
                              ? AppTextStyles.labelOnTradeDifference.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )
                              : AppTextStyles.labelOnTradeDifference,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: isSmallScreen ? 8.w : 12.w),

          // BUY
          Expanded(
            flex: sideFlex,
            child: GestureDetector(
              onTap: () async {
                    // If no active trading account exists, redirect user to Dashboard to open/select one.
                    if (accountController.mt5Accounts.isEmpty ||
                        accountController.activeMT5Account == null) {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 3);
                      } else {
                        Get.to(() => DashboardScreen());
                      }
                      return;
                    }
                    // Silently clamp volume before placing order.
                    setState(() {
                      volume = volume.clamp(_minLot, _maxLot);
                      _volumeController.text = volume.toStringAsFixed(2);
                    });
                    // Check if One Click Trading is enabled
                    final oneClickService = OneClickTradingService.instance;
                    final isOneClickEnabled =
                        await oneClickService.isOneClickTradingEnabled();

                    if (isOneClickEnabled) {
                      // Add notification immediately with loading status
                      final notificationId = notificationController
                          .addTradingNotification(
                            symbol: selectedSymbol,
                            type: "buy",
                            volume: volume,
                          );

                      // Use queue service for background processing
                      // This allows multiple rapid taps without blocking
                      // Pass the notification ID so callback uses the same ID
                      OneClickTradingQueueService.instance.enqueueTrade(
                        type: "buy",
                        symbol: selectedSymbol,
                        volume: volume,
                        notificationId: notificationId,
                        onTradeComplete: (
                          id,
                          symbol,
                          type,
                          volume,
                          isSuccess,
                          errorMessage,
                        ) {
                          // Update notification status when trade completes
                          notificationController
                              .updateTradingNotificationStatus(
                                id: id,
                                isSuccess: isSuccess,
                                errorMessage: errorMessage,
                              );
                        },
                      );
                      return; // Exit immediately, trade will process in background
                    }

                    // Original flow - show confirmation screen
                    // Prevent multiple taps only when one-click is disabled
                    if (_isPlacingOrder) return;

                    // Original flow - show confirmation screen
                    // Prevent multiple taps
                    if (_isPlacingOrder) return;

                    // Update UI to show button is pressed (instant feedback)
                    setState(() {
                      _isPlacingOrder = true;
                    });

                    try {
                      // Call API first - no confirmation screen until success
                      final result = await chartController.placeTradeOrder(
                        mt5Account:
                            "${accountController.activeMT5Account?.metaAccountNumber}",
                        symbol: "${selectedSymbol}",
                        volume: volume,
                        type: "buy",
                        priceSl: "",
                        priceTp: "",
                        price: "",
                      );

                      if (result['success'] == true) {
                        // Order successful - extract data from API response
                        // API response structure:
                        // {
                        //   "status": true,
                        //   "success": true,
                        //   "message": "Order placed successfully",
                        //   "data": {
                        //     "order_id": 653491,
                        //     "position_id": 674696,
                        //     "deal": {
                        //       "Price": 4194.33,
                        //       "Symbol": "XAUUSD",
                        //       "Volume": 100,
                        //       ...
                        //     }
                        //   }
                        // }
                        final orderData =
                            result['orderData'] as Map<String, dynamic>?;
                        final responseData =
                            orderData?['data'] as Map<String, dynamic>?;
                        final deal =
                            responseData?['deal'] as Map<String, dynamic>?;

                        // Extract position_id from data.position_id
                        final positionIdValue =
                            responseData?['position_id'] ?? deal?['PositionID'];
                        final positionId =
                            positionIdValue != null
                                ? positionIdValue.toString()
                                : 'N/A';

                        // Extract order_id from data.order_id
                        final orderIdValue =
                            responseData?['order_id'] ?? deal?['Deal'];
                        final orderId =
                            orderIdValue != null
                                ? orderIdValue.toString()
                                : 'N/A';

                        // Extract execution price from deal.Price (ONLY from API response)
                        final priceValue =
                            deal?['Price'] ?? responseData?['price'];
                        final executionPrice =
                            priceValue != null ? priceValue.toString() : null;

                        // Extract symbol from deal.Symbol or use selectedSymbol
                        final symbolFromResponse =
                            deal?['Symbol']?.toString() ?? selectedSymbol;

                        // Convert execution price to double (ONLY from API, no fallback to old prices)
                        final executionPriceDouble =
                            executionPrice != null
                                ? double.tryParse(executionPrice)
                                : null;

                        // If price is missing from API, log error but don't use old cached price
                        if (executionPriceDouble == null &&
                            executionPrice != null) {
                          print(
                            '⚠️ Warning: Could not parse execution price: $executionPrice',
                          );
                        }

                        // Show confirmation screen with actual data from API response
                        Get.toNamed(
                          Routes.ORDER_CONFIRMATION,
                          arguments: {
                            'orderData': orderData ?? {},
                            'symbol': symbolFromResponse,
                            'orderType': 'buy', // Buy order
                            'volume': volume, // Use the volume that was placed
                            'price': executionPriceDouble,
                            'executionPrice': executionPrice,
                            'positionId': positionId,
                            'orderId': orderId,
                            'tabIndex': 0, // Market tab
                            'onNavigateToTrade': widget.onNavigateToTrade,
                            'isPlacing': false,
                          },
                        );

                        // After 30ms, navigate to trade screen
                        await Future.delayed(Duration(milliseconds: 30));

                        if (widget.onNavigateToTrade != null) {
                          widget.onNavigateToTrade!(0); // Market tab
                        }
                      } else {
                        // API validation error - show error and stay on chart screen
                        CustomToastService.showError(
                          title: 'Error',
                          message: result['error'] ?? 'Failed to place order',
                        );
                        // Stay on chart screen - don't navigate
                      }
                    } catch (error) {
                      CustomToastService.showError(
                        title: 'Error',
                        message: 'Failed to place order: $error',
                      );
                      // Stay on chart screen - don't navigate
                    } finally {
                      setState(() {
                        _isPlacingOrder = false;
                      });
                    }
                  },
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 100),
                opacity: _isPlacingOrder ? 0.5 : 1.0,
                child: SizedBox(
                  height: isVantage ? 42.h : 48.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isVantage ? null : AppColors.success,
                      borderRadius: BorderRadius.circular(isVantage ? 16.r : 8.r),
                      gradient:
                          isVantage
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primary,
                                  Color.alphaBlend(
                                    Colors.black.withOpacity(0.10),
                                    primary,
                                  ),
                                ],
                              )
                              : null,
                      boxShadow:
                          isVantage
                              ? [
                                BoxShadow(
                                  color: primary.withOpacity(
                                    0.20,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BUY',
                            style: AppTextStyles.button.copyWith(
                              fontSize: isSmallScreen ? 12.sp : 16.sp,
                              fontWeight: FontWeight.w700,
                              color:
                                  isVantage
                                      ? (AppColors.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
                                      : AppTextStyles.button.color,
                            ),
                          ),
                          Text(
                            askPrice.toString(),
                            style: AppTextStyles.button.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color:
                                  isVantage
                                      ? (AppColors.isDarkMode
                                          ? const Color(0xFF1E1E1E).withOpacity(0.8)
                                          : Colors.white.withOpacity(0.92))
                                      : AppTextStyles.button.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lot-size limits from the active MT5 account ────────────────────
  double get _minLot => 0.01; // Hardcoded to 0.01 to prevent jumping to 1.0
  double get _maxLot => accountController.activeMT5Account?.maxLotSize ?? 100.0;

  Widget _buildVolumeInputScreen(BuildContext context, bool isborder) {
    final isVantage = FlavorConfig.isVantage();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isborder ? 10.w : 0,
        vertical: isborder ? (isVantage ? 6.h : 10.h) : 2.h,
      ),
      child: Container(
        height: isVantage ? 44.h : 48.h,
        padding: EdgeInsets.symmetric(horizontal: isVantage ? 10.w : 11.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isborder ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Minus button
            Container(
              height: isVantage ? 22.h : 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // color: AppColors.icongrey,
                border: Border.all(color: AppColors.icongrey),
              ),
              width: isVantage ? 22.w : 24.w,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    final next = double.parse(
                      (volume - 0.01).toStringAsFixed(2),
                    );
                    volume = next < _minLot ? _minLot : next;
                    _volumeController.text = volume.toStringAsFixed(2);
                  });
                },
                icon: Icon(
                  Icons.remove,
                  size: isVantage ? 16.h : 18.h,
                  color: AppColors.icongrey,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),

            // Volume display
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Quantity (lots)',
                    style: AppTextStyles.labelOnTradeQuantity,
                  ),
                  // SizedBox(height: 1.h),
                  TextField(
                    controller: _volumeController,
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
                      // Free typing — volume synced, no mid-keystroke clamping.
                      final newVolume = double.tryParse(value);
                      if (newVolume != null && newVolume > 0) {
                        setState(() => volume = newVolume);
                      }
                    },
                    onEditingComplete: () {
                      // Clamp to [_minLot, _maxLot] when user leaves the field.
                      FocusScope.of(context).unfocus();
                      final parsed = double.tryParse(_volumeController.text);
                      final clamped =
                          (parsed == null || parsed <= 0)
                              ? _minLot
                              : parsed.clamp(_minLot, _maxLot);
                      setState(() {
                        volume = double.parse(clamped.toStringAsFixed(2));
                      });
                      _volumeController.text = volume.toStringAsFixed(2);
                    },
                  ),
                ],
              ),
            ),

            // Plus button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // color: AppColors.icongrey,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              width: isVantage ? 22.w : 24.w,
              height: isVantage ? 22.h : 24.h,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    final next = double.parse(
                      (volume + 0.01).toStringAsFixed(2),
                    );
                    volume = next > _maxLot ? _maxLot : next;
                    _volumeController.text = volume.toStringAsFixed(2);
                  });
                },
                icon: Icon(
                  Icons.add,
                  size: isVantage ? 16.h : 18.h,
                  color: AppColors.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMarketOrderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Volume Input
        _buildVolumeInput(),
        SizedBox(height: 14.h),

        // Monetary Equivalent
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Monetary equivalent',
              style: AppTextStyles.label.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textGrey,
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _openPrice,
              builder: (context, price, child) {
                return Text(
                  '${price.toStringAsFixed(2)}',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: 14.h),

        // Margin Details
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.grey,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required margin',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      '\$6.93',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Free margin',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      '\$4953.85',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Take Profit
        _buildSwitchTile(
          'Take Profit',
          _takeProfitEnabled,
          onChanged: (value) {
            _takeProfitEnabled.value = value;
            if (value) _stopLossEnabled.value = false;
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _takeProfitEnabled,
          builder: (context, enabled, child) {
            if (!enabled) return SizedBox.shrink();
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 236.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 17.0),
                            child: Container(
                              width: 22.w,
                              height: 22.h,
                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_takeProfitPrice.value > 0.01) {
                                      _takeProfitPrice.value = double.parse(
                                        (_takeProfitPrice.value - 0.01)
                                            .toStringAsFixed(2),
                                      );
                                      _takeProfitController
                                          .text = _takeProfitPrice.value
                                          .toStringAsFixed(2);
                                    }
                                  });
                                },
                                icon: Icon(
                                  Icons.remove,
                                  size: 16.h,
                                  color: AppColors.icongrey,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _volumeController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                          TextInputFormatter.withFunction((
                                            oldValue,
                                            newValue,
                                          ) {
                                            final text = newValue.text;
                                            if (text.isEmpty) return newValue;

                                            // Prevent '00', '01' etc.
                                            if (text.length > 1 &&
                                                text.startsWith('0') &&
                                                !text.startsWith('0.')) {
                                              return oldValue;
                                            }

                                            final newDouble = double.tryParse(
                                              text,
                                            );
                                            if (newDouble == null) {
                                              return oldValue;
                                            }
                                            if (newDouble > _maxLot) {
                                              return oldValue;
                                            }
                                            return newValue;
                                          }),
                                        ],
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                          // Free typing — no mid-keystroke clamping.
                                          final newVolume = double.tryParse(
                                            value,
                                          );
                                          if (newVolume != null &&
                                              newVolume > 0) {
                                            setState(() => volume = newVolume);
                                          }
                                        },
                                        onEditingComplete: () {
                                          FocusScope.of(context).unfocus();
                                          final parsed = double.tryParse(
                                            _volumeController.text,
                                          );
                                          final clamped =
                                              (parsed == null || parsed <= 0)
                                                  ? _minLot
                                                  : parsed.clamp(
                                                    _minLot,
                                                    _maxLot,
                                                  );
                                          setState(() {
                                            volume = double.parse(
                                              clamped.toStringAsFixed(2),
                                            );
                                          });
                                          _volumeController.text = volume
                                              .toStringAsFixed(2);
                                        },
                                      ),
                                    ), // Text(
                                    // volume.toStringAsFixed(2),
                                    // style: AppTextStyles.label.copyWith(
                                    // fontSize: 16.sp,
                                    // fontWeight: FontWeight.w700,
                                    // ),
                                    // ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Padding(
                            padding: const EdgeInsets.only(right: 14.0),
                            child: Container(
                              width: 22.w,
                              height: 22.h,
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
                                    _volumeController.text = volume
                                        .toStringAsFixed(2);
                                  });
                                },
                                icon: Icon(
                                  Icons.add,
                                  size: 16.h,
                                  color: AppColors.primary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 96.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: _buildPriceTypeDropdown(),
                    ),
                  ],
                ),

                // _buildPriceInput('1.15550', _takeProfitPrice),
                // SizedBox(height: 4.h),
                // Text(
                //   '68 points | Profit +4.08 USD | +0.08% of balance',
                //   style: AppTextStyles.label.copyWith(
                //     fontSize: 12.sp,
                //     color: AppColors.textGrey,
                //   ),
                // ),
                SizedBox(height: 8.h),
              ],
            );
          },
        ),

        // Stop Loss
        _buildSwitchTile(
          'Stop Loss',
          _stopLossEnabled,
          onChanged: (value) {
            _stopLossEnabled.value = value;
            if (value) _trailingStopEnabled.value = false;
            if (value) _breakEvenEnabled.value = false;
          },
        ),

        // ValueListenableBuilder<bool>(
        //   valueListenable: _stopLossEnabled,
        //   builder: (context, enabled, child) {
        //     if (!enabled) return SizedBox.shrink();
        //     return Column(
        //       children: [
        //         _buildPriceInput('1.15448', _stopLossPrice),
        //         SizedBox(height: 4.h),
        //         Text(
        //           '-37 points | Profit -2.22 USD | -0.04% of balance',
        //           style: AppTextStyles.label.copyWith(
        //             fontSize: 12.sp,
        //             color: AppColors.textGrey,
        //           ),
        //         ),
        //         SizedBox(height: 8.h),
        //       ],
        //     );
        //   },
        // ),
        ValueListenableBuilder<bool>(
          valueListenable: _stopLossEnabled,
          builder: (context, enabled, child) {
            if (!enabled) return SizedBox.shrink();
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 236.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 17.0),
                            child: Container(
                              width: 22.w,
                              height: 22.h,
                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_takeProfitPrice.value > 0.01) {
                                      _takeProfitPrice.value = double.parse(
                                        (_takeProfitPrice.value - 0.01)
                                            .toStringAsFixed(2),
                                      );
                                      _takeProfitController
                                          .text = _takeProfitPrice.value
                                          .toStringAsFixed(2);
                                    }
                                  });
                                },
                                icon: Icon(
                                  Icons.remove,
                                  size: 16.h,
                                  color: AppColors.icongrey,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _volumeController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                          final newVolume = double.tryParse(
                                            value,
                                          );
                                          if (newVolume != null &&
                                              newVolume > 0) {
                                            setState(() {
                                              volume = newVolume;
                                            });
                                          }
                                        },
                                      ),
                                    ), // Text(
                                    // volume.toStringAsFixed(2),
                                    // style: AppTextStyles.label.copyWith(
                                    // fontSize: 16.sp,
                                    // fontWeight: FontWeight.w700,
                                    // ),
                                    // ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Padding(
                            padding: const EdgeInsets.only(right: 14.0),
                            child: Container(
                              width: 22.w,
                              height: 22.h,
                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    volume = double.parse(
                                      (volume + 0.01).toStringAsFixed(2),
                                    );
                                    _volumeController.text = volume
                                        .toStringAsFixed(2);
                                  });
                                },
                                icon: Icon(
                                  Icons.add,
                                  size: 16.h,
                                  color: AppColors.primary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 96.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: _buildPriceTypeDropdown(),
                    ),
                  ],
                ),

                // _buildPriceInput('1.15550', _takeProfitPrice),
                // SizedBox(height: 4.h),
                // Text(
                //   '68 points | Profit +4.08 USD | +0.08% of balance',
                //   style: AppTextStyles.label.copyWith(
                //     fontSize: 12.sp,
                //     color: AppColors.textGrey,
                //   ),
                // ),
                SizedBox(height: 8.h),
              ],
            );
          },
        ),

        // // Advanced Settings
        _buildAdvancedSettings(),

        SizedBox(height: 24.h),

        // Confirm Button
        Container(
          width: double.infinity,
          height: 50.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Confirm Buy order',
                style: AppTextStyles.button.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.whiteColor,
                ),
              ),
              Text(
                '1.15482',
                style: AppTextStyles.button.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to show trade snackbar at the top
  void _showTradeSnackbar(
    String symbol,
    String type,
    double volume,
    bool isSuccess,
  ) {
    if (!mounted || !context.mounted) return;

    final message = '$symbol $type $volume done';

    // Use post-frame callback to avoid draw frame errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;

      try {
        // Use CustomToastService instead of SnackBar to avoid off-screen issues
        CustomToastService.showSuccess(
          message: message,
          duration: Duration(seconds: 2),
          position: SnackPosition.TOP,
        );
      } catch (e) {
        print('Error showing toast: $e');
      }
    });
  }

  // Helper method to execute one-click trade
  // ignore: unused_element
  Future<void> _executeOneClickTrade({
    required String type, // "buy" or "1" (sell)
    required String symbol,
    required double volume,
  }) async {
    // Prevent multiple taps
    if (_isPlacingOrder) return;

    // Update UI to show button is pressed
    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Call API
      final result = await chartController.placeTradeOrder(
        mt5Account: "${accountController.activeMT5Account?.metaAccountNumber}",
        symbol: symbol,
        volume: volume,
        type: type,
        priceSl: "",
        priceTp: "",
        price: "",
      );

      if (result['success'] == true) {
        // Play success sound
        try {
          await AudioService.playSuccessSound();
        } catch (e) {
          print('Error playing success sound: $e');
        }

        // Show snackbar after frame is built
        final typeText = type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';
        if (mounted) {
          _showTradeSnackbar(symbol, typeText, volume, true);
        }

        // Don't force reconnect as it clears prices - prices will update naturally via WebSocket
      } else {
        // Show error notification
        final errorMessage = result['error'] ?? 'Failed to place order';
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: errorMessage,
          );
        }
      }
    } catch (error) {
      // Show error notification
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to place order: $error',
        );
      }
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  // ignore: unused_element
  Widget _buildPendingOrderContent() {
    return PendingOrderContent(
      selectedPendingOrderType: _selectedPendingOrderType,
      selectedOrderType: _selectedOrderType,
      limitPrice: _limitPrice,
      openPrice: _openPrice,
      distance: _distance,
      whenPriceIsEnabled: _whenPriceIsEnabled,
      takeProfitEnabled: _takeProfitEnabled,
      stopLossEnabled: _stopLossEnabled,
      takeProfitPrice: _takeProfitPrice,
      stopLossPrice: _stopLossPrice,
      takeProfitController: _takeProfitController,
      stopLossController: _stopLossController,
      limitPriceController: _limitPriceController,
      onPlaceOrder: _placePendingOrder,
      selectedSymbol: selectedSymbol,
      onVolumeChanged: (newVolume) {
        volume = newVolume;
      },
    );
  }

  Widget _buildVolumeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 236.w,
          height: 50.h,
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 17.0),
                child: Container(
                  width: 22.w,
                  height: 22.h,
                  alignment: Alignment.center,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        if (volume > 0.01) {
                          volume -= 0.01;
                          _volumeController.text = volume.toStringAsFixed(2);
                        }
                      });
                    },
                    icon: Icon(
                      Icons.remove,
                      size: 16.h,
                      color: AppColors.icongrey,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Volume',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _volumeController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
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
                              final newVolume = double.tryParse(value);
                              if (newVolume != null && newVolume > 0) {
                                setState(() {
                                  volume = newVolume;
                                });
                              }
                            },
                          ),
                        ), // Text(
                        // volume.toStringAsFixed(2),
                        // style: AppTextStyles.label.copyWith(
                        // fontSize: 16.sp,
                        // fontWeight: FontWeight.w700,
                        // ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Container(
                  width: 22.w,
                  height: 22.h,
                  alignment: Alignment.center,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        volume += 0.01;
                        _volumeController.text = volume.toStringAsFixed(2);
                      });
                    },
                    icon: Icon(Icons.add, size: 16.h, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 96.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            languageService.tr('chart_label_lots'),
            style: AppTextStyles.label.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildQuentyPendingOrder() {
    return Container(
      height: 117.h,
      width: 343.w,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildVolumeInputScreen(context, false),
          Container(width: double.maxFinite, height: 2, color: AppColors.grey),
          SizedBox(height: 6.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 11.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      languageService.tr('chart_required_margin'),
                      style: AppTextStyles.labelOnChartPendingOrder,
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.info_outline_rounded, size: 16.h),
                  ],
                ),
                Text(
                  "\$0.066%",
                  style: AppTextStyles.labelOnChartPendingOrderBold,
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 11.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageService.tr('chart_free_margin'),
                  style: AppTextStyles.labelOnChartPendingOrder,
                ),
                Text("\$356.68", style: AppTextStyles.labelOnChartPendingOrder),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
                // color: AppColors.icongrey,
                border: Border.all(color: AppColors.icongrey),
              ),
              width: 24.w,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    if (volume > 0.01) {
                      volume -= 0.01;
                      _volumeController.text = volume.toStringAsFixed(2);
                    }
                  });
                },
                icon: Icon(Icons.remove, size: 18.h, color: AppColors.icongrey),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),

            // Volume display
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Quantity (lots)',
                    style: AppTextStyles.labelOnTradeQuantity,
                  ),
                  // SizedBox(height: 1.h),
                  TextField(
                    controller: _volumeController,
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
                      final newVolume = double.tryParse(value);
                      if (newVolume != null && newVolume > 0) {
                        setState(() {
                          volume = newVolume;
                        });
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
                // color: AppColors.icongrey,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              width: 24.w,
              height: 24.h,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    volume += 0.01;
                    _volumeController.text = volume.toStringAsFixed(2);
                  });
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

  // ignore: unused_element
  Widget _buildPriceInputField(
    String label,
    ValueNotifier<double> priceNotifier,
    TextEditingController controller,
  ) {
    return Container(
      width: 236.w,
      height: 50.h,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 17.0),
            child: Container(
              width: 22.w,
              height: 22.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                onPressed: () {
                  if (priceNotifier.value > 0.01) {
                    priceNotifier.value -= 0.01;
                    controller.text = PrecisionHelper.formatPrice(
                      priceNotifier.value,
                      decimals: _getCurrentDigits(),
                    );
                  }
                },
                icon: Icon(Icons.remove, size: 16.h, color: AppColors.icongrey),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
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
                          final newPrice = double.tryParse(value);
                          if (newPrice != null && newPrice > 0) {
                            priceNotifier.value = newPrice;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Container(
              width: 22.w,
              height: 22.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary),
              ),
              child: IconButton(
                onPressed: () {
                  priceNotifier.value += 0.01;
                  controller.text = PrecisionHelper.formatPrice(
                    priceNotifier.value,
                    decimals: _getCurrentDigits(),
                  );
                },
                icon: Icon(Icons.add, size: 16.h, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPriceInput(String label, ValueNotifier<double> priceNotifier) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: priceNotifier,
        builder: (context, price, child) {
          return Row(
            children: [
              Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: IconButton(
                  onPressed: () {
                    if (price > 0.01) priceNotifier.value = price - 0.01;
                  },
                  icon: Icon(Icons.remove, size: 16.h, color: Colors.grey[600]),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    PrecisionHelper.formatPrice(
                      price,
                      decimals: _getCurrentDigits(),
                    ),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
                child: IconButton(
                  onPressed: () {
                    priceNotifier.value = price + 0.01;
                  },
                  icon: Icon(Icons.add, size: 16.h, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
              SizedBox(width: 12.w),
              _buildPriceTypeDropdown(),
            ],
          );
        },
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

  Widget _buildAdvancedSettings() {
    return ValueListenableBuilder<bool>(
      valueListenable: _advanceSettingsEnabled,
      builder: (context, expanded, child) {
        return Column(
          children: [
            GestureDetector(
              onTap: () => _advanceSettingsEnabled.value = !expanded,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Advanced settings',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                      size: 20.h,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              SizedBox(height: 8.h),
              _buildSwitchTile(
                'Trailing stop',
                _trailingStopEnabled,
                onChanged: (value) {
                  _trailingStopEnabled.value = value;
                  if (value) _stopLossEnabled.value = false;
                  if (value) _breakEvenEnabled.value = false;
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _trailingStopEnabled,
                builder: (context, enabled, child) {
                  if (!enabled) return SizedBox.shrink();
                  return Column(
                    children: [
                      SizedBox(height: 8.h),
                      _buildDistanceInput(),
                      SizedBox(height: 8.h),
                    ],
                  );
                },
              ),

              _buildSwitchTile(
                'Break even',
                _breakEvenEnabled,
                onChanged: (value) {
                  _breakEvenEnabled.value = value;
                  if (value) _trailingStopEnabled.value = false;
                  if (value) _stopLossEnabled.value = false;
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _breakEvenEnabled,
                builder: (context, enabled, child) {
                  if (!enabled) return SizedBox.shrink();
                  return Column(
                    children: [
                      SizedBox(height: 8.h),
                      _buildDistanceInput(),
                      SizedBox(height: 8.h),
                    ],
                  );
                },
              ),
              ValueListenableBuilder<int>(
                valueListenable: _selectedOrderTab,
                builder: (context, selectedTab, child) {
                  return selectedTab == 1
                      ? Column(
                        children: [
                          _buildSwitchTile(
                            'Order expiration',
                            _orderExpirationEnabled,
                            onChanged: (value) {
                              _orderExpirationEnabled.value = value;
                            },
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: _orderExpirationEnabled,
                            builder: (context, enabled, child) {
                              if (!enabled) return SizedBox.shrink();
                              return Column(
                                children: [
                                  SizedBox(height: 8.h),
                                  _buildOrderExpirationInput(),
                                  SizedBox(height: 8.h),
                                ],
                              );
                            },
                          ),
                        ],
                      )
                      : SizedBox.shrink();
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOrderExpirationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // First container - Display selected date/time with calendar icon
            InkWell(
              onTap: _selectOrderExpirationDate,
              child: Container(
                width: 150.w,
                height: 50.h,
                padding: EdgeInsets.only(left: 12.w, top: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: _orderExpirationDate,
                        builder: (context, dateTime, child) {
                          return Text(
                            DateFormat('MMM dd, yyyy').format(dateTime),
                            style: AppTextStyles.label.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Third container - Time picker button
            Container(
              width: 150.w,
              height: 50.h,
              padding: EdgeInsets.only(left: 12.w, top: 6.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: InkWell(
                onTap: _selectOrderExpirationTime,
                borderRadius: BorderRadius.circular(8.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _orderExpirationTime,
                      builder: (context, dateTime, child) {
                        return Text(
                          DateFormat('hh:MM').format(dateTime),
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectOrderExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _orderExpirationDate.value,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Keep the current time, only update the date
      final currentDateTime = _orderExpirationDate.value;
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        currentDateTime.hour,
        currentDateTime.minute,
      );
      _orderExpirationDate.value = newDateTime;
    }
  }

  Future<void> _selectOrderExpirationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_orderExpirationTime.value),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Keep the current date, only update the time
      final currentDateTime = _orderExpirationTime.value;
      final newDateTime = DateTime(
        currentDateTime.year,
        currentDateTime.month,
        currentDateTime.day,
        picked.hour,
        picked.minute,
      );
      _orderExpirationTime.value = newDateTime;
    }
  }

  Widget _buildDistanceInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distance, points',
          style: AppTextStyles.label.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 8.h),
        ValueListenableBuilder<double>(
          valueListenable: _distance,
          builder: (context, distance, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 340.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 17.0),
                        child: Container(
                          width: 22.w,
                          height: 22.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (distance > 10) {
                                _distance.value = distance - 10;
                                distanceController.text = _distance.value
                                    .toStringAsFixed(2);
                              }
                            },
                            icon: Icon(
                              Icons.remove,
                              size: 16.h,
                              color: AppColors.icongrey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: distanceController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                      if (value.isNotEmpty) {
                                        try {
                                          double newDistance = double.parse(
                                            value,
                                          );
                                          if (newDistance > 0) {
                                            _distance.value = newDistance;
                                          }
                                        } catch (e) {
                                          // Handle invalid input
                                        }
                                      }
                                    },
                                  ),
                                ), // Text(
                                // volume.toStringAsFixed(2),
                                // style: AppTextStyles.label.copyWith(
                                // fontSize: 16.sp,
                                // fontWeight: FontWeight.w700,
                                // ),
                                // ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Padding(
                        padding: const EdgeInsets.only(right: 14.0),
                        child: Container(
                          width: 22.w,
                          height: 22.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _distance.value = distance + 10;
                              distanceController.text = _distance.value
                                  .toStringAsFixed(2);
                            },
                            icon: Icon(
                              Icons.add,
                              size: 16.h,
                              color: AppColors.primary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            //  Row(
            //   children: [
            //     Container(
            //       width: 32.w,
            //       height: 32.h,
            //       decoration: BoxDecoration(
            //         shape: BoxShape.circle,
            //         border: Border.all(color: Colors.grey[400]!),
            //       ),
            //       child: IconButton(
            //         onPressed: () {
            //           if (distance > 10) _distance.value = distance - 10;
            //         },
            //         icon: Icon(
            //           Icons.remove,
            //           size: 16.h,
            //           color: Colors.grey[600],
            //         ),
            //         padding: EdgeInsets.zero,
            //         constraints: BoxConstraints(),
            //       ),
            //     ),
            //     Expanded(
            //       child: Center(
            //         child: Text(
            //           distance.toInt().toString(),
            //           style: AppTextStyles.label.copyWith(
            //             fontSize: 18.sp,
            //             fontWeight: FontWeight.w700,
            //             color: AppColors.textPrimary,
            //           ),
            //         ),
            //       ),
            //     ),
            //     Container(
            //       width: 32.w,
            //       height: 32.h,
            //       decoration: BoxDecoration(
            //         shape: BoxShape.circle,
            //         border: Border.all(color: AppColors.primary),
            //       ),
            //       child: IconButton(
            //         onPressed: () {
            //           _distance.value = distance + 10;
            //         },
            //         icon: Icon(
            //           Icons.add,
            //           size: 16.h,
            //           color: AppColors.primary,
            //         ),
            //         padding: EdgeInsets.zero,
            //         constraints: BoxConstraints(),
            //       ),
            //     ),
            //   ],
            // );
          },
        ),
      ],
    );
  }

  Widget _buildPriceTypeDropdown() {
    return ValueListenableBuilder<String>(
      valueListenable: selectedPriceType,
      builder: (context, value, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 16.h,
                color: AppColors.textGrey,
              ),
              style: AppTextStyles.label.copyWith(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'Asset Price',
                  child: Text('Asset Price'),
                ),
                DropdownMenuItem<String>(
                  value: 'Profit in \$',
                  child: Text('Profit in \$'),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  selectedPriceType.value = newValue;
                }
              },
            ),
          ),
        );
      },
    );
  }

}
