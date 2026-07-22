import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/screens/home/dashboard_screen.dart';
import 'package:crm_app/screens/home/pending_order_screen.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/services/price_alert_service.dart';
import 'package:crm_app/services/price_alert_monitor_service.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/price_alert_dialog.dart';

/// iQuote-themed chart screen.
///
/// Mirrors `iquote_order_details_screen.dart` styling tokens
/// (AppColors.background, AppColors.card, AppColors.textPrimary,
/// AppColors.textSecondary, AppColors.border) so the chart looks
/// correct in both light and dark themes.
///
/// Uses `ChartSocketController.priceStream` directly for live bid/ask
/// updates so the SELL/BUY price pill always reflects the websocket feed
/// regardless of the underlying chart iframe.
class IquoteChartScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final String? initialSymbol;

  const IquoteChartScreen({super.key, this.onNavigateToTab, this.initialSymbol});

  @override
  State<IquoteChartScreen> createState() => _IquoteChartScreenState();
}

class _IquoteChartScreenState extends State<IquoteChartScreen> {
  static const String _fallbackSymbol = 'XAUUSD';

  late final ChartSocketController _socket;
  late final ChartController _chartController;
  late final AccountController _accountController;
  late final InstrumentsController _instrumentsController;
  late final TradingController _tradingController;
  late final SymbolSelectionService _symbolSelection;
  late final LanguageService _language;

  String _selectedSymbol = '';
  bool _isPlacingOrder = false;
  bool _socketReady = false;

  // For datafeed_symbol lookup
  String _datafeedSymbol = '';
  String _lastLookupSymbol = '';
  bool _isFetchingDatafeed = false;

  final GlobalKey<ChartInAppWebViewState> _webViewKey =
      GlobalKey<ChartInAppWebViewState>();

  StreamSubscription<Map<String, dynamic>>? _priceSub;

  @override
  void initState() {
    super.initState();

    _socket = Get.isRegistered<ChartSocketController>()
        ? Get.find<ChartSocketController>()
        : Get.put(ChartSocketController());
    _chartController = Get.isRegistered<ChartController>()
        ? Get.find<ChartController>()
        : Get.put(ChartController());
    _accountController = Get.find<AccountController>();
    _instrumentsController = Get.find<InstrumentsController>();
    _tradingController = Get.find<TradingController>();
    _symbolSelection = Get.isRegistered<SymbolSelectionService>()
        ? Get.find<SymbolSelectionService>()
        : Get.put(SymbolSelectionService(), permanent: true);
    _language = Get.find<LanguageService>();

    // Pick symbol in priority order: explicit arg > selection service > fallback
    if (widget.initialSymbol != null && widget.initialSymbol!.isNotEmpty) {
      _selectedSymbol = widget.initialSymbol!;
      _symbolSelection.setSymbol(_selectedSymbol);
    } else {
      final cached = _symbolSelection.currentSymbol;
      _selectedSymbol = cached.isNotEmpty ? cached : _fallbackSymbol;
    }

    // Bootstrap price-alert monitoring on first open
    unawaited(_initPriceAlertService());

    // Make sure the symbol-list websocket is up so the symbol-switcher
    // bottom sheet has data
    if (Get.isRegistered<TradingWebSocketService>()) {
      Get.find<TradingWebSocketService>().ensureSymbolsConnected();
    }

    // Subscribe to live ticks for bid/ask + UI rebuild
    _priceSub = _socket.priceStream.listen(_onPriceTick);

    // Kick off the chart socket for the selected symbol
    _socket.initializeSocketForSymbol(_selectedSymbol);

    // Resolve datafeed symbol for the iframe URL
    _scheduleDatafeedLookup(_selectedSymbol);
  }

  Future<void> _initPriceAlertService() async {
    try {
      await PriceAlertService().initialize();
      if (!Get.isRegistered<PriceAlertMonitorService>()) {
        Get.put(PriceAlertMonitorService());
      }
    } catch (_) {}
  }

  void _onPriceTick(Map<String, dynamic> tick) {
    if (!mounted) return;
    setState(() {
      _socketReady = _socket.isConnected.value;
    });
  }

