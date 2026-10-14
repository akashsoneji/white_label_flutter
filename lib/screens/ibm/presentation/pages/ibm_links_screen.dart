import 'package:crm_app/flavor_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_link_stats_sheet.dart';
import 'package:crm_app/services/language_service.dart';

class IbmLinksScreen extends StatefulWidget {
  const IbmLinksScreen({super.key});

  @override
  State<IbmLinksScreen> createState() => _IbmLinksScreenState();
}

class _IbmLinksScreenState extends State<IbmLinksScreen> {
  final IbmController controller = Get.find<IbmController>();
  final Set<int> _togglingLinkIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchLinks();
    });
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: IbmTopHeader(
        title: TranslationUtils.tr('ibm_referral_links'),
        showBackButton: false,
        extraActions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 8.w),
            child: InkWell(
              onTap: () => _openCreateEditDialog(context),
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14.w, color: AppColors.whiteColor),
                    SizedBox(width: 4.w),
                    Text(
                      TranslationUtils.tr('ibm_create_link'),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final links = controller.linksList;
        final isLoading = controller.isLinksLoading.value;
        int totalVisits = 0;
        int totalSignups = 0;
        int totalAccounts = 0;
        int totalFunded = 0;

        for (final item in links) {
          if (item is Map) {
            final counts = item['counts'];
            if (counts is Map) {
              totalVisits += _parseInt(counts['visits']);
              totalSignups += _parseInt(counts['signups']);
              totalAccounts += _parseInt(counts['accounts']);
              totalFunded += _parseInt(counts['funded']);
            }
          }
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await controller.fetchLinks();
          },
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (isLoading && links.isEmpty) ...[
                LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppColors.primary,
                  minHeight: 2.h,
                ),
                SizedBox(height: 8.h),
              ],
              // Header title + New link button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationUtils.tr('ibm_referral_links'),
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          TranslationUtils.tr('ibm_every_way_sign_up_under_you'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _openCreateEditDialog(context),
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 14.w,
                            color: AppColors.whiteColor,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            TranslationUtils.tr('ibm_new_link'),
                            style: TextStyle(
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
              SizedBox(height: 14.h),

              // 4 Summary Metric Cards in a Grid / Wrap
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 10.w) / 2;
                  return Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      _buildMetricCard(
                        width: cardWidth,
                        icon: Icons.link,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('ibm_nav_links'),
                        value: '${links.length}',
                        subtitle: TranslationUtils.trArgs('ibm_n_of_your_own', {
                          'count': '${links.length}',
                        }),
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        icon: Icons.person_add_alt_1,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('ibm_signed_up'),
                        value: '$totalSignups',
                        subtitle: TranslationUtils.trArgs('ibm_from_n_visits', {
                          'count': '$totalVisits',
                        }),
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        icon: Icons.account_balance_wallet,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('ibm_opened_an_account'),
                        value: '$totalAccounts',
                        subtitle: TranslationUtils.tr('ibm_got_as_far_as_trading_account'),
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        icon: Icons.arrow_downward,
                        iconBg: const Color(0xFF2E7D32),
                        title: TranslationUtils.tr('ibm_funded'),
                        value: '$totalFunded',
                        subtitle: TranslationUtils.tr('ibm_put_money_in'),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 20.h),

              // Section Label
              Text(
                TranslationUtils.trArgs('ibm_your_own_links_count', {
                  'count': '${links.length}',
                }),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),

              // Links List or Empty State
              if (links.isEmpty && !isLoading)
                Container(
                  margin: EdgeInsets.only(top: 20.h),
                  padding: EdgeInsets.symmetric(
                    vertical: 40.h,
                    horizontal: 20.w,
                  ),
                  decoration: BoxDecoration(
                    color:
                        AppColors.isDarkMode ? AppColors.card : AppColors.card,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 40.w,
                          color: AppColors.textGrey.withOpacity(0.5),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          TranslationUtils.tr('ibm_no_referral_links_yet'),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          TranslationUtils.tr('ibm_click_new_link_to_generate'),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...links.map((link) => _buildLinkCard(link)).toList(),
              SizedBox(height: 30.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMetricCard({
    required double width,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.card : AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 16.w, color: AppColors.whiteColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(dynamic link) {
    if (link is! Map) return const SizedBox();

    final linkId = _parseInt(link['link_id'] ?? link['id']);
    final label =
        link['label']?.toString() ?? TranslationUtils.tr('ibm_unnamed_link');
    final code = link['code']?.toString() ?? '';
    final isActive = _parseBool(link['is_active']);
    final isToggling = _togglingLinkIds.contains(linkId);

    // Groups info
    String groupsText = TranslationUtils.tr('bonus_screen_all_groups');
    if (link['groups'] is List && (link['groups'] as List).isNotEmpty) {
      final names =
          (link['groups'] as List)
              .map(
                (g) => g is Map ? (g['name'] ?? '').toString() : g.toString(),
              )
              .where((n) => n.isNotEmpty)
              .toList();
      if (names.isNotEmpty) {
        groupsText = names.join(' · ');
      }
    }

    // Counts
    final counts = link['counts'] is Map ? link['counts'] : {};
    final visits = _parseInt(counts['visits']);
    final signups = _parseInt(counts['signups']);
    final accounts = _parseInt(counts['accounts']);
    final funded = _parseInt(counts['funded']);

    final signupPct =
        visits > 0 ? ((signups / visits) * 100).toStringAsFixed(0) : '0';

    // Full URL
    final url = '${FlavorConfig.instance.chartBaseUrl}/register?ref=$code';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.card : AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color:
              isActive ? AppColors.divider : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Label & Action Buttons (Edit, Switch on/off, Delete)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        if (!isActive)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              TranslationUtils.tr('wallet_inactive'),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      groupsText,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              InkWell(
                onTap: () => IbmLinkStatsSheet.show(
                  context,
                  linkId: linkId,
                  label: label,
                ),
                borderRadius: BorderRadius.circular(6.r),
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 16.w,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              // Edit button
              InkWell(
                onTap: () => _openCreateEditDialog(context, existingLink: link),
                borderRadius: BorderRadius.circular(6.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 13.w,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        TranslationUtils.tr('general_edit'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              // Switch off / on button
              InkWell(
                onTap:
                    isToggling
                        ? null
                        : () async {
                          setState(() => _togglingLinkIds.add(linkId));
                          await controller.toggleLinkStatus(linkId, isActive);
                          if (mounted) {
                            setState(() => _togglingLinkIds.remove(linkId));
                          }
                        },
                borderRadius: BorderRadius.circular(6.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color:
                        AppColors.isDarkMode
                            ? Colors.grey[800]
                            : const Color(0xFFF1F1F4),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child:
                      isToggling
                          ? SizedBox(
                            width: 12.w,
                            height: 12.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                          : Text(
                            isActive
                                ? TranslationUtils.tr('ibm_switch_off')
                                : TranslationUtils.tr('ibm_switch_on'),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  isActive
                                      ? AppColors.textPrimary
                                      : Colors.green,
                            ),
                          ),
                ),
              ),
              SizedBox(width: 6.w),
              // Delete icon button
              InkWell(
                onTap: () => _confirmDeleteLink(context, linkId, label),
                borderRadius: BorderRadius.circular(6.r),
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16.w,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Row 2: Link URL Container with Copy button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color:
                  AppColors.isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: url));
                    CustomToastService.showSuccess(
                      message: TranslationUtils.tr('ibm_referral_link_copied'),
                    );
                  },
                  borderRadius: BorderRadius.circular(6.r),
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy_outlined,
                        size: 13.w,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        TranslationUtils.tr('common_copy'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Row 3: 4 Stats metrics (Visits, Signed up %, Opened account, Funded)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLinkStatColumn(
                '$visits',
                TranslationUtils.tr('ibm_visits'),
              ),
              _buildLinkStatColumn(
                '$signups',
                '${TranslationUtils.tr('ibm_signed_up')}\n$signupPct%',
              ),
              _buildLinkStatColumn(
                '$accounts',
                TranslationUtils.tr('ibm_opened_account'),
              ),
              _buildLinkStatColumn(
                '$funded',
                TranslationUtils.tr('ibm_funded'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkStatColumn(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: AppColors.textGrey,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteLink(BuildContext context, int linkId, String label) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        title: Text(
          TranslationUtils.tr('ibm_delete_referral_link'),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          TranslationUtils.trArgs('ibm_confirm_delete_referral_link', {
            'label': label,
          }),
          style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
        ),
        actionsPadding: EdgeInsetsDirectional.fromSTEB(16.w, 0, 16.w, 16.h),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    TranslationUtils.tr('account_management_cancel'),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    await controller.deleteReferralLink(linkId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    TranslationUtils.tr('account_management_delete'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateEditDialog(BuildContext context, {dynamic existingLink}) {
    final isEdit = existingLink != null;
    final linkId =
        isEdit ? _parseInt(existingLink['link_id'] ?? existingLink['id']) : 0;
    final labelCtrl = TextEditingController(
      text: isEdit ? (existingLink['label']?.toString() ?? '') : '',
    );
    final codeCtrl = TextEditingController(
      text: isEdit ? (existingLink['code']?.toString() ?? '') : '',
    );

    // Existing group IDs
    final List<int> selectedGroups = [];
    if (isEdit && existingLink['plan_group_ids'] is List) {
      for (final g in existingLink['plan_group_ids']) {
        final id = _parseInt(g);
        if (id > 0) selectedGroups.add(id);
      }
    } else if (isEdit && existingLink['groups'] is List) {
      for (final g in existingLink['groups']) {
        final id =
            g is Map ? _parseInt(g['id'] ?? g['plan_group_id']) : _parseInt(g);
        if (id > 0) selectedGroups.add(id);
      }
    }

    int? defaultGroupId;
    if (isEdit && existingLink['default_plan_group_id'] != null) {
      defaultGroupId = _parseInt(existingLink['default_plan_group_id']);
    }

    DateTime? selectedExpiryDate;
    if (isEdit && existingLink['expires_at'] != null) {
      selectedExpiryDate = DateTime.tryParse(
        existingLink['expires_at'].toString(),
      );
    }

    // Default template groups matching design if API returns empty list initially
    final List<Map<String, dynamic>> fallbackGroups = [
      {'id': 1, 'name': 'Cent 15'},
      {'id': 2, 'name': 'cent 20'},
      {'id': 3, 'name': 'ECN'},
      {'id': 4, 'name': 'Hedged'},
      {'id': 5, 'name': 'PRO'},
      {'id': 6, 'name': 'PRO 25'},
      {'id': 7, 'name': 'Standard'},
      {'id': 8, 'name': 'Standard 30'},
    ];

    // If new link and no selection, pre-select default first 6 groups as shown in mockup
    if (!isEdit && selectedGroups.isEmpty) {
      selectedGroups.addAll([1, 2, 3, 4, 5, 6]);
      defaultGroupId = 1;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final rawPlanGroups = controller.planGroupsList;
            final List<Map<String, dynamic>> availableGroups = [];

            if (rawPlanGroups.isNotEmpty) {
              for (final g in rawPlanGroups) {
                if (g is Map) {
                  final id = _parseInt(g['plan_group_id'] ?? g['id']);
                  final name = g['name']?.toString() ?? 'Group';
                  if (id > 0) {
                    availableGroups.add({'id': id, 'name': name});
                  }
                }
              }
            }

            final groupsToDisplay =
                availableGroups.isNotEmpty ? availableGroups : fallbackGroups;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color:
                      AppColors.isDarkMode
                          ? AppColors.pureBlack
                          : AppColors.whiteColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.r),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Row with title & close button
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(20.w, 16.h, 16.w, 12.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit
                                        ? TranslationUtils.tr('ibm_edit_link')
                                        : TranslationUtils.tr('ibm_new_link'),
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    TranslationUtils.tr(
                                      'ibm_where_you_post_it',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.of(ctx).pop(),
                              borderRadius: BorderRadius.circular(8.r),
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16.w,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppColors.divider, height: 1.h),

                      // Form body
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 16.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Name it
                              Text(
                                TranslationUtils.tr('ibm_name_it'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextField(
                                controller: labelCtrl,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: TranslationUtils.tr(
                                    'ibm_instagram_bio',
                                  ),
                                  hintStyle: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.textGrey.withOpacity(0.7),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                TranslationUtils.tr('ibm_only_you_see_this'),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E9BB0),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // 2. Code (optional)
                              Text(
                                TranslationUtils.tr('ibm_code_optional'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextField(
                                controller: codeCtrl,
                                enabled: !isEdit,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: TranslationUtils.tr(
                                    'ibm_leave_blank_we_make_one',
                                  ),
                                  hintStyle: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.textGrey.withOpacity(0.7),
                                  ),
                                  filled: isEdit,
                                  fillColor:
                                      isEdit
                                          ? (AppColors.isDarkMode
                                              ? Colors.grey[900]
                                              : const Color(0xFFF7F8FA))
                                          : null,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                TranslationUtils.tr(
                                  'ibm_letters_numbers_dashes',
                                ),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E9BB0),
                                ),
                              ),
                              SizedBox(height: 18.h),

                              // 3. GROUPS THIS LINK OFFERS
                              Text(
                                TranslationUtils.tr(
                                  'ibm_groups_this_link_offers',
                                ),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF758A99),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                TranslationUtils.tr(
                                  'ibm_client_can_open_account_in_groups',
                                ),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E9BB0),
                                ),
                              ),
                              SizedBox(height: 10.h),

                              // Groups list
                              ...groupsToDisplay.map((group) {
                                final gId = _parseInt(group['id']);
                                final gName =
                                    group['name']?.toString() ?? 'Group';
                                final isSelected = selectedGroups.contains(gId);
                                final isShownFirst =
                                    (defaultGroupId == gId) ||
                                    (selectedGroups.isNotEmpty &&
                                        selectedGroups.first == gId);

                                return InkWell(
                                  onTap: () {
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedGroups.remove(gId);
                                        if (defaultGroupId == gId) {
                                          defaultGroupId =
                                              selectedGroups.isNotEmpty
                                                  ? selectedGroups.first
                                                  : null;
                                        }
                                      } else {
                                        selectedGroups.add(gId);
                                        defaultGroupId ??= gId;
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8.h),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 10.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? (AppColors.isDarkMode
                                                  ? AppColors.card
                                                  : const Color(0xFFF7F2FA))
                                              : (AppColors.isDarkMode
                                                  ? AppColors.card
                                                  : const Color(0xFFF9FAFB)),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? AppColors.primary
                                                : AppColors.divider,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Custom Checkbox
                                        Container(
                                          width: 18.w,
                                          height: 18.w,
                                          decoration: BoxDecoration(
                                            color:
                                              isSelected
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? AppColors.primary
                                                      : AppColors.divider,
                                              width: 1.5,
                                            ),
                                          ),
                                          child:
                                              isSelected
                                                  ? Icon(
                                                    Icons.check,
                                                    size: 13.w,
                                                    color: AppColors.whiteColor,
                                                  )
                                                  : null,
                                        ),
                                        SizedBox(width: 10.w),
                                        // Drag handle dots
                                        Icon(
                                          Icons.drag_indicator,
                                          size: 16.w,
                                          color:
                                              isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textGrey
                                                      .withOpacity(0.6),
                                        ),
                                        SizedBox(width: 10.w),
                                        // Group Name
                                        Expanded(
                                          child: Text(
                                            gName,
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // "Shown first" badge
                                        if (isShownFirst && isSelected)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 3.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDFF6E4),
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              TranslationUtils.tr(
                                                'ibm_shown_first',
                                              ),
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              SizedBox(height: 16.h),

                              // 4. Stop working on (optional)
                              Text(
                                TranslationUtils.tr(
                                  'ibm_stop_working_on_optional',
                                ),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        selectedExpiryDate ??
                                        now.add(const Duration(days: 30)),
                                    firstDate: now,
                                    lastDate: now.add(
                                      const Duration(days: 365 * 5),
                                    ),
                                    builder: (ctx, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: AppColors.primary,
                                            onPrimary: AppColors.whiteColor,
                                            surface: AppColors.card,
                                            onSurface: AppColors.textPrimary,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      selectedExpiryDate = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.card
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedExpiryDate != null
                                              ? DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(selectedExpiryDate!)
                                              : 'dd/mm/yyyy',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color:
                                                selectedExpiryDate != null
                                                    ? AppColors.textPrimary
                                                    : AppColors.textGrey
                                                        .withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                      if (selectedExpiryDate != null)
                                        InkWell(
                                          onTap: () {
                                            setSheetState(() {
                                              selectedExpiryDate = null;
                                            });
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: 6.w,
                                            ),
                                            child: Icon(
                                              Icons.clear,
                                              size: 16.w,
                                              color: AppColors.textGrey,
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 18.w,
                                        color: AppColors.textPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                TranslationUtils.tr('ibm_useful_for_a_campaign'),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E9BB0),
                                ),
                              ),
                              SizedBox(height: 24.h),

                              // Bottom Actions: Make link / Cancel
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      if (labelCtrl.text.trim().isEmpty) {
                                        CustomToastService.showError(
                                          message: TranslationUtils.tr(
                                            'ibm_please_provide_link_name',
                                          ),
                                        );
                                        return;
                                      }

                                      final expiresStr =
                                          selectedExpiryDate != null
                                              ? DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(selectedExpiryDate!)
                                              : null;

                                      Navigator.of(ctx).pop();

                                      if (isEdit) {
                                        await controller.updateReferralLink(
                                          linkId: linkId,
                                          label: labelCtrl.text.trim(),
                                          planGroupIds:
                                              selectedGroups.isNotEmpty
                                                  ? selectedGroups
                                                  : null,
                                          defaultPlanGroupId: defaultGroupId,
                                          expiresAt: expiresStr,
                                        );
                                      } else {
                                        await controller.createReferralLink(
                                          label: labelCtrl.text.trim(),
                                          code:
                                              codeCtrl.text.trim().isNotEmpty
                                                  ? codeCtrl.text.trim()
                                                  : null,
                                          planGroupIds:
                                              selectedGroups.isNotEmpty
                                                  ? selectedGroups
                                                  : null,
                                          defaultPlanGroupId: defaultGroupId,
                                          expiresAt: expiresStr,
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 22.w,
                                        vertical: 12.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        isEdit
                                            ? TranslationUtils.tr(
                                              'edit_plan_bottom_sheet_save_changes',
                                            )
                                            : TranslationUtils.tr(
                                              'ibm_make_link',
                                            ),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.whiteColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  InkWell(
                                    onTap: () => Navigator.of(ctx).pop(),
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                        vertical: 12.h,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.divider),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        TranslationUtils.tr(
                                          'account_management_cancel',
                                        ),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
