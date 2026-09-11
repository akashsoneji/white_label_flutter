import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'meta_theme.dart';
import 'widgets/meta_native_chart.dart';

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
String _fmt(double v, int d) => v.toStringAsFixed(d);

double pow10(int d) {
  double r = 1;
  for (var i = 0; i < d; i++) r *= 10;
  return r;
}

typedef MetaCloseCallback = Future<void> Function(double volume);

class MetaClosePositionScreen extends StatefulWidget {
  final TradePosition position;
  final VoidCallback onModify;
  final MetaCloseCallback onClose;
  final bool initialPartial;

  const MetaClosePositionScreen({
    super.key,
    required this.position,
    required this.onModify,
    required this.onClose,
    this.initialPartial = false,
  });

  @override
  State<MetaClosePositionScreen> createState() => _MetaClosePositionScreenState();
}

class _MetaClosePositionScreenState extends State<MetaClosePositionScreen> {
  static const double _minLot = 0.01;

  final ChartSocketController _socket = Get.find<ChartSocketController>();
  final TradingController _trading = Get.find<TradingController>();

  String? _previousChartSymbol;
  String _fillPolicy = Get.find<LanguageService>().tr('meta_close_fok');
  double _closeVolumeValue = 0.01;

  late final TextEditingController _volumeController =
      TextEditingController(text: _formatPillNumber(_closeVolumeValue));

  bool _isSubmitting = false;

  static const List<double> _pillSteps = [-0.5, -0.1, -0.01, 0, 0.01, 0.1, 0.5];

  double get _closeVolume {
    final full = widget.position.volume;
    final v = _closeVolumeValue.clamp(_minLot, full);
    return (v * 100).round() / 100.0;
  }

  Future<void> _submitClose() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final volume = _closeVolume;
      final isPartial = volume < widget.position.volume - 0.00005;
      debugPrint(
        'Meta MetaClosePositionScreen: submitting close '
        'orderId=${widget.position.orderId} '
        'symbol=${widget.position.symbol} '
        'volume=$volume '
        'isPartial=$isPartial',
      );
      String mt5Account = '';
      try {
        if (Get.isRegistered<AccountController>()) {
          final accountController = Get.find<AccountController>();
          final active = accountController.activeMT5Account;
          if (active != null) {
            mt5Account = active.metaAccountNumber;
          }
        }
      } catch (_) {}

