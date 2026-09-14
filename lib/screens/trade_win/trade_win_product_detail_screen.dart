import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_product_image.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class TradeWinProductDetailScreen extends StatefulWidget {
  const TradeWinProductDetailScreen({super.key});

  @override
  State<TradeWinProductDetailScreen> createState() =>
      _TradeWinProductDetailScreenState();
}

class _TradeWinProductDetailScreenState
    extends State<TradeWinProductDetailScreen> {
  int _quantity = 1;
  TradeWinProductModel? _product;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    final productId = args?['productId'] as int?;
    final ctrl = Get.find<TradeWinController>();
    if (productId != null) {
      _product = ctrl.productById(productId);
    }
    _product ??= args?['product'] as TradeWinProductModel?;

    // Always use latest parsed product from controller (avoids stale/hot-reload instances).
    final id = _product?.id;
    if (id != null) {
      final fresh = ctrl.productById(id);
      if (fresh != null) _product = fresh;
    }
  }

  int get _maxQty {
    final product = _product;
    if (product == null || product.stock <= 0) return 1;
    return product.stock;
  }

  bool get _canRedeem => _product?.canRedeemQuantity(_quantity) ?? false;

  String _redeemButtonLabel(LanguageService languageService) {
    final product = _product!;
    if (product.stock <= 0) {
      return languageService.tr('tw_out_of_stock');
    }
    if (_canRedeem) {
      return languageService.tr('tw_redeem_now');
    }
    final pointsShort = product.pointsShortfallFor(_quantity);
    if (pointsShort > 0) {
      return languageService.tr('tw_more_points_needed', {
        'count': '$pointsShort',
      });
    }
    final lotsShort = product.lotsShortfallFor(_quantity);
    if (lotsShort > 0) {
      final lotsText = TradeWinFormat.lots(lotsShort);
      return languageService.tr('tw_more_lots_needed', {'count': lotsText});
    }
    return languageService.tr('tw_insufficient_eligibility');
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final product = _product;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
        ),
        body: Center(child: Text(languageService.tr('tw_product_not_found'))),
      );
    }

    final progress = product.progressFraction;
    final percent = (progress * 100).round();
    final maxQty = _maxQty;

    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeWinScaffoldBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          languageService.tr('tw_product_detail'),
          style: AppTextStyles.heading,
        ),
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 0, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TradeWinProductImage(
              imagePath: product.imagePath,
              width: double.infinity,
              height: 250.h,
              borderRadius: BorderRadius.circular(12.r),
            ),
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.headingblack.copyWith(
                          fontSize: 17.sp,
                        ),
                      ),
                      if (product.description.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          product.description,
                          style: AppTextStyles.subheading.copyWith(
                            fontSize: 12.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    TradeWinFormat.categoryTag(product.category),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  _EligibilityRow(
                    label: languageService.tr('tw_allowed_groups'),
                    value: product.displayAllowedGroups,
                  ),
                  _eligibilityDivider(),
                  _EligibilityRow(
                    label: languageService.tr('tw_allowed_symbols'),
                    value: product.displayAllowedSymbols,
                  ),
                  _eligibilityDivider(),
                  _EligibilityRow(
                    label: languageService.tr('tw_your_available_lots'),
                    value: TradeWinFormat.lots(product.availableLots),
                    valueColor: AppColors.green,
                  ),
                  _eligibilityDivider(),
                  _EligibilityRow(
                    label: languageService.tr('tw_your_available_points'),
                    value: TradeWinFormat.points(product.calculatedPoints),
                    valueColor: AppColors.green,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: _MetaLine(
                    label: languageService.tr('tw_value_label'),
                    value: TradeWinFormat.currency(product.prizeValue),
                  ),
                ),
                Expanded(
                  child: _MetaLine(
                    label: languageService.tr('tw_stock_label'),
                    value: languageService.tr('tw_stock_count', {
                      'count': '${product.stock}',
                    }),
                    valueColor: AppColors.quickActionOrange,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            _MetaLine(
              label: languageService.tr('tw_claimed_label'),
              value: languageService.tr('tw_claimed_times', {
                'count': '${product.claimsCount}',
              }),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageService.tr('tw_quantity'),
                  style: AppTextStyles.headingblack.copyWith(fontSize: 14.sp),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        enabled: _quantity > 1,
                        onTap: () => setState(() => _quantity--),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          '$_quantity',
                          style: AppTextStyles.headingblack.copyWith(
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        enabled: _quantity < maxQty,
                        onTap: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6.h,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              languageService.tr('tw_progress_lots', {
                'current': TradeWinFormat.lots(product.availableLots),
                'required': TradeWinFormat.lots(product.requiredLots),
                'percent': '$percent',
              }),
              style: AppTextStyles.subheading.copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canRedeem ? () => _redeem(product, languageService) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canRedeem
                          ? AppColors.primary
                          : AppColors.icongrey.withValues(alpha: 0.35),
                  foregroundColor:
                      _canRedeem
                          ? (ThemeData.estimateBrightnessForColor(AppColors.primary) == Brightness.light
                              ? Colors.black
                              : Colors.white)
                          : AppColors.textGrey,
                  disabledBackgroundColor: AppColors.icongrey.withValues(
                    alpha: 0.35,
                  ),
                  disabledForegroundColor: AppColors.textGrey,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  _redeemButtonLabel(languageService),
                  style: AppTextStyles.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eligibilityDivider() =>
      Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.12));

  void _redeem(TradeWinProductModel product, LanguageService languageService) {
    if (!product.canRedeemQuantity(_quantity)) {
      CustomToastService.showWarning(
        message: _redeemButtonLabel(languageService),
      );
      return;
    }
    Get.toNamed(
      AppPages.TRADE_WIN_REDEEM,
      arguments: {'product': product, 'quantity': _quantity},
    );
  }
}

class _EligibilityRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _EligibilityRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 12.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.headingblack.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  const _MetaLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      text: TextSpan(
        style: AppTextStyles.subheading.copyWith(
          fontSize: 12.sp,
          color: AppColors.textSecondary,
        ),
        children: [
          TextSpan(text: label),
          TextSpan(
            text: ' $value',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36.w,
          height: 36.h,
          child: Icon(
            icon,
            size: 18.sp,
            color: enabled ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}
