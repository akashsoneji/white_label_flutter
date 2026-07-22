import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../constants/color.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import '../../models/order_types.dart';
import '../../utils/precision_helper.dart';
import '../../services/language_service.dart';

class EnhancedPendingOrderContent extends StatefulWidget {
  final String selectedSymbol;
  final Function(double) onVolumeChanged;
  final VoidCallback onPlaceOrder;
  final VoidCallback? onClose;

  const EnhancedPendingOrderContent({
    Key? key,
    required this.selectedSymbol,
    required this.onVolumeChanged,
    required this.onPlaceOrder,
    this.onClose,
  }) : super(key: key);

  @override
  State<EnhancedPendingOrderContent> createState() =>
      _EnhancedPendingOrderContentState();
}

class _EnhancedPendingOrderContentState
    extends State<EnhancedPendingOrderContent> {
  final TradingController tradingController = Get.find<TradingController>();
  late ChartSocketController chartSocketController;
  late AccountController accountController;

  // Text controllers
  final TextEditingController volumeController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stopLossController = TextEditingController();
  final TextEditingController takeProfitController = TextEditingController();

  // State variables
  bool isManuallyEditingPrice = false;
  bool isManuallyEditingStopLoss = false;
  bool isManuallyEditingTakeProfit = false;
  double volume = 0.01;

  // Live price data
  double? currentBidPrice;
  double? currentAskPrice;
  int currentDigits = 5;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeTrading();
    _setupListeners();
  }

  void _initializeControllers() {
    chartSocketController = Get.find<ChartSocketController>();
    accountController = Get.find<AccountController>();
  }

  void _initializeTrading() {
    // Set current symbol and update pip values
    tradingController.setCurrentSymbol(widget.selectedSymbol);

    // Get current market prices
    currentBidPrice = chartSocketController.getBidPrice();
    currentAskPrice = chartSocketController.getAskPrice();

    if (currentBidPrice != null && currentAskPrice != null) {
      tradingController.updateMarketPrices(currentBidPrice!, currentAskPrice!);
    }

    // Set default volume
    volumeController.text = '0.01';

    // Set default price based on order type
    _updatePriceBasedOnOrderType();
  }

  void _setupListeners() {
    // Listen to order type changes
    ever(tradingController.selectedOrderTypeObs, (OrderType orderType) {
      if (mounted) {
        setState(() {
          isManuallyEditingPrice = false;
          isManuallyEditingStopLoss = false;
          isManuallyEditingTakeProfit = false;
          _updatePriceBasedOnOrderType();
        });
      }
    });

    // Listen to price changes for SL/TP updates
    priceController.addListener(_onPriceChanged);

    // Listen to volume changes
    volumeController.addListener(() {
      final newVolume = double.tryParse(volumeController.text) ?? 0.01;
      volume = newVolume;
      widget.onVolumeChanged(volume);
    });
  }

  void _updatePriceBasedOnOrderType() {
    if (!isManuallyEditingPrice) {
      final orderType = tradingController.selectedOrderType;
      if (orderType.requiresPrice) {
        if (orderType.isBuyOrder) {
          priceController.text = PrecisionHelper.formatPrice(
            currentAskPrice ?? 1.0850,
            decimals: tradingController.getDecimalDigits(
              (currentAskPrice ?? 1.0850).toString(),
            ),
          );
        } else {
          priceController.text = PrecisionHelper.formatPrice(
            currentBidPrice ?? 1.0850,
            decimals: tradingController.getDecimalDigits(
              (currentBidPrice ?? 1.0850).toString(),
            ),
          );
        }
      }
    }
    _updateSLTPBasedOnPrice();
  }

  void _onPriceChanged() {
    if (!isManuallyEditingPrice) {
      _updateSLTPBasedOnPrice();
    }
  }

  void _updateSLTPBasedOnPrice() {
    final orderType = tradingController.selectedOrderType;
    final entryPrice =
        priceController.text.isNotEmpty
            ? priceController.text
            : (orderType.isBuyOrder
                ? (currentAskPrice ?? 1.0850).toString()
                : (currentBidPrice ?? 1.0850).toString());

    if (entryPrice.isNotEmpty) {
      final entryPriceValue = double.tryParse(entryPrice) ?? 0.0;
      final percentageValue = entryPriceValue * 0.0115; // 1.15%

      // Update Take Profit
      if (!isManuallyEditingTakeProfit) {
        if (orderType.isBuyOrder) {
          takeProfitController.text = PrecisionHelper.formatPrice(
            entryPriceValue + percentageValue,
            decimals: tradingController.getDecimalDigits(entryPrice),
          );
        } else {
          takeProfitController.text = PrecisionHelper.formatPrice(
            entryPriceValue - percentageValue,
            decimals: tradingController.getDecimalDigits(entryPrice),
          );
        }
      }

      // Update Stop Loss
      if (!isManuallyEditingStopLoss) {
        if (orderType.isBuyOrder) {
          stopLossController.text = PrecisionHelper.formatPrice(
            entryPriceValue - percentageValue,
            decimals: tradingController.getDecimalDigits(entryPrice),
          );
        } else {
          stopLossController.text = PrecisionHelper.formatPrice(
            entryPriceValue + percentageValue,
            decimals: tradingController.getDecimalDigits(entryPrice),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderTypeSelector(),
          SizedBox(height: 20.h),
          _buildPriceSection(),
          SizedBox(height: 20.h),
          _buildVolumeSection(),
          SizedBox(height: 20.h),
          _buildSLTPSection(),
          SizedBox(height: 30.h),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildOrderTypeSelector() {
    return Obx(() {
      final orderType = tradingController.selectedOrderType;
      return GestureDetector(
        onTap: _showOrderTypeDialog,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                orderType.displayName,
                style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPriceSection() {
    return Obx(() {
      final orderType = tradingController.selectedOrderType;
      if (!orderType.requiresPrice) return SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price',
            style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    hintText: 'Enter price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    isManuallyEditingPrice = true;
                    _updateSLTPBasedOnPrice();
                  },
                ),
              ),
              SizedBox(width: 8.w),
              _buildAdjustmentButtons('price'),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildVolumeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volume',
          style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: volumeController,
                decoration: InputDecoration(
                  hintText: '0.01',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            SizedBox(width: 8.w),
            _buildAdjustmentButtons('volume'),
          ],
        ),
      ],
    );
  }

  Widget _buildSLTPSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stop Loss & Take Profit',
          style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stop Loss',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stopLossController,
                          decoration: InputDecoration(
                            hintText: 'SL',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            isManuallyEditingStopLoss = true;
                          },
                        ),
                      ),
                      SizedBox(width: 4.w),
                      _buildAdjustmentButtons('sl'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take Profit',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: takeProfitController,
                          decoration: InputDecoration(
                            hintText: 'TP',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            isManuallyEditingTakeProfit = true;
                          },
                        ),
                      ),
                      SizedBox(width: 4.w),
                      _buildAdjustmentButtons('tp'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdjustmentButtons(String type) {
    return Column(
      children: [
        _buildAdjustmentButton(
          icon: Icons.add,
          onTap: () => _adjustValue(true, type),
        ),
        SizedBox(height: 4.h),
        _buildAdjustmentButton(
          icon: Icons.remove,
          onTap: () => _adjustValue(false, type),
        ),
      ],
    );
  }

  Widget _buildAdjustmentButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Icon(icon, color: AppColors.whiteColor, size: 16.sp),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Obx(() {
      final orderType = tradingController.selectedOrderType;
      return Row(
        children: [
          if (orderType.isBuyOrder || orderType == OrderType.buyMarket)
            Expanded(
              child: ElevatedButton(
                onPressed: _placeBuyOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'BUY',
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (orderType.isBuyOrder || orderType == OrderType.buyMarket)
            SizedBox(width: 12.w),
          if (orderType.isSellOrder || orderType == OrderType.sellMarket)
            Expanded(
              child: ElevatedButton(
                onPressed: _placeSellOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'SELL',
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  void _showOrderTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Order Type',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),
                ...tradingController.getAvailableOrderTypes().map(
                  (orderType) => ListTile(
                    title: Text(
                      orderType.displayName,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      tradingController.setOrderType(orderType);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _adjustValue(bool isIncrease, String type) {
    switch (type) {
      case 'price':
        _adjustPrice(isIncrease);
        break;
      case 'volume':
        _adjustVolume(isIncrease);
        break;
      case 'sl':
        _adjustSLTP(isIncrease, 'sl');
        break;
      case 'tp':
        _adjustSLTP(isIncrease, 'tp');
        break;
    }
  }

  void _adjustPrice(bool isIncrease) {
    final orderType = tradingController.selectedOrderType;
    final newPrice = tradingController.adjustPriceByPip(
      priceController.text,
      isIncrease,
      orderType,
      decimals: currentDigits,
    );
    priceController.text = newPrice;
    isManuallyEditingPrice = true;
    _updateSLTPBasedOnPrice();
  }

  void _adjustVolume(bool isIncrease) {
    final currentVolume = double.tryParse(volumeController.text) ?? 0.01;
    final adjustment = isIncrease ? 0.01 : -0.01;
    final newVolume = (currentVolume + adjustment).clamp(0.01, 100.0);
    volumeController.text = PrecisionHelper.formatVolume(newVolume);
  }

  void _adjustSLTP(bool isIncrease, String type) {
    final orderType = tradingController.selectedOrderType;
    final entryPrice =
        priceController.text.isNotEmpty
            ? priceController.text
            : (orderType.isBuyOrder
                ? (currentAskPrice ?? 1.0850).toString()
                : (currentBidPrice ?? 1.0850).toString());

    String newValue;
    if (type == 'sl') {
      newValue = tradingController.adjustSLTPByPip(
        stopLossController.text,
        isIncrease,
        orderType,
        entryPrice,
        decimals: currentDigits,
      );
      stopLossController.text = newValue;
      isManuallyEditingStopLoss = true;
    } else {
      newValue = tradingController.adjustSLTPByPip(
        takeProfitController.text,
        isIncrease,
        orderType,
        entryPrice,
        decimals: currentDigits,
      );
      takeProfitController.text = newValue;
      isManuallyEditingTakeProfit = true;
    }
  }

  void _placeBuyOrder() async {
    final orderType = tradingController.selectedOrderType;
    final success = await tradingController.placeTradeOrder(
      symbol: widget.selectedSymbol,
      volume: volumeController.text,
      orderType: orderType,
      price: orderType.requiresPrice ? priceController.text : null,
      takeProfit:
          takeProfitController.text.isNotEmpty
              ? takeProfitController.text
              : null,
      stopLoss:
          stopLossController.text.isNotEmpty ? stopLossController.text : null,
    );

    if (success) {
      _showSuccessDialog('BUY');
    }
  }

  void _placeSellOrder() async {
    final orderType = tradingController.selectedOrderType;
    final success = await tradingController.placeTradeOrder(
      symbol: widget.selectedSymbol,
      volume: volumeController.text,
      orderType: orderType,
      price: orderType.requiresPrice ? priceController.text : null,
      takeProfit:
          takeProfitController.text.isNotEmpty
              ? takeProfitController.text
              : null,
      stopLoss:
          stopLossController.text.isNotEmpty ? stopLossController.text : null,
    );

    if (success) {
      _showSuccessDialog('SELL');
    }
  }

  void _showSuccessDialog(String action) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              Get.find<LanguageService>().tr('pending_order_order_placed'),
            ),
            content: Text('$action order has been placed successfully'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onPlaceOrder();
                  if (widget.onClose != null) {
                    widget.onClose!();
                  }
                },
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    volumeController.dispose();
    priceController.dispose();
    stopLossController.dispose();
    takeProfitController.dispose();
    super.dispose();
  }
}