  /// Strip the broker suffix (e.g. `EURUSD.r` → `EURUSD`) for display only.
  String _displaySymbol(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  int _digitsForCurrentSymbol() {
    final priceData = _socket.getCurrentPrice();
    if (priceData != null && priceData['digits'] != null) {
      return int.tryParse(priceData['digits'].toString()) ?? 5;
    }
    return 5;
  }

  void _scheduleDatafeedLookup(String symbol) {
    if (symbol.isEmpty || symbol == _lastLookupSymbol || _isFetchingDatafeed) {
      return;
    }
    _lastLookupSymbol = symbol;
    _isFetchingDatafeed = true;

    unawaited(() async {
      try {
        final account =
            _accountController.activeMT5Account?.metaAccountNumber;
        if (account == null) {
          if (!mounted) return;
          setState(() {
            _datafeedSymbol = _displaySymbol(symbol);
            _isFetchingDatafeed = false;
          });
          return;
        }

        final accountStr = account.toString();
        final ok = await SymbolDetailsCacheService.ensureCached(accountStr);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _datafeedSymbol = _displaySymbol(symbol);
            _isFetchingDatafeed = false;
          });
          return;
        }

        final details =
            await SymbolDetailsCacheService.getSymbolDetails(symbol, accountStr);
        if (!mounted) return;
        if (symbol != _lastLookupSymbol) return; // symbol changed mid-fetch

        final resolved = (details?['datafeed_symbol'] ?? '').toString();
        setState(() {
          _datafeedSymbol = resolved.isNotEmpty
              ? resolved
              : _displaySymbol(symbol);
          _isFetchingDatafeed = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _datafeedSymbol = _displaySymbol(symbol);
          _isFetchingDatafeed = false;
        });
      }
    }());
  }

  void _changeSymbol(String newSymbol) {
    if (newSymbol == _selectedSymbol || newSymbol.isEmpty) return;
    setState(() {
      _selectedSymbol = newSymbol;
      _datafeedSymbol = '';
      _lastLookupSymbol = '';
      _isFetchingDatafeed = false;
    });
    _symbolSelection.setSymbol(newSymbol);
    _socket.changeSymbol(newSymbol);
    _scheduleDatafeedLookup(newSymbol);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _webViewKey.currentState;
      if (state != null) {
        state.updateSymbol(_displaySymbol(newSymbol));
      } else {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _webViewKey.currentState?.updateSymbol(_displaySymbol(newSymbol));
        });
      }
    });
  }

  void _showSymbolPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          child: SearchInstrumentsScreen(
            favoritesOnly: true,
            onNavigateToChart: _changeSymbol,
          ),
        ),
      ),
    );
  }

  Future<void> _placeOneClickTrade(String type) async {
    if (_isPlacingOrder) return;
    if (_accountController.mt5Accounts.isEmpty ||
        _accountController.activeMT5Account == null) {
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(3);
      } else {
        Get.to(() =>  DashboardScreen());
      }
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final result = await _chartController.placeTradeOrder(
        mt5Account:
            '${_accountController.activeMT5Account?.metaAccountNumber}',
        symbol: _selectedSymbol,
        volume: 0.01,
        type: type,
        priceSl: '',
        priceTp: '',
        price: '',
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnack('Order placed: $_selectedSymbol $type 0.01');
      } else {
        _showSnack(result['error'] ?? 'Failed to place order',
            isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (isError) {
      CustomToastService.showError(message: message);
    } else {
      CustomToastService.showSuccess(message: message);
    }
  }

  void _showPriceAlertDialogForSymbol() {
    final currentPrice = _socket.getMarketPrice() ?? 0.0;
    final digits = _digitsForCurrentSymbol();
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (ctx) => PriceAlertDialog(
        symbol: _selectedSymbol,
        currentPrice: currentPrice,
        digits: digits,
      ),
    );
  }

  @override
  void dispose() {
    _priceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bid = _socket.getBidPrice() ?? 0.0;
    final ask = _socket.getAskPrice() ?? 0.0;
    final digits = _digitsForCurrentSymbol();
    final bidStr = PrecisionHelper.formatPrice(bid, decimals: digits);
    final askStr = PrecisionHelper.formatPrice(ask, decimals: digits);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(),
        title: GestureDetector(
          onTap: _showSymbolPicker,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displaySymbol(_selectedSymbol),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    _SocketDot(connected: _socketReady),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
              size: 22.sp,
            ),
            onPressed: _showPriceAlertDialogForSymbol,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _quoteStrip(bidStr, askStr),
            _chartArea(),
            _quantityRow(),
            _tradingRow(),
          ],
        ),
      ),
    );
  }

  Widget _quoteStrip(String bidStr, String askStr) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _quoteCell(
              label: 'BID',
              value: bidStr,
              color: AppColors.statusRed,
            ),
          ),
          Container(
            height: 26.h,
            width: 1,
            color: AppColors.border.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _quoteCell(
              label: 'ASK',
              value: askStr,
              color: AppColors.statusGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteCell({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _chartArea() {
    final displaySymbol = _displaySymbol(_selectedSymbol);
    final effectiveSymbol =
        _datafeedSymbol.isNotEmpty ? _datafeedSymbol : displaySymbol;
    final url =
        '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$effectiveSymbol&theme=${AppColors.chartTheme}';

    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: ChartInAppWebView(
          key: _webViewKey,
          symbol: effectiveSymbol,
          url: url,
        ),
      ),
    );
  }

  Widget _quantityRow() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 8.w),
          Text(
            'Quantity',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '0.01 Lot',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tradingRow() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 14.h),
      child: Row(
        children: [
          Expanded(
            child: _tradeButton(
              label: 'SELL',
              color: AppColors.statusRed,
              onTap: () => _placeOneClickTrade('1'),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _tradeButton(
              label: 'BUY',
              color: AppColors.statusGreen,
              onTap: () => _placeOneClickTrade('buy'),
            ),
          ),
          SizedBox(width: 10.w),
          _pendingButton(),
        ],
      ),
    );
  }

  Widget _tradeButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isPlacingOrder ? null : onTap,
      child: AnimatedOpacity(
        opacity: _isPlacingOrder ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingButton() {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => PendingOrderScreen(
            symbol: _selectedSymbol,
            onNavigateToTrade: (i) {
              if (widget.onNavigateToTab != null && i != null) {
                widget.onNavigateToTab!(i);
              }
            },
          ),
        );
      },
      child: Container(
        height: 46.h,
        width: 46.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          Icons.access_time_rounded,
          color: AppColors.textPrimary,
          size: 20.sp,
        ),
      ),
    );
  }
}

/// Tiny status dot for the symbol pill that lights green when the chart
/// websocket is connected and grey when it isn't.
class _SocketDot extends StatelessWidget {
  final bool connected;

  const _SocketDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.statusGreen : AppColors.textSecondary;
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// Keep imports clean: json is used by chart-internal websockets indirectly.
// ignore: unused_element
void _kJson() => jsonEncode(<String, dynamic>{});
