import 'dart:async';

import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import 'vantage_glass_tokens.dart';
import '../../../../widgets/app_switch_tile.dart';

/// Vantage-only compact Pending Order content.
///
/// This is intentionally a presentation fork: business logic and interactions
/// remain identical to the base `PendingOrderContent`.
class VantagePendingOrderContent extends StatefulWidget {
  final ValueNotifier<int> selectedPendingOrderType;
  final ValueNotifier<String> selectedOrderType;
  final ValueNotifier<double> limitPrice;
  final ValueNotifier<double> openPrice;
  final ValueNotifier<double> distance;
  final ValueNotifier<bool> whenPriceIsEnabled;
  final ValueNotifier<bool> takeProfitEnabled;
  final ValueNotifier<bool> stopLossEnabled;
  final ValueNotifier<double> takeProfitPrice;
  final ValueNotifier<double> stopLossPrice;
  final TextEditingController takeProfitController;
  final TextEditingController stopLossController;
  final TextEditingController limitPriceController;
  final VoidCallback onPlaceOrder;
  final String selectedSymbol;
  final bool isLoading;
  final Function(double) onVolumeChanged;

  const VantagePendingOrderContent({
    super.key,
    required this.selectedPendingOrderType,
    required this.selectedOrderType,
    required this.limitPrice,
    required this.openPrice,
    required this.distance,
    required this.whenPriceIsEnabled,
    required this.takeProfitEnabled,
    required this.stopLossEnabled,
    required this.takeProfitPrice,
    required this.stopLossPrice,
    required this.takeProfitController,
    required this.stopLossController,
    required this.limitPriceController,
    required this.onPlaceOrder,
    required this.selectedSymbol,
    required this.onVolumeChanged,
    this.isLoading = false,
  });

  @override
  State<VantagePendingOrderContent> createState() =>
      _VantagePendingOrderContentState();
}

