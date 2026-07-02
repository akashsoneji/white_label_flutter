import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_switch_tile.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class ClosePositionScreen extends StatefulWidget {
  final TradePosition position;

  const ClosePositionScreen({super.key, required this.position});

  @override
  State<ClosePositionScreen> createState() => _ClosePositionScreenState();
}

class _ClosePositionScreenState extends State<ClosePositionScreen> {
  // Controllers - Both Chart Socket and Trading Controller
  late final ChartSocketController chartSocketController;
  late final AccountController accountController;
  late final TradingController tradingController;

  // Position controls
  double closeVolume = 0.01;
  double? stopLossPrice;
  double? takeProfitPrice;

  // Store original SL/TP values to detect modifications
  double? originalStopLoss;
  double? originalTakeProfit;

  // UI states
  bool isProcessing = false;
  bool stopLossEnabled = false;
  bool takeProfitEnabled = false;
  bool showChart = false; // Default chart switch OFF

  // Double-click prevention
  DateTime? _lastButtonClickTime;
  static const Duration _buttonClickDelay = Duration(milliseconds: 500);

  // Controllers for text fields
  late TextEditingController stopLossController;
  late TextEditingController takeProfitController;
  late TextEditingController volumeController;

  // Volume display controller (to avoid memory leaks)
  late TextEditingController _volumeDisplayController;

  // Stream subscription for cleanup
  StreamSubscription<Map<String, dynamic>>? _priceStreamSubscription;

  // Scroll controller for keyboard handling
  late ScrollController _scrollController;

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

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _initializeControllers();

    // Initialize position data
    closeVolume = _positionVolume;

    // Initialize text controllers
    stopLossController = TextEditingController();
    takeProfitController = TextEditingController();
    volumeController = TextEditingController();
    _volumeDisplayController = TextEditingController();

    // Initialize volume display
    _updateVolumeDisplay();

    // Prefill existing TP/SL values if available
    _prefillExistingTPSL();

    // Initialize scroll controller
    _scrollController = ScrollController();

    // Listen to price updates from chart socket
    _listenToPriceUpdates();

    // Change symbol to position's symbol for chart socket
    _changeSymbolToPosition();

