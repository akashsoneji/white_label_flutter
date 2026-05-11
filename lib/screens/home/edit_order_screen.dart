import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/flavor_config.dart';

class EditOrderScreen extends StatefulWidget {
  final TradePosition position;

  const EditOrderScreen({super.key, required this.position});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  // Order type selection - removed for modify order functionality
  // int selectedOrderType = 0; // 0: Market, 1: Buy Limit, 2: Sell Limit

  // Toggle states
  bool takeProfitEnabled = false;
  bool stopLossEnabled = false;
  bool advanceSettingsExpanded = false;
  bool trailingStopEnabled = false;
  bool breakEvenEnabled = false;

  // Loading states
  bool isProcessingEdit = false;

  // Key to force FutureBuilder rebuild when TP/SL values change
  int _pnlCalculationKey = 0;
  Timer? _pnlUpdateTimer; // Debounce timer for P&L updates

  // ValueNotifiers for targeted P&L updates (prevents full widget rebuild)
  final ValueNotifier<int> _tpPnLUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _slPnLUpdateNotifier = ValueNotifier<int>(0);

  // Manual editing flags to prevent auto-updates from datafeed
  bool _isManuallyEditingSL = false;
  bool _isManuallyEditingTP = false;

  // Cache last known P&L values to prevent text disappearing during recalculation
  Map<String, dynamic>? _lastTPPnL;
  Map<String, dynamic>? _lastSLPnL;

  // Controllers
  late TextEditingController takeProfitController;
  late TextEditingController stopLossController;
  late TextEditingController trailingStopController;
  late TextEditingController breakEvenController;
  late TextEditingController limitPriceController;

  // Real-time price data
  late final ChartSocketController chartSocketController;
  late final ChartController chartController;
  late final AccountController accountController;
  late final int _positionDigits;

  // Current market prices
  double? currentBidPrice;
  double? currentAskPrice;
  String? currentSymbol;

  // Real-time price data from socket
  Map<String, dynamic>? realTimePriceData;

  // Validation states
  String? limitPriceError;
  String? stopLossError;
  String? takeProfitError;

  // Helper method to get symbol without .c suffix
  String _getDisplaySymbol(String symbol) {
    return symbol.replaceFirst('.c', '');
  }

  // Chart toggle
  bool showChart = false;

  // Scroll controller for keyboard handling
  late ScrollController _scrollController;

  double get _priceIncrement {
    if (_positionDigits <= 0) return 0.00001;
    return math.pow(10, -_positionDigits).toDouble();
  }

  String _formatPrice(double value) {
    return PrecisionHelper.formatPrice(value, decimals: _positionDigits);
  }

  double _getCurrentPrice() {
    final bid = chartSocketController.getBidPrice() ?? 0.0;
    final ask = chartSocketController.getAskPrice() ?? 0.0;

    if (widget.position.action.toLowerCase() == 'buy') {
      return bid;
    } else {
      return ask;
    }
  }

  @override
  void initState() {
    super.initState();

    print('🚀 TradeScreen: Navigating to EditOrderScreen');
    print('🚀 TradeScreen: Position: ${widget.position.symbol}');
    print('🚀 TradeScreen: Position: ${widget.position.action}');
    print('🚀 TradeScreen: Position: ${widget.position.currentPrice}');
    print('🚀 TradeScreen: Position: ${widget.position.entryPrice}');
    print('🚀 TradeScreen: Position: ${widget.position.volume}');
    print('🚀 TradeScreen: Position: ${widget.position.profitLoss}');
    print('🚀 TradeScreen: Position: ${widget.position.orderId}');
    print('🚀 TradeScreen: Position: ${widget.position.openTime}');
    print('🚀 TradeScreen: Position: ${widget.position.closeTime}');
    print('🚀 TradeScreen: Position: ${widget.position.takeProfit}');
    print('🚀 TradeScreen: Position: ${widget.position.stopLoss}');
    print('🚀 TradeScreen: Position: ${widget.position.mt5Account}');
    print('🚀 TradeScreen: Position: ${widget.position.time}');
    print('🚀 TradeScreen: Position: ${widget.position.flag}');
    print('🚀 TradeScreen: Position: ${widget.position.accountId}');
    takeProfitController = TextEditingController();
    stopLossController = TextEditingController();
    trailingStopController = TextEditingController();
    breakEvenController = TextEditingController();
    limitPriceController = TextEditingController();

    _positionDigits =
        widget.position.digits > 0
            ? widget.position.digits
            : _getDecimalDigitsForSymbol(widget.position.symbol);

    // Initialize controllers
    _initializeControllers();

    // Initialize current symbol and prices
    currentSymbol = widget.position.symbol;
    // //print('🚀 EditOrderScreen: Position symbol: ${widget.position.symbol}');
    // //print('🚀 EditOrderScreen: Position action: ${widget.position.action}');
    // //print(
    //   '🚀 EditOrderScreen: Position current price: ${widget.position.currentPrice}',
    // );

    _initializePrices();
    _setupPriceListener();
    _initializeSocketForSymbol();

    // Initialize scroll controller
    _scrollController = ScrollController();
  }

