import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'meta_theme.dart';
import 'widgets/meta_native_chart.dart';

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
String _fmt(double v, int d) => v.toStringAsFixed(d);

double pow10(int d) {
  double r = 1;
  for (var i = 0; i < d; i++) r *= 10;
  return r;
}

class MetaModifyPositionScreen extends StatefulWidget {
  final TradePosition position;

  const MetaModifyPositionScreen({super.key, required this.position});

  @override
  State<MetaModifyPositionScreen> createState() =>
      _MetaModifyPositionScreenState();
}

class _MetaModifyPositionScreenState extends State<MetaModifyPositionScreen> {
  final ChartSocketController _socket = Get.find<ChartSocketController>();
  final TradingController _trading = Get.find<TradingController>();

  String? _previousChartSymbol;
  Map<String, dynamic>? _symbolDetails;

  late final TextEditingController _slController;
  late final TextEditingController _tpController;

  final FocusNode _slFocus = FocusNode();
  final FocusNode _tpFocus = FocusNode();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final originalSL = double.tryParse(widget.position.stopLoss) ?? 0.0;
    final originalTP = double.tryParse(widget.position.takeProfit) ?? 0.0;

    _slController = TextEditingController(
      text: originalSL > 0 ? _fmt(originalSL, widget.position.digits) : '',
    );
    _tpController = TextEditingController(
      text: originalTP > 0 ? _fmt(originalTP, widget.position.digits) : '',
    );

    _slController.addListener(_onTextChanged);
    _tpController.addListener(_onTextChanged);

    final posSymbol = _stripSuffix(widget.position.symbol);
    final prev = _socket.currentSymbol.value;
    _previousChartSymbol = prev.isEmpty ? null : prev;
    _socket.changeSymbol(posSymbol);

    _loadSymbolDetails();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  String _stripSuffix(String sym) {
    final i = sym.indexOf('.');
    return i < 0 ? sym : sym.substring(0, i);
  }

  Future<void> _loadSymbolDetails() async {
    try {
      if (Get.isRegistered<AccountController>()) {
        final accountController = Get.find<AccountController>();
        final active = accountController.activeMT5Account;
        final accountNumber = active?.metaAccountNumber ?? '0';
        final details = await SymbolDetailsCacheService.getSymbolDetails(
          widget.position.symbol,
          accountNumber,
        );
        if (mounted) {
          setState(() {
            _symbolDetails = details;
          });
        }
      }
    } catch (e) {
      debugPrint('MetaModifyScreen: Failed to load symbol details: $e');
    }
  }

  @override
  void dispose() {
    if (_previousChartSymbol != null && _previousChartSymbol!.isNotEmpty) {
      _socket.changeSymbol(_previousChartSymbol!);
    } else {
      _socket.resetController();
    }
    _slController.removeListener(_onTextChanged);
    _tpController.removeListener(_onTextChanged);
    _slController.dispose();
    _tpController.dispose();
    _slFocus.dispose();
    _tpFocus.dispose();
    super.dispose();
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
            Text(
              parts.big,
              style: TextStyle(
                color: color,
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
            if (parts.small.isNotEmpty)
              Transform.translate(
                offset: Offset(0, -4.h),
                child: Text(
                  parts.small,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
          ],
        ),
      ],
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

  void _showAutoSlTpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _AutoSlTpBottomSheet(
            position: widget.position,
            symbolDetails: _symbolDetails,
            initialSL:
                double.tryParse(_slController.text.replaceAll(',', '')) ?? 0.0,
            initialTP:
                double.tryParse(_tpController.text.replaceAll(',', '')) ?? 0.0,
            onApply: (slVal, tpVal) {
              setState(() {
                _slController.text =
                    slVal > 0 ? _fmt(slVal, widget.position.digits) : '';
                _tpController.text =
                    tpVal > 0 ? _fmt(tpVal, widget.position.digits) : '';
              });
            },
          ),
    );
  }

  bool get _isModifyEnabled {
    final slText = _slController.text.trim();
    final tpText = _tpController.text.trim();
    final slVal = double.tryParse(slText.replaceAll(',', '')) ?? 0.0;
    final tpVal = double.tryParse(tpText.replaceAll(',', '')) ?? 0.0;

    final origSL = double.tryParse(widget.position.stopLoss) ?? 0.0;
    final origTP = double.tryParse(widget.position.takeProfit) ?? 0.0;

    final slChanged = (slVal - origSL).abs() > 0.00005;
    final tpChanged = (tpVal - origTP).abs() > 0.00005;

    return (slChanged || tpChanged) && !_isSubmitting;
  }

