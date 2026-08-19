import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IbmLinksScreen extends StatefulWidget {
  const IbmLinksScreen({super.key});

  @override
  State<IbmLinksScreen> createState() => _IbmLinksScreenState();
}

class _IbmLinksScreenState extends State<IbmLinksScreen> {
  final IbmController controller = Get.find<IbmController>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: const IbmTopHeader(title: 'Referral Links', showBackButton: false),
      body: Obx(() {
        if (controller.isLoading.value && controller.linksList.isEmpty) {
          return Center(child: CommonLoadingWidget(size: 50.0, color: AppColors.primary));
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.fetchLinks,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Links',
                        style: AppTextStyles.heading.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Share with clients to build your network',
                        style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12.sp),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateLinkDialog,
                    icon: Icon(Icons.add, size: 16.w),
                    label: Text('New Link', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259E),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              if (controller.linksList.isEmpty)
                _buildEmptyState()
              else
                ...controller.linksList.map((link) => _buildLinkCard(link as Map<String, dynamic>)).toList(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link) {
    final label = link['label'] ?? 'General Link';
    final code = link['code'] ?? '';
    final counts = link['counts'] ?? {};
    final signups = counts['signups'] ?? 0;
    final accounts = counts['accounts'] ?? 0;
    final funded = counts['funded'] ?? 0;
    final isActive = link['is_active'] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.heading.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00C48C).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF00C48C) : Colors.grey,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5F259E),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CustomToastService.showSuccess(message: 'Code copied to clipboard');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F259E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 12.w, color: const Color(0xFF5F259E)),
                        SizedBox(width: 4.w),
                        Text('Copy', style: TextStyle(color: const Color(0xFF5F259E), fontSize: 11.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildMetricPill(label: 'Signups', value: '$signups', icon: Icons.person_outline),
              SizedBox(width: 8.w),
              _buildMetricPill(label: 'Accounts', value: '$accounts', icon: Icons.account_balance_outlined),
              SizedBox(width: 8.w),
              _buildMetricPill(label: 'Funded', value: '$funded', icon: Icons.attach_money),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({required String label, required String value, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        children: [
          Icon(Icons.link, size: 56.w, color: AppColors.textGrey.withOpacity(0.4)),
          SizedBox(height: 12.h),
          Text('No Referral Links Yet', style: AppTextStyles.heading.copyWith(fontSize: 16.sp)),
          SizedBox(height: 6.h),
          Text('Create your first link to start inviting clients.', style: TextStyle(color: AppColors.textGrey, fontSize: 13.sp)),
        ],
      ),
    );
  }

  void _showCreateLinkDialog() {
    final labelController = TextEditingController();
    final codeController = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Referral Link', style: AppTextStyles.heading.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Label (e.g. Facebook campaign)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Custom Code (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: () async {
                      if (labelController.text.trim().isEmpty) {
                        CustomToastService.showError(message: 'Please enter a label');
                        return;
                      }
                      Get.back();
                      // create link
                      await controller.createReferralLink(
                        label: labelController.text.trim(),
                        code: codeController.text.trim().isNotEmpty ? codeController.text.trim() : null,
                      );
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
