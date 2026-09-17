// ============================================================
// Mirrors the TRADYN/JSX reference design (pixel-perfect):
//   • Slim header   : ←  SYMBOL ⌄  ●(tick)         [slider pill] top-right
//   • Top-right     : brand-primary icon (light mode) / white icon (dark mode)
//   • Chart area    : TradingView WebView (free widget)
//   • Bottom dock   : Quantity stepper + [pending-pill icon] + bell
//                     ─────────────────────────────────────────
//                     SELL  bid  •  spread  •  ask  BUY
//   • BUY button    : FlavorConfig.primaryColor
//   • SELL button   : AppColors.error (red gradient)
//   • Spread chip   : pip number in the middle
//
// Symbol pill (← SYMBOL ⌄) opens a **favourites dropdown** listing only
// the symbols in FavoritesStorageService. Long-press or the settings
// icon opens the full search screen.
//
// The "pending order" icon between quantity `+` and bell opens the
// PendingOrderScreen pre-loaded with the current symbol.
//
// Reuses the existing ChartInAppWebView (from lib/widgets/) so the
// datafeed bridge and TradingView JS shim loaded by the legacy
// chart screen are reused unchanged.
//
// Wired into lib/screens/home/chart_screen.dart via
// `if (FlavorConfig.usesVantageUi()) return VantageChartLayout(...)`.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crm_app/constants/text_styles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/home/pending_order_screen.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/favorites_storage_service.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/widgets/tenax_chart_webview.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/price_alert_dialog.dart';

class VantageChartLayout extends StatefulWidget {
  /// Called when the user taps a symbol in the favourites dropdown.
  /// Optional — when null, the layout selects the symbol itself.
  final ValueChanged<String>? onSymbolSelected;

  /// Called when the user wants to leave the chart tab for another
  /// bottom-nav destination. Null when shown standalone.
  final ValueChanged<int>? onNavigateToTab;

  const VantageChartLayout({
    super.key,
    this.onSymbolSelected,
    this.onNavigateToTab,
  });

  @override
  State<VantageChartLayout> createState() => _VantageChartLayoutState();
}

class _VantageChartLayoutState extends State<VantageChartLayout> {
  final GlobalKey<ChartInAppWebViewState> _webViewKey = GlobalKey<ChartInAppWebViewState>();
  double _volume = 0.01;

  /// Editable backing field for the quantity TextField. Keeps the
  /// raw user-typed string so the user can clear & retype a value
  /// without the field forcing a fixed-decimal format mid-edit.
  late final TextEditingController _volumeController;
  // ignore: prefer_final_fields
  bool _userTypingVolume = false;

  // Bumped on every price tick AND when the active symbol changes so
  // the bottom-dock Obx rebuilds bid/ask/spread for the new symbol.
  final RxInt _tick = 0.obs;
  StreamSubscription<dynamic>? _priceSub;

  // ── Controller shortcuts ─────────────────────────────────────────────
  TradingController get _trade => Get.find<TradingController>();
  ChartSocketController get _socket => Get.find<ChartSocketController>();
  AccountController get _account => Get.find<AccountController>();
  LanguageService get _lang => Get.find<LanguageService>();

  StreamSubscription<String>? _symSub;

  @override
  void initState() {
    super.initState();
    _volumeController = TextEditingController(text: _volume.toStringAsFixed(2));
    // Push the active symbol into the socket so its bid/ask maps start
    // streaming ticks for the selected instrument.
    final initial = _rawSymbol();
    if (initial.isNotEmpty) {
      _socket.changeSymbol(initial);
    }
    // Live tick → bump _tick so SELL/BUY sub-labels refresh.
    _priceSub = _socket.priceStream.listen((_) {
      if (mounted) _tick.value++;
    });
    // Listen to symbol changes from Prices/Watchlist/Search screens
    _symSub = Get.find<SymbolSelectionService>().lastSymbolRx.listen((sym) {
      if (mounted && sym.isNotEmpty) {
        setState(() {});
        _socket.changeSymbol(_rawSymbol());
      }
    });
  }

