import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/services/language_service.dart';

class IbmSettingsScreen extends StatefulWidget {
  const IbmSettingsScreen({super.key});

  @override
  State<IbmSettingsScreen> createState() => _IbmSettingsScreenState();
}

class _IbmSettingsScreenState extends State<IbmSettingsScreen> {
  final IbmController controller = Get.find<IbmController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchClientVisibility();
      controller.fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: const IbmTopHeader(
        title: 'Partner Settings',
        showBackButton: false,
      ),
      body: Obx(() {
        final groups = controller.clientVisibilityGroups;
        final selectedIds = controller.selectedVisibleGroupIds;
        final defaultId = controller.defaultVisibilityGroupId.value;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await controller.fetchClientVisibility();
          },
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Partner Profile Summary Card
              _buildPartnerProfileCard(),
              SizedBox(height: 16.h),

              // Client Account Visibility Section
              _buildVisibilityCard(groups, selectedIds, defaultId),
              SizedBox(height: 16.h),

              // Portal Preferences Section
              _buildPreferencesCard(languageService),
              SizedBox(height: 16.h),

              // Switch to Client Mode / Exit
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text(
                    'Switch to Client Portal',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPartnerProfileCard() {
    final dashboard = controller.dashboardData;
    final clients = dashboard['clients'] is Map ? dashboard['clients'] : {};
    final partners = dashboard['partners'] is Map ? dashboard['partners'] : {};

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.whiteColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IB Partner Profile',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Status: Active Partner',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProfileStat('Direct Clients', '${clients['total'] ?? 0}'),
              _buildProfileStat(
                'Direct Partners',
                '${partners['direct'] ?? 0}',
              ),
              _buildProfileStat(
                'Network Partners',
                '${partners['network'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityCard(
    List<dynamic> groups,
    List<int> selectedIds,
    int? defaultId,
  ) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Client Account Visibility',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (controller.isVisibilityLoading.value)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Control which trading account groups your referred clients see when registering.',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 12.h),

          if (groups.isEmpty && !controller.isVisibilityLoading.value)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Text(
                'All standard account groups are currently enabled.',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
              ),
            )
          else ...[
            ...groups.map((group) {
              if (group is! Map) return const SizedBox();
              final id =
                  int.tryParse(
                    (group['plan_group_id'] ??
                            group['group_id'] ??
                            group['id'] ??
                            0)
                        .toString(),
                  ) ??
                  0;
              final name = group['name']?.toString() ?? 'Group';
              final isVisible = selectedIds.contains(id);
              final isDefault = (defaultId == id);

              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color:
                      AppColors.isDarkMode
                          ? Colors.grey[900]
                          : const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color:
                        isDefault
                            ? AppColors.primary.withOpacity(0.5)
                            : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isDefault) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isVisible && !isDefault)
                            InkWell(
                              onTap:
                                  () =>
                                      controller.setDefaultVisibilityGroup(id),
                              child: Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  'Set as default',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isVisible,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        controller.toggleGroupVisibility(id);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => controller.saveClientVisibility(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Save Visibility Settings',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(LanguageService languageService) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portal Preferences',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language_outlined, color: AppColors.primary),
            title: Text(
              'Language',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: Text(
              languageService.currentLanguage.value.toUpperCase(),
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              'Notification Alerts',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
