import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_subscribe_controller.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class EditSubscriptionSheet extends StatefulWidget {
  final int subscriptionId;
  final String masterCode;
  final int planId;
  final String masterName;

  const EditSubscriptionSheet({
    super.key,
    required this.subscriptionId,
    required this.masterCode,
    required this.planId,
    required this.masterName,
  });

  @override
  State<EditSubscriptionSheet> createState() => _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends State<EditSubscriptionSheet> {
  late final CopyTradingSubscribeController _subController;
  bool _isLoadingDetail = true;
  String _detailError = '';

  final _fixedLotCtrl = TextEditingController();
  final _multiplierCtrl = TextEditingController();
  final _mirrorRatioCtrl = TextEditingController();
  final _riskPercentCtrl = TextEditingController();
  final _dynamicDdCtrl = TextEditingController();
  final _dynamicReduceCtrl = TextEditingController();
  final _fixedRatioProfitStepCtrl = TextEditingController();
  final _fixedRatioLotStepCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Instantiate subscription controller without auto selecting accounts
    _subController = Get.put(
      CopyTradingSubscribeController(
        masterCode: widget.masterCode,
        planId: widget.planId,
        autoSelectFirstAccount: false,
      ),
      tag: 'edit_sub_${widget.subscriptionId}',
    );
    _loadSubscriptionDetail();
  }

  @override
  void dispose() {
    _fixedLotCtrl.dispose();
    _multiplierCtrl.dispose();
    _mirrorRatioCtrl.dispose();
    _riskPercentCtrl.dispose();
    _dynamicDdCtrl.dispose();
    _dynamicReduceCtrl.dispose();
    _fixedRatioProfitStepCtrl.dispose();
    _fixedRatioLotStepCtrl.dispose();
    _tpCtrl.dispose();
    _slCtrl.dispose();
    Get.delete<CopyTradingSubscribeController>(
      tag: 'edit_sub_${widget.subscriptionId}',
      force: true,
    );
    super.dispose();
  }

  Future<void> _loadSubscriptionDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = '';
    });

    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionDetail(widget.subscriptionId),
      );

      if (!res.success || res.data == null) {
        setState(() {
          _detailError = res.message ?? 'Failed to load copy details';
          _isLoadingDetail = false;
        });
        return;
      }

      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _subController.applySubscriptionDetail(data);

        // Populate text fields
        _fixedLotCtrl.text = _subController.fixedLotSize.value.toString();
        _multiplierCtrl.text = _subController.lotMultiplier.value.toString();
        _mirrorRatioCtrl.text = _subController.mirrorRatio.value.toString();
        _riskPercentCtrl.text = _subController.percentageRisk.value.toString();
        _dynamicDdCtrl.text = _subController.dynamicDrawdownThreshold.value.toString();
        _dynamicReduceCtrl.text = _subController.dynamicReductionRatio.value.toString();
        _fixedRatioProfitStepCtrl.text = _subController.fixedRatioProfitStep.value.toString();
        _fixedRatioLotStepCtrl.text = _subController.fixedRatioLotStep.value.toString();

        if (_subController.slTpMode.value == 'pip') {
          _tpCtrl.text = _subController.takeProfitPips.value.toString();
          _slCtrl.text = _subController.stopLossPips.value.toString();
        } else {
          _tpCtrl.text = _subController.takeProfitDollar.value.toString();
          _slCtrl.text = _subController.stopLossDollar.value.toString();
        }
      }
      setState(() {
        _isLoadingDetail = false;
      });
    } catch (e) {
      setState(() {
        _detailError = 'Error: $e';
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _onSave() async {
    // Validate inputs based on selected sizing method
    final method = _subController.sizingMethod.value;
    switch (method) {
      case 'fixed':
        final fixed = double.tryParse(_fixedLotCtrl.text) ?? 0;
        if (fixed <= 0) {
          CustomToastService.showError(title: 'Validation', message: 'Enter a valid fixed lot size');
          return;
        }
        _subController.fixedLotSize.value = fixed;
        break;
      case 'mirror_ratio':
        final r = double.tryParse(_mirrorRatioCtrl.text) ?? 0;
        if (r <= 0) {
          CustomToastService.showError(title: 'Validation', message: 'Enter a valid ratio');
          return;
        }
        _subController.mirrorRatio.value = r;
        break;
      case 'percentage_risk':
        final risk = double.tryParse(_riskPercentCtrl.text) ?? 0;
        if (risk <= 0) {
          CustomToastService.showError(title: 'Validation', message: 'Enter a valid risk percentage');
          return;
        }
        _subController.percentageRisk.value = risk;
        break;
      case 'dynamic_lot':
        final dd = double.tryParse(_dynamicDdCtrl.text) ?? 0;
        final red = double.tryParse(_dynamicReduceCtrl.text) ?? 0;
        if (dd <= 0 || red <= 0) {
          CustomToastService.showError(title: 'Validation', message: 'Enter valid dynamic rules');
          return;
        }
        _subController.dynamicDrawdownThreshold.value = dd;
        _subController.dynamicReductionRatio.value = red;
        break;
      case 'fixed_ratio':
        final step = double.tryParse(_fixedRatioProfitStepCtrl.text) ?? 0;
        final lot = double.tryParse(_fixedRatioLotStepCtrl.text) ?? 0;
        if (step <= 0 || lot <= 0) {
          CustomToastService.showError(title: 'Validation', message: 'Enter valid fixed ratio parameters');
          return;
        }
        _subController.fixedRatioProfitStep.value = step;
        _subController.fixedRatioLotStep.value = lot;
        break;
      default:
        break;
    }

    if (_subController.copyingMethod.value == 'proportional') {
      final mult = double.tryParse(_multiplierCtrl.text) ?? 0;
      if (mult <= 0) {
        CustomToastService.showError(title: 'Validation', message: 'Enter a valid multiplier');
        return;
      }
      _subController.lotMultiplier.value = mult;
    }

    if (_subController.overridesSlTp.value) {
      final tp = double.tryParse(_tpCtrl.text) ?? 0;
      final sl = double.tryParse(_slCtrl.text) ?? 0;
      if (tp <= 0 || sl <= 0) {
        CustomToastService.showError(title: 'Validation', message: 'Enter valid TP and SL values');
        return;
      }
      if (_subController.slTpMode.value == 'pip') {
        _subController.takeProfitPips.value = tp;
        _subController.stopLossPips.value = sl;
      } else {
        _subController.takeProfitDollar.value = tp;
        _subController.stopLossDollar.value = sl;
      }
    }

    final res = await _subController.updateSubscription(subscriptionId: widget.subscriptionId);
    if (res.success) {
      CustomToastService.showSuccess(title: 'Success', message: res.message ?? 'Copy settings updated');
      Get.back(result: true);
    } else {
      CustomToastService.showError(title: 'Failed', message: res.message ?? 'Update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header handle
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 10.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Copy Settings',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
          const Divider(),

          if (_isLoadingDetail)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_detailError.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                children: [
                  Text(_detailError, style: TextStyle(color: AppColors.error)),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: _loadSubscriptionDetail,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Obx(() {
                  final method = _subController.sizingMethod.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Copying master: ${widget.masterName}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Sizing Method Dropdown
                      Text(
                        'Sizing Method',
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        value: method,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed Lot Size')),
                          DropdownMenuItem(value: 'proportional_equity', child: Text('Equity Proportional')),
                          DropdownMenuItem(value: 'proportional_balance', child: Text('Balance Proportional')),
                          DropdownMenuItem(value: 'multiplier_only', child: Text('Lot Multiplier')),
                          DropdownMenuItem(value: 'mirror_ratio', child: Text('Mirror Ratio')),
                          DropdownMenuItem(value: 'percentage_risk', child: Text('Percentage Risk')),
                          DropdownMenuItem(value: 'reverse', child: Text('Reverse Copying')),
                          DropdownMenuItem(value: 'dynamic_lot', child: Text('Dynamic Drawdown Lot')),
                          DropdownMenuItem(value: 'fixed_ratio', child: Text('Fixed Profit Ratio')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            _subController.sizingMethod.value = v;
                            _subController.copyingMethod.value = v == 'fixed' ? 'fixed' : 'proportional';
                          }
                        },
                      ),
                      SizedBox(height: 12.h),

                      // Method-specific input fields
                      if (method == 'fixed')
                        LabeledAppTextField(
                          label: 'Fixed Lot Size *',
                          controller: _fixedLotCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 0.01',
                        )
                      else if (method == 'mirror_ratio')
                        LabeledAppTextField(
                          label: 'Mirror Ratio *',
                          controller: _mirrorRatioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 0.5',
                        )
                      else if (method == 'percentage_risk')
                        LabeledAppTextField(
                          label: 'Risk % per trade *',
                          controller: _riskPercentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 2.0',
                        )
                      else if (method == 'dynamic_lot') ...[
                        LabeledAppTextField(
                          label: 'Drawdown threshold (%) *',
                          controller: _dynamicDdCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 20',
                        ),
                        SizedBox(height: 12.h),
                        LabeledAppTextField(
                          label: 'Reduction ratio (0–1) *',
                          controller: _dynamicReduceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 0.5',
                        ),
                      ] else if (method == 'fixed_ratio') ...[
                        LabeledAppTextField(
                          label: 'Profit milestone (USD) *',
                          controller: _fixedRatioProfitStepCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 1000.00',
                        ),
                        SizedBox(height: 12.h),
                        LabeledAppTextField(
                          label: 'Lot increase per milestone *',
                          controller: _fixedRatioLotStepCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 0.01',
                        ),
                      ],

                      // Proportional lot multiplier
                      if (_subController.copyingMethod.value == 'proportional') ...[
                        SizedBox(height: 12.h),
                        LabeledAppTextField(
                          label: 'Lot Multiplier *',
                          controller: _multiplierCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          hintText: 'e.g. 1.0',
                        ),
                      ],
                      SizedBox(height: 16.h),

                      // Overrides SL/TP Switch
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: AppColors.tradeBackgroundCenterColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.textGrey.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Override Master SL/TP',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Switch(
                                  value: _subController.overridesSlTp.value,
                                  onChanged: (v) {
                                    _subController.overridesSlTp.value = v;
                                  },
                                  activeColor: AppColors.primary,
                                ),
                              ],
                            ),
                            if (_subController.overridesSlTp.value) ...[
                              SizedBox(height: 10.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildModeButton(
                                      label: 'Pip Mode',
                                      selected: _subController.slTpMode.value == 'pip',
                                      onTap: () {
                                        _subController.slTpMode.value = 'pip';
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: _buildModeButton(
                                      label: 'Dollar Mode',
                                      selected: _subController.slTpMode.value == 'dollar',
                                      onTap: () {
                                        _subController.slTpMode.value = 'dollar';
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: LabeledAppTextField(
                                      label: 'Take Profit',
                                      controller: _tpCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      hintText: '0.0',
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: LabeledAppTextField(
                                      label: 'Stop Loss',
                                      controller: _slCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      hintText: '0.0',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Actions buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onColoredBackground,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.textGrey.withOpacity(0.2),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}
