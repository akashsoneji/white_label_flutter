import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'widgets/meta_native_chart.dart';

/// MetaTrader-style "New Order" screen, 1:1 with the design screenshots.
class MetaNewOrderScreen extends StatefulWidget {
  const MetaNewOrderScreen({super.key, this.symbol});

  final String? symbol;

  @override
  State<MetaNewOrderScreen> createState() => _MetaNewOrderScreenState();
}

enum _Expiration { gtc, today, specified, specifiedDay }

extension _ExpirationX on _Expiration {
  String get api => switch (this) {
        _Expiration.today => 'TODAY',
        _Expiration.specified => 'SPECIFIED',
        _Expiration.specifiedDay => 'SPECIFIED_DAY',
        _Expiration.gtc => 'GTC',
      };
  String get label => switch (this) {
        _Expiration.today => 'Today',
        _Expiration.specified => 'Specified',
        _Expiration.specifiedDay => 'Specified day',
        _Expiration.gtc => 'GTC',
      };
}

class _MetaNewOrderScreenState extends State<MetaNewOrderScreen> {
  late final TradingController _trading;
  late final ChartSocketController _socket;
  late final AccountController _accounts;

  /// All 7 order types shown in the picker.
  /// "Market Execution" (buyMarket) is shared by SELL and BUY since the side
  /// is decided at the bottom action bar. After it: 3 limits and 3 stops.
  static const List<OrderType> _orderTypes = <OrderType>[
    OrderType.buyMarket, // shared Market Execution
    OrderType.buyLimit,
    OrderType.sellLimit,
    OrderType.buyStop,
    OrderType.sellStop,
    OrderType.buyStopLimit,
    OrderType.sellStopLimit,
  ];

  static const double _minLot = 0.01;
  double get _maxLot => _accounts.activeMT5Account?.maxLotSize ?? 100.0;

  /// Volume chip row – 7 chips total: 3 negative deltas, the live volume
  /// in the centre (always bold/active), then 3 positive deltas.
  /// Layout: -0.5 | -0.1 | -0.01 | [volume] | +0.01 | +0.1 | +0.5
  static const List<double> _negativeDeltas = <double>[-0.5, -0.1, -0.01];
  static const List<double> _positiveDeltas = <double>[0.01, 0.1, 0.5];

  /// Brand colors used by the Market Execution SELL|BUY 50/50 bar.
  static const Color _brandBlue = Color(0xFF1877F2);
  static const Color _sellRed = Color(0xFFD72E1F);

  final ValueNotifier<OrderType> _orderType =
      ValueNotifier<OrderType>(OrderType.buyMarket);
  final ValueNotifier<_Expiration> _expiration =
      ValueNotifier<_Expiration>(_Expiration.gtc);

  String _symbol = 'XAUUSD';
  StreamSubscription<Map<String, dynamic>>? _priceSub;

  // Volume.
  double _volume = 0.01;
  final TextEditingController _volumeController =
      TextEditingController(text: '0.01');

  // Pending-only trigger price and stop-limit price.
  final TextEditingController _triggerPriceController =
      TextEditingController();
  final TextEditingController _stopLimitPriceController =
      TextEditingController();
  final FocusNode _triggerFocus = FocusNode();
  final FocusNode _stopLimitFocus = FocusNode();

  // SL / TP.
  final ValueNotifier<bool> _slEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _tpEnabled = ValueNotifier<bool>(false);
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _tpController = TextEditingController();
  final FocusNode _slFocus = FocusNode();
  final FocusNode _tpFocus = FocusNode();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _trading = Get.find<TradingController>();
    _socket = Get.find<ChartSocketController>();
    _accounts = Get.find<AccountController>();

    if (widget.symbol != null && widget.symbol!.isNotEmpty) {
      _symbol = widget.symbol!;
      _socket.changeSymbol(_symbol);
    } else {
      final current = _socket.currentSymbol.value;
      if (current.isNotEmpty) _symbol = current;
    }