      final positionId = int.tryParse(widget.position.orderId) ?? 0;
      await _trading.closePositionById(
        mt5Account: mt5Account,
        positionId: positionId,
        volume: volume,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('Meta MetaClosePositionScreen: close failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Get.find<LanguageService>().tr('meta_close_failed').replaceAll('{error}', '$e'))),
      );
    }
  }

  String _formatPillNumber(double v) {
    return v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPartial) {
      final half = widget.position.volume / 2.0;
      _closeVolumeValue = (half * 100).round() / 100.0;
      if (_closeVolumeValue < _minLot) {
        _closeVolumeValue = _minLot;
      }
    } else {
      _closeVolumeValue = widget.position.volume;
    }
    _volumeController.text = _formatPillNumber(_closeVolumeValue);

    final posSymbol = _stripSuffix(widget.position.symbol);
    final prev = _socket.currentSymbol.value;
    _previousChartSymbol = prev.isEmpty ? null : prev;
    _socket.changeSymbol(posSymbol);
  }

  String _stripSuffix(String sym) {
    final i = sym.indexOf('.');
    return i < 0 ? sym : sym.substring(0, i);
  }

  @override
  void dispose() {
    if (_previousChartSymbol != null && _previousChartSymbol!.isNotEmpty) {
      _socket.changeSymbol(_previousChartSymbol!);
    } else {
      _socket.resetController();
    }
    _volumeController.dispose();
    super.dispose();
  }

  double _pillCloseVolume(int i) {
    final full = widget.position.volume;
    if (i == 3) return full;
    final step = _pillSteps[i];
    final target = _closeVolume + step;
    return target.clamp(_minLot, full);
  }

  bool _isPillEnabled(int i) {
    final full = widget.position.volume;
    if (full <= 0) return false;
    if (i == 3) return true;
    final step = _pillSteps[i];
    final target = _closeVolume + step;
    if (step < 0) {
      if (target < _minLot - 0.0005) return false;
      if ((target - _closeVolume).abs() < 0.0005) return false;
      return true;
    } else {
      if (target > full + 0.0005) return false;
      if ((target - _closeVolume).abs() < 0.0005) return false;
      return true;
    }
  }

  bool _isPillActive(int i) {
    if (i == 3) {
      return (_closeVolume - widget.position.volume).abs() < 0.0005;
    }
    return false;
  }

  double get _expectedProfit {
    if (widget.position.volume <= 0) return 0;
    final livePos = _trading.marketPositions.firstWhereOrNull(
      (p) => p.orderId == widget.position.orderId,
    );
    final fullProfit = livePos?.profitLoss ?? widget.position.profitLoss;
    return fullProfit * (_closeVolume / widget.position.volume);
  }

  ({String big, String small}) _splitPrice(String s) {
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dotIdx = body.indexOf('.');
    final intPart = dotIdx < 0 ? body : body.substring(0, dotIdx);
    final decPart = dotIdx < 0 ? '' : body.substring(dotIdx + 1);
    if (decPart.length <= 1) {
      return (big: neg ? '-$body' : body, small: '');
    }
    final mainDec = decPart.substring(0, decPart.length - 1);
    final sup = decPart.substring(decPart.length - 1);
    final bigStr = '$intPart.$mainDec';
    return (big: neg ? '-$bigStr' : bigStr, small: sup);
  }

  Widget _bidAskColumn(double value, Color color) {
    final parts = _splitPrice(value.toStringAsFixed(widget.position.digits));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(parts.big,
                style: AppTextStyles.bodyText.copyWith(
                  color: color,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.0,
                )),
            if (parts.small.isNotEmpty)
              Transform.translate(
                offset: Offset(0, -4.h),
                child: Text(parts.small,
                    style: AppTextStyles.bodyText.copyWith(
                      color: color,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    )),
              ),
          ],
        ),
      ],
    );
  }

  Widget _volumePill(BuildContext c, int i) {
    final active = _isPillActive(i);
    final enabled = _isPillEnabled(i);
    String label;
    if (i == 3) {
      label = _closeVolume.toStringAsFixed(2);
    } else {
      final sign = _pillSteps[i] < 0 ? '−' : '+';
      label = '$sign${_pillSteps[i].abs().toStringAsFixed(2)}';
    }
    final Color color;
    if (active) {
      color = MetaTheme.mainText(c);
    } else if (enabled) {
      color = MetaTheme.buy(c);
    } else {
      color = MetaTheme.subText(c).withValues(alpha: 0.55);
    }
    final showLeftDivider = i > 0;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () => setState(() {
                  final step = _pillSteps[i];
                  final target = _closeVolume + step;
                  _closeVolumeValue = target.clamp(_minLot, widget.position.volume);
                  _volumeController.text = _formatPillNumber(_closeVolumeValue);
                })
            : null,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: showLeftDivider
                  ? BorderSide(
                      color: MetaTheme.subText(c).withValues(alpha: 0.25),
                      width: 0.6,
                    )
                  : BorderSide.none,
              bottom: active
                  ? BorderSide(
                      color: color,
                      width: 1.6,
                    )
                  : BorderSide.none,
            ),
          ),
          child: i == 3
              ? TextField(
                  controller: _volumeController,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,3}')),
                  ],
                  style: AppTextStyles.bodyText.copyWith(
                    color: color,
                    fontSize: 14.sp,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  cursorColor: color,
                  onChanged: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed == null) return;
                    final clamped =
                        parsed.clamp(_minLot, widget.position.volume);
                    setState(() {
                      _closeVolumeValue = clamped;
                    });
                  },
                )
              : Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    color: color,
                    fontSize: 14.sp,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  ({double bid, double ask}) _resolveBidAsk() {
    final p = widget.position;
    final posSymbol = _stripSuffix(p.symbol);
    final live = _socket.realTimePrice;
    final liveSym = (live['symbol'] ?? live['Symbol'] ?? '').toString();
    final liveBid = (live['bid'] ?? live['Bid']);
    final liveAsk = (live['ask'] ?? live['Ask']);
    if (_stripSuffix(liveSym) == posSymbol &&
        liveBid != null &&
        liveAsk != null) {
      final b = (liveBid as num).toDouble();
      final a = (liveAsk as num).toDouble();
      if (b > 0 && a > 0) {
        return (bid: b, ask: a);
      }
    }
    final seed = double.tryParse(p.currentPrice) ?? 0;
    if (seed <= 0) return (bid: 0, ask: 0);
    final tickSize = 1 / pow10(p.digits.clamp(2, 5));
    return (bid: seed, ask: seed + tickSize * 5);
  }

  @override
  Widget build(BuildContext c) {
    final p = widget.position;
    final isBuy = p.action.toUpperCase().contains('BUY');
    final isPartial = widget.initialPartial || (_closeVolume - p.volume).abs() > 0.0005;
    final digits = p.digits.clamp(2, 5);

    return Scaffold(
      backgroundColor: MetaTheme.card(c),
      appBar: AppBar(
        backgroundColor: MetaTheme.card(c),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MetaTheme.mainText(c)),
          onPressed: () => Navigator.pop(c),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.trArgs(
                'meta_close_position_title',
                {'orderId': '${p.orderId}'},
              ),
              style: AppTextStyles.bodyText.copyWith(
                color: MetaTheme.mainText(c),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '${isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} ${p.symbol} at ${p.entryPrice}',
              style: AppTextStyles.bodyText.copyWith(
                color: MetaTheme.subText(c),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
              child: Row(
                children: [
                  Text(
                    Get.find<LanguageService>().tr('meta_close_mode'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: MetaTheme.subText(c),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: isPartial
                          ? MetaTheme.buy(c).withValues(alpha: 0.12)
                          : MetaTheme.subText(c).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      isPartial ? 'PARTIAL' : 'FULL',
                      style: AppTextStyles.bodyText.copyWith(
                        color: isPartial
                            ? MetaTheme.buy(c)
                            : MetaTheme.subText(c),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              height: 40.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: MetaTheme.subText(c).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: [
                  _volumePill(c, 0),
                  _volumePill(c, 1),
                  _volumePill(c, 2),
                  _volumePill(c, 3),
                  _volumePill(c, 4),
                  _volumePill(c, 5),
                  _volumePill(c, 6),
                ],
              ),
            ),
            if (!isPartial)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
                child: Text(
                  Get.find<LanguageService>().tr('meta_close_partial_hint'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: MetaTheme.subText(c).withValues(alpha: 0.7),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
              child: Obx(() {
                final live = _resolveBidAsk();
                return Row(
                  children: [
                    Expanded(
                      child: _bidAskColumn(live.bid, MetaTheme.sell(c)),
                    ),
                    SizedBox(width: 18.w),
                    Expanded(
                      child: _bidAskColumn(live.ask, MetaTheme.buy(c)),
                    ),
                  ],
                );
              }),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _slTpBox(
                      context: c,
                      color: isBuy ? MetaTheme.sell(c) : MetaTheme.buy(c),
                      label: 'SL',
                      digits: digits,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: _slTpBox(
                      context: c,
                      color: MetaTheme.buy(c),
                      label: 'TP',
                      digits: digits,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 4.h),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: MetaTheme.subText(c).withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_close_fill_policy'),
                        style: AppTextStyles.bodyText.copyWith(
                          color: MetaTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        )),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fillPolicy,
                        isDense: true,
                        icon: Icon(Icons.expand_more,
                            color: MetaTheme.subText(c), size: 18.sp),
                        iconSize: 18,
                        style: AppTextStyles.bodyText.copyWith(
                          color: MetaTheme.subText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        dropdownColor: MetaTheme.card(c),
                        items: [
                          DropdownMenuItem(
                            value: Get.find<LanguageService>().tr('meta_close_fok'),
                            child: Text(Get.find<LanguageService>().tr('meta_close_fok')),
                          ),
                          DropdownMenuItem(
                            value: Get.find<LanguageService>().tr('meta_close_ioc'),
                            child: Text(Get.find<LanguageService>().tr('meta_close_ioc')),
                          ),
                          DropdownMenuItem(
                            value: Get.find<LanguageService>().tr('meta_close_boc'),
                            child: Text(Get.find<LanguageService>().tr('meta_close_boc')),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fillPolicy = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(
              height: 340.h,
              child: MetaNativeChart(
                symbol: p.symbol,
                maxPoints: 220,
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: Text(
                TranslationUtils.tr('meta_close_position_market_warning'),
                style: AppTextStyles.bodyText.copyWith(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: 12.h),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Obx(() {
                    final profit = _expectedProfit;
                    final isLoss = profit < 0;
                    final btnColor = isLoss
                        ? MetaTheme.sell(c)
                        : MetaTheme.buy(c);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (_isSubmitting)
                          SizedBox(
                            width: 16.w,
                            height: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(btnColor),
                            ),
                          )
                        else ...[
                          Text(
                            isPartial
                                ? TranslationUtils.tr(
                                    'close_position_screen_partial_close',
                                  )
                                : (isLoss
                                    ? TranslationUtils.tr(
                                        'meta_close_position_close_with_loss',
                                      )
                                    : TranslationUtils.tr(
                                        'meta_close_position_close_with_profit',
                                      )),
                            style: AppTextStyles.bodyText.copyWith(
                              color: btnColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _fmtUSD(profit),
                            style: AppTextStyles.bodyText.copyWith(
                              color: btnColor,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtUSD(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs().toStringAsFixed(2);
    return '$sign$abs';
  }

  Widget _slTpBox({
    required BuildContext context,
    required Color color,
    required String label,
    required int digits,
  }) {
    final c = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove, color: MetaTheme.mainText(c)),
              onPressed: () {
                widget.onModify();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: Center(
                child: Text(label,
                    style: AppTextStyles.bodyText.copyWith(
                      color: MetaTheme.mainText(c),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: MetaTheme.mainText(c)),
              onPressed: () {
                widget.onModify();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(height: 2, color: color),
      ],
    );
  }
}
