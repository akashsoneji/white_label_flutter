import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/models/ib_models.dart';

class MyStructureScreen extends StatefulWidget {
  const MyStructureScreen({super.key});

  @override
  State<MyStructureScreen> createState() => _MyStructureScreenState();
}

class _MyStructureScreenState extends State<MyStructureScreen> {
  late IBController ibController;
  final Map<int, bool> _expandedGroups =
      {}; // Track expanded state for each group

  @override
  void initState() {
    super.initState();
    // Get or create IBController
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    _loadData();
  }

  Future<void> _loadData() async {
    await ibController.getIBStructure();
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  String _getCommissionValue(MasterGroup group, String categoryName) {
    if (group.commissions == null) return '0.00';
    final value = group.commissions![categoryName];
    if (value == null || value.isEmpty) return '0.00';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'My Structure',
          style: TextStyle(
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
          id: 'ib_structure',
          builder: (controller) {
            if (controller.isLoading.value &&
                controller.ibStructureData.value == null) {
              return Center(
                child: CommonLoadingWidget(
                  message: 'Loading structure...',
                  size: 50.0,
                  color: AppColors.primary,
                ),
              );
            }

            final structureData = controller.ibStructureData.value;

            // Check for error message
            if (controller.errorMessage.value.isNotEmpty &&
                structureData == null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
                      SizedBox(height: 16.h),
                      Text(
                        controller.errorMessage.value,
                        style: TextStyle(fontSize: 16.sp, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (structureData == null ||
                structureData.masterGroups == null ||
                structureData.masterGroups!.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: 64.sp,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No structure data found',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Please check your IB status or contact support',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final masterGroups = structureData.masterGroups!;
            final symbolCategories = structureData.symbolCategories ?? [];

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Standard Groups Tab (read-only, no tabs needed)
                  Container(
                    padding: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    child: Text(
                      'Standard Groups',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Description
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            size: 16.sp,
                            color: AppColors.whiteColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'These commission rates are used for your direct clients. Commission flows up the hierarchy: Your Rate - Sub-IB Rate = Your Profit.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Commission Groups Cards (Expandable Vertical List)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: masterGroups.length,
                    itemBuilder: (context, index) {
                      final group = masterGroups[index];
                      final isExpanded = _expandedGroups[index] ?? false;
                      return _buildExpandableGroupCard(
                        group,
                        index,
                        isExpanded,
                        symbolCategories,
                      );
                    },
                  ),

                  // Bottom padding for floating navigation bar (safe area + nav bar height + extra spacing)
                  SizedBox(height: 100.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandableGroupCard(
    MasterGroup group,
    int index,
    bool isExpanded,
    List<SymbolCategory> symbolCategories,
  ) {
    // Use groupName or planTitle, default to 'Standard'
    final groupName = group.groupName ?? group.planTitle ?? 'Standard';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isExpanded ? AppColors.primary : AppColors.border,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Always visible (collapsed/expanded toggle)
          InkWell(
            onTap: () {
              setState(() {
                _expandedGroups[index] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.r),
              topRight: Radius.circular(12.r),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: !isExpanded ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.all(Radius.circular(12.r)),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    groupName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color:
                          isExpanded ? AppColors.primary : AppColors.whiteColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Animated triangle icon (caret)
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color:
                          isExpanded ? AppColors.primary : AppColors.whiteColor,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (isExpanded)
            Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 16.h,
                bottom: 20.h,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child:
                  symbolCategories.isEmpty
                      ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: Text(
                            'No categories available',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            symbolCategories.asMap().entries.map((entry) {
                              final category = entry.value;
                              final categoryName = category.categoryName ?? '';
                              final commissionValue = _getCommissionValue(
                                group,
                                categoryName,
                              );
                              final isLast =
                                  entry.key == symbolCategories.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 16.h,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        categoryName,
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Container(
                                      width: 110.w,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(
                                            0.2,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '\$$commissionValue',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
            ),
        ],
      ),
    );
  }
}
