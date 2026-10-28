import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/price_alerts_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// "My Price Alerts": server-side alerts with edit, pause/resume and delete.
class PriceAlertsScreen extends StatelessWidget {
  const PriceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PriceAlertsController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('price_alerts_title'),
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.alerts.isEmpty) {
            return const Center(child: CommonLoadingWidget(isFullScreen: false));
          }
          if (controller.errorMessage.value.isNotEmpty &&
              controller.alerts.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              message: controller.errorMessage.value,
              onRetry: controller.loadAlerts,
            );
          }
          if (controller.alerts.isEmpty) {
            return _CenteredMessage(
              icon: Icons.notifications_none_rounded,
              message: TranslationUtils.tr('price_alerts_empty'),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadAlerts,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 12.h),
              itemCount: controller.alerts.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final alert = controller.alerts[index];
                return _AlertCard(
                  alert: alert,
                  onEdit: () => _openEditSheet(context, controller, alert),
                  onDelete: () => _confirmDelete(context, controller, alert),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    PriceAlertsController controller,
    ServerPriceAlert alert,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _EditAlertSheet(controller: controller, alert: alert),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PriceAlertsController controller,
    ServerPriceAlert alert,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TranslationUtils.tr('price_alerts_delete')),
        content: Text(TranslationUtils.tr('price_alerts_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(TranslationUtils.tr('navigation_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              TranslationUtils.tr('price_alerts_delete'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAlert(alert);
  }
}

class _AlertCard extends GetView<PriceAlertsController> {
  final ServerPriceAlert alert;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove = alert.condition == 'above';
    final conditionLabel = TranslationUtils.tr(
      isAbove ? 'price_alerts_above' : 'price_alerts_below',
    );
    final statusLabel = alert.isTriggered
        ? TranslationUtils.tr('price_alerts_triggered')
        : TranslationUtils.tr(
            alert.isActive ? 'price_alerts_active' : 'price_alerts_paused',
          );
    final statusColor = alert.isTriggered
        ? AppColors.textSecondary
        : alert.isActive
            ? AppColors.success
            : AppColors.warning;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 10.h, 4.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isAbove ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isAbove ? AppColors.success : AppColors.error,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        alert.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        statusLabel,
                        style: AppTextStyles.bodyText.copyWith(
                          color: statusColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  '$conditionLabel ${alert.targetPrice}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                if (alert.accountNumber.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '#${alert.accountNumber}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Obx(() {
            if (controller.busyIds.contains(alert.id)) {
              return Padding(
                padding: EdgeInsets.all(12.w),
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alert.isTriggered)
                  Switch.adaptive(
                    value: alert.isActive,
                    activeColor: AppColors.primary,
                    onChanged: (value) =>
                        controller.updateAlert(alert, isActive: value),
                  ),
                IconButton(
                  tooltip: TranslationUtils.tr('price_alerts_edit'),
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
                IconButton(
                  tooltip: TranslationUtils.tr('price_alerts_delete'),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20.sp,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _EditAlertSheet extends StatefulWidget {
  final PriceAlertsController controller;
  final ServerPriceAlert alert;

  const _EditAlertSheet({required this.controller, required this.alert});

  @override
  State<_EditAlertSheet> createState() => _EditAlertSheetState();
}

class _EditAlertSheetState extends State<_EditAlertSheet> {
  late final TextEditingController _priceController =
      TextEditingController(text: '${widget.alert.targetPrice}');
  late String _condition = widget.alert.condition;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = TranslationUtils.tr('price_alerts_invalid_price'));
      return;
    }
    setState(() => _error = null);
    final saved = await widget.controller.updateAlert(
      widget.alert,
      targetPrice: price,
      condition: _condition,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            12.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${TranslationUtils.tr('price_alerts_edit')} · ${widget.alert.symbol}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'above',
                label: Text(TranslationUtils.tr('price_alerts_above')),
              ),
              ButtonSegment(
                value: 'below',
                label: Text(TranslationUtils.tr('price_alerts_below')),
              ),
            ],
            selected: {_condition},
            onSelectionChanged: (selection) =>
                setState(() => _condition = selection.first),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: TranslationUtils.tr('price_alerts_target_price'),
              errorText: _error,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Obx(() {
            final isSaving = widget.controller.busyIds.contains(widget.alert.id);
            return SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: isSaving
                    ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                    : Text(
                        TranslationUtils.tr('price_alerts_save'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.whiteColor,
                        ),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40.sp),
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