    _priceSub = _socket.priceStream.listen((_) {
      if (mounted) setState(() {});
    });

    _slController.addListener(_rebuild);
    _tpController.addListener(_rebuild);
    _slFocus.addListener(_rebuild);
    _tpFocus.addListener(_rebuild);
    _triggerFocus.addListener(_rebuild);
    _stopLimitFocus.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _priceSub?.cancel();
    _volumeController.dispose();
    _triggerPriceController.dispose();
    _stopLimitPriceController.dispose();
    _slController.dispose();
    _tpController.dispose();
    _slFocus.dispose();
    _tpFocus.dispose();
    _triggerFocus.dispose();
    _stopLimitFocus.dispose();
    _orderType.dispose();
    _slEnabled.dispose();
    _tpEnabled.dispose();
    _expiration.dispose();
    super.dispose();
  }

  // ──── Format helpers ──────────────────────────────────────────────────────

  int get _digits {
    final d = _socket.realTimePrice['digits'];
    if (d is int) return d;
    if (d is num) return d.toInt();
    if (d is String) return int.tryParse(d) ?? 5;
    return 5;
  }

  double? get _bid => _socket.getBidPrice();
  double? get _ask => _socket.getAskPrice();

  double get _pipValue {
    switch (_digits) {
      case 1:
        return 1.0;
      case 2:
        return 0.1;
      case 3:
        return 0.01;
      case 4:
        return 0.001;
      case 5:
        return 0.0001;
      default:
        return 0.00001;
    }
  }

  String _formatPrice(double v) =>
      PrecisionHelper.formatPrice(v, decimals: _digits);

  String _formatVolume(double v) {
    final s = v.toString();
    final dot = s.indexOf('.');
    final decimals = dot == -1 ? 0 : s.length - dot - 1;
    return v.toStringAsFixed(decimals < 2 ? 2 : decimals);
  }

  String _formatSigned(double v) {
    final s = _formatVolume(v.abs());
    return v > 0 ? '+$s' : '\u2212$s';
  }

  // ──── Order-type helpers ─────────────────────────────────────────────────

  bool get _isMarket =>
      _orderType.value == OrderType.buyMarket ||
      _orderType.value == OrderType.sellMarket;

  bool get _isPending => !_isMarket;

  bool get _isStopLimit =>
      _orderType.value == OrderType.buyStopLimit ||
      _orderType.value == OrderType.sellStopLimit;

  String _orderTypeLabel(OrderType t) {
    switch (t) {
      case OrderType.buyMarket:
      case OrderType.sellMarket:
        return 'Market Execution';
      case OrderType.buyLimit:
        return 'Buy Limit';
      case OrderType.sellLimit:
        return 'Sell Limit';
      case OrderType.buyStop:
        return 'Buy Stop';
      case OrderType.sellStop:
        return 'Sell Stop';
      case OrderType.buyStopLimit:
        return 'Buy Stop Limit';
      case OrderType.sellStopLimit:
        return 'Sell Stop Limit';
    }
  }

  double? _defaultTriggerPrice(OrderType type) {
    final bid = _bid;
    final ask = _ask;
    if (bid == null && ask == null) return null;
    final ref = type == OrderType.buyLimit || type == OrderType.sellStop
        ? ask
        : bid;
    if (ref == null) return null;
    final offset = _pipValue * 5;
    return type == OrderType.buyLimit || type == OrderType.sellStop
        ? ref - offset
        : ref + offset;
  }

  double? _slDefault() {
    final trigger = _defaultTriggerPrice(_orderType.value);
    if (trigger == null) return null;
    final dir = _orderType.value.isBuyOrder ? -1 : 1;
    return trigger + dir * (trigger.abs() * 0.0115);
  }

  double? _tpDefault() {
    final trigger = _defaultTriggerPrice(_orderType.value);
    if (trigger == null) return null;
    final dir = _orderType.value.isBuyOrder ? 1 : -1;
    return trigger + dir * (trigger.abs() * 0.0115);
  }

  // ──── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submit({required OrderType type}) async {
    if (_submitting) return;
    _orderType.value = type;

    final v = double.tryParse(_volumeController.text) ?? _volume;
    _volume = v.clamp(_minLot, _maxLot);
    _volumeController.text = _formatVolume(_volume);

    final account = _accounts.activeMT5Account;
    if (account == null) {
      CustomToastService.showError(
        title: 'No active account',
        message: 'Switch to an MT5 account to place an order.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String? priceStr;
      String? stopLimitStr;

      if (_isPending) {
        priceStr = _triggerPriceController.text.trim().isEmpty
            ? '0.00'
            : _formatPrice(double.parse(_triggerPriceController.text));
      }
      if (_isStopLimit) {
        stopLimitStr = _stopLimitPriceController.text.trim().isEmpty
            ? _formatPrice(
                (_defaultTriggerPrice(type) ?? 0.0) + _pipValue * 10)
            : _formatPrice(double.parse(_stopLimitPriceController.text));
      }

      final tp = _tpEnabled.value
          ? _formatPrice(
              double.tryParse(_tpController.text) ?? _tpDefault() ?? 0.0)
          : null;
      final sl = _slEnabled.value
          ? _formatPrice(
              double.tryParse(_slController.text) ?? _slDefault() ?? 0.0)
          : null;

      final success = await _trading.placeTradeOrder(
        symbol: _symbol,
        volume: _formatVolume(_volume),
        orderType: type,
        price: _isMarket ? null : priceStr,
        takeProfit: tp,
        stopLoss: sl,
        stopLimitPrice: _isStopLimit ? stopLimitStr : null,
        mt5Account: account.metaAccountNumber,
      );

      if (!mounted) return;
      if (success) {
        Get.back(closeOverlays: true);
        Get.toNamed(
          Routes.ORDER_CONFIRMATION,
          arguments: {
            'orderData': {
              'status': true,
              'message': 'Order placed',
              'data': {
                'order_id': null,
                'position_id': null,
                'price': _isMarket ? null : priceStr,
              },
            },
            'symbol': _symbol,
            'orderType': type.value.toString(),
            'volume': _volume,
            'price': _isMarket ? null : double.tryParse(priceStr ?? ''),
            'executionPrice': _isMarket ? null : priceStr,
            'positionId': null,
            'orderId': null,
            'tabIndex': 1,
            'isPlacing': false,
            'expiration': _isPending ? _expiration.value.api : null,
          },
        );
        if (Get.isRegistered<TradingWebSocketService>()) {
          Get.find<TradingWebSocketService>()
              .ensurePendingOrdersConnection()
              .catchError((_) {});
        }
      } else {
        CustomToastService.showError(
          title: 'Order failed',
          message: _trading.errorMessage.isNotEmpty
              ? _trading.errorMessage
              : 'Unable to place order',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to place order: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ──── Header / symbol flag helpers ───────────────────────────────────────

  String _removeSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  String _symbolDisplayName() {
    final s = _symbol;
    if (s.startsWith('XAU')) return 'Gold vs US Dollar';
    if (s.startsWith('XAG')) return 'Silver vs US Dollar';
    if (s.startsWith('EURUSD')) return 'Euro vs US Dollar';
    if (s.startsWith('GBPUSD')) return 'Pound vs US Dollar';
    if (s.startsWith('USDJPY')) return 'US Dollar vs Yen';
    if (s.startsWith('BTCUSD')) return 'Bitcoin vs US Dollar';
    return s;
  }

  String _flagPath(String symbol) {
    final clean = _removeSuffix(symbol);
    return 'assets/svg/flags/${clean.toLowerCase()}.svg';
  }

  Widget _flagOrFallback(String symbol) {
    final size = 24.h;
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        _flagPath(symbol),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Image.asset(
          'assets/image/no_flag_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ──── Layout sections ──────────────────────────────────────────────

  Widget _buildOrderTypeRow() {
    return ValueListenableBuilder<OrderType>(
      valueListenable: _orderType,
      builder: (_, type, __) => InkWell(
        onTap: _showOrderTypeMenu,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          color: AppColors.whiteColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _orderTypeLabel(type),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.expand_more, size: 18.sp, color: AppColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChipRow() {
    // Helper used by every side chip to mutate _volume.
    void applyDelta(double delta) {
      final next = (_volume + delta).clamp(_minLot, _maxLot);
      setState(() {
        _volume = double.parse(next.toStringAsFixed(2));
        _volumeController.text = _formatVolume(_volume);
      });
      HapticFeedback.selectionClick();
    }

    // 7 chips total: -0.5 | -0.1 | -0.01 | [current] | +0.01 | +0.1 | +0.5
    final children = <Widget>[
      for (final d in _negativeDeltas)
        _VolumeChip(
          label: _formatSigned(d),
          isActive: false,
          onTap: () => applyDelta(d),
        ),
      _VolumeChip(
        label: _formatVolume(_volume),
        isActive: true,
        onTap: null,
      ),
      for (final d in _positiveDeltas)
        _VolumeChip(
          label: _formatSigned(d),
          isActive: false,
          onTap: () => applyDelta(d),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      color: AppColors.whiteColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }

  Widget _buildPriceTicker() {
    final bid = _bid ?? 0.0;
    final ask = _ask ?? 0.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      color: AppColors.whiteColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatPrice(bid),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: _sellRed,
                ),
              ),
            ],
          ),
          Container(width: 1, height: 30.h, color: AppColors.border),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatPrice(ask),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: _brandBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerPriceRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.h),
      // padding: EdgeInsets.zero,
      color: AppColors.whiteColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final current = double.tryParse(_triggerPriceController.text) ??
                  _defaultTriggerPrice(_orderType.value) ??
                  0.0;
              _triggerPriceController.text = _formatPrice(current - _pipValue);
            },
            icon: Icon(Icons.remove, color: AppColors.textGrey),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Price: ',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15.sp,
                    color: AppColors.textGrey,
                  ),
                ),
                AppTextFormField(
                  controller: _triggerPriceController,
                  focusNode: _triggerFocus,
                  width: 130.w,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,5}$'),
                    ),
                  ],
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: '0.00',
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final current = double.tryParse(_triggerPriceController.text) ??
                  _defaultTriggerPrice(_orderType.value) ??
                  0.0;
              _triggerPriceController.text = _formatPrice(current + _pipValue);
            },
            icon: Icon(Icons.add, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildStopLimitPriceRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.h),
      color: AppColors.whiteColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final current = double.tryParse(_stopLimitPriceController.text) ??
                  0.0;
              _stopLimitPriceController.text =
                  _formatPrice(current - _pipValue);
            },
            icon: Icon(Icons.remove, color: AppColors.textGrey),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stop Limit price: ',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15.sp,
                    color: AppColors.textGrey,
                  ),
                ),
                AppTextFormField(
                  controller: _stopLimitPriceController,
                  focusNode: _stopLimitFocus,
                  width: 130.w,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,5}$'),
                    ),
                  ],
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: '0.00',
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final current = double.tryParse(_stopLimitPriceController.text) ??
                  0.0;
              _stopLimitPriceController.text =
                  _formatPrice(current + _pipValue);
            },
            icon: Icon(Icons.add, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildSlTpRow() {
    return Container(
      width: double.infinity,
      color: AppColors.whiteColor,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _slEnabled.value = !_slEnabled.value,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.border.withOpacity(0.5)),
                      bottom: _slEnabled.value
                          ? BorderSide(color: _sellRed, width: 2)
                          :BorderSide.none
                          // : BorderSide(color: AppColors.border.withOpacity(0.5), width: 0.0),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: _SlTpInner(
                    controller: _slController,
                    focusNode: _slFocus,
                    pipValue: _pipValue,
                    enabled: _slEnabled.value,
                    label: 'SL',
                    accent: _sellRed,
                    defaultValue: _slDefault() ??
                        double.tryParse(_slController.text) ??
                        0.0,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _tpEnabled.value = !_tpEnabled.value,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: _tpEnabled.value
                          ? BorderSide(color: AppColors.success, width: 2)
                          : BorderSide(color: AppColors.border.withOpacity(0.5), width: 0.5),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: _SlTpInner(
                    controller: _tpController,
                    focusNode: _tpFocus,
                    pipValue: _pipValue,
                    enabled: _tpEnabled.value,
                    label: 'TP',
                    accent: AppColors.success,
                    defaultValue: _tpDefault() ??
                        double.tryParse(_tpController.text) ??
                        0.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFillPolicyRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      color: AppColors.whiteColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Fill policy',
            style: AppTextStyles.label.copyWith(
              fontSize: 14.sp,
              color: AppColors.textGrey,
            ),
          ),
          Text(
            'Fill or Kill',
            style: AppTextStyles.heading.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.h),
      color: AppColors.whiteColor,
      child: ValueListenableBuilder<_Expiration>(
        valueListenable: _expiration,
        builder: (_, value, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expiration:',
              style: AppTextStyles.label.copyWith(
                fontSize: 14.sp,
                color: AppColors.textGrey,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<_Expiration>(
                value: value,
                onChanged: (v) {
                  if (v != null) _expiration.value = v;
                },
                icon: Icon(Icons.expand_more),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final opt in _Expiration.values)
                    DropdownMenuItem(value: opt, child: Text(opt.label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    // Chart fills the remaining vertical space (Expanded in the body).
    return Container(
      color: AppColors.whiteColor,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: MetaNativeChart(
        key: ValueKey(
          'native_chart|$_symbol|${_accounts.activeMT5Account?.metaAccountNumber ?? ''}',
        ),
        symbol: _symbol,
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      color: AppColors.whiteColor,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Text(
        'Attention! The trade will be executed at market conditions, '
        'difference with requested price may be significant!',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildMarketExecutionBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _submitting
                    ? null
                    : () => _submit(type: OrderType.sellMarket),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _sellRed,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SELL',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.whiteColor,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'BY MARKET',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 10.sp,
                          color: AppColors.whiteColor.withOpacity(0.85),
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: _submitting
                    ? null
                    : () => _submit(type: OrderType.buyMarket),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _brandBlue,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BUY',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.whiteColor,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'BY MARKET',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 10.sp,
                          color: AppColors.whiteColor.withOpacity(0.85),
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceButton() {
    final isBuy = _orderType.value.isBuyOrder;
    final color = isBuy ? AppColors.success : _sellRed;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: SizedBox(
        height: 48.h,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : () => _submit(type: _orderType.value),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(
            'PLACE',
            style: AppTextStyles.heading.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.whiteColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // ──── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(onPressed: (){
          Get.back();
        },),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _refresh,
          ),
        ],
        titleSpacing: 0,
        title: Row(
          children: [
            _flagOrFallback(_symbol),
            SizedBox(width: 8.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _removeSuffix(_symbol).toUpperCase(),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _symbolDisplayName(),
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top form section – fixed height, no scroll.
            _buildOrderTypeRow(),
            _divider(),
            _buildVolumeChipRow(),
            _divider(),
            _buildPriceTicker(),
            _divider(),
            if (_isPending) _buildTriggerPriceRow(),
            if (_isPending) _divider(),
            if (_isStopLimit) _buildStopLimitPriceRow(),
            if (_isStopLimit) _divider(),
            _buildSlTpRow(),
            _divider(),
            if (_isMarket) _buildFillPolicyRow(),
            if (_isMarket) _divider(),
            if (_isPending) _buildExpirationRow(),
            if (_isPending) _divider(),
            // Chart fills the remaining space – never scrolls.
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: _buildChartSection(),
              ),
            ),
            if (_isMarket) _buildMarketExecutionBar(),
            if (!_isMarket) _buildDisclaimer(),
            if (!_isMarket) _buildPlaceButton(),
          ],
        ),
      ),
    );
  }

  /// Lightweight inline order-type picker. Uses a PopupMenuButton to keep
  /// the UI clean and on a single screen (no bottom sheet, no scroll).
  Future<void> _showOrderTypeMenu() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromLTRB(40, 200, 40, 0);
    final selected = await showMenu<OrderType>(
      context: context,
      position: position,
      color: AppColors.whiteColor,
      elevation: 4,
      items: [
        for (final t in _orderTypes)
          PopupMenuItem<OrderType>(
            value: t,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 16.w),
              child: Text(
                _orderTypeLabel(t),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
    if (selected != null) _orderType.value = selected;
  }

  /// Thin horizontal hairline divider matching the Meta MT5 reference.
  Widget _divider({double indent = 0}) {
    return Container(
      width: double.infinity,
      height: 1,
      color: AppColors.border.withOpacity(0.5),
      margin: EdgeInsets.symmetric(horizontal: indent),
    );
  }

  void _refresh() {
    _socket.changeSymbol(_symbol);
    CustomToastService.showInfo(
      title: 'Refreshed',
      message: 'Re-subscribing to live prices for $_symbol',
    );
  }
}

// ──── Local widget primitives ──────────────────────────────────────────────

class _VolumeChip extends StatelessWidget {
  const _VolumeChip({
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Centre chip is always bold/black. Side chips are grey and tap to
    // add/subtract their delta to the centre.
    final color = isActive ? AppColors.textPrimary : AppColors.textGrey;
    final weight = isActive ? FontWeight.w700 : FontWeight.w500;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
        child: Text(
          label,
          style: AppTextStyles.heading.copyWith(
            fontSize: 14.sp,
            fontWeight: weight,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _SlTpInner extends StatefulWidget {
  const _SlTpInner({
    required this.controller,
    required this.focusNode,
    required this.pipValue,
    required this.enabled,
    required this.label,
    required this.accent,
    required this.defaultValue,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double pipValue;
  final bool enabled;
  final String label;
  final Color accent;
  final double defaultValue;

  @override
  State<_SlTpInner> createState() => _SlTpInnerState();
}

class _SlTpInnerState extends State<_SlTpInner> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_bump);
    widget.focusNode.addListener(_bump);
  }

  @override
  void didUpdateWidget(covariant _SlTpInner old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) {
      widget.controller.text =
          _format(widget.defaultValue, widget.pipValue);
    }
    if (!widget.enabled && old.enabled) {
      widget.controller.clear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_bump);
    widget.focusNode.removeListener(_bump);
    super.dispose();
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  String _format(double v, double pipValue) {
    final d = pipValue >= 0.01 ? 2 : pipValue >= 0.001 ? 3 : 5;
    return v.toStringAsFixed(d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled
                  ? () {
                      final current =
                          double.tryParse(widget.controller.text) ??
                              widget.defaultValue;
                      widget.controller.text =
                          _format(current - widget.pipValue, widget.pipValue);
                    }
                  : null,
              icon: Icon(Icons.remove, color: widget.accent, size: 18.sp),
            ),
            Text(
              widget.label,
              style: AppTextStyles.heading.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: widget.enabled
                    ? AppColors.textPrimary
                    : AppColors.textGrey,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled
                  ? () {
                      final current =
                          double.tryParse(widget.controller.text) ??
                              widget.defaultValue;
                      widget.controller.text =
                          _format(current + widget.pipValue, widget.pipValue);
                    }
                  : null,
              icon: Icon(Icons.add, color: widget.accent, size: 18.sp),
            ),
          ],
        ),
        if (widget.enabled)
          Padding(
            padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
            child: Container(
              // Coloured bottom border when SL/TP is enabled.
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: widget.accent, width: 1.5),
                ),
              ),
              child: AppTextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                width: 130.w,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,5}$'),
                  ),
                ],
                style: AppTextStyles.heading.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
                hintText: _format(widget.defaultValue, widget.pipValue),
                hintStyle: TextStyle(
                  color: widget.accent.withOpacity(0.5),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