  @override
  void dispose() {
    _symSub?.cancel();
    _priceSub?.cancel();
    _volumeController.dispose();
    super.dispose();
  }

  // ── Symbol / price helpers ──────────────────────────────────────────
  String _rawSymbol() {
    final s = Get.find<SymbolSelectionService>().currentSymbol;
    if (s.isNotEmpty) return s;
    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>();
      if (inst.instruments.isNotEmpty) return inst.instruments.first.symbol;
    }
    return 'XAUUSD';
  }

  String _displaySymbol() {
    final s = _rawSymbol();
    return s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;
  }

  // ── Order handling ────────────────────────────────────────────────
  Future<void> _placeOrder(String side) async {
    final bid = _socket.getBidPrice();
    final ask = _socket.getAskPrice();
    if (bid == null || ask == null) {
      CustomToastService.showWarning(message: _lang.tr('vantage_waiting_live_price'));
      return;
    }
    final active = _account.activeMT5Account;
    if (active == null) {
      CustomToastService.showWarning(message: _lang.tr('vantage_no_active_account'));
      return;
    }

    try {
      final ok = await _trade.placeTradeOrder(
        orderType:
            side.toLowerCase() == 'buy'
                ? OrderType.buyMarket
                : OrderType.sellMarket,
        symbol: _rawSymbol(),
        volume: _volume.toStringAsFixed(2),
        price: '',
      );

      if (!mounted) return;
      if (ok) {
        CustomToastService.showInfo(
          message: '${side.toUpperCase()} $_volume ${_rawSymbol()} placed.',
        );
      }
      // Error toast is already shown by TradingController._setError
      // with the actual API message + account number
    } catch (e) {
      if (!mounted) return;
      CustomToastService.showError(message: '${_lang.tr('vantage_trade_error')}: $e');
    }
  }

  void _bumpVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0.01, 100.0);
      _volume = double.parse(_volume.toStringAsFixed(2));
      // Sync the editable field ONLY when the user isn't actively
      // typing — otherwise typing becomes a fight with the +/- keys.
      if (!_userTypingVolume) {
        _volumeController.value = TextEditingValue(
          text: _volume.toStringAsFixed(2),
          selection: TextSelection.collapsed(
            offset: _volume.toStringAsFixed(2).length,
          ),
        );
      }
    });
  }

  /// Parse text typed into the Quantity TextField. Accepts partial
  /// input (e.g. "0.", ".5", "12.") so the user can edit naturally,
  /// but commits a clamped 2-decimal double to `_volume` on every
  /// keystroke so the order handlers always see a usable value.
  void _onVolumeTextChanged(String raw) {
    // Empty / just a dot / just a leading-zero dot: keep the typed
    // text visible (don't clobber with a fixed format) but don't
    // change `_volume` so the place-order code stays guarded.
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '-') {
      _userTypingVolume = true;
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      // Invalid input — revert the field back to the last known good
      // value so the user can keep editing.
      _userTypingVolume = true;
      _volumeController.value = TextEditingValue(
        text: _volume.toStringAsFixed(2),
        selection: TextSelection.collapsed(
          offset: _volume.toStringAsFixed(2).length,
        ),
      );
      return;
    }
    _userTypingVolume = true;
    setState(() {
      _volume = parsed.clamp(0.01, 100.0).toDouble();
      // Don't rewrite the field on every keystroke — that would lose
      // the cursor position. We only sync from `+` / `-` buttons.
    });
  }

  /// Called when the TextField loses focus — final normalization:
  /// snap the displayed text back to 2-decimal format.
  void _onVolumeEditingComplete() {
    _userTypingVolume = false;
    final formatted = _volume.toStringAsFixed(2);
    _volumeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    if (mounted) setState(() {});
  }

  // Symbol dropdown (only favourites, scrollable).
  //
  // Mirrors the watchlist behaviour: tapping a symbol in this sheet
  // (a) updates the chart via SymbolSelectionService,
  // (b) flips the chart socket so the bottom-dock bid/ask/spread
  //     refreshes for the new symbol (same as
  //     `ChartScreen.setSelectedSymbol` does on watchlist tap), and
  // (c) notifies the host via `widget.onSymbolSelected` so the parent
  //     (e.g. TradingMainScreen) can react if needed.
  Future<void> _openFavouritesDropdown() async {
    if (!mounted) return;

    // Dark-mode-aware colors for the bottom sheet.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final sheetBg = isDark ? const Color(0xFF1A1A20) : Colors.white;
    final rowBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F5);
    final dividerColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F5);
    final handleColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E5);
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);
    final fg = isDark ? Colors.white : const Color(0xFF111114);

    // Active symbol so we can highlight it in the list.
    final active = _displaySymbol();

    // Pull favourites from storage. FavoritesStorageService persists the
    // user's list across launches (with sensible defaults if it has
    // never been written yet) — it is the same source of truth the
    // watchlist's "Favorites" filter uses.
    final favoritesRaw =
        await FavoritesStorageService.instance.getFavoriteInstruments();

    if (!mounted) return;

    // Pull ALL instruments from the live instruments stream so we can
    // resolve favourites → display names + metadata. If the stream is
    // still empty (cold start), we fall back to the raw favourites
    // strings so the user still sees their list.
    final instruments =
        Get.find<InstrumentsController>().allInstruments.toList();

    if (!mounted) return;

    // Normalize favourites to the same stripped form we display, so a
    // favourite like "EURUSD.c" matches an instrument stored as
    // "EURUSD.c" and a display label "EURUSD".
    final favSet =
        favoritesRaw.map((s) => _stripSuffix(s).toUpperCase()).toSet();

    // Build a list of raw symbol strings. Prefer symbols that resolve
    // to an entry in `allInstruments` (so the row taps the same backing
    // data the rest of the app uses); fall back to the favourite string
    // itself if the stream hasn't loaded yet.
    final filtered = <String>[];
    final seen = <String>{};
    if (instruments.isNotEmpty) {
      for (final inst in instruments) {
        final stripped = _stripSuffix(inst.symbol).toUpperCase();
        if (favSet.contains(stripped) && !seen.contains(stripped)) {
          seen.add(stripped);
          filtered.add(inst.symbol);
        }
      }
    } else {
      for (final raw in favoritesRaw) {
        final stripped = _stripSuffix(raw).toUpperCase();
        if (!seen.contains(stripped)) {
          seen.add(stripped);
          filtered.add(raw);
        }
      }
    }
    filtered.sort(
      (a, b) => _stripSuffix(
        a,
      ).toUpperCase().compareTo(_stripSuffix(b).toUpperCase()),
    );

    if (filtered.isEmpty) {
      // Nothing favourited yet — open the full search screen so the user
      // can pick a symbol AND promote it to favourites in one go.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SearchInstrumentsScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                // Scrollable list of FAVOURITE symbols only
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, __) => Divider(height: 1, color: dividerColor),
                    itemBuilder: (_, i) {
                      final raw = filtered[i];
                      final sym = _stripSuffix(raw);
                      final isActive = sym == active;
                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          // (a) tell the rest of the app which symbol to
                          //     use (drives chart rebuild via ValueKey in
                          //     `_ChartArea`).
                          Get.find<SymbolSelectionService>().setSymbol(raw);
                          ChartScreen.setSelectedSymbol(raw);
                          // Immediately rebuild this layout so the Header
                          // (top-left) shows the new symbol instantly.
                          setState(() {});
                          // (b) flip the chart socket so the bottom dock
                          //     bid / ask / spread refresh for the new
                          //     symbol — same as the watchlist row tap
                          //     flow does via `ChartScreen.setSelectedSymbol`.
                          try {
                            _socket.changeSymbol(raw);
                          } catch (_) {}
                          // (c) bump the local tick so the dock Obx
                          //     rebuilds even before the first tick of
                          //     the new symbol arrives (avoids stale '—').
                          _tick.value++;
                          // (d) notify the host — same semantics the
                          //     watchlist gives the TradingMainScreen.
                          widget.onSymbolSelected?.call(raw);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28.w,
                                height: 28.h,
                                decoration: BoxDecoration(
                                  color:
                                      isActive
                                          ? primary.withValues(alpha: 0.12)
                                          : rowBg,
                                  borderRadius: BorderRadius.circular(7.r),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.show_chart,
                                  size: 16.sp,
                                  color: isActive ? primary : muted,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  sym,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 15.sp,
                                    fontWeight:
                                        isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color: isActive ? primary : fg,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Icon(Icons.check, size: 18.sp, color: primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _stripSuffix(String symbol) {
    return symbol.contains('.')
        ? symbol.substring(0, symbol.lastIndexOf('.'))
        : symbol;
  }

  void _openPendingOrderScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PendingOrderScreen(symbol: _rawSymbol()),
      ),
    );
  }

  // ── Price alert bottom sheet (reuses the legacy PriceAlertDialog) ──────
  void _openPriceAlertSheet() {
    final symbol = _rawSymbol();
    final marketPrice = _socket.getMarketPrice() ?? 0.0;
    if (marketPrice == 0.0) {
      CustomToastService.showWarning(message: _lang.tr('vantage_waiting_live_price'));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder:
          (_) => PriceAlertDialog(symbol: symbol, currentPrice: marketPrice),
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // AppColors.primary automatically returns darkPrimaryColor when dark mode
    // is on, so the BUY button + top-right pill + qty bar stay on-brand.
    final primary = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              symbol: _displaySymbol(),
              primary: primary,
              isDark: isDark,
              onBack: () => Navigator.of(context).maybePop(),
              onSymbolTap: _openFavouritesDropdown,
              // Top-right button jumps to the "Trade" tab.
              // Vantage 5-tab nav (as of 2026-07-09):
              //   Prices(0), Chart(1), Markets(2)=Trade, Accounts(3), Settings(4).
              onSettingsTap: () {
                // Always jump to the Markets tab (index 2 in the Vantage
                // 5-tab layout: Prices(0), Chart(1), Markets(2), Accounts(3),
                // Settings(4)).
                //
                // The parent (TradingMainScreen._openChartScreenVantage)
                // wires onNavigateToTab to a callback that pops the chart
                // route and calls _onTabChanged(2). We MUST NOT call
                // Navigator.pop / Get.back here — that would double-pop
                // and tear down TradingMainScreen, kicking the user out
                // of the app.
                print(
                  '🔧 VantageChartLayout: onSettingsTap fired, onNavigateToTab=${widget.onNavigateToTab != null}',
                );
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(2);
                } else {
                  // Standalone context (chart shown outside the bottom-nav
                  // tree, e.g. opened from a deep link). Fall back to a
                  // regular pop so the user can still leave the chart.
                  Navigator.of(context).maybePop();
                  CustomToastService.showInfo(
                    message: _lang.tr('vantage_trade_tab_unavailable'),
                  );
                }
              },
            ),
            // hairline divider exactly as in the TRADYN reference
            Container(height: 1, color: const Color(0x14000000)),
            Expanded(child: _ChartArea(isDark: isDark, webViewKey: _webViewKey)),
            Container(height: 1, color: const Color(0x14000000)),
            _BottomDock(
              primary: primary,
              isDark: isDark,
              volume: _volume,
              tick: _tick,
              volumeController: _volumeController,
              onVolumeChanged: _onVolumeTextChanged,
              onVolumeSubmitted: _onVolumeEditingComplete,
              onMinus: () => _bumpVolume(-0.01),
              onPlus: () => _bumpVolume(0.01),
              onPending: _openPendingOrderScreen,
              onSell: () => _placeOrder('sell'),
              onBuy: () => _placeOrder('buy'),
              onBell: _openPriceAlertSheet,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Header  :  ←  SYMBOL ⌄  ●  +  brand-primary (light) / white (dark)
//              top-right pill icon
// ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String symbol;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSymbolTap;
  final VoidCallback onSettingsTap;

  const _Header({
    required this.symbol,
    required this.primary,
    required this.isDark,
    required this.onBack,
    required this.onSymbolTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111114);
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 8.h, 12.w, 8.h),
      child: Row(
        children: [
          // Back arrow
          // IconButton(
          //   onPressed: onBack,
          //   icon: Icon(Icons.arrow_back, size: 22.sp, color: fg),
          //   padding: EdgeInsets.zero,
          //   constraints: const BoxConstraints(),
          // ),
          // SizedBox(width: 6.w),
          // Symbol pill
          Expanded(
            child: InkWell(
              onTap: onSymbolTap,
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slightly bolder font for the symbol, like the reference
                  Text(
                    symbol,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.keyboard_arrow_down, size: 22.sp, color: muted),
                ],
              ),
            ),
          ),
          // Top-right active-account chip: wallet icon + #account + DEMO/LIVE
          // badge. Tapping opens the SAME dropdown the Prices tab uses
          // (anchored popup menu) so both tabs stay in sync via AccountController.
          Builder(
            builder: (pillContext) => GestureDetector(
              onTap: () {
                final accCtrl = Get.find<AccountController>();
                accCtrl.resetToDefaultAccounts();
                _showAccountPopup(pillContext, accCtrl);
              },
              child: Obx(() {
                final active = Get.find<AccountController>().activeMT5Account;
                final accNumber = active?.metaAccountNumber ?? '------';
                final isDemo =
                    (active?.accountType ?? 'REAL').toUpperCase() == 'DEMO';
                final typeText = isDemo ? 'DEMO' : 'LIVE';
                final typeColor = isDemo ? AppColors.primary : AppColors.accent;

                final tcInfo = Get.isRegistered<TradingController>()
                    ? Get.find<TradingController>().accountInfoRx.value
                    : null;
                final double? equity = tcInfo?.equity;
                final double? profit = tcInfo?.profit;
                final equityText = equity != null
                    ? '\$${equity.toStringAsFixed(2)}'
                    : null;
                final profitText = (profit != null && profit != 0.0)
                    ? '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)}'
                    : null;

                return Container(
                  height: 28.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: AppColors.isDarkMode
                        ? AppColors.surfaceSecondary
                        : AppColors.card.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.18),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: AppColors.isDarkMode
                              ? AppColors.surfaceSecondary
                              : typeColor.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 12.sp,
                          color: AppColors.isDarkMode
                              ? AppColors.whiteColor
                              : typeColor,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        accNumber,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (equityText != null) ...[
                        SizedBox(width: 6.w),
                        Text(
                          equityText,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      // if (profitText != null) ...[
                      //   SizedBox(width: 4.w),
                      //   Text(
                      //     profitText,
                      //     style: AppTextStyles.bodyText.copyWith(
                      //       fontSize: 11.sp,
                      //       fontWeight: FontWeight.w500,
                      //       color: AppColors.textGrey,
                      //     ),
                      //   ),
                      // ],
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.isDarkMode
                              ? AppColors.surfaceSecondary
                              : typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeText,
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.isDarkMode
                                ? AppColors.whiteColor
                                : typeColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Anchored dropdown listing all MT5 accounts (same UX as the Prices tab
  /// header). Tapping a row switches the active account via AccountController,
  /// which the chip's Obx picks up automatically.
  Future<void> _showAccountPopup(
    BuildContext anchorContext,
    AccountController accountController,
  ) async {
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = position & renderBox.size;

    final selected = await showMenu<String>(
      context: anchorContext,
      color: AppColors.card,
      surfaceTintColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.border.withOpacity(0.18), width: 0.5),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(rect.left, rect.bottom + 6.h, rect.width, rect.height),
        Offset.zero & overlay.size,
      ),
      items: accountController.mt5Accounts.map((account) {
        final isActive =
            accountController.activeMT5Account?.metaAccountNumber ==
            account.metaAccountNumber;
        final type = account.accountType.toUpperCase();
        final typeColor = type == 'LIVE' ? AppColors.accent : AppColors.primary;

        return PopupMenuItem<String>(
          value: account.metaAccountNumber,
          height: 42.h,
          child: Row(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.isDarkMode
                      ? AppColors.surfaceSecondary
                      : typeColor.withOpacity(0.16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 12.sp,
                  color: AppColors.isDarkMode
                      ? AppColors.whiteColor
                      : typeColor,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  account.metaAccountNumber,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.isDarkMode
                      ? AppColors.surfaceSecondary
                      : typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  type,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.isDarkMode
                        ? AppColors.whiteColor
                        : typeColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isActive) ...[
                SizedBox(width: 8.w),
                Icon(Icons.check, size: 16.sp, color: AppColors.success),
              ],
            ],
          ),
        );
      }).toList(),
    );

    if (selected == null) return;
    if (accountController.isLoading) return;
    if (accountController.activeMT5Account?.metaAccountNumber == selected) {
      return;
    }

    try {
      await accountController.setActiveMT5Account(selected);
    } catch (e) {
      if (kDebugMode) debugPrint('Account switch failed: $e');
    }
  }
}

// ────────────────────────────────────────────────────────────────────
//  Chart area  :  TradingView WebView (free widget if enabled)
// ────────────────────────────────────────────────────────────────────
//
// For Pipze: StatefulWidget that owns the TenaxChartWebView key locally
// and subscribes to SymbolSelectionService directly (no GlobalKey
// propagation through Obx parents). When the symbol changes, it calls
// updateSymbol() on the TenaxChartWebView state directly — guaranteed
// to reach the controller without any widget-tree matching ambiguity.
// ────────────────────────────────────────────────────────────────────
class _ChartArea extends StatefulWidget {
  final bool isDark;
  final GlobalKey<ChartInAppWebViewState> webViewKey;

  const _ChartArea({
    required this.isDark,
    required this.webViewKey,
  });

  @override
  State<_ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<_ChartArea> {
  // Local key owned by this State — never passed through Obx rebuild chains.
  final _tenaxKey = GlobalKey<TenaxChartWebViewState>();

  // The symbol the TenaxChartWebView was FIRST built with. Never changes so
  // the WebView is never torn down. Symbol updates go through the controller.
  String? _initialSymbol;

  late SymbolSelectionService _symService;
  StreamSubscription<String>? _symSub;

  @override
  void initState() {
    super.initState();
    _symService = Get.find<SymbolSelectionService>();

    // Seed the initial symbol synchronously.
    _initialSymbol = _stripDot(_symService.currentSymbol);

    // Listen for future symbol changes and push them into the chart
    // controller directly — no rebuild of TenaxChartWebView needed.
    _symSub = _symService.lastSymbolRx.listen(_onSymbolChanged);
  }

  @override
  void dispose() {
    _symSub?.cancel();
    super.dispose();
  }

  void _onSymbolChanged(String newSym) {
    final raw = _stripDot(newSym);
    String? acc;
    if (Get.isRegistered<AccountController>()) {
      acc = Get.find<AccountController>().activeMT5Account?.metaAccountNumber.toString();
    }
    final effective = SymbolDetailsCacheService.resolveDatafeedSymbolSync(raw, acc);
    _initialSymbol = effective;
    // Push the new symbol into the running WebView without rebuilding.
    _tenaxKey.currentState?.updateSymbol(effective);
    widget.webViewKey.currentState?.updateSymbol(effective);
  }

  static String _stripDot(String s) {
    if (s.isNotEmpty) return s;
    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>();
      if (inst.instruments.isNotEmpty) {
        return inst.instruments.first.symbol;
      }
    }
    return 'XAUUSD';
  }

  @override
  Widget build(BuildContext context) {
    // The chart WebView renders candles / price axes and must never be
    // mirrored by the ambient RTL direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Obx(() {
      final useNew = FlavorConfig.instance.useNewChart;
      final raw = _stripDot(Get.find<SymbolSelectionService>().currentSymbol);
      String? acc;
      if (Get.isRegistered<AccountController>()) {
        acc = Get.find<AccountController>().activeMT5Account?.metaAccountNumber.toString();
      }
      final effective = SymbolDetailsCacheService.resolveDatafeedSymbolSync(raw, acc);

      if (useNew) {
        return TenaxChartWebView(
          key: _tenaxKey,
          symbol: _initialSymbol ?? effective,
          isDark: widget.isDark,
        );
      }
      
      final url =
          '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?theme=${widget.isDark ? 'dark' : 'light'}';
      return ChartInAppWebView(
        key: widget.webViewKey,
        symbol: effective,
        url: url,
      );
      }),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Bottom dock  :  Quantity stepper + SELL • spread • BUY
// ────────────────────────────────────────────────────────────────────
class _BottomDock extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final double volume;
  final RxInt tick;
  final TextEditingController volumeController;
  final ValueChanged<String> onVolumeChanged;
  final VoidCallback onVolumeSubmitted;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPending;
  final VoidCallback onSell;
  final VoidCallback onBuy;
  final VoidCallback onBell;

  const _BottomDock({
    required this.primary,
    required this.isDark,
    required this.volume,
    required this.tick,
    required this.volumeController,
    required this.onVolumeChanged,
    required this.onVolumeSubmitted,
    required this.onMinus,
    required this.onPlus,
    required this.onPending,
    required this.onSell,
    required this.onBuy,
    required this.onBell,
  });

  /// Strip trailing zeros (and a dangling `.`) so 20.00 -> "20",
  /// 20.50 -> "20.5", 1.08000 -> "1.08". Used to display
  /// bid/ask/spreadDiff as the server sent them, without a forced
  /// fixed-decimal count.
  static String _trimTrailingZeros(double value) {
    var s = value.toString();
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F12) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 8.h, 12.w, 14.h),
      child: Obx(() {
        // ──────────────────────────────────────────�───────────────
        // ignore: unused_local_variable
        final _ = tick.value;
        // Guard against teardown (e.g. logout) where controllers are deleted
        // while this layout is still mounted — an unguarded find throws
        // "ChartSocketController not found" every frame.
        if (!Get.isRegistered<ChartSocketController>()) {
          return const SizedBox.shrink();
        }
        final socket = Get.find<ChartSocketController>();
        // ignore: invalid_use_of_protected_member
        final priceMap = socket.realTimePrice.value;

        // Direct display - no digit-rounding, no pip-conversion.
        // The server already sends bid/ask at the symbol's natural
        // precision (5 digits for EURUSD, 2 for XAUUSD/JPY pairs,
        // 3 for JPY crosses). bid.toString() preserves those
        // decimals exactly.
        // spreadDiff comes from the WS pre-converted to *points*
        // (the controller's // spread_points comment). Display
        // it as-is - no extra /pip math.
        final sym = socket.currentSymbol.value.isNotEmpty
            ? socket.currentSymbol.value
            : Get.find<SymbolSelectionService>().currentSymbol;

        final priceSymbol = priceMap['symbol']?.toString();
        final bool isMatch = priceSymbol != null &&
            (priceSymbol == sym ||
                _VantageChartLayoutState._stripSuffix(priceSymbol) ==
                    _VantageChartLayoutState._stripSuffix(sym));

        var bid = isMatch && priceMap['bid'] is num
            ? (priceMap['bid'] as num).toDouble()
            : null;
        var ask = isMatch && priceMap['ask'] is num
            ? (priceMap['ask'] as num).toDouble()
            : null;
        var spreadDiff = isMatch && priceMap['spreadDiff'] is num
            ? (priceMap['spreadDiff'] as num).toDouble()
            : null;

        if ((bid == null || bid == 0.0 || ask == null || ask == 0.0) &&
            Get.isRegistered<InstrumentsController>()) {
          final inst = Get.find<InstrumentsController>();
          final live = inst.getLivePrice(sym);
          if (live != null && live.bid > 0) {
            bid = live.bid;
            ask = live.ask;
            spreadDiff = live.spreadDiff;
          } else {
            final match = inst.findInstrument(sym);
            if (match != null && match.bid > 0) {
              bid = match.bid;
              ask = match.ask;
              spreadDiff = match.spreadDiff;
            }
          }
        }

        // Absolute fallback to last valid socket price to eliminate dash lines
        if ((bid == null || bid == 0.0) &&
            priceMap['bid'] is num &&
            (priceMap['bid'] as num) > 0) {
          bid = (priceMap['bid'] as num).toDouble();
          ask = priceMap['ask'] is num
              ? (priceMap['ask'] as num).toDouble()
              : bid;
          spreadDiff = priceMap['spreadDiff'] is num
              ? (priceMap['spreadDiff'] as num).toDouble()
              : 0.0;
        }

        final bidStr =
            (bid != null && bid != 0.0) ? _trimTrailingZeros(bid) : '—';
        final askStr =
            (ask != null && ask != 0.0) ? _trimTrailingZeros(ask) : '—';
        final spreadStr =
            (spreadDiff != null && spreadDiff > 0)
                ? _trimTrailingZeros(spreadDiff)
                : '—';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuantityBar(
              primary: primary,
              isDark: isDark,
              volume: volume,
              volumeController: volumeController,
              onVolumeChanged: onVolumeChanged,
              onVolumeSubmitted: onVolumeSubmitted,
              onMinus: onMinus,
              onPlus: onPlus,
              onPending: onPending,
              onBell: onBell,
            ),
            SizedBox(height: 10.h),
            SafeArea(
              // Bid / spread / ask are numeric market data — keep the
              // price columns left-to-right even in Arabic.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                children: [
                  Expanded(
                    child: _SideButton(
                      label: Get.find<LanguageService>().tr('meta_neworder_sell'),
                      sub: bidStr,
                      color: AppColors.error,
                      onTap: onSell,
                    ),
                  ),
                  Container(
                    width: 56.w,
                    height: 56.h,
                    margin: EdgeInsets.symmetric(horizontal: 6.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1A1A20)
                              : const Color(0xFFF6F4F8),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      spreadStr,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _SideButton(
                      label: Get.find<LanguageService>().tr('meta_neworder_buy'),
                      sub: askStr,
                      color: primary,
                      onTap: onBuy,
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Quantity bar  :  [−]  Quantity (lots) 0.01 (editable)  [+]  [📋]  [🔔]
// ────────────────────────────────────────────────────────────────────
class _QuantityBar extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final double volume;
  final TextEditingController volumeController;
  final ValueChanged<String> onVolumeChanged;
  final VoidCallback onVolumeSubmitted;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPending;
  final VoidCallback onBell;

  const _QuantityBar({
    required this.primary,
    required this.isDark,
    required this.volume,
    required this.volumeController,
    required this.onVolumeChanged,
    required this.onVolumeSubmitted,
    required this.onMinus,
    required this.onPlus,
    required this.onPending,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);

    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A20) : const Color(0xFFF6F4F8),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          _QtyBtn(icon: Icons.remove, color: primary, onTap: onMinus),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Get.find<LanguageService>().tr('vantage_chart_layout_quantity_lots'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      color: muted,
                    ),
                  ),
                  // Editable TextField in place of the static Text widget.
                  // Same footprint as the previous Text so the +/- icons
                  // and pending/bell buttons stay in their existing slots.
                  SizedBox(
                    height: 24.h,
                    child: TextField(
                      controller: volumeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      // Don't fight the +/- buttons while user is mid-typing.
                      // The parent normalizes the displayed value once on
                      // focus-loss / submit via `onVolumeSubmitted`.
                      onChanged: onVolumeChanged,
                      onEditingComplete: onVolumeSubmitted,
                      onSubmitted: (_) => onVolumeSubmitted(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        // color: fg,
                        height: 1.1,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add, color: primary, onTap: onPlus),
          // Pending order (pen + note) icon — opens the pending screen
          _QtyBtn(icon: Icons.edit_note, color: primary, onTap: onPending),
          _QtyBtn(
            icon: Icons.notifications_none,
            color: primary,
            onTap: onBell,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 44.w,
        height: 44.h,
        alignment: Alignment.center,
        child: Icon(icon, size: 22.sp, color: color),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _SideButton({
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16.r),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.whiteColor,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              sub,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.whiteColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
