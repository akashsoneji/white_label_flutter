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

double _pipForSymbol(String symbol) {
  final digits = Get.find<InstrumentsController>().priceRx(symbol).value.digits;
  return math.pow(10, -digits).toDouble();
}



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

class IQuotePositionDetailScreen extends StatefulWidget {
  const IQuotePositionDetailScreen({
    super.key,
    required this.position,
    this.isPending = false,
  });

  /// The open position to display. Symbol/side/volume/sl/tp/price are all
  /// pulled from this object; live bid/ask is layered on top for the price
  /// header + chart markers.
  final TradePosition position;
  final bool isPending;

  @override
  State<IQuotePositionDetailScreen> createState() =>
      _IQuotePositionDetailScreenState();
}

class _IQuotePositionDetailScreenState
    extends State<IQuotePositionDetailScreen> {
  // ── TP/SL state ────────────────────────────────────────────────────────
  // Two simple stepper values (USD) — empty/0 means "no change".
  final TextEditingController _tpCtl = TextEditingController();
  final TextEditingController _slCtl = TextEditingController();
  final FocusNode _tpFocus = FocusNode();
  final FocusNode _slFocus = FocusNode();

  bool _isPartialClose = false;
  late final TextEditingController _closeVolumeCtl;
  final FocusNode _volumeFocus = FocusNode();
  String? _volumeError;
  // Once a user has manually edited a field (typed, cleared, or used the
  // explicit X button), stop auto-filling it on focus — they've expressed
  // an explicit intent and we shouldn't clobber it.
  bool _tpUserTouched = false;
  bool _slUserTouched = false;
  // Tracks the live value we last wrote to each controller so the
  // TextEditingController listener can distinguish user edits from our
  // own programmatic writes (auto-fill / pre-fill) and only set the
  // "user touched" flag on the former.
  String _tpLastWritten = '';
  String _slLastWritten = '';
  // Snapshot of the TP/SL values as they arrived from the server. Used
  // to detect whether the user has actually modified a field (dirty)
  // vs. the field still reflecting the server state.
  late final double? _origTp;
  late final double? _origSl;

  // ── Reverse-Order state is read-only (displays the existing + opposite) ─

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pos = widget.position;
    final d = pos.digits;
    // Pre-fill from whatever the position already has on the server so
    // reopening this screen shows the previously-set TP/SL values (the
    // user may want to leave them unchanged, modify them, or clear them
    // via the explicit × button). If the position has no TP/SL set, the
    // fields stay blank — that's the "close the position" affordance.
    final existingTp = _priceStrToDouble(pos.takeProfit);
    final existingSl = _priceStrToDouble(pos.stopLoss);
    _origTp = existingTp;
    _origSl = existingSl;
    if (existingTp != null && existingTp > 0) {
      _tpCtl.text = existingTp.toStringAsFixed(d);
      _tpLastWritten = _tpCtl.text;
    }
    if (existingSl != null && existingSl > 0) {
      _slCtl.text = existingSl.toStringAsFixed(d);
      _slLastWritten = _slCtl.text;
    }
    // Wire listeners. Focus listeners auto-fill only when the field is
    // still empty AND the user hasn't manually edited it yet. Controller
    // listeners distinguish user edits (keyboard, × clear) from our own
    // programmatic writes (initState pre-fill, focus auto-fill) so the
    // touched flag is only set on real user input.
    _tpFocus.addListener(_handleTpFocusChange);
    _slFocus.addListener(_handleSlFocusChange);
    _tpCtl.addListener(_handleTpControllerChange);
    _slCtl.addListener(_handleSlControllerChange);

    final halfVol = widget.position.volume / 2;
    _closeVolumeCtl = TextEditingController(text: halfVol.toStringAsFixed(2));
    _closeVolumeCtl.addListener(_validateCloseVolume);

    // Force one rebuild after first frame so _isTpSlEmpty() in build()
    // re-evaluates against the pre-filled controller text (TP/SL values
    // restored from the server). The controller listener above does NOT
    // fire for pre-fills because the text matches _tpLastWritten /
    // _slLastWritten — so without this the first build could snapshot
    // an empty _isTpSlEmpty() result and the Close Order / Confirm
    // button label would be stuck until the user types something.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleTpControllerChange() {
    if (_tpCtl.text == _tpLastWritten) return;
    setState(() {});
    _tpLastWritten = _tpCtl.text;
    _tpUserTouched = true;
  }

  void _handleSlControllerChange() {
    if (_slCtl.text == _slLastWritten) return;
    setState(() {});
    _slLastWritten = _slCtl.text;
    _slUserTouched = true;
  }

  void _handleTpFocusChange() {
    if (!_tpFocus.hasFocus) return;
    if (_tpUserTouched) return;
    if (_tpCtl.text.trim().isNotEmpty) return;
    final pos = widget.position;
    final d = pos.digits;
    final isBuy = _isBuy(pos);
    const slPips = 50;
    final pip = _pipForSymbol(pos.symbol);
    final q = Get.find<InstrumentsController>()
        .priceRx(pos.symbol.toUpperCase())
        .value;
    final anchor = isBuy ? q.ask : q.bid;
    final profitDir = isBuy ? 1 : -1;
    final slGap = slPips * pip;
    final tp = anchor + profitDir * slGap * 2;
    _writeTp(tp.toStringAsFixed(d));
  }

  void _handleSlFocusChange() {
    if (!_slFocus.hasFocus) return;
    if (_slUserTouched) return;
    if (_slCtl.text.trim().isNotEmpty) return;
    final pos = widget.position;
    final d = pos.digits;
    final isBuy = _isBuy(pos);
    const slPips = 50;
    final pip = _pipForSymbol(pos.symbol);
    final q = Get.find<InstrumentsController>()
        .priceRx(pos.symbol.toUpperCase())
        .value;
    final anchor = isBuy ? q.ask : q.bid;
    final slGap = slPips * pip;
    final sl = anchor + (isBuy ? -slGap : slGap);
    _writeSl(sl.toStringAsFixed(d));
  }

  /// Programmatic write that updates the field and syncs the last-written
  /// tracker so the controller listener doesn't mistakenly mark the field
  /// as user-touched.
  void _writeTp(String value) {
    _tpLastWritten = value;
    _tpCtl.text = value;
    _tpCtl.selection = TextSelection.collapsed(offset: value.length);
  }

  void _writeSl(String value) {
    _slLastWritten = value;
    _slCtl.text = value;
    _slCtl.selection = TextSelection.collapsed(offset: value.length);
  }

  void _validateCloseVolume() {
    final vol = double.tryParse(_closeVolumeCtl.text.trim()) ?? 0.0;
    final maxVol = widget.position.volume;
    if (vol <= 0) {
      setState(() => _volumeError = 'Volume must be greater than 0');
    } else if (vol >= maxVol) {
      setState(() => _volumeError = 'Volume must be less than total volume (${maxVol.toStringAsFixed(2)})');
    } else {
      setState(() => _volumeError = null);
    }
  }

  void _bumpVolume(double delta) {
    final cur = double.tryParse(_closeVolumeCtl.text.trim()) ?? 0.0;
    final maxVol = widget.position.volume;
    final next = (cur + delta).clamp(0.01, maxVol - 0.01);
    _closeVolumeCtl.text = next.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tpFocus.removeListener(_handleTpFocusChange);
    _slFocus.removeListener(_handleSlFocusChange);
    _tpCtl.dispose();
    _slCtl.dispose();
    _tpFocus.dispose();
    _slFocus.dispose();
    _closeVolumeCtl.dispose();
    _volumeFocus.dispose();
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
            Expanded(
              flex: 100,
              child: Align(
                alignment: Alignment.topCenter,
                child: _TpSlPanel(
                  pos: pos,
                  tpCtl: _tpCtl,
                  slCtl: _slCtl,
                  tpFocus: _tpFocus,
                  slFocus: _slFocus,
                  palette: palette,
                  isPartialClose: _isPartialClose,
                  onPartialCloseChanged: (val) {
                    setState(() {
                      _isPartialClose = val;
                      _validateCloseVolume();
                    });
                  },
                  closeVolumeCtl: _closeVolumeCtl,
                  volumeFocus: _volumeFocus,
                  onVolumeMinus: () => _bumpVolume(-0.01),
                  onVolumePlus: () => _bumpVolume(0.01),
                  volumeError: _volumeError,
                ),
              ),
            ),
            _ActionRow(
              primaryLabel: _isPartialClose
                  ? (_volumeError != null ? 'Close Order' : 'Close ${_closeVolumeCtl.text} Lot')
                  : (_isTpSlDirty() ? 'Confirm' : 'Close Order'),
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


  // ── primary button per tab ─────────────────────────────────────────────
  Future<void> _onPrimary(BuildContext context) async {
    if (_isPartialClose) {
      if (_volumeError != null) {
        _toastError(_volumeError!);
        return;
      }
      final pos = widget.position;
      final acct = _account.activeMT5AccountRx.value;
      if (acct == null) {
        _toastError('No active MT5 account selected.');
        return;
      }
      final vol = double.tryParse(_closeVolumeCtl.text.trim());
      await _executeClose(pos, acct.metaAccountNumber, volume: vol);
    } else if (_isTpSlDirty()) {
      // User modified TP/SL from server values — apply the modification.
      await _submitTpSl();
    } else {
      // No changes — close the position instead.
      await _submitCloseWithConfirm(context);
    }
  }

  /// True when the current TP/SL values differ numerically from the
  /// server originals captured in initState. Non-numeric input is
  /// treated as dirty. Drives the bottom action label and submit
  /// routing: "Confirm" when values diverge, "Close Order" otherwise.
  /// True iff either TP or SL field text differs from the server's
  /// pre-fill for this position. Compared as raw trimmed strings so
  /// partial / unparseable input (e.g. user typed "42" or "4,250.6"
  /// mid-entry) still flips the button to "Confirm" the moment the
  /// text no longer matches the original. Numeric precision / parsing
  /// errors are reported by the submit path, not by this helper.
  bool _isTpSlDirty() {
    final curTpText = _tpCtl.text.trim();
    final curSlText = _slCtl.text.trim();

    // Original text the screen was opened with ('' if server had none).
    final origTpText = (_origTp == null || _origTp! <= 0) ? '' : _origTp!.toString();
    final origSlText = (_origSl == null || _origSl! <= 0) ? '' : _origSl!.toString();

    // Short-circuit: only skip when nothing was ever set and user hasn't
    // touched either field. Clearing a field that originally had a value
    // (i.e. removing TP or SL) IS a change → must show Confirm.
    if (origTpText.isEmpty && origSlText.isEmpty
        && curTpText.isEmpty && curSlText.isEmpty) {
      return false;
    }

    return curTpText != origTpText || curSlText != origSlText;
  }

  Future<void> _submitTpSl() async {
    final pos = widget.position;
    final acct = _account.activeMT5AccountRx.value;
    if (acct == null) {
      _toastError('No active MT5 account selected.');
      return;
    }
    // Blank field means "remove TP/SL" → send 0.0 (not null) so the
    // server clears the value instead of treating it as a no-op.
    final tp = _parsePriceOrNull(_tpCtl.text) ?? 0.0;
    final sl = _parsePriceOrNull(_slCtl.text) ?? 0.0;
    setState(() => _busy = true);
    try {
      bool ok = false;
      if (widget.isPending) {
        ok = await _trading.updatePendingOrderTPSL(
          mt5Account: acct.metaAccountNumber,
          orderId: int.tryParse(pos.orderId.toString()) ?? 0,
          stopLoss: sl,
          takeProfit: tp,
        );
      } else {
        ok = await _trading.updateTPSL(
          mt5Account: acct.metaAccountNumber,
          positionId: int.tryParse(pos.orderId.toString()) ?? 0,
          stopLoss: sl,
          takeProfit: tp,
          digits: pos.digits,
        );
      }
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

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.isDarkMode
              ? const Color(0xFF111A2E)
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            'Close Position',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to close this position entirely?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tabAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                'Close Order',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _executeClose(pos, acct.metaAccountNumber);
  }

  /// Fire the actual close API — only called after the user confirms the dialog.
  Future<void> _executeClose(TradePosition pos, String mt5Account, {double? volume}) async {
    setState(() => _busy = true);
    try {
      bool closed = false;
      if (widget.isPending) {
        closed = await _trading.cancelOrderWithImmediateUpdate(
          mt5Account: mt5Account,
          orderId: int.tryParse(pos.orderId) ?? 0,
        );
      } else {
        closed = await _trading.closePositionById(
          mt5Account: mt5Account,
          positionId: int.tryParse(pos.orderId.toString()) ?? 0,
          volume: volume,
        );
      }
      if (closed) {
        final displayVolume = volume ?? pos.volume;
        CustomToastService.showSuccess(
          message:
              'Closed ${_sideFor(pos)} ${displayVolume.toStringAsFixed(2)} ${pos.symbol}',
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

  /// Per-symbol contract size used to scale the client-side P/L formula.
  /// The server already returns a correct `pos.profitLoss`; this helper is
  /// only consulted when the close-confirm dialog recomputes P/L from
  /// live bid/ask vs entry — the broker quotes different lot contracts
  /// per asset class:
  ///   - Standard forex: 1 lot = 100000 base units
  ///   - Metals (XAUUSD, XAGUSD): 1 lot = 100 oz
  ///   - Crypto (BTCUSD, ETHUSD, ...): 1 lot = 1 coin
  static double _contractSizeFor(String symbol) {
    final s = symbol.toUpperCase();
    if (s.startsWith('XAU') ||
        s.startsWith('XAG') ||
        s.startsWith('XPT') ||
        s.startsWith('XPD')) {
      return 100.0; // metals: 1 lot = 100 oz
    }
    if (s.startsWith('BTC') ||
        s.startsWith('ETH') ||
        s.startsWith('LTC') ||
        s.startsWith('XRP') ||
        s.startsWith('EOS') ||
        s.startsWith('DOT') ||
        s.startsWith('DOG')) {
      return 1.0; // crypto: 1 lot = 1 coin
    }
    return 100000.0; // standard forex
  }

  /// Compute the live P/L (in account currency units, approximate) using the
  /// current bid/ask vs entry price, instead of the (possibly stale) value
  /// attached to the position object. Falls back to pos.profitLoss when any
  /// leg is missing so the dialog still shows *something*.
  double _livePL(TradePosition pos, double? closePx, double? entryVal,
      bool isBuy) {
    if (closePx == null || entryVal == null || entryVal <= 0) {
      return pos.profitLoss;
    }
    final delta = isBuy ? closePx - entryVal : entryVal - closePx;
    return delta * pos.volume * _contractSizeFor(pos.symbol);
  }

  String _computeLivePLDisplay(
      TradePosition pos, double? closePx, double? entryVal, bool isBuy) {
    final v = _livePL(pos, closePx, entryVal, isBuy);
    return v.toStringAsFixed(2);
  }

  Color _computeLivePLColor(
      TradePosition pos, double? closePx, double? entryVal, bool isBuy) {
    final v = _livePL(pos, closePx, entryVal, isBuy);
    return v >= 0 ? AppColors.statusGreen : AppColors.error;
  }

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
      if (q == null || (q.bid == 0 && q.ask == 0)) {
        return Text(
          '—',
          style: TextStyle(
            color: AppColors.statusGreen,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bid',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                q.bid.toStringAsFixed(digits),
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Ask',
                style: TextStyle(
                  color: AppColors.statusGreen,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                q.ask.toStringAsFixed(digits),
                style: TextStyle(
                  color: AppColors.statusGreen,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
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
    required this.isPartialClose,
    required this.onPartialCloseChanged,
    required this.closeVolumeCtl,
    required this.volumeFocus,
    required this.onVolumeMinus,
    required this.onVolumePlus,
    required this.volumeError,
    super.key,
  });

  final TradePosition pos;
  final TextEditingController tpCtl;
  final TextEditingController slCtl;
  final FocusNode tpFocus;
  final FocusNode slFocus;
  final _Palette palette;
  final bool isPartialClose;
  final ValueChanged<bool> onPartialCloseChanged;
  final TextEditingController closeVolumeCtl;
  final FocusNode volumeFocus;
  final VoidCallback onVolumeMinus;
  final VoidCallback onVolumePlus;
  final String? volumeError;

  /// Stepper bump for TP / SL fields. Each press moves the value by
  /// [slPips] PIPs for the symbol (same scale as the auto-fill defaults),
  /// not by a single decimal tick. SL uses 50 pips; TP uses 100 pips (1:2).
  /// Falls back to the live mid-market if the field is empty, so the
  /// user immediately sees a starting point on first press.
  /// Stepper bump for TP / SL fields.
  ///
  /// Behaviour:
  /// - First press on a BLANK field → place value at `pos.entryPrice`
  ///   ± 50 pips (SL) / ± 100 pips (TP). Same as the focus auto-fill.
  ///   This gives the user a clean starting point that lines up with
  ///   what the server-side validation expects.
  /// - Subsequent presses on a NON-blank field → move by a single tick
  ///   for the symbol (one last-digit increment). So XAUUSD moves in
  ///   0.01 steps, EURUSD in 0.00001, USDJPY in 0.001, BTCUSD in 1.00.
  ///   The pip magnitude is read from `_pipForSymbol` so it matches the
  ///   server-side pip definition.
  void _bump(TextEditingController c, double delta, int digits,
      {required int slPips, required TradePosition position}) {
    final pos = position;
    final raw = c.text.trim();
    final wasBlank = raw.isEmpty;
    // For Sell positions, flip `delta` so the button semantics match Buy:
    // "minus" always moves the value further from entry, "plus" closer.
    // The focus listener already does this for the blank-field branch;
    // we do it here so the non-blank (tick-step) branch behaves the same.
    final d = _isBuy(pos) ? delta : -delta;
    double current = double.tryParse(raw) ?? 0;
    if (wasBlank) {
      // First press from blank: anchor to the LIVE price the user
      // actually traded at — not the historical entryPrice.
      //   Buy  → Ask  (what the user paid to open)
      //   Sell → Bid  (what the user received when opening)
      // TP is placed in the PROFIT direction from that anchor;
      // SL is placed in the LOSS direction.
      final q = Get.find<InstrumentsController>()
          .priceRx(pos.symbol.toUpperCase())
          .value;
      current = _isBuy(pos) ? q.ask : q.bid;
      // Use the symbol pip magnitude for the 50/100-pip offset (so
      // BTCUSD gets a 50 USD step, XAUUSD gets a 0.50 step, etc.).
      // TP and SL are anchored relative to entry, each on the correct
      // side for the position direction:
      //   Buy  → TP = entry + 100 pips,  SL = entry − 50 pips
      //   Sell → TP = entry − 100 pips,  SL = entry + 50 pips
      // `_isBuy ? 1 : -1` is the profit-side direction; negating it
      // (`-(...)`) gives the loss-side direction.
      final pip = _pipForSymbol(pos.symbol);
      final profitDir = _isBuy(pos) ? 1 : -1;
      // Whether we are on the profit or loss side depends on the caller:
      // TP passes slPips=100 (profit side), SL passes slPips=50 (loss side).
      // We detect which side by comparing abs(slPips) to the known values.
      final isTpSide = (slPips == 100);
      final dir = isTpSide ? profitDir : -profitDir;
      current = current + (dir * (slPips.abs()) * pip);
    } else {
      // Subsequent presses: move by one LAST-DIGIT increment (the
      // tick), NOT by one pip. Tick is read from `pos.digits` so the
      // step is always 0.01 for digits=2 (XAUUSD, XAGUSD, JPY, BTCUSD),
      // 0.0001 for digits=4 (some forex / 4-digit metals), 0.00001 for
      // digits=5 (5-digit forex). This matches the per-symbol last
      // digit the user sees in the field.
      final tick = math.pow(10, -digits).toDouble();
      current = current + (d * tick);
    }
    final next = current.clamp(0.0, double.infinity);
    c.text = next == 0 ? '' : next.toStringAsFixed(digits);
    c.selection = TextSelection.fromPosition(
      TextPosition(offset: c.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    final d = pos.digits;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close Partially toggle / switch row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: palette.fieldBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Close Partially',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isPartialClose,
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                    onChanged: onPartialCloseChanged,
                  ),
                ),
              ],
            ),
          ),
          if (isPartialClose) ...[
            SizedBox(height: 12.h),
            _TpSlSection(
              label: 'Close volume',
              field: _StepperField(
                controller: closeVolumeCtl,
                focusNode: volumeFocus,
                palette: palette,
                onMinus: onVolumeMinus,
                onPlus: onVolumePlus,
              ),
              helper: 'Specify the volume (lot size) to close.',
              helperColor: palette.axisText,
            ),
            if (volumeError != null) ...[
              SizedBox(height: 4.h),
              Text(
                volumeError!,
                style: TextStyle(color: AppColors.error, fontSize: 11.sp),
              ),
            ],
          ],
          SizedBox(height: 16.h),
          _TpSlSection(
            label: 'Take profit',
            field: _StepperField(
              controller: tpCtl,
              focusNode: tpFocus,
              palette: palette,
              onMinus: () => _bump(tpCtl, -1.0, d, slPips: 100, position: pos),
              onPlus:  () => _bump(tpCtl,  1.0, d, slPips: 100, position: pos),
            ),
            helper: 'When Mark Price reaches —, it will trigger '
                'Take Profit Market order to close this position. '
                'Estimated PNL will be \$---.',
            helperColor: palette.axisText,
          ),
          SizedBox(height: 16.h),
          _TpSlSection(
            label: 'Stop loss',
            field: _StepperField(
              controller: slCtl,
              focusNode: slFocus,
              palette: palette,
              onMinus: () => _bump(slCtl, -1.0, d, slPips: 50, position: pos),
              onPlus:  () => _bump(slCtl,  1.0, d, slPips: 50, position: pos),
            ),
            helper: 'When Mark Price reaches —, it will trigger '
                'Stop Market order to close this position. '
                'Estimated PNL will be \$---.',
            helperColor: palette.axisText,
          ),
        ],
      ),
    );
  }
}

/// A single TP/SL block: inline suggested-value label, stepper field, helper.
class _TpSlSection extends StatelessWidget {
  const _TpSlSection({
    required this.label,
    required this.field,
    required this.helper,
    required this.helperColor,
  });

  final String label;
  final Widget field;
  final String helper;
  final Color helperColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 8.h),
        field,
        SizedBox(height: 4.h),
        Text(
          helper,
          style: TextStyle(color: helperColor, fontSize: 11.sp),
        ),
      ],
    );
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
    // Borderless container: only the background + rounded corners; the
    // minus/plus buttons sit inside the same rounded container so the field
    // reads as a single pill with no visible dividing line.
    return Container(
      decoration: BoxDecoration(
        color: palette.fieldBg,
        borderRadius: BorderRadius.circular(10.r),
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
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  if (RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)) {
                    return newValue;
                  }
                  return oldValue;
                }),
              ],
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onPlus, palette: palette),
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
    // Slightly tighter than the previous 14/14 so the button feels
    // integrated with the field, not floating on top of it.
    return InkResponse(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Icon(icon, size: 18.sp, color: AppColors.textPrimary),
      ),
    );
  }
}

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
    required this.primaryLabel,
    required this.busy,
    required this.onCancel,
    required this.onPrimary,
    required this.sideColor,
    required this.palette,
  });
  final String primaryLabel;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;
  final Color sideColor;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final label = primaryLabel;
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
