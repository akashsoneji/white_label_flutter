import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IBRequestsScreen extends StatefulWidget {
  const IBRequestsScreen({super.key});

  @override
  State<IBRequestsScreen> createState() => _IBRequestsScreenState();
}

class _IBRequestsScreenState extends State<IBRequestsScreen> {
  late IBController ibController;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    // Reset filter when screen initializes
    _selectedStatus = 'All';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApprovalRequests();
    });
  }

  Future<void> _loadApprovalRequests() async {
    await ibController.getIBApprovalRequests();
  }

  Future<void> _onRefresh() async {
    await _loadApprovalRequests();
  }

  List<IBApprovalRequest> _getFilteredRequests() {
    final allRequests = ibController.ibApprovalRequests.toList();
    if (_selectedStatus == 'All') return allRequests;
    return allRequests
        .where((request) => request.status == _selectedStatus.toLowerCase())
        .toList();
  }

  Color _getApprovalStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'inreview':
        return AppColors.warning;
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textGrey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'inreview':
        return 'In Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status ?? 'Unknown';
    }
  }

  String _getRequestName(IBApprovalRequest request) {
    final name = (request.fullname ?? '').trim();
    if (name.isNotEmpty) return name;
    final user = request.user;
    final fallback = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    return fallback.isNotEmpty ? fallback : 'N/A';
  }

  String _getRequestEmail(IBApprovalRequest request) {
    final email = (request.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return (request.user?.email ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text(
          'IB Requests',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset("assets/svg/ib_dashboard/home.svg", colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: AppColors.whiteColor,
        color: AppColors.primary,
        child: GetBuilder<IBController>(
          id: 'ib_requests',
          builder: (controller) {
            if (controller.isLoading.value &&
                controller.ibApprovalRequests.isEmpty) {
              return Center(
                child: CommonLoadingWidget(
                  message: 'Loading requests...',
                  size: 50.0,
                  color: AppColors.primary,
                ),
              );
            }

            return Column(
              children: [
                // Status Filter Tabs
                _buildStatusFilter(),

                // Requests List
                Expanded(child: _buildRequestsList()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = ['All', 'In Review', 'Approved', 'Rejected'];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              statuses.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: EdgeInsets.only(right: 10.w),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                          width: 1,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        status,
                        style: AppTextStyles.bodyText.copyWith(
                          color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    final filteredRequests = _getFilteredRequests();

    if (filteredRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 48.sp,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'No requests found',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'There are no $_selectedStatus requests at the moment',
                style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Bottom padding for floating navigation bar (safe area + nav bar height + extra spacing)
    final bottomPadding = 100.h;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, bottomPadding),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(IBApprovalRequest request) {
    final statusColor = _getApprovalStatusColor(request.status);
    final name = _getRequestName(request);
    final email = _getRequestEmail(request);
    final assignedPlan =
        (request.assignedPlan ?? '').isNotEmpty
            ? request.assignedPlan!
            : 'Not Assigned';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Avatar, Name, Status
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.8),
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'N',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        email,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusLabel(request.status),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details Section
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _buildInfoGrid([
                  _buildInfoItem(
                    Icons.assignment_outlined,
                    'Plan',
                    assignedPlan,
                  ),
                ]),
                // SizedBox(height: 12.h),
                // _buildInfoGrid([
                //   _buildInfoItem(
                //     Icons.calendar_today_outlined,
                //     'Submitted',
                //     submissionDate,
                //   ),

                // ]),
              ],
            ),
          ),
          // Action Button Section
          if (request.status?.toLowerCase() == 'approved')
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
              child: ElevatedButton.icon(
                onPressed: () {
                  _showChangePlanDialog(request);
                },
                icon: Icon(
                  Icons.edit_outlined,
                  size: 16.sp,
                  color: AppColors.whiteColor,
                ),
                label: Text(
                  'Change Plan',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  // padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return Row(
      children: children.map((child) => Expanded(child: child)).toList(),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            size: 16.sp,
            color: AppColors.primary.withOpacity(0.7),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showChangePlanDialog(IBApprovalRequest request) {
    final reasonController = TextEditingController();
    CommissionGroup? selectedGroup;
    String structureType = 'standard';

    // Fetch commission groups
    ibController.getCommissionGroups();

    Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assign Plan',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: Get.back,
                          icon: Icon(Icons.close, size: 22.sp),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),
                    const Divider(),
                    SizedBox(height: 16.h),

                    // Structure type
                    _requiredLabel('Structure Type'),
                    SizedBox(height: 8.h),

                    Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Standard Group',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.whiteColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    _requiredLabel('Select Standard Group'),
                    SizedBox(height: 8.h),

                    Obx(() {
                      if (ibController.isCommissionGroupsLoading.value) {
                        return SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // Try to pre-select based on assigned_plan from API
                      if (selectedGroup == null &&
                          request.assignedPlan != null &&
                          request.assignedPlan != "Not Assigned" &&
                          ibController.commissionGroups.isNotEmpty) {
                        final match = ibController.commissionGroups
                            .firstWhereOrNull(
                              (g) => g.groupName == request.assignedPlan,
                            );
                        if (match != null) {
                          selectedGroup = match;
                        }
                      }

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CommissionGroup>(
                            isExpanded: true,
                            value: selectedGroup,
                            dropdownColor: AppColors.card,
                            iconEnabledColor: AppColors.textPrimary,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            hint: Text(
                              'Select Group',
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.textGrey,
                              ),
                            ),
                            items:
                                ibController.commissionGroups.map((group) {
                                  return DropdownMenuItem(
                                    value: group,
                                    child: Text(
                                      group.groupName ?? 'N/A',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() => selectedGroup = value);
                            },
                          ),
                        ),
                      );
                    }),

                    SizedBox(height: 16.h),

                    _requiredLabel('Approval Reason'),
                    SizedBox(height: 8.h),

                    TextField(
                      style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                      controller: reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Please provide a reason...',
                        hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Buttons (FIXED)
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8.w,
                      children: [
                        // OutlinedButton(
                        //   onPressed: Get.back,
                        //   child: Text('Close'),
                        // ),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedGroup == null ||
                                reasonController.text.trim().isEmpty) {
                              CustomToastService.showError(
                                message: 'Fill all required fields',
                              );
                              return;
                            }

                            final success = await ibController
                                .updateIBStatusRequest(
                                  requestId: request.id!,
                                  payload: {
                                    "status": "approve",
                                    "reason": reasonController.text.trim(),
                                    "structure_type": structureType,
                                    "group_id": selectedGroup!.id.toString(),
                                  },
                                );

                            if (success) {
                              Get.back();
                              _loadApprovalRequests();
                            }
                          },
                          child: Text('Submit', style: AppTextStyles.textButton.copyWith(color: AppColors.whiteColor)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: '$text ',
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        children: [
          TextSpan(text: '*', style: AppTextStyles.bodyText.copyWith(color: AppColors.error)),
        ],
      ),
    );
  }
}