  void _initializeControllers() {
    // Initialize ChartSocketController
    try {
      chartSocketController = Get.find<ChartSocketController>();
      //print('EditOrderScreen: ChartSocketController found');
    } catch (e) {
      //print(
      // 'EditOrderScreen: ChartSocketController not found, creating new one: $e',
      // );
      chartSocketController = ChartSocketController();
      Get.put(chartSocketController, permanent: true);
    }

    // Initialize ChartController
    try {
      chartController = Get.find<ChartController>();
      // //print('EditOrderScreen: ChartController found');
    } catch (e) {
      //print('EditOrderScreen: ChartController not found, creating new one: $e');
      chartController = ChartController();
      Get.put(chartController, permanent: true);
    }

    // Initialize AccountController
    try {
      accountController = Get.find<AccountController>();
      // //print('EditOrderScreen: AccountController found');
    } catch (e) {
      // //print('EditOrderScreen: AccountController not found: $e');
      // AccountController should always be available, but just in case
      // Get.snackbar('Error', 'Account controller not available');
    }

    // Initialize Take Profit and Stop Loss from position data
    // Initialize Take Profit if it exists
    if (widget.position.takeProfit.isNotEmpty &&
        widget.position.takeProfit != '0' &&
        widget.position.takeProfit != '0.0' &&
        widget.position.takeProfit != '0.00000') {
      takeProfitEnabled = true;
      final tpValue = double.tryParse(widget.position.takeProfit) ?? 0.0;
      if (tpValue > 0) {
        takeProfitController.text = PrecisionHelper.formatPrice(
          tpValue,
          decimals: _positionDigits,
        );
      }
    }

    // Initialize Stop Loss if it exists
    if (widget.position.stopLoss.isNotEmpty &&
        widget.position.stopLoss != '0' &&
        widget.position.stopLoss != '0.0' &&
        widget.position.stopLoss != '0.00000') {
      stopLossEnabled = true;
      final slValue = double.tryParse(widget.position.stopLoss) ?? 0.0;
      if (slValue > 0) {
        stopLossController.text = PrecisionHelper.formatPrice(
          slValue,
          decimals: _positionDigits,
        );
      }
    }
  }

  // Helper method to get decimal digits for a symbol
  int _getDecimalDigitsForSymbol(String symbol) {
    final symbolUpper = symbol.toUpperCase();
    if (symbolUpper.contains('JPY')) {
      return 3;
    } else if (symbolUpper.contains('XAU') || symbolUpper.contains('GOLD')) {
      return 2;
    } else if (symbolUpper.contains('XAG') || symbolUpper.contains('SILVER')) {
      return 3;
    } else {
      // Default for major currency pairs
      return 5;
    }
  }

  // Helper method to get pip increment value for a symbol
  double _getPipIncrementForSymbol(String symbol) {
    final symbolUpper = symbol.toUpperCase();
    if (symbolUpper.contains('JPY')) {
      return 0.01;
    } else if (symbolUpper.contains('XAU') || symbolUpper.contains('GOLD')) {
      return 0.01;
    } else if (symbolUpper.contains('XAG') || symbolUpper.contains('SILVER')) {
      return 0.001;
    } else {
      // Default for major currency pairs
      return 0.0001;
    }
  }

  void _initializePrices() {
    // Get current prices from chart socket controller
    final priceData = chartSocketController.getCurrentPrice();
    if (priceData != null) {
      currentBidPrice = chartSocketController.getBidPrice();
      currentAskPrice = chartSocketController.getAskPrice();
    }
  }

  void _setupPriceListener() {
    // Listen to real-time price updates
    chartSocketController.priceStream.listen((priceData) {
      if (mounted) {
        // Update internal state without setState to avoid losing focus
        realTimePriceData = priceData;
        currentBidPrice = chartSocketController.getBidPrice();
        currentAskPrice = chartSocketController.getAskPrice();

        // Only update UI if user is NOT manually editing to prevent focus loss
        if (!_isManuallyEditingSL && !_isManuallyEditingTP) {
          setState(() {
            _validateStopLoss();
            _validateTakeProfit();
            _updatePriceFieldsWithCurrentPrices();
          });
        } else {
          // Still validate silently without setState to avoid rebuilds
          _validateStopLoss();
          _validateTakeProfit();
          // Don't update price fields when user is editing
        }
      }
    });
  }

  void _updatePriceFieldsWithCurrentPrices() {
    // REMOVED: Datafeed should not auto-fill SL/TP fields
    // SL/TP should only be set by user or by 1:2 risk-reward calculation based on entry price
    // This prevents interference with manual editing and ensures values are based on entry price, not current market price
  }

