import 'package:crm_app/constants/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Bottom sheet for moving a specific sub-IB onto one of the partner's own
/// commission plans.
///
/// Flow (per IB_MANAGER_PORTAL_API_UI.md §3):
///  - `GET /portal/partner-plans` → the plans the partner built (choices).
///  - `POST /portal/partner-plans/{planId}/assign` `{ ib_user_id }`.
class ChangePlanBottomSheet extends StatefulWidget {
  final int ibUserId;
  final String ibName;
  final int? currentPlanId;
  final VoidCallback onAssigned;

  const ChangePlanBottomSheet({
    super.key,
    required this.ibUserId,
    required this.ibName,
    required this.onAssigned,
    this.currentPlanId,
  });

  @override
  State<ChangePlanBottomSheet> createState() => _ChangePlanBottomSheetState();
}

class _ChangePlanBottomSheetState extends State<ChangePlanBottomSheet> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _plans = [];
  String? _error;
  int? _selectedPlanId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.currentPlanId;
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final res = await IbmApiProvider().getPartnerPlans();
      if (res.success && res.data != null) {
        final data = res.data;
        List rawPlans = [];
        if (data is Map && data['data'] is Map && data['data']['plans'] is List) {
          rawPlans = data['data']['plans'];
        } else if (data is Map && data['plans'] is List) {
          rawPlans = data['plans'];
        } else if (data is List) {
          rawPlans = data;
        }
        _plans = rawPlans.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _error = res.message ?? TranslationUtils.tr('ibm_failed_to_load_plans');
      }
    } catch (e) {
      _error = TranslationUtils.tr('ibm_error_loading_plans');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignPlan() async {
    if (_selectedPlanId == null) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await IbmApiProvider().assignPartnerPlan(
        _selectedPlanId!,
        widget.ibUserId,
      );
      if (res.success) {
        widget.onAssigned();
        if (mounted) Navigator.pop(context);
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('ibm_plan_updated_successfully'),
        );
      } else {
        CustomToastService.showError(
          message:
              res.message ?? TranslationUtils.tr('ibm_failed_to_change_plan'),
        );
      }
    } catch (e) {
      CustomToastService.showError(
        message: TranslationUtils.tr('ibm_error_changing_plan'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _plans
        : _plans
            .where(
              (p) => (p['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
            )
            .toList();

    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.ibName.isNotEmpty
                      ? widget.ibName.substring(0, 1).toUpperCase()
                      : 'C',
                  style: TextStyle(color: AppColors.whiteColor),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.trArgs('ibm_move_ib_to_another_plan', {
                        'name': widget.ibName,
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      TranslationUtils.tr('ibm_applies_to_commission_from_now'),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: TranslationUtils.tr('ibm_search_your_plans'),
              prefixIcon:  Icon(Icons.search,color: AppColors.textPrimary,),
              hintStyle: TextStyle(color: AppColors.textGrey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(child: _buildList(filtered)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    TranslationUtils.tr('account_management_cancel'),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting || _selectedPlanId == null
                      ? null
                      : _assignPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(TranslationUtils.tr('ibm_move_them')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> plans) {
    if (_isLoading) {
      return  Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Colors.red, fontSize: 14.sp),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (plans.isEmpty) {
      return Center(
        child: Text(
          TranslationUtils.tr('ibm_no_plans_found'),
          style: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
        ),
      );
    }
    return ListView.builder(
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final int planId = plan['plan_id'] is int
            ? plan['plan_id']
            : int.tryParse(plan['plan_id'].toString()) ?? 0;
        final String name = plan['name']?.toString() ?? 'Plan';
        final int partners = plan['partners_using'] is int
            ? plan['partners_using']
            : int.tryParse(plan['partners_using']?.toString() ?? '0') ?? 0;
        final bool isCurrent = planId == widget.currentPlanId;
        return RadioListTile<int>(
          value: planId,
          groupValue: _selectedPlanId,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _selectedPlanId = v),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style:  TextStyle(fontWeight: FontWeight.bold,color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent) ...[
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    TranslationUtils.tr('ibm_on_it_now'),
                    style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            TranslationUtils.trArgs('ibm_partners_on_it', {
              'count': '$partners',
            }),
            style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
          ),
        );
      },
    );
  }
}