  Future<void> _submitModify() async {
    if (!_isModifyEnabled) return;
    setState(() => _isSubmitting = true);
    try {
      final slText = _slController.text.trim();
      final tpText = _tpController.text.trim();
      final slVal = double.tryParse(slText.replaceAll(',', '')) ?? 0.0;
      final tpVal = double.tryParse(tpText.replaceAll(',', '')) ?? 0.0;

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
      final success = await _trading.updateTPSL(
        mt5Account: mt5Account,
        positionId: positionId,
        stopLoss: slVal,
        takeProfit: tpVal,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Modify failed: $e')));
    }
  }

  Widget _slTpEditBox({
    required BuildContext context,
    required Color color,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double step,
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
                final cur =
                    double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
                final entry =
                    double.tryParse(widget.position.entryPrice) ?? 0.0;
                final startPrice = cur > 0 ? cur : entry;
                final nextVal = (startPrice - step).clamp(0.0, double.infinity);
                controller.text = _fmt(nextVal, widget.position.digits);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: MetaTheme.mainText(c),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: MetaTheme.mainText(c)),
              onPressed: () {
                final cur =
                    double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
                final entry =
                    double.tryParse(widget.position.entryPrice) ?? 0.0;
                final startPrice = cur > 0 ? cur : entry;
                final nextVal = startPrice + step;
                controller.text = _fmt(nextVal, widget.position.digits);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: color, width: 2)),
          ),
          child: AppTextFormField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            readOnly: false,
            onTap: () {
              if (controller.text.isEmpty) {
                final entryPrice =
                    double.tryParse(widget.position.entryPrice) ?? 0.0;
                if (entryPrice > 0) {
                  final isBuy = widget.position.action.toLowerCase() == 'buy';
                  final isJPY =
                      widget.position.symbol.contains('JPY') ||
                      widget.position.symbol.contains('GOLD') ||
                      widget.position.symbol.contains('XAU');
                  if (label == 'SL') {
                    final standardRisk = isJPY ? 0.50 : 0.0050;
                    final defaultSL =
                        isBuy
                            ? entryPrice - standardRisk
                            : entryPrice + standardRisk;
                    controller.text = _fmt(defaultSL, widget.position.digits);
                  } else {
                    final standardReward = isJPY ? 1.00 : 0.0100;
                    final defaultTP =
                        isBuy
                            ? entryPrice + standardReward
                            : entryPrice - standardReward;
                    controller.text = _fmt(defaultTP, widget.position.digits);
                  }
                }
              }
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,5}$')),
            ],
            style: TextStyle(
              color: MetaTheme.mainText(c),
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 4.h),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = widget.position;
    final isBuy = p.action.toUpperCase().contains('BUY');
    final digits = p.digits.clamp(2, 5);
    final step = 1 / pow10(digits);

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
              Get.find<LanguageService>().tr('meta_modify_position_label', {'id': '$p.orderId'}),
              style: TextStyle(
                color: MetaTheme.mainText(c),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '${isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} ${p.symbol} at ${p.entryPrice}',
              style: TextStyle(
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
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
              child: Obx(() {
                final live = _resolveBidAsk();
                return Row(
                  children: [
                    Expanded(child: _bidAskColumn(live.bid, MetaTheme.sell(c))),
                    SizedBox(width: 18.w),
                    Expanded(child: _bidAskColumn(live.ask, MetaTheme.buy(c))),
                  ],
                );
              }),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _slTpEditBox(
                      context: c,
                      color: isBuy ? MetaTheme.sell(c) : MetaTheme.buy(c),
                      label: 'SL',
                      controller: _slController,
                      focusNode: _slFocus,
                      step: step,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: _slTpEditBox(
                      context: c,
                      color: MetaTheme.buy(c),
                      label: 'TP',
                      controller: _tpController,
                      focusNode: _tpFocus,
                      step: step,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 22.h),

            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            //   child: Align(
            //     alignment: Alignment.centerLeft,
            //     child: TextButton.icon(
            //       icon: Icon(Icons.calculate_outlined, color: MetaTheme.buy(c)),
            //       label: Text(
            //         Get.find<LanguageService>().tr('meta_modify_auto_sl_tp'),
            //         style: TextStyle(
            //           color: MetaTheme.buy(c),
            //           fontSize: 14.sp,
            //           fontWeight: FontWeight.w600,
            //         ),
            //       ),
            //       onPressed: () => _showAutoSlTpBottomSheet(c),
            //     ),
            //   ),
            // ),
            SizedBox(
              height: 340.h,
              child: MetaNativeChart(symbol: p.symbol, maxPoints: 220),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
              child: Text(
                'Stop Loss or Take Profit you set must differ from market price by at least 20 points. Stops processing is performed on the broker side.',
                style: TextStyle(
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
                  onPressed: _isModifyEnabled ? _submitModify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isModifyEnabled ? MetaTheme.buy(c) : Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? SizedBox(
                            width: 18.w,
                            height: 18.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Text(
                            Get.find<LanguageService>().tr('meta_modify_button'),
                            style: TextStyle(
                              color:
                                  _isModifyEnabled
                                      ? Colors.white
                                      : Colors.grey[600],
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
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
}

class _AutoSlTpBottomSheet extends StatefulWidget {
  final TradePosition position;
  final Map<String, dynamic>? symbolDetails;
  final double initialSL;
  final double initialTP;
  final void Function(double slVal, double tpVal) onApply;

  const _AutoSlTpBottomSheet({
    required this.position,
    required this.symbolDetails,
    required this.initialSL,
    required this.initialTP,
    required this.onApply,
  });

  @override
  State<_AutoSlTpBottomSheet> createState() => _AutoSlTpBottomSheetState();
}

class _AutoSlTpBottomSheetState extends State<_AutoSlTpBottomSheet> {
  late bool _slEnabled;
  late bool _tpEnabled;

  late final TextEditingController _slController;
  late final TextEditingController _tpController;

  final FocusNode _slFocus = FocusNode();
  final FocusNode _tpFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _slEnabled = widget.initialSL > 0;
    _tpEnabled = widget.initialTP > 0;

    _slController = TextEditingController(
      text: _slEnabled ? _fmt(widget.initialSL, widget.position.digits) : '',
    );
    _tpController = TextEditingController(
      text: _tpEnabled ? _fmt(widget.initialTP, widget.position.digits) : '',
    );

    _slController.addListener(_onTextChanged);
    _tpController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _slController.removeListener(_onTextChanged);
    _tpController.removeListener(_onTextChanged);
    _slController.dispose();
    _tpController.dispose();
    _slFocus.dispose();
    _tpFocus.dispose();
    super.dispose();
  }

  void _calculateTPFromRiskReward() {
    if (!_slEnabled) return;
    final slPrice =
        double.tryParse(_slController.text.replaceAll(',', '')) ?? 0.0;
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;
    if (slPrice <= 0 || entryPrice <= 0) return;
    final isBuy = widget.position.action.toLowerCase() == 'buy';
    double tpPrice;
    if (isBuy) {
      final risk = entryPrice - slPrice;
      tpPrice = entryPrice + (2 * risk);
    } else {
      final risk = slPrice - entryPrice;
      tpPrice = entryPrice - (2 * risk);
    }
    _tpController.text = _fmt(tpPrice, widget.position.digits);
  }

  void _incrementValue(
    TextEditingController controller,
    double step,
    bool isTP,
  ) {
    final cur =
        double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newVal = cur + step;
    controller.text = _fmt(newVal, widget.position.digits);
    if (!isTP) _calculateTPFromRiskReward();
  }

  void _decrementValue(
    TextEditingController controller,
    double step,
    bool isTP,
  ) {
    final cur =
        double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newVal = (cur - step).clamp(0.0, double.infinity);
    controller.text = _fmt(newVal, widget.position.digits);
    if (!isTP) _calculateTPFromRiskReward();
  }

  double _expectedPnL(double targetPrice, bool isTP) {
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;
    if (entryPrice <= 0 || targetPrice <= 0) return 0.0;

    final details = widget.symbolDetails;
    final contractSize = (details?['contract_size'] as num?)?.toDouble() ?? 1.0;
    final volume = widget.position.volume;
    final isBuy = widget.position.action.toLowerCase() == 'buy';

    double diff;
    if (isTP) {
      diff = isBuy ? (targetPrice - entryPrice) : (entryPrice - targetPrice);
    } else {
      diff = isBuy ? (entryPrice - targetPrice) : (targetPrice - entryPrice);
    }

    return diff * volume * contractSize;
  }

  Widget _switchTile(
    BuildContext c,
    String label,
    bool enabled,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(
        label,
        style: TextStyle(
          color: MetaTheme.mainText(c),
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: enabled,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor:
          label == Get.find<LanguageService>().tr('meta_modify_stop_loss') ? MetaTheme.sell(c) : MetaTheme.buy(c),
    );
  }

  Widget _calculatorCard(
    BuildContext c, {
    required String label,
    required Color color,
    required bool enabled,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double step,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required ValueChanged<String> onChanged,
  }) {
    final double targetPrice =
        double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
    final pnl = _expectedPnL(targetPrice, label == Get.find<LanguageService>().tr('meta_modify_take_profit'));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: MetaTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: MetaTheme.divider(c).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (enabled) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                GestureDetector(
                  onTap: onDecrement,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.remove, color: color, size: 18.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppTextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,5}$'),
                      ),
                    ],
                    style: TextStyle(
                      color: MetaTheme.mainText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: MetaTheme.card(c),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 8.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: color, width: 1.5),
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: onIncrement,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.add, color: color, size: 18.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              label == Get.find<LanguageService>().tr('meta_modify_take_profit')
                  ? 'Potential Profit: \$${pnl.toStringAsFixed(2)}'
                  : 'Potential Loss: \$${(-pnl.abs()).toStringAsFixed(2)}',
              style: TextStyle(
                color:
                    label == Get.find<LanguageService>().tr('meta_modify_take_profit')
                        ? MetaTheme.buy(c)
                        : MetaTheme.sell(c),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    final digits = widget.position.digits.clamp(2, 5);
    final step = 1 / pow10(digits);

    return Container(
      decoration: BoxDecoration(
        color: MetaTheme.card(c),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(c).viewInsets.bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: MetaTheme.subText(c).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              Get.find<LanguageService>().tr('meta_modify_auto_sl_tp'),
              style: TextStyle(
                color: MetaTheme.mainText(c),
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(),

          _switchTile(c, Get.find<LanguageService>().tr('meta_modify_stop_loss'), _slEnabled, (v) {
            setState(() {
              _slEnabled = v;
              if (v) {
                final entryPrice =
                    double.tryParse(widget.position.entryPrice) ?? 0.0;
                if (entryPrice > 0) {
                  final isBuy = widget.position.action.toLowerCase() == 'buy';
                  final isJPY =
                      widget.position.symbol.contains('JPY') ||
                      widget.position.symbol.contains('GOLD') ||
                      widget.position.symbol.contains('XAU');
                  final standardRisk = isJPY ? 0.50 : 0.0050;
                  final defaultSL =
                      isBuy
                          ? entryPrice - standardRisk
                          : entryPrice + standardRisk;
                  _slController.text = _fmt(defaultSL, digits);
                  _calculateTPFromRiskReward();
                }
              } else {
                _slController.clear();
              }
            });
          }),

          _calculatorCard(
            c,
            label: Get.find<LanguageService>().tr('meta_modify_stop_loss'),
            color: MetaTheme.sell(c),
            enabled: _slEnabled,
            controller: _slController,
            focusNode: _slFocus,
            step: step,
            onIncrement: () => _incrementValue(_slController, step, false),
            onDecrement: () => _decrementValue(_slController, step, false),
            onChanged: (_) => _calculateTPFromRiskReward(),
          ),

          _switchTile(c, Get.find<LanguageService>().tr('meta_modify_take_profit'), _tpEnabled, (v) {
            setState(() {
              _tpEnabled = v;
              if (v) {
                if (_slEnabled && _slController.text.isNotEmpty) {
                  _calculateTPFromRiskReward();
                } else {
                  final entryPrice =
                      double.tryParse(widget.position.entryPrice) ?? 0.0;
                  if (entryPrice > 0) {
                    final isBuy = widget.position.action.toLowerCase() == 'buy';
                    final isJPY =
                        widget.position.symbol.contains('JPY') ||
                        widget.position.symbol.contains('GOLD') ||
                        widget.position.symbol.contains('XAU');
                    final standardReward = isJPY ? 1.00 : 0.0100;
                    final defaultTP =
                        isBuy
                            ? entryPrice + standardReward
                            : entryPrice - standardReward;
                    _tpController.text = _fmt(defaultTP, digits);
                  }
                }
              } else {
                _tpController.clear();
              }
            });
          }),

          _calculatorCard(
            c,
            label: Get.find<LanguageService>().tr('meta_modify_take_profit'),
            color: MetaTheme.tpGreen,
            enabled: _tpEnabled,
            controller: _tpController,
            focusNode: _tpFocus,
            step: step,
            onIncrement: () => _incrementValue(_tpController, step, true),
            onDecrement: () => _decrementValue(_tpController, step, true),
            onChanged: (_) {},
          ),

          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              height: 44.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaTheme.buy(c),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: () {
                  final slVal =
                      _slEnabled
                          ? (double.tryParse(
                                _slController.text.replaceAll(',', ''),
                              ) ??
                              0.0)
                          : 0.0;
                  final tpVal =
                      _tpEnabled
                          ? (double.tryParse(
                                _tpController.text.replaceAll(',', ''),
                              ) ??
                              0.0)
                          : 0.0;
                  widget.onApply(slVal, tpVal);
                  Navigator.of(c).pop();
                },
                child: Text(
                  Get.find<LanguageService>().tr('meta_modify_apply'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
