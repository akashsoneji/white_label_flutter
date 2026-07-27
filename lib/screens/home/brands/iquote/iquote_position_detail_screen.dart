// IQuotePositionDetailScreen — dedicated full-screen detail view that
// opens when a row is tapped from IQuotePositionScreen.
//
// Layout matches the trading-app reference:
//
//   ┌─────────────────────────────────────────────────┐
//   │  ✕    [account no.] 🔗                          │  ← top header
//   │  XAU/USD                8.0400                  │  ← symbol + live px
//   │  Sell 300X 0.03Lot                              │  ← side + lev + lot
//   │  Period  1M  5M  15M  30M  More  📅  ⚙  ⛶     │  ← toolbar (faded)
//   │  MA5:xx   MA10:xx   MA30:xx                     │  ← MA strip (faded)
//   │                                                 │
//   │       ── candle area (placeholder) ──            │  ← reserved chart
//   │                                                 │     area (real chart
//   │                                                 │      lands later)
//   │  TP/SL | Add Position | Reverse Order           │  ← tab bar
//   │  ─────────────────────────────────────────       │
//   │  [tab content here — TP/SL steppers,            │
//   │   Add Position volume, Reverse Order summary]   │
//   │  Cancel                              Close Order│  ← bottom bar
//   └─────────────────────────────────────────────────┘
//
// Wiring:
//   • Header price is live via InstrumentsController.priceRx(symbol)
//   • TP/SL tab → TradingController.updateTPSL on Close Order
//   • Add Position tab → TradingController.placeTradeOrder on Open Order
//   • Reverse Order tab → closePositionById + placeTradeOrder on confirm
//
// Note: the chart area is a *placeholder* — the real chart (with candles +
// MA + MACD + period zoom) lands in a follow-up. We reserve ~42% of screen
// height with a dark area + right-axis ticks + bid/ask marker lines so the
// page already looks right and the chart has a stable slot to mount into.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';


// Module-private helpers — exposed to child StatelessWidgets so
// _TpSlPanel / _ReversePanel can derive side labels without duplicating logic.
String _sideFor(TradePosition p) {
  final a = p.action.trim().toLowerCase();
  if (a == 'buy') return 'Buy';
  if (a == 'sell') return 'Sell';
  return 'Sell';
}

bool _isBuy(TradePosition p) => _sideFor(p) == 'Buy';

double? _priceStrToDouble(String s) {
  final v = double.tryParse(s.trim());
  if (v == null || v <= 0) return null;
  return v;
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.chartAreaBg,
    required this.divider,
    required this.axisText,
    required this.fieldBg,
    required this.fieldBorder,
    required this.surface,
  });
  final Color bg;
  final Color chartAreaBg;
  final Color divider;
  final Color axisText;
  final Color fieldBg;
  final Color fieldBorder;
  final Color surface;

  static _Palette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _Palette(
        bg: Color(0xFF0E1726),
        chartAreaBg: Color(0xFF142033),
        divider: Color(0x22FFFFFF),
        axisText: Color(0xFFAAAACC),
        fieldBg: Color(0xFF1A2440),
        fieldBorder: Color(0x33FFFFFF),
        surface: Color(0xFF111A2E),
      );
    }
    return const _Palette(
      bg: Color(0xFFF6F7FB),
      chartAreaBg: Color(0xFFFFFFFF),
      divider: Color(0x22000000),
      axisText: Color(0xFF6B7280),
      fieldBg: Color(0xFFF1F3F8),
      fieldBorder: Color(0xFFE3E6EE),
      surface: Color(0xFFFFFFFF),
    );
  }
}

enum _DetailTab { tpsl, addPosition, reverse, close }

class IQuotePositionDetailScreen extends StatefulWidget {
  const IQuotePositionDetailScreen({super.key, required this.position});

  /// The open position to display. Symbol/side/volume/sl/tp/price are all
  /// pulled from this object; live bid/ask is layered on top for the price
  /// header + chart markers.
  final TradePosition position;

  @override
  State<IQuotePositionDetailScreen> createState() =>
      _IQuotePositionDetailScreenState();
}

