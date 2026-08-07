import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/navigation_helper.dart';

class IQuoteOrderDetailsScreen extends StatelessWidget {
  final IQuoteOrderData? data;

  const IQuoteOrderDetailsScreen({super.key, this.data});

  IQuoteOrderData get _d =>
      data ??
      const IQuoteOrderData(
        orderNo: 'CP68527316834593',
        symbol: 'XAU/USD',
        buySell: 'Sell',
        lots: '0.01',
        contractSize: '1XAU',
        leverage: '800X',
        profit: '0.9400',
        openTime: '11:33:13 21/07/2026',
        openPrice: '4065.77',
        closeTime: '11:37:02 21/07/2026',
        closePrice: '4064.83',
        closingMethod: 'Closed by Trader',
        swap: '0.0000',
      );

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final t = languageService.tr;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20.sp),
          onPressed: () => NavigationHelper.safeBack(),
        ),
        title: Text(
          t('order_details_title'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.shortcut, color: const Color(0xFFE88A4A), size: 22.sp),
        //     onPressed: () {},
        //   ),
        // ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            children: [
              _summaryCard(context, t),
              SizedBox(height: 12.h),
              _cardContainer([
                _row(t('order_no'), _d.orderNo, trailing: _copyButton(_d.orderNo)),
                _row(t('closing_method'), _d.closingMethod, valueColor: const Color(0xFFE88A4A)),
                _row(t('open_time'), _d.openTime),
                _row(t('open_price'), _d.openPrice),
                _row(t('close_time'), _d.closeTime),
                _row(t('close_price'), _d.closePrice),
                _row(t('take_profit'), '---'),
                _row(t('stop_loss'), '---', showDivider: false),
              ]),
              SizedBox(height: 12.h),
              _cardContainer([
                _row(t('fee'), ''),
                _row(t('swap'), _d.swap, showDivider: false),
              ]),
              SizedBox(height: 12.h),
              _cardContainer([
                _row(t('order_type'), '---'),
                _row(t('dividend_amount'), '---'),
                _row(t('dividend_target'), '---', showDivider: false),
              ]),
              SizedBox(height: 12.h),
              _cardContainer([
                // _actionRow(
                //   iconAsset: 'assets/svg/emailLogo.svg',
                //   iconData: Icons.telegram,
                //   iconColor: const Color(0xFF2EA6DA),
                //   title: t('telegram'),
                //   onTap: () {},
                // ),
                _actionRow(
                  iconAsset: 'assets/svg/edit_profile.svg',
                  iconData: Icons.assignment_outlined,
                  iconColor: const Color(0xFFE1B68C),
                  title: t('feedback'),
                  onTap: () => Get.toNamed(Routes.TICKET_LIST),
                  showDivider: false,
                ),
              ]),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _summaryCard(BuildContext context, String Function(String) t) {
    final isProfit = _d.profit.isNotEmpty && _d.profit[0] != '-';
    final isBuy = _d.buySell.toLowerCase() == 'buy';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _d.symbol,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill(
                _d.buySell,
                bg: isBuy ? AppColors.statusGreen.withOpacity(0.15) : AppColors.statusRed.withOpacity(0.15),
                fg: isBuy ? AppColors.statusGreen : AppColors.statusRed,
              ),
              SizedBox(width: 8.w),
              Text(
                '${_d.lots}Lot  ${_d.contractSize}  ${_d.leverage}',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            _d.profit,
            style: AppTextStyles.bodyText.copyWith(
              color: isProfit ? AppColors.statusGreen : AppColors.statusRed,
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(
          color: fg,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, Widget? trailing, bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              if (trailing != null) 
                trailing
              else
                Text(
                  value.isEmpty ? '---' : value,
                  style: AppTextStyles.bodyText.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 0.5,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            color: AppColors.border.withOpacity(0.3),
          ),
      ],
    );
  }

  Widget _copyButton(String text) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        Get.snackbar(
          '',
          '',
          titleText: const SizedBox.shrink(),
          messageText: Text(
            'Copied',
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 12.sp),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.copy_rounded, size: 14.sp, color: const Color(0xFFE88A4A)),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String iconAsset,
    required IconData iconData,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Icon(iconData, color: iconColor, size: 22.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textGrey, size: 20.sp),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 0.5,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            color: AppColors.border.withOpacity(0.3),
          ),
      ],
    );
  }
}

class IQuoteOrderData {
  final String orderNo;
  final String symbol;
  final String buySell;
  final String lots;
  final String contractSize;
  final String leverage;
  final String profit;
  final String openTime;
  final String openPrice;
  final String closeTime;
  final String closePrice;
  final String closingMethod;
  final String swap;

  const IQuoteOrderData({
    required this.orderNo,
    required this.symbol,
    required this.buySell,
    required this.lots,
    required this.contractSize,
    required this.leverage,
    required this.profit,
    required this.openTime,
    required this.openPrice,
    required this.closeTime,
    required this.closePrice,
    required this.closingMethod,
    required this.swap,
  });
}
