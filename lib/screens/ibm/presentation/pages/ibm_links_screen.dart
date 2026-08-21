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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.linksList.isEmpty) controller.fetchLinks();
      if (controller.planGroupsList.isEmpty) controller.fetchPlanGroups();
    });
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              _buildTopSection(),
              SizedBox(height: 24.h),
              _buildSummaryCards(),
              SizedBox(height: 32.h),
              Text(
                'YOUR OWN LINKS  ${controller.linksList.length}',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 16.h),
              if (controller.linksList.isEmpty)
                _buildEmptyState()
              else
                ...controller.linksList.map((rawLink) {
                  final link = rawLink is Map ? Map<String, dynamic>.from(rawLink) : <String, dynamic>{};
                  return _buildLinkCard(link);
                }).toList(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Referral Links',
                style: AppTextStyles.heading.copyWith(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              Text(
                'Every way somebody can sign up under you',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13.sp),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        ElevatedButton.icon(
          onPressed: _showCreateLinkDialog,
          icon: Icon(Icons.add, size: 16.w),
          label: Text('New link', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5F259E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Widget _buildSummaryCards() {
    int totalLinks = controller.linksList.length;
    int totalSignedUp = 0;
    int totalVisits = 0;
    int totalOpened = 0;
    int totalFunded = 0;

    for (var rawLink in controller.linksList) {
      final link = rawLink is Map ? Map<String, dynamic>.from(rawLink) : {};
      final counts = link['counts'] is Map ? Map<String, dynamic>.from(link['counts']) : {};
      totalSignedUp += _parseInt(counts['signups']);
      totalVisits += _parseInt(counts['visits']);
      totalOpened += _parseInt(counts['accounts']);
      totalFunded += _parseInt(counts['funded']);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(Icons.link, 'Links', '$totalLinks', '$totalLinks of your own', const Color(0xFF5F259E)),
          SizedBox(width: 12.w),
          _buildSummaryCard(Icons.person_add, 'Signed up', '$totalSignedUp', 'from $totalVisits visits', const Color(0xFF5F259E)),
          SizedBox(width: 12.w),
          _buildSummaryCard(Icons.account_balance_wallet, 'Opened an account', '$totalOpened', 'got as far as a trading account', const Color(0xFF5F259E)),
          SizedBox(width: 12.w),
          _buildSummaryCard(Icons.arrow_downward, 'Funded', '$totalFunded', 'put money in', const Color(0xFF238644)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String title, String value, String subtitle, Color iconColor) {
    return Container(
      width: 220.w,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: Colors.white, size: 24.w),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp)),
                SizedBox(height: 4.h),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.textPrimary)),
                SizedBox(height: 4.h),
                Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link) {
    final linkId = link['id'] ?? 0;
    final label = link['label'] ?? 'General Link';
    final code = link['code'] ?? '';
    final isActive = link['is_active'] ?? true;
    
    // Group string formatting
    final groups = link['groups'] is List ? (link['groups'] as List) : [];
    final groupNames = groups.map((g) {
      if (g is Map) return g['name']?.toString() ?? '';
      return g.toString();
    }).where((s) => s.isNotEmpty).join(' • ');

    final baseUrl = 'https://dev.tenaxcodecrm.com/register';
    final fullUrl = '$baseUrl?ref=$code';

    final counts = link['counts'] is Map ? Map<String, dynamic>.from(link['counts']) : {};
    final visits = _parseInt(counts['visits']);
    final signups = _parseInt(counts['signups']);
    final accounts = _parseInt(counts['accounts']);
    final funded = _parseInt(counts['funded']);
    
    final conversion = visits > 0 ? ((signups / visits) * 100).toStringAsFixed(0) : '0';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.textPrimary),
                ),
              ),
              Row(
                children: [
                  _buildActionButton(Icons.edit, 'Edit', () {
                    // Update functionality can be added here
                  }),
                  SizedBox(width: 8.w),
                  _buildActionButton(isActive ? Icons.toggle_on : Icons.toggle_off, isActive ? 'Switch off' : 'Switch on', () async {
                    await controller.updateReferralLink(linkId: linkId, isActive: !isActive);
                  }),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () async {
                      // Confirm delete
                      bool? confirm = await Get.dialog<bool>(
                        AlertDialog(
                          title: const Text('Delete Link'),
                          content: const Text('Are you sure you want to delete this referral link?'),
                          actions: [
                            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Get.back(result: true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await controller.deleteReferralLink(linkId);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Icon(Icons.delete_outline, color: Colors.red, size: 16.w),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            groupNames.isNotEmpty ? groupNames : 'All Groups',
            style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
          ),
          SizedBox(height: 16.h),
          // URL Box
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fullUrl,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp, overflow: TextOverflow.ellipsis),
                  ),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fullUrl));
                    CustomToastService.showSuccess(message: 'Link copied!');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 14.w, color: AppColors.textPrimary),
                        SizedBox(width: 4.w),
                        Text('Copy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.sp, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          // Stats Row
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                _buildStatMetric('$visits', 'Visits', null),
                _buildDivider(),
                _buildStatMetric('$signups', 'Signed up', '$conversion%'),
                _buildDivider(),
                _buildStatMetric('$accounts', 'Opened account', null),
                _buildDivider(),
                _buildStatMetric('$funded', 'Funded', null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4.r),
          color: AppColors.card,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14.w, color: AppColors.textPrimary),
            SizedBox(width: 4.w),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.sp, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMetric(String value, String label, String? subValue) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.textPrimary)),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(color: AppColors.textGrey, fontSize: 10.sp)),
          if (subValue != null) ...[
            SizedBox(height: 2.h),
            Text(subValue, style: TextStyle(color: const Color(0xFF5F259E), fontWeight: FontWeight.bold, fontSize: 10.sp)),
          ]
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40.h,
      width: 1,
      color: AppColors.border,
      margin: EdgeInsets.symmetric(horizontal: 12.w),
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
    RxList<int> selectedGroupIds = <int>[].obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        backgroundColor: AppColors.card,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: Get.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.only(left: 20.w, right: 12.w, top: 16.h, bottom: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.textPrimary)),
                        SizedBox(height: 4.h),
                        Text('Where you post it, and what it opens the door to', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textGrey),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Input
                      Text('Name it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppColors.textPrimary)),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: labelController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Instagram bio',
                          hintStyle: TextStyle(color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.tradeBackgroundCenterColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text('Only you see this. It is how you tell your links apart.', style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
                      SizedBox(height: 20.h),

                      // Code Input
                      Text('Code (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppColors.textPrimary)),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: codeController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'leave blank and we make one',
                          hintStyle: TextStyle(color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.tradeBackgroundCenterColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text('Letters, numbers, dashes and underscores. It cannot be changed later.', style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
                      SizedBox(height: 24.h),

                      // Groups
                      Text('GROUPS THIS LINK OFFERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: AppColors.textGrey, letterSpacing: 1.1)),
                      SizedBox(height: 8.h),
                      Text('A client who signs up here can open an account in these groups, and nothing else.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp)),
                      SizedBox(height: 16.h),

                      // Group List
                      Obx(() {
                        if (controller.planGroupsList.isEmpty) {
                          return Text('No groups available.', style: TextStyle(color: AppColors.textSecondary));
                        }
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.planGroupsList.length,
                          itemBuilder: (context, index) {
                            final group = controller.planGroupsList[index];
                            final int groupId = group['group_id'] ?? group['plan_group_id'] ?? 0;
                            final String groupName = group['name'] ?? 'Unknown';

                            return Obx(() {
                              final isSelected = selectedGroupIds.contains(groupId);
                              final isFirst = selectedGroupIds.isNotEmpty && selectedGroupIds.first == groupId;

                              return GestureDetector(
                                onTap: () {
                                  if (isSelected) {
                                    selectedGroupIds.remove(groupId);
                                  } else {
                                    selectedGroupIds.add(groupId);
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF5F259E).withOpacity(0.05) : AppColors.card,
                                    border: Border.all(color: isSelected ? const Color(0xFF5F259E) : AppColors.border),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                        color: isSelected ? const Color(0xFF5F259E) : AppColors.textGrey,
                                        size: 20.w,
                                      ),
                                      SizedBox(width: 12.w),
                                      Icon(Icons.drag_indicator, color: AppColors.textGrey.withOpacity(0.5), size: 16.w),
                                      SizedBox(width: 8.w),
                                      Text(
                                        groupName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.sp,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isFirst) ...[
                                        SizedBox(width: 12.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Text(
                                            'Shown first',
                                            style: TextStyle(color: Colors.green, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              Divider(height: 1, color: AppColors.border),
              // Footer
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC7A2E5), // secondary purple
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      onPressed: () async {
                        if (labelController.text.trim().isEmpty) {
                          CustomToastService.showError(message: 'Please enter a label for the link.');
                          return;
                        }
                        
                        int? defaultGroupId = selectedGroupIds.isNotEmpty ? selectedGroupIds.first : null;

                        Get.back(); // close dialog
                        await controller.createReferralLink(
                          label: labelController.text.trim(),
                          code: codeController.text.trim().isNotEmpty ? codeController.text.trim() : null,
                          planGroupIds: selectedGroupIds.toList(),
                          defaultPlanGroupId: defaultGroupId,
                        );
                      },
                      child: Text('Make link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    ),
                    SizedBox(width: 12.w),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      onPressed: () => Get.back(),
                      child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