class _IQuotePositionDetailScreenState
    extends State<IQuotePositionDetailScreen> {
  _DetailTab _tab = _DetailTab.tpsl;

  // ── TP/SL state ────────────────────────────────────────────────────────
  // Two simple stepper values (USD) — empty/0 means "no change".
  final TextEditingController _tpCtl = TextEditingController();
  final TextEditingController _slCtl = TextEditingController();
  final FocusNode _tpFocus = FocusNode();
  final FocusNode _slFocus = FocusNode();

  // ── Add-Position state ─────────────────────────────────────────────────
  late TextEditingController _addVolumeCtl;
  double _addVolume = 0.03;
  bool _addIncludeVip = true;

  // ── Reverse-Order state is read-only (displays the existing + opposite) ─

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pos = widget.position;
    _addVolumeCtl = TextEditingController(text: pos.volume.toStringAsFixed(2));
    _addVolume = pos.volume;
    // Pre-fill TP/SL from the existing position if present.
    final sl = _priceStrToDouble(pos.stopLoss);
    final tp = _priceStrToDouble(pos.takeProfit);
    if (sl != null && sl > 0) _slCtl.text = sl.toStringAsFixed(pos.digits);
    if (tp != null && tp > 0) _tpCtl.text = tp.toStringAsFixed(pos.digits);
  }

  @override
  void dispose() {
    _tpCtl.dispose();
    _slCtl.dispose();
    _tpFocus.dispose();
    _slFocus.dispose();
    _addVolumeCtl.dispose();
    super.dispose();
  }

  TradingController get _trading => Get.find<TradingController>();
  AccountController get _account => Get.find<AccountController>();

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final palette = _Palette.of(context);
    final isBuy = _isBuy(pos);
    final sideLabel = isBuy ? 'Buy' : 'Sell';
    final sideColor = isBuy ? AppColors.statusGreen : AppColors.error;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              pos: pos,
              sideLabel: sideLabel,
              sideColor: sideColor,
              palette: palette,
            ),
            // Chart-area placeholder (reserves ~42% of screen height). The
            // real chart will mount into this slot in a follow-up.
            Expanded(
              flex: 100,
              child: _ChartPlaceholder(
                symbol: pos.symbol,
                digits: pos.digits,
                palette: palette,
              ),
            ),
            _TabBar(
              current: _tab,
              onChange: (t) => setState(() => _tab = t),
              palette: palette,
            ),
            Expanded(
              flex: 100,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (_tab) {
                  _DetailTab.tpsl => _TpSlPanel(
                      pos: pos,
                      tpCtl: _tpCtl,
                      slCtl: _slCtl,
                      tpFocus: _tpFocus,
                      slFocus: _slFocus,
                      palette: palette,
                      key: const ValueKey('tpsl'),
                    ),
                  _DetailTab.addPosition => _AddPositionPanel(
                      pos: pos,
                      sideLabel: sideLabel,
                      volumeCtl: _addVolumeCtl,
                      volume: _addVolume,
                      onVolumeChange: _onAddVolumeChange,
                      includeVip: _addIncludeVip,
                      onIncludeVipChange: (v) =>
                          setState(() => _addIncludeVip = v),
                      palette: palette,
                      key: const ValueKey('add'),
                    ),
                  _DetailTab.reverse => _ReversePanel(
                      pos: pos,
                      sideLabel: sideLabel,
                      palette: palette,
                      key: const ValueKey('rev'),
                    ),
                  _DetailTab.close => _ClosePanel(
                      pos: pos,
                      sideLabel: sideLabel,
                      palette: palette,
                      key: const ValueKey('close'),
                    ),
                },
              ),
            ),
            _ActionRow(
              tab: _tab,
              busy: _busy,
              onCancel: () => Get.back<void>(),
              onPrimary: () => _onPrimary(context),
              sideColor: sideColor,
              palette: palette,
            ),
          ],
        ),
      ),
    );
  }

  // ── Add-position stepper ───────────────────────────────────────────────
  void _onAddVolumeChange(double v) {
    setState(() {
      _addVolume = v.clamp(0.01, 99.0);
      _addVolumeCtl.text = _addVolume.toStringAsFixed(2);
    });
  }

  // ── primary button per tab ─────────────────────────────────────────────
  Future<void> _onPrimary(BuildContext context) async {
    switch (_tab) {
      case _DetailTab.tpsl:
        await _submitTpSl();
        break;
      case _DetailTab.addPosition:
        await _submitAddPosition();
        break;
      case _DetailTab.reverse:
        await _submitReverse();
        break;
      case _DetailTab.close:
        await _submitCloseWithConfirm(context);
        break;
    }
  }

  Future<void> _submitTpSl() async {
    final pos = widget.position;
    final acct = _account.activeMT5AccountRx.value;
    if (acct == null) {
      _toastError('No active MT5 account selected.');
      return;
    }
    final tp = _parsePriceOrNull(_tpCtl.text);
    final sl = _parsePriceOrNull(_slCtl.text);
    setState(() => _busy = true);
    try {
      final ok = await _trading.updateTPSL(
        mt5Account: acct.metaAccountNumber,
        positionId: int.tryParse(pos.orderId.toString()) ?? 0,
        stopLoss: sl,
        takeProfit: tp,
        digits: pos.digits,
      );
      if (ok) {
        CustomToastService.showSuccess(
          message: 'TP/SL updated',
          title: 'Position updated',
        );
        await _trading.refreshTradeHistory();
        if (mounted) Get.back<void>();
      } else {
        _toastError(_trading.errorMessage.isEmpty
            ? 'Failed to update TP/SL.'
            : _trading.errorMessage);
      }
    } catch (e) {
      _toastError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAddPosition() async {
    final pos = widget.position;
    final acct = _account.activeMT5AccountRx.value;
    if (acct == null) {
      _toastError('No active MT5 account selected.');
      return;
    }
    if (_addVolume <= 0) {
      _toastError('Volume must be greater than 0.');
      return;
    }
    setState(() => _busy = true);
    try {
      final oppositeSide = _isBuy(pos) ? OrderType.sellMarket : OrderType.buyMarket;
      final ok = await _trading.placeTradeOrder(
        symbol: pos.symbol,
        volume: _addVolume.toStringAsFixed(2),
        orderType: oppositeSide,
        price: '',
        mt5Account: acct.metaAccountNumber,
      );
      if (ok) {
        CustomToastService.showSuccess(
          message:
              'Opened ${oppositeSide == OrderType.buyMarket ? "Buy" : "Sell"} ${_addVolume.toStringAsFixed(2)} ${pos.symbol}',
          title: 'Position opened',
        );
        await _trading.refreshTradeHistory();
        if (mounted) Get.back<void>();
      } else {
        _toastError(_trading.errorMessage.isEmpty
            ? 'Failed to open position.'
            : _trading.errorMessage);
      }
    } catch (e) {
      _toastError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReverse() async {
    final pos = widget.position;
    final acct = _account.activeMT5AccountRx.value;
    if (acct == null) {
      _toastError('No active MT5 account selected.');
      return;
    }
    setState(() => _busy = true);
    try {
      // 1) Close the current position.
      final closed = await _trading.closePositionById(
        mt5Account: acct.metaAccountNumber,
        positionId: int.tryParse(pos.orderId.toString()) ?? 0,
        volume: pos.volume,
      );
      if (!closed) {
        _toastError(_trading.errorMessage.isEmpty
            ? 'Failed to close position.'
            : _trading.errorMessage);
        return;
      }
      // 2) Open the opposite one at the same volume.
      final opposite = _isBuy(pos) ? OrderType.sellMarket : OrderType.buyMarket;
      final opened = await _trading.placeTradeOrder(
        symbol: pos.symbol,
        volume: pos.volume.toStringAsFixed(2),
        orderType: opposite,
        price: '',
        mt5Account: acct.metaAccountNumber,
      );
      if (opened) {
        CustomToastService.showSuccess(
          message:
              'Reversed to ${opposite == OrderType.buyMarket ? "Buy" : "Sell"} ${pos.volume.toStringAsFixed(2)} ${pos.symbol}',
          title: 'Order reversed',
        );
        await _trading.refreshTradeHistory();
        if (mounted) Get.back<void>();
      } else {
        _toastError(_trading.errorMessage.isEmpty
            ? 'Closed original position but failed to open opposite.'
            : _trading.errorMessage);
      }
    } catch (e) {
      _toastError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Close-Position flow: shows a confirmation dialog FIRST, and only fires
  /// the close API when the user explicitly taps "Close Order". This differs
  /// from the TP/SL flow which calls the API directly on the primary button.
  Future<void> _submitCloseWithConfirm(BuildContext context) async {
    final pos = widget.position;
    final acct = _account.activeMT5AccountRx.value;
    if (acct == null) {
      _toastError('No active MT5 account selected.');
      return;
    }
    if (_busy) return;

    // Live close-price snapshot for the dialog body.
    final instruments = Get.find<InstrumentsController>();
    final sym = pos.symbol.toUpperCase();
    final isBuy = _isBuy(pos);
    // For Buy → close at bid; for Sell → close at ask.
    final px = instruments.priceRx(sym).value;
    final closePx = px == null
        ? null
        : isBuy
            ? px.bid
            : px.ask;
    final digits = pos.digits;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.isDarkMode
              ? const Color(0xFF111A2E)
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Close Order',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogRow(
                label: 'Lot',
                value: pos.volume.toStringAsFixed(2),
              ),
              SizedBox(height: 6.h),
              _DialogRow(
                label: 'Close Price',
                value: closePx == null
                    ? '—'
                    : closePx.toStringAsFixed(digits),
              ),
              SizedBox(height: 6.h),
              _DialogRow(
                label: 'P/L',
                value: pos.profitLoss == 0
                    ? '0.00'
                    : pos.profitLoss.toStringAsFixed(2),
                valueColor: pos.profitLoss >= 0 ? AppColors.statusGreen : AppColors.error,
              ),
              SizedBox(height: 8.h),
              _DialogRow(
                label: 'Open Time',
                value: _formatOpenTime(pos),
              ),
              SizedBox(height: 4.h),
              Text(
                'Position has been running for ${_formatDuration(pos)}.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Are you sure you want to close this position?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tabAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 8.h,
                ),
              ),
              child: Text(
                'Close Order',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _executeClose(pos, acct.metaAccountNumber);
  }

// (helper removed — inline dialog below now uses theme-aware colors)


  /// Format TradePosition.openTime / .time into a readable local timestamp.
  static String _formatOpenTime(TradePosition position) {
    final raw = position.openTime.isNotEmpty
        ? position.openTime
        : position.time.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '—' : raw;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Compute how long this position has been open.
  static String _formatDuration(TradePosition position) {
    final raw = position.openTime.isNotEmpty
        ? position.openTime
        : position.time.toString();
    final started = DateTime.tryParse(raw);
    if (started == null) return position.duration.toString();
    final elapsed = DateTime.now().toUtc().difference(started.toUtc());
    if (elapsed.isNegative) return '0s';
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    final s = elapsed.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Fire the actual close API — only called after the user confirms the dialog.
  Future<void> _executeClose(TradePosition pos, String mt5Account) async {
    setState(() => _busy = true);
    try {
      final closed = await _trading.closePositionById(
        mt5Account: mt5Account,
        positionId: int.tryParse(pos.orderId.toString()) ?? 0,
        volume: pos.volume,
      );
      if (closed) {
        CustomToastService.showSuccess(
          message:
              'Closed ${_sideFor(pos)} ${pos.volume.toStringAsFixed(2)} ${pos.symbol}',
          title: 'Position closed',
        );
        await _trading.refreshTradeHistory();
        if (mounted) Get.back<void>();
      } else {
        _toastError(_trading.errorMessage.isEmpty
            ? 'Failed to close position.'
            : _trading.errorMessage);
      }
    } catch (e) {
      _toastError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toastError(String msg) =>
      CustomToastService.showError(message: msg);

  static double? _parsePriceOrNull(String text) {
    if (text.trim().isEmpty) return null;
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }
}

/// Small label/value row used inside the close-confirm dialog body.
class _DialogRow extends StatelessWidget {
  const _DialogRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Header
// ────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.pos,
    required this.sideLabel,
    required this.sideColor,
    required this.palette,
  });

  final TradePosition pos;
  final String sideLabel;
  final Color sideColor;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final sym = pos.symbol.toUpperCase();
    return Container(
      color: palette.bg,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        children: [
          // Top row: X close | account number w/ copy icon | —
          Row(
            children: [
              AppBackButton(
                onPressed: () => Get.back<void>(),
                closeOverlays: false,
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pos.mt5Account.isEmpty ? pos.accountId : pos.mt5Account,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.copy_rounded,
                    size: 16.sp,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(width: 32.w),
            ],
          ),
          SizedBox(height: 6.h),
          // Symbol + live price row.
          Row(
            children: [
              Text(
                sym,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _LivePrice(symbol: sym, digits: pos.digits),
            ],
          ),
          SizedBox(height: 4.h),
          // Side pill + Lot.
          Row(
            children: [
              _Pill(
                text: sideLabel,
                color: sideColor,
              ),
              SizedBox(width: 8.w),
              Text(
                '${pos.volume.toStringAsFixed(2)}Lot',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePrice extends StatelessWidget {
  const _LivePrice({required this.symbol, required this.digits});
  final String symbol;
  final int digits;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<InstrumentsController>();
    return Obx(() {
      final q = ctrl.priceRx(symbol).value;
      final px = (q == null || (q.bid == 0 && q.ask == 0))
          ? null
          : (q.bid + q.ask) / 2;
      return Text(
        px == null ? '—' : px.toStringAsFixed(digits),
        style: TextStyle(
          color: AppColors.statusGreen,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Chart-area placeholder — reserved slot for the real chart
// ────────────────────────────────────────────────────────────────────────────
class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({
    required this.symbol,
    required this.digits,
    required this.palette,
  });
  final String symbol;
  final int digits;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final instruments = Get.find<InstrumentsController>();
    return Container(
      width: double.infinity,
      color: palette.chartAreaBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period + action toolbar (faded, disabled — for layout parity only).
          Container(
            color: palette.bg,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            child: Row(
              children: [
                Text(
                  'Period',
                  style: TextStyle(color: palette.axisText, fontSize: 12.sp),
                ),
                SizedBox(width: 14.w),
                ...['1M', '5M', '15M', '30M', 'More'].map(
                  (p) => Padding(
                    padding: EdgeInsets.only(right: 14.w),
                    child: Text(
                      p,
                      style: TextStyle(
                        color: palette.axisText,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16.sp,
                  color: palette.axisText,
                ),
                SizedBox(width: 12.w),
                Icon(Icons.tune, size: 16.sp, color: palette.axisText),
                SizedBox(width: 12.w),
                Icon(Icons.aspect_ratio, size: 16.sp, color: palette.axisText),
              ],
            ),
          ),
          // MA strip (faded).
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                _MaText(
                  text: 'MA5:${_fmt(instruments, digits, fallback: '—')}',
                  color: AppColors.blue,
                ),
                SizedBox(width: 14.w),
                _MaText(
                  text: 'MA10:${_fmt(instruments, digits, fallback: '—')}',
                  color: AppColors.warning,
                ),
                SizedBox(width: 14.w),
                _MaText(
                  text: 'MA30:${_fmt(instruments, digits, fallback: '—')}',
                  color: AppColors.iconPurple,
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final q = instruments.priceRx(symbol).value;
              final bid = q?.bid;
              final ask = q?.ask;
              final px = (q == null || (q.bid == 0 && q.ask == 0))
                  ? null
                  : (q.bid + q.ask) / 2;
              return _CandlePlaceholder(
                digits: digits,
                bid: bid,
                ask: ask,
                price: px,
                palette: palette,
              );
            }),
          ),
          // Bottom MACD strip (faded band).
          Container(
            height: 32.h,
            color: palette.chartAreaBg,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            alignment: Alignment.centerLeft,
            child: Text(
              'MACD(12,26,9)  MACD:—  DIF:—  DEA:—',
              style: TextStyle(color: palette.axisText, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(
    InstrumentsController instruments,
    int digits, {
    required String fallback,
  }) {
    final q = instruments.priceRx(symbol).value;
    if (q == null || (q.bid == 0 && q.ask == 0)) return fallback;
    final px = (q.bid + q.ask) / 2;
    return px.toStringAsFixed(digits);
  }
}

class _MaText extends StatelessWidget {
  const _MaText({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CandlePlaceholder extends StatelessWidget {
  const _CandlePlaceholder({
    required this.digits,
    required this.bid,
    required this.ask,
    required this.price,
    required this.palette,
  });
  final int digits;
  final double? bid;
  final double? ask;
  final double? price;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final samples = <double>[
      if (bid != null) bid!,
      if (ask != null) ask!,
      if (price != null) price!,
    ];
    double? hi;
    double? lo;
    if (samples.isNotEmpty) {
      hi = samples.reduce(math.max);
      lo = samples.reduce(math.min);
      final pad = (hi - lo).abs() * 0.4 + hi.abs() * 0.002;
      hi = hi + pad;
      lo = lo - pad;
    }
    final ticks = <double>[];
    if (hi != null && lo != null && hi > lo) {
      for (var i = 0; i < 5; i++) {
        ticks.add(lo + (hi - lo) * (i / 4.0));
      }
    }
    double yFrac(double p) {
      if (hi == null || lo == null || hi <= lo) return 0;
      return 1 - ((p - lo) / (hi - lo));
    }

    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            // Border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.divider),
                    bottom: BorderSide(color: palette.divider),
                  ),
                ),
              ),
            ),
            // Right-axis ticks
            ...ticks.map(
              (t) => Positioned(
                right: 8.w,
                top: yFrac(t).clamp(0.0, 1.0) * c.maxHeight - 8,
                child: Text(
                  t.toStringAsFixed(digits),
                  style: TextStyle(
                    color: palette.axisText,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ),
            // Ask marker line (green)
            if (ask != null && hi != null && lo != null && hi > lo)
              Positioned(
                left: 0,
                right: 0,
                top: yFrac(ask!).clamp(0.0, 1.0) * c.maxHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.statusGreen.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      color: AppColors.statusGreen,
                      child: Text(
                        ask!.toStringAsFixed(digits),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Bid marker line (red)
            if (bid != null && hi != null && lo != null && hi > lo)
              Positioned(
                left: 0,
                right: 0,
                top: yFrac(bid!).clamp(0.0, 1.0) * c.maxHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.error.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      color: AppColors.error,
                      child: Text(
                        bid!.toStringAsFixed(digits),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Hint icon
            Center(
              child: Icon(
                Icons.show_chart,
                size: 28.sp,
                color: palette.axisText.withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tab bar (TP/SL | Add Position | Reverse Order)
// ────────────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.onChange,
    required this.palette,
  });
  final _DetailTab current;
  final ValueChanged<_DetailTab> onChange;
  final _Palette palette;

  static const _labels = {
    _DetailTab.tpsl: 'TP/SL',
    _DetailTab.addPosition: 'Add Position',
    _DetailTab.reverse: 'Reverse Order',
    _DetailTab.close: 'Close Position',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(
          top: BorderSide(color: palette.divider),
          bottom: BorderSide(color: palette.divider),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: _DetailTab.values.map((t) {
          final active = t == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(t),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _labels[t]!,
                    style: TextStyle(
                      color: active ? AppColors.tabAccent : palette.axisText,
                      fontSize: 13.sp,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: active ? AppColors.tabAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TP/SL panel — two steppers (Take profit / Stop loss)
// ────────────────────────────────────────────────────────────────────────────
class _TpSlPanel extends StatelessWidget {
  const _TpSlPanel({
    required this.pos,
    required this.tpCtl,
    required this.slCtl,
    required this.tpFocus,
    required this.slFocus,
    required this.palette,
    super.key,
  });

  final TradePosition pos;
  final TextEditingController tpCtl;
  final TextEditingController slCtl;
  final FocusNode tpFocus;
  final FocusNode slFocus;
  final _Palette palette;

  static const List<double> _quickAdd = [0.5, 1, 2, 5];

  void _bump(TextEditingController c, double delta, int digits) {
    final raw = c.text.trim();
    final current = double.tryParse(raw) ?? 0;
    final next = (current + delta).clamp(0.0, double.infinity);
    c.text = next == 0 ? '' : next.toStringAsFixed(digits);
    c.selection = TextSelection.fromPosition(
      TextPosition(offset: c.text.length),
    );
  }

  void _setTo(TextEditingController c, double v, int digits) {
    c.text = v.toStringAsFixed(digits);
    c.selection = TextSelection.fromPosition(
      TextPosition(offset: c.text.length),
    );
  }

  void _clear(TextEditingController c) {
    c.text = '';
    c.selection = const TextSelection.collapsed(offset: 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    final isBuy = _isBuy(pos);
    final sym = pos.symbol.toUpperCase();
    final d = pos.digits;

    // Reference values for the description text under each stepper.
    final entry = _priceStrToDouble(pos.entryPrice) ?? 0.0;
    final tpRef = entry > 0 ? entry * 1.01 : 0.0; // rough TP guide: +1%
    final slRef = entry > 0 ? entry * 0.99 : 0.0; // rough SL guide: -1%
    final triggerColor = AppColors.statusGreen;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rule hint row.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: palette.fieldBorder),
              ),
              child: Text(
                'Rule ?',
                style: TextStyle(
                  color: palette.axisText,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Take profit row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                    ),
                    children: [
                      const TextSpan(text: 'Take profit:'),
                      if (tpRef > 0)
                        TextSpan(
                          text: '> \$${tpRef.toStringAsFixed(d)}',
                          style: TextStyle(
                            color: triggerColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _clear(tpCtl),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: AppColors.tabAccent,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          _StepperField(
            controller: tpCtl,
            focusNode: tpFocus,
            palette: palette,
            onMinus: () => _bump(tpCtl, -1.0, d),
            onPlus: () => _bump(tpCtl, 1.0, d),
          ),
          SizedBox(height: 6.h),
          Text(
            isBuy
                ? 'When Mark Price reaches —, it will trigger Take Profit Market order to close this position. Estimated PNL will be \$${_formatPnl(0)}.'
                : 'When Mark Price reaches —, it will trigger Take Profit Market order to close this position. Estimated PNL will be \$${_formatPnl(0)}.',
            style: TextStyle(color: palette.axisText, fontSize: 11.sp),
          ),
          SizedBox(height: 4.h),
          // Quick-pick chips for TP.
          Row(
            children: _quickAdd
                .map(
                  (v) => Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: GestureDetector(
                      onTap: () => _setTo(tpCtl, v, d),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: palette.fieldBg,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: palette.fieldBorder),
                        ),
                        child: Text(
                          '\$${v.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 18.h),
          // Stop loss row.
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                    ),
                    children: [
                      const TextSpan(text: 'Stop loss:'),
                      if (slRef > 0)
                        TextSpan(
                          text: '< \$${slRef.toStringAsFixed(d)}',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _clear(slCtl),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: AppColors.tabAccent,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          _StepperField(
            controller: slCtl,
            focusNode: slFocus,
            palette: palette,
            onMinus: () => _bump(slCtl, -1.0, d),
            onPlus: () => _bump(slCtl, 1.0, d),
          ),
          SizedBox(height: 6.h),
          Text(
            'When Mark Price reaches —, it will trigger Stop Market order to close this position. Estimated PNL will be \$${_formatPnl(0)}.',
            style: TextStyle(color: palette.axisText, fontSize: 11.sp),
          ),
          SizedBox(height: 4.h),
          Row(
            children: _quickAdd
                .map(
                  (v) => Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: GestureDetector(
                      onTap: () => _setTo(slCtl, v, d),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: palette.fieldBg,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: palette.fieldBorder),
                        ),
                        child: Text(
                          '\$${v.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8.h),
          // Symbol legend, hidden — kept for parity with reference (subtitle).
          Text(
            sym,
            style: TextStyle(color: palette.axisText, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  static String _formatPnl(double v) {
    if (v == 0) return '---';
    return v.toStringAsFixed(2);
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onMinus,
    required this.onPlus,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _Palette palette;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.fieldBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: palette.fieldBorder),
      ),
      child: Row(
        children: [
          _StepperButton(icon: Icons.remove, onTap: onMinus, palette: palette),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onPlus, palette: palette),
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8.r),
                bottomRight: Radius.circular(8.r),
              ),
            ),
            child: Text(
              r'$ 1',
              style: TextStyle(
                color: palette.axisText,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.palette,
  });
  final IconData icon;
  final VoidCallback onTap;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Icon(icon, size: 18.sp, color: AppColors.textPrimary),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Add Position panel — volume stepper + quick-pick chips
// ────────────────────────────────────────────────────────────────────────────
class _AddPositionPanel extends StatelessWidget {
  const _AddPositionPanel({
    required this.pos,
    required this.sideLabel,
    required this.volumeCtl,
    required this.volume,
    required this.onVolumeChange,
    required this.includeVip,
    required this.onIncludeVipChange,
    required this.palette,
    super.key,
  });

  final TradePosition pos;
  final String sideLabel;
  final TextEditingController volumeCtl;
  final double volume;
  final ValueChanged<double> onVolumeChange;
  final bool includeVip;
  final ValueChanged<bool> onIncludeVipChange;
  final _Palette palette;

  static const List<double> _quickLots = [0.01, 0.1, 0.5, 1, 2, 5];

  @override
  Widget build(BuildContext context) {
    final sym = pos.symbol.toUpperCase();
    final d = pos.digits;
    final instruments = Get.find<InstrumentsController>();
    final px = (() {
      final q = instruments.priceRx(sym).value;
      if (q == null || (q.bid == 0 && q.ask == 0)) return 0.0;
      return (q.bid + q.ask) / 2;
    })();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary card — Sell 0.03Lot 3XAU 300X  ........ 4084.65
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _Pill(text: sideLabel, color: AppColors.error),
                    SizedBox(width: 8.w),
                    Text(
                      '${volume.toStringAsFixed(2)}Lot',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _Pill(
                      text:
                          '${(volume * 100).toStringAsFixed(0)}${sym.substring(0, math.min(sym.length, 3))}',
                      color: AppColors.blue,
                    ),
                    const Spacer(),
                    Text(
                      px.toStringAsFixed(d),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tabAccent,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'V',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tabAccent,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                      child: Text(
                        'VIP 0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Cashback',
                      style: TextStyle(
                        color: palette.axisText,
                        fontSize: 11.sp,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '0.0000',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          // Volume stepper + Lot label.
          Container(
            decoration: BoxDecoration(
              color: palette.fieldBg,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: Row(
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: () => onVolumeChange(volume - 0.01),
                  palette: palette,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      volume.toStringAsFixed(2),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  onTap: () => onVolumeChange(volume + 0.01),
                  palette: palette,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8.r),
                      bottomRight: Radius.circular(8.r),
                    ),
                    border: Border(
                      left: BorderSide(color: palette.fieldBorder),
                    ),
                  ),
                  child: Text(
                    'Lot',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '= ${(volume * 100).toStringAsFixed(0)}${sym.substring(0, math.min(sym.length, 3))}',
                  style: TextStyle(
                    color: palette.axisText,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(width: 8.w),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Quick-lot chips.
          Row(
            children: _quickLots
                .map(
                  (lot) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: GestureDetector(
                        onTap: () => onVolumeChange(lot),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: (lot == volume)
                                ? AppColors.tabAccent
                                : palette.fieldBg,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: palette.fieldBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            lot.toStringAsFixed(2),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 12.h),
          // Warning row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14.sp,
                  color: AppColors.tabAccent,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'The system will open positions at the market counterpart price',
                  style: TextStyle(color: palette.axisText, fontSize: 11.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Reverse Order panel — summary of (close current + open opposite)
// ────────────────────────────────────────────────────────────────────────────
class _ReversePanel extends StatelessWidget {
  const _ReversePanel({
    required this.pos,
    required this.sideLabel,
    required this.palette,
    super.key,
  });
  final TradePosition pos;
  final String sideLabel;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final sym = pos.symbol.toUpperCase();
    final d = pos.digits;
    final isSell = _isBuy(pos) == false;
    final opposite = isSell ? 'Buy' : 'Sell';
    final instruments = Get.find<InstrumentsController>();
    final px = (() {
      final q = instruments.priceRx(sym).value;
      if (q == null || (q.bid == 0 && q.ask == 0)) return 0.0;
      return (q.bid + q.ask) / 2;
    })();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Close Order',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          _OrderSummaryCard(
            sideLabel: sideLabel,
            sideColor: isSell ? AppColors.error : AppColors.statusGreen,
            volume: pos.volume,
            symbol: sym,
            price: _priceStrToDouble(pos.entryPrice) ?? 0.0,
            palette: palette,
            showCashback: false,
          ),
          SizedBox(height: 12.h),
          Text(
            'Open Order',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          _OrderSummaryCard(
            sideLabel: opposite,
            sideColor: isSell ? AppColors.statusGreen : AppColors.error,
            volume: pos.volume,
            symbol: sym,
            price: px,
            palette: palette,
            showCashback: true,
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14.sp,
                  color: AppColors.tabAccent,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'The system will close your current order and open a position in the opposite direction',
                  style: TextStyle(color: palette.axisText, fontSize: 11.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Digits: $d',
            style: TextStyle(color: palette.axisText, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Close Position panel — summary card + dialog prompt.
// The bottom bar primary button shows a confirm dialog before firing the API.
// ────────────────────────────────────────────────────────────────────────────
class _ClosePanel extends StatelessWidget {
  const _ClosePanel({
    required this.pos,
    required this.sideLabel,
    required this.palette,
    super.key,
  });
  final TradePosition pos;
  final String sideLabel;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final sym = pos.symbol.toUpperCase();
    final d = pos.digits;
    final isSell = _isBuy(pos) == false;
    final instruments = Get.find<InstrumentsController>();
    final closePx = (() {
      final q = instruments.priceRx(sym).value;
      if (q == null || (q.bid == 0 && q.ask == 0)) return null;
      // For Buy → close at bid; for Sell → close at ask.
      return _isBuy(pos) ? q.bid : q.ask;
    })();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderSummaryCard(
            sideLabel: sideLabel,
            sideColor: isSell ? AppColors.error : AppColors.statusGreen,
            volume: pos.volume,
            symbol: sym,
            price: _priceStrToDouble(pos.entryPrice) ?? 0.0,
            palette: palette,
            showCashback: false,
          ),
          SizedBox(height: 10.h),
          // Live close-price row.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Close Price',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                const Spacer(),
                Text(
                  closePx == null ? '—' : closePx.toStringAsFixed(d),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          // Floating P/L row.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Profit / Loss',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                const Spacer(),
                Text(
                  pos.profitLoss == 0
                      ? '0.00'
                      : pos.profitLoss.toStringAsFixed(2),
                  style: TextStyle(
                    color: pos.profitLoss >= 0 ? AppColors.statusGreen : AppColors.error,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14.sp,
                  color: AppColors.tabAccent,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Tapping Close Order will close this position at the market price. A confirmation dialog will appear before the order is submitted.',
                  style: TextStyle(color: palette.axisText, fontSize: 11.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.sideLabel,
    required this.sideColor,
    required this.volume,
    required this.symbol,
    required this.price,
    required this.palette,
    this.showCashback = false,
  });
  final String sideLabel;
  final Color sideColor;
  final double volume;
  final String symbol;
  final double price;
  final _Palette palette;
  final bool showCashback;

  @override
  Widget build(BuildContext context) {
    final d = price == price.toInt() ? 2 : 4;
    final units = '${(volume * 100).toStringAsFixed(0)}${symbol.substring(0, math.min(symbol.length, 3))}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: palette.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Pill(text: sideLabel, color: sideColor),
              SizedBox(width: 8.w),
              Text(
                '${volume.toStringAsFixed(2)}Lot',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8.w),
              _Pill(
                text: units,
                color: AppColors.blue,
              ),
              const Spacer(),
              Text(
                price.toStringAsFixed(d),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (showCashback) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tabAccent,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'V',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tabAccent,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Text(
                    'VIP 0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Cashback',
                  style: TextStyle(
                    color: palette.axisText,
                    fontSize: 11.sp,
                  ),
                ),
                const Spacer(),
                Text(
                  '0.0000',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bottom action row (Cancel | primary action pill)
// ────────────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tab,
    required this.busy,
    required this.onCancel,
    required this.onPrimary,
    required this.sideColor,
    required this.palette,
  });
  final _DetailTab tab;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;
  final Color sideColor;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final label = switch (tab) {
      _DetailTab.tpsl => 'Confirm',
      _DetailTab.addPosition => 'Open Order',
      _DetailTab.reverse => 'Reverse',
      _DetailTab.close => 'Close Order',
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: busy ? null : onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: sideColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: busy
                  ? SizedBox(
                      height: 18.h,
                      width: 18.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