class _VantagePendingOrderContentState extends State<VantagePendingOrderContent>
    with TickerProviderStateMixin {
  late ChartSocketController chartSocketController;
  late AccountController accountController;
  final TradingController tradingController = Get.find<TradingController>();

  double? currentBidPrice;
  double? currentAskPrice;
  double volume = 0.01;
  int currentDigits = 5;

  late TextEditingController volumeController;
  late FocusNode volumeFocusNode;

  bool isManuallyEditingPrice = false;
  bool isManuallyEditingTakeProfit = false;
  bool isManuallyEditingStopLoss = false;

  int _pnlCalculationKey = 0;
  Timer? _pnlUpdateTimer;

  final ValueNotifier<int> _tpPnLUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _slPnLUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _riskExpanded = ValueNotifier<bool>(true);

  Map<String, dynamic>? _lastTPPnL;
  Map<String, dynamic>? _lastSLPnL;

  int _getCurrentDigits() {
    final priceData = chartSocketController.getCurrentPrice();
    if (priceData != null) {
      final digitsVal = priceData['digits'] ?? priceData['Digits'];
      if (digitsVal != null) {
        return int.tryParse(digitsVal.toString()) ?? 5;
      }
    }
    return 5;
  }

  double get _minLot => 0.01;
  double get _maxLot => accountController.activeMT5Account?.maxLotSize ?? 100.0;

  void _adjustPrice(bool isIncrease) {
    tradingController.setCurrentSymbol(widget.selectedSymbol);
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();
    if (currentBidPrice != null && currentAskPrice != null) {
      tradingController.updateMarketPrices(currentBidPrice!, currentAskPrice!);
    }

    OrderType orderType;
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    switch (selectedOrderTypeStr) {
      case 'Buy Limit':
        orderType = OrderType.buyLimit;
        break;
      case 'Sell Limit':
        orderType = OrderType.sellLimit;
        break;
      default:
        orderType = OrderType.buyLimit;
        break;
    }

    AppLogger.trading(
      'Price adjustment: ${isIncrease ? '+' : '-'} pip for ${orderType.displayName}',
    );

    final currentPrice = widget.limitPrice.value.toString();
    final newPrice = tradingController.adjustPriceByPip(
      currentPrice,
      isIncrease,
      orderType,
      decimals: currentDigits,
    );

    final newPriceValue = double.tryParse(newPrice) ?? widget.limitPrice.value;
    widget.limitPrice.value = newPriceValue;
    widget.limitPriceController.text = PrecisionHelper.formatPrice(
      newPriceValue,
      decimals: currentDigits,
    );

    isManuallyEditingPrice = true;
    _recalculateTPSL();
  }

  void _recalculateTPSL() {
    if (widget.limitPrice.value <= 0) return;

    final entryPrice = widget.limitPrice.value;
    final percentageValue = entryPrice * 0.0115;

    OrderType orderType;
    final selectedOrderTypeStr = widget.selectedOrderType.value;
    switch (selectedOrderTypeStr) {
      case 'Buy Limit':
        orderType = OrderType.buyLimit;
        break;
      case 'Sell Limit':
        orderType = OrderType.sellLimit;
        break;
      case 'Buy Stop':
        orderType = OrderType.buyStop;
        break;
      case 'Sell Stop':
        orderType = OrderType.sellStop;
        break;
      default:
        orderType = OrderType.buyLimit;
        break;
    }

    if (widget.takeProfitEnabled.value && !isManuallyEditingTakeProfit) {
      widget.takeProfitPrice.value =
          orderType.isBuyOrder
              ? entryPrice + percentageValue
              : entryPrice - percentageValue;
      widget.takeProfitController.text = PrecisionHelper.formatPrice(
        widget.takeProfitPrice.value,
        decimals: currentDigits,
      );
    }

    if (widget.stopLossEnabled.value && !isManuallyEditingStopLoss) {
      widget.stopLossPrice.value =
          orderType.isBuyOrder
              ? entryPrice - percentageValue
              : entryPrice + percentageValue;
      widget.stopLossController.text = PrecisionHelper.formatPrice(
        widget.stopLossPrice.value,
        decimals: currentDigits,
      );
    }
  }

  void _updatePrices() {
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();
    currentDigits = _getCurrentDigits();

    if (!isManuallyEditingPrice) {
      final orderType = widget.selectedOrderType.value;
      if (orderType == 'Sell Limit') {
        widget.limitPrice.value = currentBidPrice ?? 3673.90;
      } else {
        widget.limitPrice.value = currentAskPrice ?? 3674.16;
      }
      widget.limitPriceController.text = PrecisionHelper.formatPrice(
        widget.limitPrice.value,
        decimals: currentDigits,
      );
    }

    final entryPrice = widget.limitPrice.value;
    final orderType = widget.selectedOrderType.value;
    if (entryPrice <= 0) return;

    final percentageValue = entryPrice * 0.0115;
    if (widget.takeProfitEnabled.value && !isManuallyEditingTakeProfit) {
      widget.takeProfitPrice.value =
          orderType == 'Sell Limit'
              ? entryPrice - percentageValue
              : entryPrice + percentageValue;
      widget.takeProfitController.text = PrecisionHelper.formatPrice(
        widget.takeProfitPrice.value,
        decimals: currentDigits,
      );
    }
    if (widget.stopLossEnabled.value && !isManuallyEditingStopLoss) {
      widget.stopLossPrice.value =
          orderType == 'Sell Limit'
              ? entryPrice + percentageValue
              : entryPrice - percentageValue;
      widget.stopLossController.text = PrecisionHelper.formatPrice(
        widget.stopLossPrice.value,
        decimals: currentDigits,
      );
    }
  }

  Future<Map<String, dynamic>?> _getSymbolDetails(String symbol) async {
    try {
      final activeAccount = accountController.activeMT5Account;
      final accountNumber = activeAccount?.metaAccountNumber ?? '0';
      return await SymbolDetailsCacheService.getSymbolDetails(
        symbol,
        accountNumber,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _calculateTakeProfitPnL() async {
    if (!widget.takeProfitEnabled.value ||
        widget.takeProfitController.text.isEmpty) {
      return null;
    }
    final tpPrice = PrecisionHelper.parseDouble(
      widget.takeProfitController.text,
      decimals: currentDigits,
    );
    if (tpPrice <= 0) return null;

    final entryPrice = widget.limitPrice.value;
    if (entryPrice <= 0) return null;

    final symbolDetails = await _getSymbolDetails(widget.selectedSymbol);
    if (symbolDetails == null) return null;

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) return null;

    final isBuy = widget.selectedOrderType.value == 'Buy Limit';
    final priceDiff = isBuy ? (tpPrice - entryPrice) : (entryPrice - tpPrice);
    final pnl = priceDiff * volume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;
    return {'pnl': pnl, 'digits': digits};
  }

  Future<Map<String, dynamic>?> _calculateStopLossPnL() async {
    if (!widget.stopLossEnabled.value ||
        widget.stopLossController.text.isEmpty) {
      return null;
    }
    final slPrice = PrecisionHelper.parseDouble(
      widget.stopLossController.text,
      decimals: currentDigits,
    );
    if (slPrice <= 0) return null;

    final entryPrice = widget.limitPrice.value;
    if (entryPrice <= 0) return null;

    final symbolDetails = await _getSymbolDetails(widget.selectedSymbol);
    if (symbolDetails == null) return null;

    final contractSize = (symbolDetails['contract_size'] as num?)?.toDouble();
    if (contractSize == null || contractSize <= 0) return null;

    final isBuy = widget.selectedOrderType.value == 'Buy Limit';
    final priceDiff = isBuy ? (entryPrice - slPrice) : (slPrice - entryPrice);
    final pnl = priceDiff * volume * contractSize;
    final digits = (symbolDetails['digits'] as num?)?.toInt() ?? 2;
    return {'pnl': pnl, 'digits': digits};
  }

  bool _isOrderValid() {
    if (widget.limitPrice.value <= 0) return false;
    if (volume <= 0) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    chartSocketController = Get.find<ChartSocketController>();
    accountController = Get.find<AccountController>();

    currentDigits = _getCurrentDigits();
    widget.limitPriceController.text = PrecisionHelper.formatPrice(
      widget.limitPrice.value,
      decimals: currentDigits,
    );

    volumeController = TextEditingController(
      text: PrecisionHelper.formatVolume(volume),
    );
    volumeFocusNode = FocusNode();

    widget.limitPriceController.addListener(() {
      final text = widget.limitPriceController.text;
      if (text.isEmpty) return;
      final newPrice = PrecisionHelper.parseDouble(
        text,
        decimals: currentDigits,
      );
      if (newPrice > 0) {
        if (widget.limitPrice.value != newPrice) {
          widget.limitPrice.value = newPrice;
        }
        _recalculateTPSL();
      }
    });

    _updatePrices();

    chartSocketController.priceStream.listen((_) {
      if (!mounted) return;
      setState(_updatePrices);
    });

    widget.selectedPendingOrderType.addListener(() {
      if (!mounted) return;
      setState(() {
        isManuallyEditingPrice = false;
        isManuallyEditingTakeProfit = false;
        isManuallyEditingStopLoss = false;
        _updatePrices();
      });
    });
  }

  @override
  void dispose() {
    _pnlUpdateTimer?.cancel();
    _tpPnLUpdateNotifier.dispose();
    _slPnLUpdateNotifier.dispose();
    _riskExpanded.dispose();
    volumeController.dispose();
    volumeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 10.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTicketPanel(),
              SizedBox(height: 10.h),
              ValueListenableBuilder<double>(
                valueListenable: widget.limitPrice,
                builder: (context, _, __) {
                  final isValid = _isOrderValid();
                  final isEnabled = isValid && !widget.isLoading;
                  return SizedBox(
                    width: double.infinity,
                    height: 40.h,
                    child: ElevatedButton(
                      onPressed: isEnabled ? widget.onPlaceOrder : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        disabledForegroundColor: AppColors.whiteColor
                            .withValues(alpha: 0.85),
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11.r),
                        ),
                        elevation: 1,
                      ),
                      child:
                          widget.isLoading
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18.w,
                                    height: 18.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.whiteColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Processing...',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.whiteColor,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                isValid
                                    ? 'Place pending order'
                                    : 'Fix validation errors',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketPanel() {
    final divider = Divider(
      height: 14.h,
      color: VantageUiTokens.borderColor,
      thickness: 1,
    );

    return Container(
      decoration: VantageUiTokens.groupDecoration(),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final presetsMaxWidth =
              isNarrow
                  ? (constraints.maxWidth * 0.58).clamp(
                    140.0,
                    constraints.maxWidth,
                  )
                  : (constraints.maxWidth * 0.48).clamp(160.0, 240.0);

          return Column(
            children: [
              // Row 1: Order type (kept clean)
              _buildOrderTypeSegmented(),
              divider,

              // Row 2: Quantity stepper (full width)
              _rowHeader(
                icon: Icons.tune_rounded,
                title: 'Quantity',
                trailing: _quantityPresetsTrailing(maxWidth: presetsMaxWidth),
              ),
              SizedBox(height: 8.h),
              _buildQuantitySection(),
              divider,

              // Row 3: Trigger price toggle + animated field
              _rowHeader(
                icon: Icons.show_chart_rounded,
                title: 'Trigger price',
                trailing: _switchTrailing(widget.whenPriceIsEnabled),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.whenPriceIsEnabled,
                builder: (context, enabled, _) {
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        );
                        return FadeTransition(
                          opacity: fade,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.06),
                              end: Offset.zero,
                            ).animate(fade),
                            child: child,
                          ),
                        );
                      },
                      child:
                          enabled
                              ? Padding(
                                key: const ValueKey('trigger_on'),
                                padding: EdgeInsets.only(top: 8.h),
                                child: _buildOpenPriceInput(),
                              )
                              : Padding(
                                key: const ValueKey('trigger_off_small'),
                                padding: EdgeInsets.only(top: 8.h),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _summaryPill(
                                    label: 'Market execution',
                                    value: 'ON',
                                    tint: AppColors.primary,
                                  ),
                                ),
                              ),
                    ),
                  );
                },
              ),
              divider,

              // Row 4: Risk management collapsible
              _rowHeader(
                icon: Icons.security_rounded,
                title: 'Risk management',
                trailing: ValueListenableBuilder<bool>(
                  valueListenable: _riskExpanded,
                  builder: (context, expanded, _) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(999.r),
                      onTap: () => _riskExpanded.value = !expanded,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 4.h,
                        ),
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: 22.w,
                        ),
                      ),
                    );
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _riskExpanded,
                builder: (context, expanded, _) {
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child:
                        expanded
                            ? Padding(
                              key: const ValueKey('risk_on'),
                              padding: EdgeInsets.only(top: 8.h),
                              child: _buildStopLossTakeProfitWithSwitches(),
                            )
                            : Padding(
                              key: const ValueKey('risk_off'),
                              padding: EdgeInsets.only(top: 8.h),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8.w,
                                  runSpacing: 6.h,
                                  children: [
                                    _summaryPill(
                                      label: 'Take Profit',
                                      value:
                                          widget.takeProfitEnabled.value
                                              ? 'ON'
                                              : 'OFF',
                                      tint: AppColors.success,
                                    ),
                                    _summaryPill(
                                      label: 'Stop Loss',
                                      value:
                                          widget.stopLossEnabled.value
                                              ? 'ON'
                                              : 'OFF',
                                      tint: AppColors.error,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rowHeader({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: VantageUiTokens.borderColor),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16.w),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.label.copyWith(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildOrderTypeSegmented() {
    void setType(String type) {
      widget.selectedOrderType.value = type;
      widget.selectedPendingOrderType.value = type == 'Buy Limit' ? 1 : 0;
      setState(() {
        isManuallyEditingPrice = false;
        isManuallyEditingTakeProfit = false;
        isManuallyEditingStopLoss = false;
        _updatePrices();
      });
    }

    return ValueListenableBuilder<String>(
      valueListenable: widget.selectedOrderType,
      builder: (context, value, _) {
        final isBuy = value == 'Buy Limit';
        final buyColor = AppColors.blue;
        final sellColor = AppColors.error;
        return Container(
          padding: EdgeInsets.all(3.w),
          decoration: VantageUiTokens.pillDecoration(),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999.r),
                  onTap: () => setType('Buy Limit'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color:
                          isBuy
                              ? buyColor.withValues(alpha: 0.16)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(
                        color:
                            isBuy
                                ? buyColor.withValues(alpha: 0.55)
                                : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 14.w,
                            color: isBuy ? buyColor : AppColors.textGrey,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Buy limit',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w800,
                              color: isBuy ? buyColor : AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999.r),
                  onTap: () => setType('Sell Limit'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color:
                          !isBuy
                              ? sellColor.withValues(alpha: 0.10)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(
                        color:
                            !isBuy
                                ? sellColor.withValues(alpha: 0.45)
                                : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_down_rounded,
                            size: 14.w,
                            color: !isBuy ? sellColor : AppColors.textGrey,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Sell limit',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w800,
                              color: !isBuy ? sellColor : AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          child: _stepperTextField(
            controller: volumeController,
            focusNode: volumeFocusNode,
            hintText: 'Enter lots',
            labelText: 'Lots',
            onMinus: () {
              setState(() {
                final next = double.parse((volume - 0.01).toStringAsFixed(2));
                volume = next < _minLot ? _minLot : next;
                volumeController.text = PrecisionHelper.formatVolume(volume);
                widget.onVolumeChanged(volume);
              });
            },
            onPlus: () {
              setState(() {
                final next = double.parse((volume + 0.01).toStringAsFixed(2));
                volume = next > _maxLot ? _maxLot : next;
                volumeController.text = volume.toStringAsFixed(2);
                widget.onVolumeChanged(volume);
              });
            },
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
            onChanged: (value) {
              if (value.isEmpty) return;
              final newVolume = PrecisionHelper.parseDouble(value);
              if (newVolume > 0) {
                setState(() {
                  volume = newVolume;
                  widget.onVolumeChanged(volume);
                });
              }
            },
            onEditingComplete: () {
              final parsed = double.tryParse(volumeController.text);
              final clamped =
                  (parsed == null || parsed <= 0)
                      ? _minLot
                      : parsed.clamp(_minLot, _maxLot);
              setState(() {
                volume = double.parse(clamped.toStringAsFixed(2));
                widget.onVolumeChanged(volume);
              });
              volumeController.text = volume.toStringAsFixed(2);
              volumeFocusNode.unfocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _quantityPresetsTrailing({required double maxWidth}) {
    final presets = <double>[0.01, 0.10, 0.50, 1.00];

    Widget chip(double v) {
      final selected = (volume - v).abs() < 0.000001;
      return InkWell(
        borderRadius: BorderRadius.circular(999.r),
        onTap: () {
          setState(() {
            final clamped = v.clamp(_minLot, _maxLot);
            volume = double.parse(clamped.toStringAsFixed(2));
            volumeController.text = volume.toStringAsFixed(2);
            widget.onVolumeChanged(volume);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : VantageUiTokens.surfaceAlt,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color:
                  selected
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : VantageUiTokens.borderColor,
            ),
          ),
          child: Text(
            v.toStringAsFixed(2),
            style: AppTextStyles.label.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: maxWidth,
      height: 28.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ...presets.map(
              (v) =>
                  Padding(padding: EdgeInsets.only(left: 6.w), child: chip(v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryPill({
    required String label,
    required String value,
    required Color tint,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            value,
            style: AppTextStyles.label.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenPriceInput() {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: _stepperTextField(
        controller: widget.limitPriceController,
        hintText: '',
        labelText: Get.find<LanguageService>().tr('pending_order_price'),
        onMinus: () => _adjustPrice(false),
        onPlus: () => _adjustPrice(true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) {
          isManuallyEditingPrice = true;
          final newPrice = PrecisionHelper.parseDouble(
            value,
            decimals: currentDigits,
          );
          if (newPrice > 0) {
            if (widget.limitPrice.value != newPrice) {
              widget.limitPrice.value = newPrice;
            }
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _roundActionButton({
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: iconSize, color: iconColor),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
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
      builder: (context, value, _) {
        return AppSwitchTile(title: title, value: value, onChanged: onChanged);
      },
    );
  }

  Widget _buildStopLossTakeProfitWithSwitches({Key? key}) {
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: VantageUiTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: VantageUiTokens.borderColor),
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            'Take Profit',
            widget.takeProfitEnabled,
            onChanged: (value) {
              widget.takeProfitEnabled.value = value;
              isManuallyEditingTakeProfit = false;
              if (value) {
                _recalculateTPSL();
              }
              if (!mounted) return;
              setState(() => _pnlCalculationKey++);
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.takeProfitEnabled,
            builder: (context, enabled, _) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child:
                    enabled
                        ? Column(
                          key: const ValueKey('tp_on'),
                          children: [
                            _buildPriceInput(
                              'Take Profit',
                              widget.takeProfitController,
                              widget.takeProfitPrice.value,
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: _tpPnLUpdateNotifier,
                              builder: (context, value, _) {
                                return FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                    'tp_pnl_${_pnlCalculationKey}_$value',
                                  ),
                                  future: _calculateTakeProfitPnL(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return _buildPnLDisplay(
                                        'Potential Profit at TP',
                                        _lastTPPnL,
                                        isProfit: true,
                                      );
                                    }
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
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
                        )
                        : const SizedBox.shrink(key: ValueKey('tp_off')),
              );
            },
          ),
          SizedBox(height: 4.h),
          _buildSwitchTile(
            'Stop Loss',
            widget.stopLossEnabled,
            onChanged: (value) {
              widget.stopLossEnabled.value = value;
              isManuallyEditingStopLoss = false;
              if (value) {
                _recalculateTPSL();
              }
              if (!mounted) return;
              setState(() => _pnlCalculationKey++);
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.stopLossEnabled,
            builder: (context, enabled, _) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child:
                    enabled
                        ? Column(
                          key: const ValueKey('sl_on'),
                          children: [
                            _buildPriceInput(
                              'Stop Loss',
                              widget.stopLossController,
                              widget.stopLossPrice.value,
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: _slPnLUpdateNotifier,
                              builder: (context, value, _) {
                                return FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                    'sl_pnl_${_pnlCalculationKey}_$value',
                                  ),
                                  future: _calculateStopLossPnL(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return _buildPnLDisplay(
                                        'Potential Loss at SL',
                                        _lastSLPnL,
                                        isProfit: false,
                                      );
                                    }
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
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
                        )
                        : const SizedBox.shrink(key: ValueKey('sl_off')),
              );
            },
          ),
        ],
      ),
    );
  }

  double _getPriceIncrement() {
    final decimals = currentDigits;
    if (decimals <= 0) return 1.0;
    if (decimals == 1) return 0.1;
    if (decimals == 2) return 0.01;
    if (decimals == 3) return 0.001;
    if (decimals == 4) return 0.0001;
    if (decimals == 5) return 0.00001;
    if (decimals == 6) return 0.000001;
    if (decimals == 7) return 0.0000001;
    if (decimals == 8) return 0.00000001;
    double val = 1.0;
    for (int i = 0; i < decimals; i++) {
      val /= 10.0;
    }
    return val;
  }

  String _formatPrice(double value) =>
      PrecisionHelper.formatPrice(value, decimals: currentDigits);

  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
    double defaultValue,
  ) {
    return _stepperTextField(
      controller: controller,
      hintText: '',
      labelText: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onMinus: () {
        final currentValue = double.tryParse(controller.text) ?? defaultValue;
        final step = _getPriceIncrement();
        final newValue = (currentValue - step).clamp(0.0, double.infinity);
        setState(() {
          controller.text = _formatPrice(newValue);
          if (label == 'Take Profit') widget.takeProfitPrice.value = newValue;
          if (label == 'Stop Loss') widget.stopLossPrice.value = newValue;
          _pnlCalculationKey++;
        });
      },
      onPlus: () {
        final currentValue = double.tryParse(controller.text) ?? defaultValue;
        final step = _getPriceIncrement();
        final newValue = currentValue + step;
        setState(() {
          controller.text = _formatPrice(newValue);
          if (label == 'Take Profit') widget.takeProfitPrice.value = newValue;
          if (label == 'Stop Loss') widget.stopLossPrice.value = newValue;
          _pnlCalculationKey++;
        });
      },
      onChanged: (value) {
        if (label == 'Take Profit') isManuallyEditingTakeProfit = true;
        if (label == 'Stop Loss') isManuallyEditingStopLoss = true;
        final price = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
        if (price > 0) {
          if (label == 'Take Profit') widget.takeProfitPrice.value = price;
          if (label == 'Stop Loss') widget.stopLossPrice.value = price;
        }

        _pnlUpdateTimer?.cancel();
        _pnlUpdateTimer = Timer(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          if (label == 'Take Profit') _tpPnLUpdateNotifier.value++;
          if (label == 'Stop Loss') _slPnLUpdateNotifier.value++;
        });
      },
      onEditingComplete: () {
        if (!mounted) return;
        setState(() => _pnlCalculationKey++);
        if (label == 'Take Profit') isManuallyEditingTakeProfit = false;
        if (label == 'Stop Loss') isManuallyEditingStopLoss = false;
      },
    );
  }

  Widget _stepperTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String labelText,
    required String hintText,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    TextInputType keyboardType = const TextInputType.numberWithOptions(
      decimal: true,
    ),
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
  }) {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: VantageUiTokens.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: VantageUiTokens.borderColor),
      ),
      child: Row(
        children: [
          _roundActionButton(
            borderColor: AppColors.primary,
            icon: Icons.remove,
            iconColor: AppColors.primary,
            onTap: onMinus,
            size: 32.w,
            iconSize: 16.w,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey,
                    height: 1.1,
                  ),
                ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.05,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: hintText.isEmpty ? null : hintText,
                    hintStyle: AppTextStyles.label.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: onChanged,
                  onEditingComplete: onEditingComplete,
                ),
              ],
            ),
          ),
          _roundActionButton(
            borderColor: AppColors.primary,
            icon: Icons.add,
            iconColor: AppColors.primary,
            onTap: onPlus,
            size: 32.w,
            iconSize: 16.w,
          ),
        ],
      ),
    );
  }

  Widget _buildPnLDisplay(
    String label,
    Map<String, dynamic>? pnlData, {
    required bool isProfit,
  }) {
    if (pnlData == null || pnlData['pnl'] == null) {
      return SizedBox(height: 18.h);
    }
    final pnl = (pnlData['pnl'] as num).toDouble();
    final digits = (pnlData['digits'] as int?) ?? 2;
    final formatted = '\$${PrecisionHelper.formatPnL(pnl, decimals: digits)}';
    final isPositive = pnl >= 0;
    final color =
        isProfit
            ? (isPositive ? AppColors.success : AppColors.error)
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(top: 6.h, left: 8.w, right: 8.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textGrey,
            ),
          ),
          Text(
            formatted,
            style: AppTextStyles.label.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTrailing(ValueNotifier<bool> notifier) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return Transform.scale(
          scale: 0.88,
          child: Switch(
            value: value,
            onChanged: (v) => notifier.value = v,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.whiteColor,
            inactiveTrackColor: AppColors.icongrey.withAlpha(55),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}
