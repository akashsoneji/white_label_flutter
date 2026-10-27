import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/trader_transfer_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/currency_format.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import 'package:crm_app/utils/single_decimal_point_formatter.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Send money from the user's wallet to another trader (by registered email).
/// Flow: config → verify recipient → send OTP → submit; history on tab 2.
class TraderTransferScreen extends GetView<TraderTransferController> {
  const TraderTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          backgroundColor: AppColors.background,
          leading: AppBackButton(
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
          title: Text(
            TranslationUtils.tr('trader_transfer_title'),
            style: AppTextStyles.screenTitle,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Obx(() {
            if (controller.isConfigLoading.value) {
              return const Center(
                child: CommonLoadingWidget(isFullScreen: false),
              );
            }
            if (controller.configError.value.isNotEmpty) {
              return _MessageState(
                icon: Icons.error_outline_rounded,
                message: controller.configError.value,
                onRetry: controller.loadConfig,
              );
            }
            if (!controller.isEnabled.value) {
              return _MessageState(
                icon: Icons.block_outlined,
                message: TranslationUtils.tr('trader_transfer_not_available'),
              );
            }
            return Column(
              children: [
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.icongrey,
                  indicatorColor: AppColors.primary,
                  labelStyle: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(text: TranslationUtils.tr('trader_transfer_tab_send')),
                    Tab(
                      text: TranslationUtils.tr('trader_transfer_tab_history'),
                    ),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [_SendTab(), _HistoryTab()],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _SendTab extends GetView<TraderTransferController> {
  const _SendTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 12.h),
      child: _Card(
        child: Obx(() {
          final recipient = controller.recipient.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recipient == null)
                const _RecipientInput()
              else
                _RecipientTile(
                  name: recipient.name,
                  email: recipient.email,
                  onChange: controller.changeRecipient,
                ),
              if (recipient != null) ...[
                SizedBox(height: 12.h),
                AppTextFormField(
                  controller: controller.amountController,
                  label: TranslationUtils.tr('trader_transfer_amount'),
                  hintText: TranslationUtils.tr('trader_transfer_amount_hint'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [SingleDecimalPointFormatter()],
                ),
                SizedBox(height: 10.h),
                AppTextFormField(
                  controller: controller.noteController,
                  label: TranslationUtils.tr('trader_transfer_note'),
                  maxLines: 2,
                ),
                SizedBox(height: 12.h),
                const _OtpSection(),
                SizedBox(height: 8.h),
                Text(
                  TranslationUtils.tr('trader_transfer_approval_note'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.icongrey,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _RecipientInput extends GetView<TraderTransferController> {
  const _RecipientInput();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          controller: controller.emailController,
          label: TranslationUtils.tr('trader_transfer_recipient_email'),
          hintText: TranslationUtils.tr('trader_transfer_recipient_email_hint'),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 10.h),
        Obx(
          () => _PrimaryButton(
            label: TranslationUtils.tr('trader_transfer_verify'),
            isLoading: controller.isVerifying.value,
            onPressed: controller.verifyRecipient,
          ),
        ),
      ],
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onChange;

  const _RecipientTile({
    required this.name,
    required this.email,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: AppColors.success, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationUtils.tr('trader_transfer_recipient'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.icongrey,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  name.isEmpty ? email : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.icongrey,
                      fontSize: 11.sp,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(
              TranslationUtils.tr('trader_transfer_change'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.primary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpSection extends GetView<TraderTransferController> {
  const _OtpSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final seconds = controller.resendSeconds.value;
      final resendLabel = seconds > 0
          ? '${TranslationUtils.tr('trader_transfer_resend_otp')} (${seconds}s)'
          : TranslationUtils.tr('trader_transfer_resend_otp');

      if (!controller.otpSent.value) {
        return _PrimaryButton(
          label: TranslationUtils.tr('trader_transfer_send_otp'),
          isLoading: controller.isSendingOtp.value,
          onPressed: controller.sendOtp,
        );
      }

      final channel = controller.otpChannel.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            channel.isEmpty
                ? TranslationUtils.tr('trader_transfer_otp_sent')
                : '${TranslationUtils.tr('trader_transfer_otp_sent')} ($channel)',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.success,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          AppTextFormField(
            controller: controller.otpController,
            label: TranslationUtils.tr('trader_transfer_otp'),
            hintText: TranslationUtils.tr('trader_transfer_otp_hint'),
            keyboardType: TextInputType.number,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: seconds > 0 || controller.isSendingOtp.value
                  ? null
                  : controller.sendOtp,
              child: Text(
                resendLabel,
                style: AppTextStyles.bodyText.copyWith(
                  color: seconds > 0 ? AppColors.icongrey : AppColors.primary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _PrimaryButton(
            label: TranslationUtils.tr('trader_transfer_submit'),
            isLoading: controller.isSubmitting.value,
            onPressed: () async {
              final tabController = DefaultTabController.of(context);
              final submitted = await controller.submit();
              if (submitted) tabController.animateTo(1);
            },
          ),
        ],
      );
    });
  }
}

class _HistoryTab extends GetView<TraderTransferController> {
  const _HistoryTab();

  static const _directions = ['', 'sent', 'received'];

  String _directionLabel(String value) {
    switch (value) {
      case 'sent':
        return TranslationUtils.tr('trader_transfer_filter_sent');
      case 'received':
        return TranslationUtils.tr('trader_transfer_filter_received');
      default:
        return TranslationUtils.tr('trader_transfer_filter_all');
    }
  }

  Future<void> _pickDates(BuildContext context) async {
    final from = controller.fromDate.value;
    final to = controller.toDate.value;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange:
          from != null && to != null ? DateTimeRange(start: from, end: to) : null,
    );
    if (picked == null) return;
    controller.setDateRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.w, 10.h, 8.w, 4.h),
          child: Obx(() {
            final hasDates = controller.fromDate.value != null;
            return Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6.w,
                    children: _directions
                        .map(
                          (value) => ChoiceChip(
                            label: Text(_directionLabel(value)),
                            selected: controller.direction.value == value,
                            onSelected: (_) => controller.setDirection(value),
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              color: controller.direction.value == value
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ),
                IconButton(
                  tooltip: TranslationUtils.tr('trader_transfer_date_range'),
                  onPressed: () => _pickDates(context),
                  icon: Icon(
                    Icons.date_range_rounded,
                    color: hasDates ? AppColors.primary : AppColors.icongrey,
                    size: 20.sp,
                  ),
                ),
                if (hasDates)
                  IconButton(
                    tooltip: TranslationUtils.tr('trader_transfer_clear_dates'),
                    onPressed: () => controller.setDateRange(null, null),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.icongrey,
                      size: 18.sp,
                    ),
                  ),
              ],
            );
          }),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isHistoryLoading.value && controller.items.isEmpty) {
              return const Center(
                child: CommonLoadingWidget(isFullScreen: false),
              );
            }
            if (controller.historyError.value.isNotEmpty &&
                controller.items.isEmpty) {
              return _MessageState(
                icon: Icons.error_outline_rounded,
                message: controller.historyError.value,
                onRetry: controller.refreshHistory,
              );
            }
            if (controller.items.isEmpty) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: controller.refreshHistory,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    _MessageState(
                      icon: Icons.receipt_long_outlined,
                      message: TranslationUtils.tr('trader_transfer_no_history'),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshHistory,
              child: ListView.builder(
                controller: controller.historyScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsetsDirectional.fromSTEB(16.w, 4.h, 16.w, 12.h),
                itemCount: controller.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == controller.items.length) {
                    return Obx(
                      () => controller.isLoadingMore.value
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: const Center(child: CommonLoadingWidget()),
                            )
                          : const SizedBox.shrink(),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _TransferCard(item: controller.items[index]),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TraderTransferItem item;

  const _TransferCard({required this.item});

  Color _statusColor() {
    switch (item.status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'success':
        return AppColors.success;
      case 'rejected':
      case 'failed':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final amountColor = item.isSent ? AppColors.error : AppColors.success;
    final sign = item.isSent ? '-' : '+';
    final counterparty = item.counterpartyName.isNotEmpty
        ? item.counterpartyName
        : item.counterpartyEmail;
    final directionLabel = TranslationUtils.tr(
      item.isSent ? 'trader_transfer_to' : 'trader_transfer_from',
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isSent
                    ? Icons.north_east_rounded
                    : Icons.south_west_rounded,
                color: amountColor,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '$directionLabel: $counterparty',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$sign${CurrencyFormat.amount(item.amount, null)}',
                style: AppTextStyles.bodyText.copyWith(
                  color: amountColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  [item.reference, _formatDate(item.createdAt)]
                      .where((part) => part.isNotEmpty)
                      .join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.icongrey,
                    fontSize: 11.sp,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  item.status.capitalizeFirst ?? item.status,
                  style: AppTextStyles.bodyText.copyWith(
                    color: statusColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              item.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.sp,
              ),
            ),
          ],
          if (item.adminRemarks.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              '${TranslationUtils.tr('trader_transfer_admin_remarks')}: ${item.adminRemarks}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.icongrey,
                fontSize: 11.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 0),
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 18.w,
                width: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.whiteColor,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.whiteColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _MessageState({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.icongrey, size: 40.sp),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('common_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