  void _initializeSocketForSymbol() {
    // Initialize socket for the current symbol to get real-time price updates
    if (currentSymbol != null) {
      // //print(
      //   '🚀 EditOrderScreen: Initializing socket for symbol: $currentSymbol',
      // );
      // //print(
      //   '🚀 EditOrderScreen: Initializing socket for symbol position: ${widget.position.symbol}',
      // );
      // Use the symbol as-is since it already has .c suffix
      String formattedSymbol = currentSymbol!;

      //print('🚀 EditOrderScreen: Original symbol: $currentSymbol');
      //print(
      // '🚀 EditOrderScreen: Formatted symbol for socket: $formattedSymbol',
      // );
      //print(
      // '🚀 EditOrderScreen: Socket connected: ${chartSocketController.isConnected.value}',
      // );

      // Change symbol in chart socket controller to get real-time updates
      chartSocketController.changeSymbol(formattedSymbol);

      // Wait a bit for socket to be ready, then request data
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && chartSocketController.isConnected.value) {
          chartSocketController.getSocketData();
        } else {
          // Retry after another delay
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              chartSocketController.getSocketData();
            }
          });
        }
      });
    }
  }

  // Validation methods - limit price validation removed for modify order
  // void _validateLimitPrice() {
  //   // Limit price validation removed for modify order functionality
  // }

  /// Validate Stop Loss price based on position type and current market price
  /// MT5 Standard: SL must be at least 20 points away from current market price
  /// Buy: SL must be at least 20 points below current Ask
  /// Sell: SL must be at least 20 points above current Bid
  bool _validateStopLoss() {
    if (!stopLossEnabled || stopLossController.text.isEmpty) {
      return true; // No validation needed if disabled or empty
    }

    final slPrice = double.tryParse(
      stopLossController.text.replaceAll(',', ''),
    );
    if (slPrice == null) {
      return false;
    }

    final isBuy = widget.position.action.toLowerCase() == 'buy';
    final currentPrice = _getCurrentRealTimePriceAsDouble();

    if (currentPrice <= 0) {
      return true; // Can't validate without current price
    }

    // Calculate minimum distance (20 points)
    final minDistance = widget.position.symbol.contains('JPY') ? 0.20 : 0.0020;

    if (isBuy) {
      // Buy: SL must be at least 20 points below current Ask
      return slPrice <= (currentPrice - minDistance);
    } else {
      // Sell: SL must be at least 20 points above current Bid
      return slPrice >= (currentPrice + minDistance);
    }
  }

  /// Validate Take Profit price based on position type and current market price
  /// MT5 Standard: TP must be at least 20 points away from current market price
  /// Buy: TP must be at least 20 points above current Bid
  /// Sell: TP must be at least 20 points below current Ask
  bool _validateTakeProfit() {
    if (!takeProfitEnabled || takeProfitController.text.isEmpty) {
      return true; // No validation needed if disabled or empty
    }

    final tpPrice = double.tryParse(
      takeProfitController.text.replaceAll(',', ''),
    );
    if (tpPrice == null) {
      return false;
    }

    final isBuy = widget.position.action.toLowerCase() == 'buy';
    final currentPrice = _getCurrentRealTimePriceAsDouble();

    if (currentPrice <= 0) {
      return true; // Can't validate without current price
    }

    // Calculate minimum distance (20 points)
    final minDistance = widget.position.symbol.contains('JPY') ? 0.20 : 0.0020;

    if (isBuy) {
      // Buy: TP must be at least 20 points above current Bid
      return tpPrice >= (currentPrice + minDistance);
    } else {
      // Sell: TP must be at least 20 points below current Ask
      return tpPrice <= (currentPrice - minDistance);
    }
  }

  // Modify order method - using update-tp-sl API
  Future<void> _modifyOrder() async {
    // Check if both take profit and stop loss are empty
    if (takeProfitController.text.isEmpty && stopLossController.text.isEmpty) {
      return;
    }

    setState(() {
      isProcessingEdit = true;
    });

    try {
      final activeAccount = accountController.activeMT5Account;
      if (activeAccount == null) {
        CustomToastService.showError(
          title: 'Error',
          message: 'No active account found',
        );
        return;
      }

      // Get position ID
      final positionId = int.tryParse(widget.position.orderId) ?? 0;

      // Parse TP/SL values
      double? takeProfit;
      double? stopLoss;

      if (takeProfitController.text.isNotEmpty) {
        takeProfit = double.tryParse(takeProfitController.text);
      }

      if (stopLossController.text.isNotEmpty) {
        stopLoss = double.tryParse(stopLossController.text);
      }

      // Get trading controller
      final tradingController = Get.find<TradingController>();

      // Call the updateTPSL method from trading controller
      final success = await tradingController.updateTPSL(
        mt5Account: activeAccount.metaAccountNumber,
        positionId: positionId,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        digits: _positionDigits,
      );

      // Navigate back on success (no toast)
      if (success) {
        Get.back(closeOverlays: true);
      }
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to modify order: ${e.toString()}',
      );
    } finally {
      setState(() {
        isProcessingEdit = false;
      });
    }
  }

  bool _isOrderValid() {
    _validateStopLoss();
    _validateTakeProfit();

    if (stopLossEnabled && stopLossError != null) return false;
    if (takeProfitEnabled && takeProfitError != null) return false;

    return true;
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
  Widget _buildFlagIcon(String symbol, {double? size}) {
    final flagSize = size ?? 24.h;
    final containerSize = flagSize + 16.h; // Add padding for container
    final iconSize = flagSize; // Icon size stays the same
    final flagPath = _getFlagPath(symbol);

    return FutureBuilder<String?>(
      future: _checkAssetExists(flagPath),
      builder: (context, snapshot) {
        // If asset exists, show SVG
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: SvgPicture.asset(
                flagPath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        // If asset doesn't exist or error occurred, show fallback
        return _buildFallbackFlag(flagSize, containerSize, iconSize);
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
  Widget _buildFallbackFlag(
    double flagSize,
    double containerSize,
    double iconSize,
  ) {
    return Container(
      width: containerSize,
      height: containerSize,
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
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Image.asset(
                  'assets/image/no_flag_icon.png',
                  width: iconSize,
                  height: iconSize,
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
    _pnlUpdateTimer?.cancel();
    _tpPnLUpdateNotifier.dispose();
    _slPnLUpdateNotifier.dispose();
    takeProfitController.dispose();
    stopLossController.dispose();
    trailingStopController.dispose();
    breakEvenController.dispose();
    limitPriceController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if controllers are available
    if (!Get.isRegistered<ChartSocketController>()) {
      return Scaffold(
        body: Center(
          child: Text(
            Get.find<LanguageService>().tr('edit_order_chart_controller_error'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 72.h,
        centerTitle: false,
        leading: const AppBackButton(),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFlagIcon(widget.position.symbol, size: 20.h),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${widget.position.action} ${widget.position.volume} ${_getDisplaySymbol(widget.position.symbol)} at ${widget.position.entryPrice}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [SizedBox(width: 16.w)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Current Prices (Bid/Ask) - Above Chart
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: _buildCurrentPrices(),
                ),

                // Chart Section
                _buildChartSection(),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Order Details (Open Time, Position ID)
                        _buildOrderDetails(),

                        SizedBox(height: 12.h),

                        // Stop Loss and Take Profit with Switches
                        _buildEditContent(),

                        // Extra padding for keyboard
                        SizedBox(
                          height:
                              MediaQuery.of(context).viewInsets.bottom > 0
                                  ? MediaQuery.of(context).viewInsets.bottom +
                                      20.h
                                  : 20.h,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : kBottomNavigationBarHeight,
        ),
        child: _buildSimpleButton(),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: showChart ? MediaQuery.of(context).size.height * 0.4 : 64.h,
      child: Column(
        children: [
          // Chart Header with Toggle
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chart',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    // Chart On/Off Toggle
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: showChart,
                        onChanged: (value) {
                          setState(() {
                            showChart = value;
                          });
                        },
                        activeColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withOpacity(0.3),
                        inactiveThumbColor: AppColors.whiteColor,
                        inactiveTrackColor: AppColors.icongrey.withAlpha(55),
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chart WebView (only when chart is enabled)
          if (showChart)
            Expanded(
              child: ChartInAppWebView(
                key: ValueKey(widget.position.symbol),
                symbol: _removeSymbolSuffixForDisplay(widget.position.symbol),
                url: _buildChartUrl(widget.position.symbol),
              ),
            ),
        ],
      ),
    );
  }

  String _removeSymbolSuffixForDisplay(String symbol) {
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol;
  }

  String _buildChartUrl(String symbol) {
    final displaySymbol = _removeSymbolSuffixForDisplay(symbol);
    final themeParam = AppColors.isDarkMode ? 'dark' : 'light';
    return '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$displaySymbol&theme=$themeParam';
  }

  Widget _buildCurrentPrices() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bid Price (from Chart Socket)
          Column(
            children: [
              Text(
                'Bid',
                style: AppTextStyles.label.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Obx(() {
                final bid = chartSocketController.getBidPrice() ?? 0.0;
                return Text(
                  bid.toString(),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                );
              }),
            ],
          ),
          Container(width: 2.w, height: 30.h, color: AppColors.border),
          // Ask Price (from Chart Socket)
          Column(
            children: [
              Text(
                'Ask',
                style: AppTextStyles.label.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Obx(() {
                final ask = chartSocketController.getAskPrice() ?? 0.0;
                return Text(
                  ask.toString(),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildDetailRow('Open Time', widget.position.openTime),
          SizedBox(height: 12.h),
          _buildDetailRow('Position ID', '#${widget.position.orderId}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textGrey,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEditContent() {
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
            takeProfitEnabled,
            onChanged: (value) {
              setState(() {
                takeProfitEnabled = value;
                _isManuallyEditingTP = false;
                if (value) {
                  trailingStopEnabled = false;
                  breakEvenEnabled = false;
                } else {
                  takeProfitController.clear();
                  _lastTPPnL = null;
                }
                _validateTakeProfit();
                _pnlCalculationKey++;
              });

              if (value && takeProfitController.text.isEmpty) {
                Future.microtask(() {
                  if (mounted) {
                    if (stopLossEnabled && stopLossController.text.isNotEmpty) {
                      _calculateTPFromRiskReward();
                    } else {
                      final entryPrice =
                          double.tryParse(widget.position.entryPrice) ?? 0.0;
                      if (entryPrice > 0) {
                        final standardReward =
                            widget.position.symbol.contains('JPY')
                                ? 1.00
                                : 0.0100;
                        final isBuy =
                            widget.position.action.toLowerCase() == 'buy';
                        final defaultTP =
                            isBuy
                                ? entryPrice + standardReward
                                : entryPrice - standardReward;

                        takeProfitController.text = _formatPrice(defaultTP);
                        setState(() {
                          _pnlCalculationKey++;
                        });
                      }
                    }
                  }
                });
              }
            },
          ),
          if (takeProfitEnabled) ...[
            _buildPriceInputCompact(
              'Take Profit',
              takeProfitController,
              _getCurrentPrice(),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _tpPnLUpdateNotifier,
              builder: (context, value, child) {
                return FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey('tp_pnl_${_pnlCalculationKey}_$value'),
                  future: _calculateTakeProfitPnL(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildPnLDisplay(
                        'Potential Profit at TP',
                        _lastTPPnL,
                        isProfit: true,
                      );
                    }
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

          SizedBox(height: 4.h),

          // Stop Loss with Switch
          _buildSwitchTile(
            'Stop Loss',
            stopLossEnabled,
            onChanged: (value) {
              setState(() {
                stopLossEnabled = value;
                _isManuallyEditingSL = false;
                if (value) {
                  trailingStopEnabled = false;
                  breakEvenEnabled = false;
                } else {
                  stopLossController.clear();
                  _lastSLPnL = null;
                }
                _validateStopLoss();
                _pnlCalculationKey++;
              });

              if (value && stopLossController.text.isEmpty) {
                Future.microtask(() {
                  if (mounted) {
                    final entryPrice =
                        double.tryParse(widget.position.entryPrice) ?? 0.0;
                    if (entryPrice > 0) {
                      final standardRisk =
                          widget.position.symbol.contains('JPY')
                              ? 0.50
                              : 0.0050;
                      final isBuy =
                          widget.position.action.toLowerCase() == 'buy';
                      final defaultSL =
                          isBuy
                              ? entryPrice - standardRisk
                              : entryPrice + standardRisk;

                      stopLossController.text = _formatPrice(defaultSL);
                      setState(() {
                        _pnlCalculationKey++;
                      });
                    }
                  }
                });
              }
            },
          ),
          if (stopLossEnabled) ...[
            _buildPriceInputCompact(
              'Stop Loss',
              stopLossController,
              _getCurrentPrice(),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _slPnLUpdateNotifier,
              builder: (context, value, child) {
                return FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey('sl_pnl_${_pnlCalculationKey}_$value'),
                  future: _calculateStopLossPnL(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildPnLDisplay(
                        'Potential Loss at SL',
                        _lastSLPnL,
                        isProfit: false,
                      );
                    }
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
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value, {
    required Function(bool) onChanged,
  }) {
    return Container(
      height: 35,
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            style: AppTextStyles.label.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              inactiveThumbColor: AppColors.whiteColor,
              inactiveTrackColor: AppColors.icongrey.withAlpha(55),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// Build P&L display widget below TP/SL fields
  /// Calculate TP from risk-reward ratio (1:2)
  /// When SL is set, TP = Entry + 2 * (Entry - SL) for Buy, or Entry - 2 * (SL - Entry) for Sell
  /// Uses entry price (static from order), not current price (from datafeed)
  /// Auto-calculates when TP is enabled and SL has a value
  void _calculateTPFromRiskReward() {
    // Only require SL to be enabled and have a value
    // TP enabled state is checked by caller
    if (!stopLossEnabled || !takeProfitEnabled) return;

    final slPrice = PrecisionHelper.parseDouble(stopLossController.text);
    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;

    if (slPrice <= 0 || entryPrice <= 0) return;

    final isBuy = widget.position.action.toLowerCase() == 'buy';
    double tpPrice;

    if (isBuy) {
      // Buy: risk = Entry - SL, reward = 2 * risk, TP = Entry + reward
      final risk = entryPrice - slPrice;
      tpPrice = entryPrice + (2 * risk);
    } else {
      // Sell: risk = SL - Entry, reward = 2 * risk, TP = Entry - reward
      final risk = slPrice - entryPrice;
      tpPrice = entryPrice - (2 * risk);
    }

    // Update TP field with calculated value
    if (mounted) {
      takeProfitController.text = PrecisionHelper.formatPrice(
        tpPrice,
        decimals: _positionDigits,
      );
      setState(() {
        _pnlCalculationKey++; // Force P&L recalculation
      });
    }
  }

  Widget _buildPnLDisplay(
    String label,
    Map<String, dynamic>? pnlData, {
    required bool isProfit,
  }) {
    if (pnlData == null || pnlData['pnl'] == null) {
      return SizedBox(height: 20.h);
    }

    final pnl = (pnlData['pnl'] as num).toDouble();
    final digits = (pnlData['digits'] as int?) ?? 2;

    final formattedPnL =
        '\$${PrecisionHelper.formatPnL(pnl, decimals: digits)}';
    final isPositive = pnl >= 0;

    final color =
        isProfit
            ? (isPositive ? AppColors.success : AppColors.error)
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(top: 8.h, left: 12.w, right: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(
            width: 100.w,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                formattedPnL,
                key: ValueKey(formattedPnL),
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

  Widget _buildPriceInputCompact(
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
                final newValue = (currentValue - _priceIncrement).clamp(
                  0.0,
                  double.infinity,
                );
                setState(() {
                  controller.text = _formatPrice(newValue);
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
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (value) {
                  if (label == 'Take Profit') {
                    _isManuallyEditingTP = true;
                  } else if (label == 'Stop Loss') {
                    _isManuallyEditingSL = true;
                  }

                  final price =
                      double.tryParse(value.replaceAll(',', '')) ?? 0.0;
                  if (price > 0) {
                    // Update price value
                  }

                  _pnlUpdateTimer?.cancel();
                  _pnlUpdateTimer = Timer(
                    const Duration(milliseconds: 100),
                    () {
                      if (mounted) {
                        if (label == 'Take Profit') {
                          _tpPnLUpdateNotifier.value++;
                        } else if (label == 'Stop Loss') {
                          _slPnLUpdateNotifier.value++;
                        }
                      }
                    },
                  );
                },
                onTap: () {
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent * 0.8,
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                },
                onEditingComplete: () {
                  if (mounted) {
                    setState(() {
                      _pnlCalculationKey++;
                    });
                  }
                  if (label == 'Take Profit') {
                    _isManuallyEditingTP = false;
                  } else if (label == 'Stop Loss') {
                    _isManuallyEditingSL = false;
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
                final newValue = currentValue + _priceIncrement;
                setState(() {
                  controller.text = _formatPrice(newValue);
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

  // ignore: unused_element
  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
    double defaultValue, {
    String? error,
  }) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.88,
              height: 50.h,
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: error != null ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Minus button
                  Padding(
                    padding: EdgeInsets.only(left: 17.w),
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
                            final pipIncrement = _getPipIncrementForSymbol(
                              widget.position.symbol,
                            );
                            final currentValue =
                                double.tryParse(controller.text) ??
                                defaultValue;
                            if (currentValue > pipIncrement) {
                              final newValue = currentValue - pipIncrement;
                              controller.text = PrecisionHelper.formatPrice(
                                newValue,
                                decimals: _positionDigits,
                              );
                              if (label == 'Stop Loss') {
                                _validateStopLoss();
                              } else if (label == 'Take Profit') {
                                _validateTakeProfit();
                              }
                              // Force FutureBuilder to rebuild by incrementing key
                              _pnlCalculationKey++;
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
                  // Price input field
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textGrey,
                          ),
                        ),
                        TextField(
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
                            // Mark as manually editing to prevent auto-updates from datafeed
                            if (label == 'Take Profit') {
                              _isManuallyEditingTP = true;
                            } else if (label == 'Stop Loss') {
                              _isManuallyEditingSL = true;
                            }

                            // Debounce P&L calculation to update in real-time while typing
                            // Use ValueNotifier to update only the specific P&L widget, not the entire form
                            _pnlUpdateTimer?.cancel();
                            _pnlUpdateTimer = Timer(
                              const Duration(milliseconds: 100),
                              () {
                                if (mounted) {
                                  // Update only the specific P&L widget using ValueNotifier
                                  if (label == 'Take Profit') {
                                    _tpPnLUpdateNotifier.value++;
                                  } else if (label == 'Stop Loss') {
                                    _slPnLUpdateNotifier.value++;
                                  }
                                }
                              },
                            );
                          },
                          onEditingComplete: () {
                            // Update P&L when user finishes editing (keyboard dismissed or Enter pressed)
                            if (mounted) {
                              setState(() {
                                _pnlCalculationKey++;
                              });
                            }
                            // Clear manual editing flag
                            if (label == 'Take Profit') {
                              _isManuallyEditingTP = false;
                            } else if (label == 'Stop Loss') {
                              _isManuallyEditingSL = false;
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Plus button
                  Padding(
                    padding: EdgeInsets.only(right: 17.w),
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
                            final pipIncrement = _getPipIncrementForSymbol(
                              widget.position.symbol,
                            );
                            final currentValue =
                                double.tryParse(controller.text) ??
                                defaultValue;
                            final newValue = currentValue + pipIncrement;
                            controller.text = PrecisionHelper.formatPrice(
                              newValue,
                              decimals: _positionDigits,
                            );
                            if (label == 'Stop Loss') {
                              _validateStopLoss();
                            } else if (label == 'Take Profit') {
                              _validateTakeProfit();
                            }
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
            // Price type dropdown (optional)
            // Container(
            //   width: 96.w,
            //   height: 48.h,
            //   decoration: BoxDecoration(
            //     color: AppColors.whiteColor,
            //     borderRadius: BorderRadius.circular(8.r),
            //     border: Border.all(color: AppColors.border),
            //   ),
            //   alignment: Alignment.center,
            //   child: Text(
            //     'Points',
            //     style: AppTextStyles.label.copyWith(
            //       fontSize: 12.sp,
            //       fontWeight: FontWeight.w500,
            //       color: AppColors.textGrey,
            //     ),
            //   ),
            // ),
          ],
        ),
        if (error != null) ...[
          SizedBox(height: 4.h),
          Text(
            error,
            style: AppTextStyles.label.copyWith(
              fontSize: 12.sp,
              color: AppColors.error,
            ),
          ),
        ],
        SizedBox(height: 8.h),
        // Additional info text (optional)
        // Text(
        //   '68 points | Profit +4.08 USD | +0.08% of balance',
        //   style: AppTextStyles.label.copyWith(
        //     fontSize: 12.sp,
        //     color: AppColors.textGrey,
        //   ),
        // ),
      ],
    );
  }

  // Bottom action buttons
  Widget _buildSimpleButton() {
    final hasTPValue =
        takeProfitEnabled &&
        takeProfitController.text.isNotEmpty &&
        PrecisionHelper.parseDouble(takeProfitController.text) > 0;
    final hasSLValue =
        stopLossEnabled &&
        stopLossController.text.isNotEmpty &&
        PrecisionHelper.parseDouble(stopLossController.text) > 0;
    final canConfirm = hasTPValue || hasSLValue;

    final bool hasInvalidSLTP =
        (stopLossEnabled && !_validateStopLoss()) ||
        (takeProfitEnabled && !_validateTakeProfit());

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Discard Button
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: OutlinedButton(
                onPressed: () => Get.back(closeOverlays: true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xffEFEAF6),
                  side: BorderSide(color: AppColors.whiteColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'Discard',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Confirm Button
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: ElevatedButton(
                onPressed:
                    (canConfirm &&
                            _isOrderValid() &&
                            !isProcessingEdit &&
                            !hasInvalidSLTP)
                        ? _modifyOrder
                        : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 2,
                ),
                child:
                    isProcessingEdit
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ButtonLoadingWidget(
                              size: 20.0,
                              color: AppColors.whiteColor,
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
                          'Confirm',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.whiteColor,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get contract size and digits for symbol from cache
  /// Returns null if not found (no hardcoded fallback)
  Future<Map<String, dynamic>?> _getSymbolDetails(String symbol) async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      final accountNumber = activeAccount?.metaAccountNumber ?? '0';

      return await SymbolDetailsCacheService.getSymbolDetails(
        symbol,
        accountNumber,
      );
    } catch (e) {
      print('EditOrderScreen: Error getting symbol details from cache: $e');
      return null;
    }
  }

  /// Calculate potential profit if Take Profit is hit
  /// Returns Map with 'pnl' and 'digits' for formatting
  /// Uses entry price (static from order), not current price (from datafeed)
  Future<Map<String, dynamic>?> _calculateTakeProfitPnL() async {
    if (!takeProfitEnabled || takeProfitController.text.isEmpty) {
      return null;
    }

    final tpPrice = PrecisionHelper.parseDouble(takeProfitController.text);
    if (tpPrice <= 0) return null;

    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;
    if (entryPrice <= 0) return null;

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.position.symbol);
    if (symbolDetails == null) {
      print(
        'EditOrderScreen: Symbol details not found in cache for ${widget.position.symbol}',
      );
      return null;
    }

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'EditOrderScreen: Invalid contract size for ${widget.position.symbol}',
      );
      return null;
    }

    final volume = widget.position.volume;
    final isBuy = widget.position.action.toLowerCase() == 'buy';

    double priceDiff;
    if (isBuy) {
      // Buy: profit when price goes up (TP > Entry)
      priceDiff = tpPrice - entryPrice;
    } else {
      // Sell: profit when price goes down (Entry > TP)
      priceDiff = entryPrice - tpPrice;
    }

    final pnl = priceDiff * volume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;

    return {'pnl': pnl, 'digits': digits};
  }

  /// Calculate potential loss if Stop Loss is hit
  /// Returns Map with 'pnl' and 'digits' for formatting
  /// Uses entry price (static from order), not current price (from datafeed)
  Future<Map<String, dynamic>?> _calculateStopLossPnL() async {
    if (!stopLossEnabled || stopLossController.text.isEmpty) {
      print('EditOrderScreen: SL P&L - SL disabled or empty');
      return null;
    }

    final slPrice = PrecisionHelper.parseDouble(stopLossController.text);
    if (slPrice <= 0) {
      print(
        'EditOrderScreen: SL P&L - Invalid SL price: ${stopLossController.text}',
      );
      return null;
    }

    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;
    if (entryPrice <= 0) {
      print(
        'EditOrderScreen: SL P&L - Invalid entry price: ${widget.position.entryPrice}',
      );
      return null;
    }

    print(
      'EditOrderScreen: SL P&L - Calculating for symbol: ${widget.position.symbol}',
    );

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.position.symbol);
    if (symbolDetails == null) {
      print(
        'EditOrderScreen: SL P&L - Symbol details not found in cache for ${widget.position.symbol}',
      );
      return null;
    }

    print(
      'EditOrderScreen: SL P&L - Symbol details found: contract_size=${symbolDetails['contract_size']}, digits=${symbolDetails['digits']}',
    );

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'EditOrderScreen: Invalid contract size for ${widget.position.symbol}',
      );
      return null;
    }

    final volume = widget.position.volume;
    final isBuy = widget.position.action.toLowerCase() == 'buy';

    double priceDiff;
    if (isBuy) {
      // Buy: loss when price goes down (Entry > SL)
      priceDiff = entryPrice - slPrice;
    } else {
      // Sell: loss when price goes up (SL > Entry)
      priceDiff = slPrice - entryPrice;
    }

    final pnl = priceDiff * volume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;

    return {'pnl': pnl, 'digits': digits};
  }

  // ignore: unused_element
  String _getCurrentRealTimePrice() {
    // Get real-time price from socket data
    if (realTimePriceData != null) {
      final socketSymbol = realTimePriceData!['symbol']?.toString() ?? '';
      final originalSymbol = currentSymbol ?? '';

      // Check if symbols match (with or without .c suffix)
      bool symbolsMatch =
          socketSymbol == originalSymbol ||
          socketSymbol == '$originalSymbol.c' ||
          socketSymbol.replaceAll('.c', '') == originalSymbol;

      if (symbolsMatch) {
        final bid = realTimePriceData!['bid']?.toString() ?? '0';
        final ask = realTimePriceData!['ask']?.toString() ?? '0';

        // Return the appropriate price based on position action
        if (widget.position.action.toLowerCase() == 'buy') {
          return ask;
        } else {
          return bid;
        }
      }
    }

    // Fallback to current price from position

    return widget.position.currentPrice;
  }

  // ignore: unused_element
  bool _isRealTimeDataActive() {
    if (realTimePriceData != null) {
      final socketSymbol = realTimePriceData!['symbol']?.toString() ?? '';
      final originalSymbol = currentSymbol ?? '';

      // Check if symbols match (with or without .c suffix)
      return socketSymbol == originalSymbol ||
          socketSymbol == '$originalSymbol.c' ||
          socketSymbol.replaceAll('.c', '') == originalSymbol;
    }
    return false;
  }

  double _getCurrentRealTimePriceAsDouble() {
    if (realTimePriceData != null) {
      final socketSymbol = realTimePriceData!['symbol']?.toString() ?? '';
      final originalSymbol = currentSymbol ?? '';

      // Check if symbols match (with or without .c suffix)
      bool symbolsMatch =
          socketSymbol == originalSymbol ||
          socketSymbol == '$originalSymbol.c' ||
          socketSymbol.replaceAll('.c', '') == originalSymbol;

      if (symbolsMatch) {
        final bid =
            double.tryParse(realTimePriceData!['bid']?.toString() ?? '0') ??
            0.0;
        final ask =
            double.tryParse(realTimePriceData!['ask']?.toString() ?? '0') ??
            0.0;

        // Return the appropriate price based on position action
        if (widget.position.action.toLowerCase() == 'buy') {
          return ask;
        } else {
          return bid;
        }
      }
    }

    // Fallback to current price from position
    return double.tryParse(widget.position.currentPrice) ?? 0.0;
  }
}
