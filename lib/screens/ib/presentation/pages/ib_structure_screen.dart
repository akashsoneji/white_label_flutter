import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:intl/intl.dart';
import 'commission_group_form_screen.dart';

class IBStructureScreen extends StatefulWidget {
  final bool isEmbedded;
  const IBStructureScreen({super.key, this.isEmbedded = false});

  @override
  State<IBStructureScreen> createState() => _IBStructureScreenState();
}

class _IBStructureScreenState extends State<IBStructureScreen> {
  late IBController ibController;

  @override
  void initState() {
    super.initState();
    // Get or create IBController
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await ibController.getCommissionGroups();
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  void _navigateToAddGroup() async {
    await Get.to(() => CommissionGroupFormScreen());
    // Refresh data after returning from form screen
    await _loadData();
  }

  void _navigateToEditGroup(CommissionGroup group) async {
    await Get.to(() => CommissionGroupFormScreen(group: group));
    // Refresh data after returning from form screen
    await _loadData();
  }

  Future<void> _deleteGroup(CommissionGroup group) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          TranslationUtils.tr('commission_groups_screen_delete_group'),
          style: AppTextStyles.bodyText.copyWith(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        content: Text(
          TranslationUtils.trArgs('ib_delete_group_confirm', {
            'name': group.groupName ?? '',
          }),
          style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              TranslationUtils.tr('account_management_cancel'),
              style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              TranslationUtils.tr('account_management_delete'),
              style: AppTextStyles.bodyText.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && group.id != null) {
      await ibController.deleteCommissionGroup(groupId: group.id!);
      await _loadData();
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: AppColors.tradeBackgroundCenterColor,
              elevation: 0,
              leading: IconButton(
                icon: SvgPicture.asset("assets/svg/ib_dashboard/home.svg", colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
                onPressed: () => Get.offAllNamed(AppPages.TRADING),
              ),
              title: Text(
                TranslationUtils.tr('ib_structure_screen_ib_structure'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: AppColors.whiteColor,
        color: AppColors.primary,
        child: GetBuilder<IBController>(
          id: 'commission_groups',
          builder: (controller) {
            // Show loading only if actively loading and no data
            if (controller.isCommissionGroupsLoading.value &&
                controller.commissionGroups.isEmpty &&
                !controller.isLoading.value) {
              return Center(
                child: CommonLoadingWidget(
                  message: TranslationUtils.tr(
                    'commission_groups_screen_loading_commission_groups',
                  ),
                  size: 50.0,
                  color: AppColors.primary,
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          TranslationUtils.tr(
                            'commission_groups_screen_commission_groups',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: _navigateToAddGroup,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: AppColors.whiteColor, size: 16.sp),
                              SizedBox(width: 4.w),
                              Text(
                                TranslationUtils.tr(
                                  'ib_structure_screen_add_group',
                                ),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Groups Table
                  if (controller.commissionGroups.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 64.sp,
                              color: AppColors.textGrey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              TranslationUtils.tr(
                                'commission_groups_screen_no_commission_groups_found',
                              ),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 16.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    else
                    _buildGroupsTable(controller.commissionGroups),
                  
                  // Bottom padding for floating navigation bar
                  SizedBox(height: 100.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupsTable(List<CommissionGroup> groups) {
    return SingleChildScrollView(
      // scrollDirection: Axis.horizontal,
      child: Container(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 32.w,
        ),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40.w,
                    child: Text(
                      '#',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      TranslationUtils.tr('commission_group_form_screen_group_name'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      TranslationUtils.tr('commission_groups_screen_created_date'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      TranslationUtils.tr('actions_section_title'),
                      textAlign: TextAlign.end,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...groups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.textGrey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        '${index + 1}',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        group.groupName ?? 'N/A',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(group.createdAt),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        spacing: 6.w,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _navigateToEditGroup(group),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              minimumSize: Size(30.w, 32.h),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                            child: Icon(Icons.edit, color: AppColors.textPrimary, size: 14.sp,),
                          ),
                          TextButton(
                            onPressed: () => _deleteGroup(group),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              minimumSize: Size(30.w, 32.h),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                            child: Icon(Icons.delete, color: AppColors.textPrimary, size: 14.sp,),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
