import 'package:crm_app/constants/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class AssignPlanBottomSheet extends StatefulWidget {
  final int planId;
  final String planName;
  final VoidCallback onAssigned;

  const AssignPlanBottomSheet({
    super.key,
    required this.planId,
    required this.planName,
    required this.onAssigned,
  });

  @override
  State<AssignPlanBottomSheet> createState() => _AssignPlanBottomSheetState();
}

class _AssignPlanBottomSheetState extends State<AssignPlanBottomSheet> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _subIbs = [];
  String? _error;
  int? _selectedSubIbId;

  @override
  void initState() {
    super.initState();
    _fetchSubIbs();
  }

  Future<void> _fetchSubIbs() async {
    try {
      final res = await IbmApiProvider().getAssignableSubIbs();
      if (res.success && res.data != null) {
        final data = res.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          _subIbs = data['data'];
        } else if (data is List) {
          _subIbs = data;
        } else if (data is Map<String, dynamic> && data['sub_ibs'] is List) {
          _subIbs = data['sub_ibs'];
        }
      } else {
        _error =
            res.message ?? TranslationUtils.tr('ibm_failed_to_load_sub_ibs');
      }
    } catch (e) {
      _error = TranslationUtils.tr('ibm_error_loading_sub_ibs');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignPlan() async {
    if (_selectedSubIbId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await IbmApiProvider().assignPartnerPlan(
        widget.planId,
        _selectedSubIbId!,
      );
      if (res.success) {
        CustomToastService.show(
          message: TranslationUtils.tr('ibm_plan_assigned_successfully'),
        );
        widget.onAssigned();
        if (mounted) Navigator.pop(context);
      } else {
        CustomToastService.show(
          message:
              res.message ?? TranslationUtils.tr('ibm_failed_to_assign_plan'),
        );
      }
    } catch (e) {
      CustomToastService.show(
        message: TranslationUtils.tr('ibm_error_assigning_plan'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TranslationUtils.trArgs('ibm_assign_plan_named', {
              'plan': widget.planName,
            }),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.purple))
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Colors.red, fontSize: 14.sp),
              textAlign: TextAlign.center,
            )
          else if (_subIbs.isEmpty)
            Text(
              TranslationUtils.tr('ibm_no_assignable_sub_ibs_found'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
              textAlign: TextAlign.center,
            )
          else ...[
            Text(
              TranslationUtils.tr('ibm_select_a_sub_ib'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
              ),
              value: _selectedSubIbId,
              hint: Text(TranslationUtils.tr('ibm_choose_a_sub_ib')),
              items:
                  _subIbs.map<DropdownMenuItem<int>>((sub) {
                    final int id =
                        sub['partner_user_id'] ??
                        sub['id'] ??
                        sub['user_id'] ??
                        0;
                    final String name =
                        sub['name'] ?? sub['email'] ?? 'Unknown';
                    return DropdownMenuItem<int>(value: id, child: Text(name));
                  }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSubIbId = val;
                });
              },
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed:
                  _isSubmitting || _selectedSubIbId == null
                      ? null
                      : _assignPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child:
                  _isSubmitting
                      ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        TranslationUtils.tr('ib_requests_screen_assign_plan'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