    // Ensure symbol details cache is loaded for this account
    _ensureSymbolCacheLoaded();
  }

  /// Ensure symbol details cache is loaded for the current account
  Future<void> _ensureSymbolCacheLoaded() async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      final accountNumber = activeAccount?.metaAccountNumber ?? '0';

      print(
        'ClosePositionScreen: Ensuring symbol cache for account $accountNumber',
      );
      final cacheLoaded = await SymbolDetailsCacheService.ensureCached(
        accountNumber,
      );
      if (cacheLoaded) {
        print('ClosePositionScreen: Symbol cache loaded successfully');
      } else {
        print('ClosePositionScreen: Failed to load symbol cache');
      }
    } catch (e) {
      print('ClosePositionScreen: Error ensuring symbol cache: $e');
    }
  }

  void _initializeControllers() {
    // Chart Socket Controller for real-time price data
    chartSocketController = Get.find<ChartSocketController>();

    // Account Controller for account info
    accountController = Get.find<AccountController>();

    // Trading Controller for profit data (like trade screen)
    tradingController = Get.find<TradingController>();
  }

  void _listenToPriceUpdates() {
    // Listen to chart socket for real-time price updates
    _priceStreamSubscription = chartSocketController.priceStream.listen((
      priceData,
    ) {
      if (mounted) {
        // Only update if user is NOT manually editing to prevent focus loss and keyboard hiding
        if (!_isManuallyEditingSL && !_isManuallyEditingTP) {
          // Update TP/SL fields with current prices if enabled
          _updatePriceFieldsWithCurrentPrices();
        }
        // Don't call setState to avoid rebuilding widget tree and losing focus
      }
    });
  }

  void _updatePriceFieldsWithCurrentPrices() {
    // REMOVED: Datafeed should not auto-fill SL/TP fields
    // SL/TP should only be set by user or by 1:2 risk-reward calculation based on entry price
    // This prevents interference with manual editing and ensures values are based on entry price, not current market price
  }

  void _changeSymbolToPosition() {
    // Change chart socket symbol to position's symbol for real-time prices
    chartSocketController.changeSymbol(widget.position.symbol);
  }

  void _prefillExistingTPSL() {
    final digits = _positionDigits;

    final existingTP = double.tryParse(widget.position.takeProfit);
    if (existingTP != null && existingTP > 0) {
      takeProfitEnabled = true;
      takeProfitPrice = existingTP;
      originalTakeProfit = existingTP; // Store original value
      takeProfitController.text = PrecisionHelper.formatPrice(
        existingTP,
        decimals: digits,
      );
    } else {
      originalTakeProfit = null;
    }

    final existingSL = double.tryParse(widget.position.stopLoss);
    if (existingSL != null && existingSL > 0) {
      stopLossEnabled = true;
      stopLossPrice = existingSL;
      originalStopLoss = existingSL; // Store original value
      stopLossController.text = PrecisionHelper.formatPrice(
        existingSL,
        decimals: digits,
      );
    } else {
      originalStopLoss = null;
    }
  }

  double _getCurrentPrice() {
    // Get real-time price from chart socket controller
    final bid = chartSocketController.getBidPrice() ?? 0.0;
    final ask = chartSocketController.getAskPrice() ?? 0.0;

    // Return the appropriate price based on position action
    if (widget.position.action.toLowerCase() == 'buy') {
      return bid; // For buy positions, close at bid
    } else {
      return ask; // For sell positions, close at ask
    }
  }

  // Helper method to get position volume as double
  double get _positionVolume => widget.position.volume;

  int get _positionDigits {
    if (widget.position.digits > 0) {
      return widget.position.digits;
    }
    return tradingController.getDecimalDigits(widget.position.currentPrice);
  }

  double get _priceIncrement {
    if (_positionDigits <= 0) return 0.00001;
    return math.pow(10, -_positionDigits).toDouble();
  }

  String _formatPrice(double value) {
    return PrecisionHelper.formatPrice(value, decimals: _positionDigits);
  }

  // Helper method to get symbol without .c suffix
  String get _displaySymbol => widget.position.symbol.replaceFirst('.c', '');

  // Wrapper method for button press with debug logging
  void _onButtonPressed() {
    print('🚀 _onButtonPressed: Button pressed!');
    print('🚀 _onButtonPressed: isProcessing: $isProcessing');
    print(
      '🚀 _onButtonPressed: hasTPSL: ${takeProfitEnabled || stopLossEnabled}',
    );
    print('🚀 _onButtonPressed: takeProfitEnabled: $takeProfitEnabled');
    print('🚀 _onButtonPressed: stopLossEnabled: $stopLossEnabled');

    if (isProcessing) {
      print('🚀 _onButtonPressed: Blocked - isProcessing is true');
      return;
    }

    if (!_canClickButton()) {
      print('🚀 _onButtonPressed: Blocked - _canClickButton returned false');
      return;
    }

    _closePosition();
  }

  // Prevent double-click on buttons
  bool _canClickButton() {
    final now = DateTime.now();
    print('🚀 _canClickButton: Checking button click timing');
    print('🚀 _canClickButton: _lastButtonClickTime: $_lastButtonClickTime');

    if (_lastButtonClickTime == null) {
      _lastButtonClickTime = now;
      print('🚀 _canClickButton: First click - allowing');
      return true;
    }

    final timeDiff = now.difference(_lastButtonClickTime!);
    print('🚀 _canClickButton: Time difference: ${timeDiff.inMilliseconds}ms');
    print(
      '🚀 _canClickButton: Button delay: ${_buttonClickDelay.inMilliseconds}ms',
    );

    if (timeDiff > _buttonClickDelay) {
      _lastButtonClickTime = now;
      print('🚀 _canClickButton: Time passed - allowing click');
      return true;
    }

    print('🚀 _canClickButton: Too soon - blocking click');
    return false;
  }

  // Update volume display controller
  void _updateVolumeDisplay() {
    _volumeDisplayController.text = PrecisionHelper.formatVolume(closeVolume);
  }

  double _calculateProfitLoss() {
    // Get real-time profit from TradingController like trade screen
    final positions = tradingController.marketPositions;
    final position = positions.firstWhereOrNull(
      (p) => p.orderId == widget.position.orderId,
    );

    if (position != null) {
      // Use real-time profit from WebSocket data
      final realTimeProfit = position.profitLoss;

      // Calculate proportional profit based on close volume
      final totalVolume = _positionVolume;
      final closeVolumeRatio =
          totalVolume > 0 ? closeVolume / totalVolume : 0.0;
      final proportionalProfit = realTimeProfit * closeVolumeRatio;

      return proportionalProfit;
    }

    // Fallback to static position profit if not found in real-time data
    final totalVolume = _positionVolume;
    final closeVolumeRatio = totalVolume > 0 ? closeVolume / totalVolume : 0.0;
    return widget.position.profitLoss * closeVolumeRatio;
  }

  Future<void> _editOrder() async {
    print('🚀 _editOrder: Starting edit order process');
    print('🚀 _editOrder: takeProfitEnabled: $takeProfitEnabled');
    print('🚀 _editOrder: stopLossEnabled: $stopLossEnabled');
    print('🚀 _editOrder: takeProfitPrice: $takeProfitPrice');
    print('🚀 _editOrder: stopLossPrice: $stopLossPrice');

    setState(() {
      isProcessing = true;
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
      print('🚀 _editOrder: positionId: $positionId');
      print('🚀 _editOrder: mt5Account: ${activeAccount.metaAccountNumber}');

      // Update TP/SL prices from text controllers before API call
      double? finalTakeProfit;
      double? finalStopLoss;

      if (takeProfitEnabled && takeProfitController.text.isNotEmpty) {
        finalTakeProfit = double.tryParse(takeProfitController.text);
        // PrecisionHelper.parseDouble(
        // takeProfitController.text,
        // );
        print(
          '🚀 _editOrder: Final takeProfit from controller: $finalTakeProfit',
        );
      }

      if (stopLossEnabled && stopLossController.text.isNotEmpty) {
        finalStopLoss = double.tryParse(stopLossController.text);
        // PrecisionHelper.parseDouble(stopLossController.text);
        print('🚀 _editOrder: Final stopLoss from controller: $finalStopLoss');
      }

      // Validate that at least one TP/SL value is provided
      if (finalTakeProfit == null && finalStopLoss == null) {
        CustomToastService.showError(
          title: 'Error',
          message: 'Please provide at least one Take Profit or Stop Loss value',
        );
        return;
      }

      print(
        '🚀 _editOrder: Calling API with TP: $finalTakeProfit, SL: $finalStopLoss',
      );

      // Call the updateTPSL method from trading controller
      final success = await tradingController.updateTPSL(
        mt5Account: activeAccount.metaAccountNumber,
        positionId: positionId,
        stopLoss: finalStopLoss,
        takeProfit: finalTakeProfit,
        digits: _positionDigits,
      );

      print('🚀 _editOrder: API call result: $success');

      // Navigate back on success (no toast)
      if (success) {
        _navigateToTradeScreen();
      }
    } catch (e) {
      print('🚀 _editOrder: Error: $e');
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to update order: ${e.toString()}',
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _closePosition() async {
    print('🚀 _closePosition: Button clicked!');
    print('🚀 _closePosition: isProcessing: $isProcessing');

    if (isProcessing) {
      print('🚀 _closePosition: Blocked by isProcessing');
      return;
    }

    // Check if TP or SL is enabled
    final hasTPSL = takeProfitEnabled || stopLossEnabled;
    print('🚀 _closePosition: hasTPSL: $hasTPSL');
    print('🚀 _closePosition: takeProfitEnabled: $takeProfitEnabled');
    print('🚀 _closePosition: stopLossEnabled: $stopLossEnabled');

    // Check if SL/TP values have been modified from original
    bool isSLModified = false;
    bool isTPModified = false;

    if (stopLossEnabled && stopLossPrice != null) {
      // Compare current SL with original (with tolerance for floating point)
      if (originalStopLoss == null) {
        // SL was added (didn't exist before)
        isSLModified = true;
      } else {
        final tolerance = _priceIncrement * 0.5;
        isSLModified = (stopLossPrice! - originalStopLoss!).abs() > tolerance;
      }
    }

    if (takeProfitEnabled && takeProfitPrice != null) {
      // Compare current TP with original (with tolerance for floating point)
      if (originalTakeProfit == null) {
        // TP was added (didn't exist before)
        isTPModified = true;
      } else {
        final tolerance = _priceIncrement * 0.5;
        isTPModified =
            (takeProfitPrice! - originalTakeProfit!).abs() > tolerance;
      }
    }

    final isSLTPModified = isSLModified || isTPModified;
    print('🚀 _closePosition: isSLTPModified: $isSLTPModified');

    // Only call _editOrder if SL/TP is enabled AND modified
    // If SL/TP exists but not modified, proceed with close position
    if (hasTPSL && isSLTPModified) {
      print('🚀 _closePosition: Calling _editOrder() - SL/TP modified');
      // Handle EDIT ORDER - modify existing position with TP/SL
      await _editOrder();
      return;
    }

    setState(() {
      isProcessing = true;
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

      // Get position ID and volume
      final positionId = int.tryParse(widget.position.orderId) ?? 0;
      final totalVolume = _positionVolume;

      // Determine if this is a partial close
      final isPartialClose = closeVolume < totalVolume;
      final volumeToClose = isPartialClose ? closeVolume : null;

      // Call the closePositionById method from trading controller
      final success = await tradingController.closePositionById(
        mt5Account: activeAccount.metaAccountNumber,
        positionId: positionId,
        volume:
            volumeToClose, // null for full close, specific volume for partial
      );

      // Navigate back on success (no toast)
      if (success) {
        _navigateToTradeScreen();
      }
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to close position: ${e.toString()}',
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
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
                  color: AppColors.border,
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
    _priceStreamSubscription?.cancel();
    stopLossController.dispose();
    takeProfitController.dispose();
    volumeController.dispose();
    _volumeDisplayController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 72.h, // a bit more height so 2 lines fit nicely
        centerTitle: false, // easier for layout; we’ll align manually
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        titleSpacing: 0, // so title starts close to leading
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFlagIcon(widget.position.symbol, size: 20.h),
                SizedBox(width: 8.w),
                Expanded(
                  // <-- let text flex in remaining space
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Close / Modify Position',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis, // <-- no overflow, show "..."
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${widget.position.action} ${widget.position.volume} $_displaySymbol at ${widget.position.openPrice}',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis, // <-- also protect second line
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
        actions: [
          SizedBox(width: 16.w), // small padding instead of 56.w “fake” action
        ],
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
                    controller: _scrollController,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Volume Adjustment
                        _buildVolumeAdjustment(),
                        SizedBox(height: 12.h),

                        // Stop Loss and Take Profit with Switches
                        _buildStopLossTakeProfitWithSwitches(),
                        SizedBox(height: 12.h),

                        // Current Profit/Loss Display (Reactive to real-time updates)
                        Obx(() {
                          final profitLoss = _calculateProfitLoss();
                          final isPositive = profitLoss >= 0;
                          return _buildCurrentProfitLoss(
                            profitLoss,
                            isPositive,
                          );
                        }),
                        SizedBox(height: 12.h),

                        // Close Button (Reactive to real-time updates)
                        Obx(() {
                          final profitLoss = _calculateProfitLoss();
                          final isPositive = profitLoss >= 0;
                          return _buildCloseButton(profitLoss, isPositive);
                        }),

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
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: showChart ? MediaQuery.of(context).size.height * 0.4 : 64.h,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: AppSwitchTile(
                title: 'Chart',
                value: showChart,
                onChanged: (value) {
                  setState(() {
                    showChart = value;
                  });
                },
              ),
            ),
          ),
          // Chart WebView (only when chart is enabled)
          if (showChart)
            Expanded(
              child: ChartInAppWebView(
                key: ValueKey(
                  widget.position.symbol,
                ), // Force update when symbol changes
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
    return '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$displaySymbol&theme=${AppColors.chartTheme}';
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
                  // PrecisionHelper.formatPrice(bid),
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
                  // PrecisionHelper.formatPrice(ask),
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

  Widget _buildVolumeAdjustment() {
    // Get lot size from position
    final lotSize = _positionVolume;
    final minVolume = 0.01;
    final maxVolume = lotSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with lot size info
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Text(
        //       'Quantity to close',
        //       style: AppTextStyles.label.copyWith(
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w600,
        //         color: AppColors.textPrimary,
        //       ),
        //     ),
        //     Text(
        //       'Max: ${lotSize.toStringAsFixed(2)} lots',
        //       style: AppTextStyles.label.copyWith(
        //         fontSize: 12.sp,
        //         fontWeight: FontWeight.w500,
        //         color: AppColors.textGrey,
        //       ),
        //     ),
        //   ],
        // ),
        // SizedBox(height: 12.h),

        // // TextFormField for direct input
        // TextFormField(
        //   controller: volumeController,
        //   keyboardType: TextInputType.numberWithOptions(decimal: true),
        //   style: AppTextStyles.label.copyWith(
        //     fontSize: 16.sp,
        //     fontWeight: FontWeight.w600,
        //     color: AppColors.textPrimary,
        //   ),
        //   decoration: InputDecoration(
        //     hintText: 'Enter volume',
        //     hintStyle: AppTextStyles.label.copyWith(
        //       fontSize: 14.sp,
        //       color: AppColors.textGrey,
        //     ),
        //     prefixIcon: Icon(
        //       Icons.trending_up,
        //       color: AppColors.primary,
        //       size: 20.sp,
        //     ),
        //     suffixText: 'lots',
        //     suffixStyle: AppTextStyles.label.copyWith(
        //       fontSize: 12.sp,
        //       color: AppColors.textGrey,
        //     ),
        //     border: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(8.r),
        //       borderSide: BorderSide(color: AppColors.border),
        //     ),
        //     enabledBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(8.r),
        //       borderSide: BorderSide(color: AppColors.border),
        //     ),
        //     focusedBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(8.r),
        //       borderSide: BorderSide(color: AppColors.primary, width: 2),
        //     ),
        //     errorBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(8.r),
        //       borderSide: BorderSide(color: AppColors.error),
        //     ),
        //     contentPadding: EdgeInsets.symmetric(
        //       horizontal: 16.w,
        //       vertical: 12.h,
        //     ),
        //   ),
        //   onChanged: (value) {
        //     final newVolume = double.tryParse(value) ?? 0.0;
        //     if (newVolume >= minVolume && newVolume <= maxVolume) {
        //       setState(() {
        //         closeVolume = newVolume;
        //       });
        //     }
        //   },
        //   validator: (value) {
        //     if (value == null || value.isEmpty) {
        //       return 'Please enter volume';
        //     }
        //     final volume = double.tryParse(value);
        //     if (volume == null) {
        //       return 'Invalid volume format';
        //     }
        //     if (volume < minVolume) {
        //       return 'Minimum volume is ${minVolume.toStringAsFixed(2)} lots';
        //     }
        //     if (volume > maxVolume) {
        //       return 'Maximum volume is ${maxVolume.toStringAsFixed(2)} lots';
        //     }
        //     return null;
        //   },
        // ),

        // SizedBox(height: 12.h),

        // // Quick adjustment buttons
        // SingleChildScrollView(
        //   scrollDirection: Axis.horizontal,
        //   child: Row(
        //     children: [
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('-0.5', -0.5),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('-0.1', -0.1),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('-0.01', -0.01),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('0.01', 0.01, isSelected: closeVolume == 0.01),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('+0.01', 0.01),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('+0.1', 0.1),
        //       SizedBox(width: 8.w),
        //       _buildVolumeButton('+0.5', 0.5),
        //       SizedBox(width: 8.w),
        //       // Max volume button
        //       _buildVolumeButton('MAX', 0, isMaxButton: true),
        //       SizedBox(width: 8.w),
        //     ],
        //   ),
        // ),

        // SizedBox(height: 12.h),

        // Close Partially Section with Heading
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Close Partially',
              style: AppTextStyles.label.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),

            // Compact switch container (like take profit style)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: AppColors.surface!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Partial Close',

                          style: AppTextStyles.label.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: closeVolume < lotSize,
                          onChanged: (value) {
                            if (value) {
                              // Enable partial close - set to half of lot size
                              setState(() {
                                closeVolume = PrecisionHelper.clamp(
                                  lotSize / 2,
                                  minVolume,
                                  maxVolume,
                                );
                                _volumeDisplayController.text = closeVolume
                                    .toStringAsFixed(2);
                              });
                            } else {
                              // Disable partial close - set to full lot size
                              setState(() {
                                closeVolume = PrecisionHelper.clamp(
                                  lotSize,
                                  minVolume,
                                  maxVolume,
                                );
                                _volumeDisplayController.text = closeVolume
                                    .toStringAsFixed(2);
                              });
                            }
                          },
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withOpacity(0.3),
                          inactiveThumbColor: AppColors.whiteColor,
                          inactiveTrackColor: AppColors.icongrey.withAlpha(55),
                          trackOutlineColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  // Show input field when partial close is enabled
                  if (closeVolume < lotSize) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
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
                              border: Border.all(color: AppColors.primary!),
                            ),
                            child: IconButton(
                              onPressed: () {
                                if (closeVolume > minVolume) {
                                  setState(() {
                                    closeVolume = PrecisionHelper.clamp(
                                      closeVolume - 0.01,
                                      minVolume,
                                      lotSize,
                                    );
                                    _volumeDisplayController.text = closeVolume
                                        .toStringAsFixed(2);
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.remove,
                                size: 20.h,
                                color: AppColors.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: TextField(
                                controller: _volumeDisplayController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
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
                                  // Allow empty value while user is typing
                                  if (value.isEmpty) {
                                    return; // Don't update, let user continue typing
                                  }

                                  final newVolume = double.tryParse(value);
                                  if (newVolume != null && newVolume > 0) {
                                    // Clamp to valid range
                                    final clampedVolume = PrecisionHelper.clamp(
                                      newVolume,
                                      minVolume,
                                      lotSize,
                                    );
                                    setState(() {
                                      closeVolume = clampedVolume;
                                      // Only update display if value changed (to avoid cursor jump)
                                      if (clampedVolume != newVolume) {
                                        _updateVolumeDisplay();
                                      }
                                    });
                                  }
                                },
                                onEditingComplete: () {
                                  // When keyboard is dismissed, validate and update
                                  final textValue =
                                      _volumeDisplayController.text;
                                  if (textValue.isEmpty) {
                                    // If empty, restore to current closeVolume
                                    _updateVolumeDisplay();
                                    FocusScope.of(context).unfocus();
                                    return;
                                  }

                                  final parsedVolume = double.tryParse(
                                    textValue,
                                  );
                                  if (parsedVolume != null &&
                                      parsedVolume > 0) {
                                    final validatedVolume =
                                        PrecisionHelper.clamp(
                                          parsedVolume,
                                          minVolume,
                                          lotSize,
                                        );
                                    setState(() {
                                      closeVolume = validatedVolume;
                                      _updateVolumeDisplay();
                                    });
                                  } else {
                                    // Invalid value, restore to current
                                    _updateVolumeDisplay();
                                  }
                                  FocusScope.of(context).unfocus();
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
                                if (closeVolume < lotSize) {
                                  setState(() {
                                    closeVolume = PrecisionHelper.clamp(
                                      closeVolume + 0.01,
                                      minVolume,
                                      lotSize,
                                    );
                                    _volumeDisplayController.text = closeVolume
                                        .toStringAsFixed(2);
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.add,
                                size: 20.h,
                                color: AppColors.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 8.h),

        // Current selection display
        Center(
          child: Container(
            width: double.maxFinite,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              'Selected: ${PrecisionHelper.formatVolume(closeVolume)} lots (${PrecisionHelper.calculatePercentage(closeVolume, lotSize)}%)',
              style: AppTextStyles.label.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
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
            takeProfitEnabled,
            onChanged: (value) {
              setState(() {
                takeProfitEnabled = value;
                // Reset manual editing flag when toggling
                _isManuallyEditingTP = false;
                if (value) {
                  // If original TP exists, restore it
                  if (originalTakeProfit != null) {
                    takeProfitPrice = originalTakeProfit;
                    takeProfitController.text = _formatPrice(
                      originalTakeProfit!,
                    );
                  } else {
                    // Auto-fill TP based on 1:2 risk-reward if SL is set, otherwise use entry price + 2%
                    Future.microtask(() {
                      if (mounted) {
                        if (stopLossEnabled &&
                            stopLossController.text.isNotEmpty) {
                          // Calculate TP from SL using 1:2 risk-reward ratio
                          _calculateTPFromRiskReward();
                        } else {
                          // No SL set, use entry price with standard 1:2 risk-reward ratio (50 pips risk, 100 pips reward)
                          final entryPrice =
                              double.tryParse(
                                widget.position.entryPrice.replaceAll(',', ''),
                              ) ??
                              0.0;
                          if (entryPrice > 0) {
                            final isBuy =
                                widget.position.action.toLowerCase() == 'buy';
                            // Use standard 50 pips risk (0.0050 for most pairs, 0.50 for JPY)
                            final standardRisk =
                                widget.position.symbol.contains('JPY')
                                    ? 0.50
                                    : 0.0050;
                            final reward =
                                standardRisk * 2; // 1:2 ratio = 100 pips reward
                            final defaultTP =
                                isBuy
                                    ? entryPrice + reward
                                    : entryPrice - reward;
                            takeProfitController.text = _formatPrice(defaultTP);
                            takeProfitPrice = defaultTP;
                            setState(() {
                              _pnlCalculationKey++;
                            });
                          }
                        }
                      }
                    });
                  }
                } else {
                  takeProfitPrice = null;
                  takeProfitController.clear();
                  _lastTPPnL = null; // Clear cached P&L
                }
              });
            },
          ),
          if (takeProfitEnabled) ...[
            _buildPriceInput(
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
                    // Use cached value during recalculation to prevent text disappearing
                    if (snapshot.connectionState == ConnectionState.waiting) {
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

          SizedBox(height: 4.h),

          // Stop Loss with Switch
          _buildSwitchTile(
            'Stop Loss',
            stopLossEnabled,
            onChanged: (value) {
              setState(() {
                stopLossEnabled = value;
                // Reset manual editing flag when toggling
                _isManuallyEditingSL = false;
                if (value) {
                  // If original SL exists, restore it
                  if (originalStopLoss != null) {
                    stopLossPrice = originalStopLoss;
                    stopLossController.text = _formatPrice(originalStopLoss!);
                  } else {
                    // Auto-fill SL with standard 50 pips risk
                    Future.microtask(() {
                      if (mounted) {
                        final entryPrice =
                            double.tryParse(
                              widget.position.entryPrice.replaceAll(',', ''),
                            ) ??
                            0.0;
                        if (entryPrice > 0) {
                          final isBuy =
                              widget.position.action.toLowerCase() == 'buy';
                          // Use standard 50 pips risk (0.0050 for most pairs, 0.50 for JPY)
                          final standardRisk =
                              widget.position.symbol.contains('JPY')
                                  ? 0.50
                                  : 0.0050;
                          final defaultSL =
                              isBuy
                                  ? entryPrice - standardRisk
                                  : entryPrice + standardRisk;
                          stopLossController.text = _formatPrice(defaultSL);
                          stopLossPrice = defaultSL;
                          setState(() {
                            _pnlCalculationKey++;
                          });
                        }
                      }
                    });
                  }
                } else {
                  stopLossPrice = null;
                  stopLossController.clear();
                  _lastSLPnL = null; // Clear cached P&L
                }
                // Force FutureBuilder to rebuild
                _pnlCalculationKey++;
              });
            },
          ),
          if (stopLossEnabled) ...[
            _buildPriceInput(
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
                    // Use cached value during recalculation to prevent text disappearing
                    if (snapshot.connectionState == ConnectionState.waiting) {
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
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value, {
    required Function(bool) onChanged,
  }) {
    return AppSwitchTile(title: title, value: value, onChanged: onChanged);
  }

  Widget _buildCurrentProfitLoss(double profitLoss, bool isPositive) {
    // Get real-time full position profit from TradingController like trade screen
    final positions = tradingController.marketPositions;
    final position = positions.firstWhereOrNull(
      (p) => p.orderId == widget.position.orderId,
    );

    double fullPositionProfit;
    if (position != null) {
      // Use real-time profit from WebSocket data
      fullPositionProfit = position.profitLoss;
    } else {
      // Fallback to static position profit
      fullPositionProfit = widget.position.profitLoss;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color:
            isPositive
                ? AppColors.success.withOpacity(0.1)
                : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color:
              isPositive
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? AppColors.success : AppColors.error,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'Current P&L: \$${PrecisionHelper.formatPnL(profitLoss)}',
                style: AppTextStyles.label.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Full Position:',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
              Text(
                '\$${PrecisionHelper.formatPnL(fullPositionProfit)}',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color:
                      fullPositionProfit >= 0
                          ? AppColors.success
                          : AppColors.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Closing:',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
              Text(
                '${PrecisionHelper.formatVolume(closeVolume)} lots',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(double profitLoss, bool isPositive) {
    // Format profit/loss to 2 decimal places with dollar sign
    final formattedProfitLoss = '\$${PrecisionHelper.formatPnL(profitLoss)}';

    // Check if TP or SL is enabled
    final hasTPSL = takeProfitEnabled || stopLossEnabled;

    // Check if SL/TP values have been modified from original
    bool isSLModified = false;
    bool isTPModified = false;

    if (stopLossEnabled && stopLossPrice != null) {
      // Compare current SL with original (with tolerance for floating point)
      if (originalStopLoss == null) {
        // SL was added (didn't exist before)
        isSLModified = true;
      } else {
        final tolerance = _priceIncrement * 0.5;
        isSLModified = (stopLossPrice! - originalStopLoss!).abs() > tolerance;
      }
    }

    if (takeProfitEnabled && takeProfitPrice != null) {
      // Compare current TP with original (with tolerance for floating point)
      if (originalTakeProfit == null) {
        // TP was added (didn't exist before)
        isTPModified = true;
      } else {
        final tolerance = _priceIncrement * 0.5;
        isTPModified =
            (takeProfitPrice! - originalTakeProfit!).abs() > tolerance;
      }
    }

    final isSLTPModified = isSLModified || isTPModified;

    // Get lot size for partial close check
    final lotSize = _positionVolume;
    final isPartialClose = closeVolume < lotSize;

    // Dynamic button text based on conditions
    String buttonText;
    if (hasTPSL && isSLTPModified) {
      // SL/TP has been modified - show "Modify POSITION"
      buttonText = 'MODIFY POSITION';
    } else if (hasTPSL && !isSLTPModified) {
      // SL/TP enabled but not modified - show "Close Trade"
      buttonText = 'CLOSE TRADE';
    } else if (isPartialClose) {
      buttonText =
          isPositive
              ? 'Close ${PrecisionHelper.formatVolume(closeVolume)} Lots with Profit +$formattedProfitLoss'
              : 'Close ${PrecisionHelper.formatVolume(closeVolume)} Lots with Loss $formattedProfitLoss';
    } else {
      buttonText =
          isPositive
              ? 'Close with Profit +$formattedProfitLoss'
              : 'Close with Loss $formattedProfitLoss';
    }

    // Check if SL/TP values are valid (20 points from current price)
    final bool hasInvalidSLTP =
        (stopLossEnabled && !_validateStopLoss()) ||
        (takeProfitEnabled && !_validateTakeProfit());

    return SizedBox(
      width: double.infinity,
      height: 40.h,
      child: ElevatedButton(
        onPressed: (isProcessing || hasInvalidSLTP) ? null : _onButtonPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              (hasTPSL && isSLTPModified)
                  ? AppColors.primary
                  : hasTPSL
                  ? AppColors
                      .textGrey // Grey for "Close Trade" when SL/TP not modified
                  : (isPositive ? AppColors.success : AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 2,
        ),
        child:
            isProcessing
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
                  buttonText,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.whiteColor,
                  ),
                ),
      ),
    );
  }

  // Price input widget like chart screen
  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
    double defaultValue,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.surface!),
      ),
      child: Row(
        children: [
          Container(
            width: 20.w,
            height: 20.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary!),
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
                  if (label == 'Take Profit') {
                    takeProfitPrice = newValue;
                  } else if (label == 'Stop Loss') {
                    stopLossPrice = newValue;
                  }
                  // Force FutureBuilder to rebuild by incrementing key
                  _pnlCalculationKey++;
                });
              },
              icon: Icon(Icons.remove, size: 10.h, color: AppColors.primary),
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
                  // Mark as manually editing to prevent auto-updates from datafeed
                  if (label == 'Take Profit') {
                    _isManuallyEditingTP = true;
                  } else if (label == 'Stop Loss') {
                    _isManuallyEditingSL = true;
                  }

                  // Update the price value when text changes (without setState to avoid keyboard closing and focus loss)
                  final price =
                      double.tryParse(value.replaceAll(',', '')) ?? 0.0;
                  if (price > 0) {
                    if (label == 'Take Profit') {
                      takeProfitPrice = price;
                    } else if (label == 'Stop Loss') {
                      stopLossPrice = price;
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
                onTap: () {
                  // Scroll to make input field visible when keyboard appears
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
                  // Just update P&L when user finishes editing
                  // Don't show error or clear value - button disable is enough feedback
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
                  if (label == 'Take Profit') {
                    takeProfitPrice = newValue;
                  } else if (label == 'Stop Loss') {
                    stopLossPrice = newValue;
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

  /// Get symbol details (contract size, digits, etc.) from cache
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
      print('ClosePositionScreen: Error getting symbol details from cache: $e');
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

    final tpPrice = double.tryParse(
      takeProfitController.text.replaceAll(',', ''),
    );
    if (tpPrice == null || tpPrice <= 0) return null;

    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice =
        double.tryParse(widget.position.entryPrice.replaceAll(',', '')) ?? 0.0;
    if (entryPrice <= 0) return null;

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.position.symbol);
    if (symbolDetails == null) {
      print(
        'ClosePositionScreen: Symbol details not found in cache for ${widget.position.symbol}',
      );
      return null;
    }

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'ClosePositionScreen: Invalid contract size for ${widget.position.symbol}',
      );
      return null;
    }

    final volume = _positionVolume;
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
      print('ClosePositionScreen: SL P&L - SL disabled or empty');
      return null;
    }

    final slPrice = double.tryParse(
      stopLossController.text.replaceAll(',', ''),
    );
    if (slPrice == null || slPrice <= 0) {
      print(
        'ClosePositionScreen: SL P&L - Invalid SL price: ${stopLossController.text}',
      );
      return null;
    }

    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice =
        double.tryParse(widget.position.entryPrice.replaceAll(',', '')) ?? 0.0;
    if (entryPrice <= 0) {
      print(
        'ClosePositionScreen: SL P&L - Invalid entry price: ${widget.position.entryPrice}',
      );
      return null;
    }

    print(
      'ClosePositionScreen: SL P&L - Calculating for symbol: ${widget.position.symbol}',
    );

    // Get symbol details from cache (contract size and digits)
    final symbolDetails = await _getSymbolDetails(widget.position.symbol);
    if (symbolDetails == null) {
      print(
        'ClosePositionScreen: SL P&L - Symbol details not found in cache for ${widget.position.symbol}',
      );
      return null;
    }

    print(
      'ClosePositionScreen: SL P&L - Symbol details found: contract_size=${symbolDetails['contract_size']}, digits=${symbolDetails['digits']}',
    );

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) {
      print(
        'ClosePositionScreen: Invalid contract size for ${widget.position.symbol}',
      );
      return null;
    }

    final volume = _positionVolume;
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

  /// Calculate TP from risk-reward ratio (1:2)
  /// When SL is set, TP = Entry + 2 * (Entry - SL) for Buy, or Entry - 2 * (SL - Entry) for Sell
  /// Uses entry price (static from order), not current price (from datafeed)
  /// Auto-calculates when TP is enabled and SL has a value
  void _calculateTPFromRiskReward() {
    // Only require SL to be enabled and have a value
    // TP enabled state is checked by caller
    if (!stopLossEnabled) return;

    final slPrice = double.tryParse(
      stopLossController.text.replaceAll(',', ''),
    );
    // Use entry price (static from order), not current price (from datafeed)
    final entryPrice =
        double.tryParse(widget.position.entryPrice.replaceAll(',', '')) ?? 0.0;

    if (slPrice == null || slPrice <= 0 || entryPrice <= 0) return;

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
      takeProfitPrice = tpPrice;
      takeProfitController.text = _formatPrice(tpPrice);
      setState(() {
        _pnlCalculationKey++; // Force P&L recalculation
      });
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
    final currentPrice = _getCurrentPrice(); // Get current Bid or Ask

    if (currentPrice <= 0) {
      return true; // Can't validate without current price
    }

    // Calculate minimum distance (20 points)
    // For most pairs: 20 points = 0.0020, for JPY pairs: 20 points = 0.20
    final minDistance = widget.position.symbol.contains('JPY') ? 0.20 : 0.0020;

    if (isBuy) {
      // Buy: TP must be at least 20 points above current Bid
      return tpPrice >= (currentPrice + minDistance);
    } else {
      // Sell: TP must be at least 20 points below current Ask
      return tpPrice <= (currentPrice - minDistance);
    }
  }

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
    final currentPrice = _getCurrentPrice(); // Get current Bid or Ask

    if (currentPrice <= 0) {
      return true; // Can't validate without current price
    }

    // Calculate minimum distance (20 points)
    // For most pairs: 20 points = 0.0020, for JPY pairs: 20 points = 0.20
    final minDistance = widget.position.symbol.contains('JPY') ? 0.20 : 0.0020;

    if (isBuy) {
      // Buy: SL must be at least 20 points below current Ask
      return slPrice <= (currentPrice - minDistance);
    } else {
      // Sell: SL must be at least 20 points above current Bid
      return slPrice >= (currentPrice + minDistance);
    }
  }

  /// Build P&L display widget below TP/SL fields
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
            width: 112.w, // Fixed width to prevent layout shifts
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

  // Navigate back to trade screen using bottom navigation
  void _navigateToTradeScreen() {
    // Simply go back to previous screen
    // The trading controller will handle UI updates
    Get.back(closeOverlays: true);
  }
}
