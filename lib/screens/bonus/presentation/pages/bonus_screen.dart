import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class EligibleBonus {
  final int id;
  final String title;
  final int bonusPercentage;
  final String bonusType;
  final bool allowBonusWithdrawal;
  final dynamic requireLot;
  final dynamic minDepositAmount;
  final dynamic maxDepositCap;
  final dynamic maxBonusDurationDays;

  EligibleBonus({
    required this.id,
    required this.title,
    required this.bonusPercentage,
    required this.bonusType,
    required this.allowBonusWithdrawal,
    this.requireLot,
    this.minDepositAmount,
    this.maxDepositCap,
    this.maxBonusDurationDays,
  });

  factory EligibleBonus.fromJson(Map<String, dynamic> json) {
    return EligibleBonus(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      bonusPercentage: (json['bonus_percentage'] as num?)?.toInt() ?? 0,
      bonusType: json['bonus_type'] as String? ?? '',
      allowBonusWithdrawal: json['allow_bonus_withdrawal'] as bool? ?? false,
      requireLot: json['require_lot'],
      minDepositAmount: json['min_deposit_amount'],
      maxDepositCap: json['max_deposit_cap'],
      maxBonusDurationDays: json['max_bonus_duration_days'],
    );
  }
}

class DepositRequestModel {
  final int id;
  final String mt5AccountId;
  final String referenceNumber;
  final String amount;
  final String status;
  final String createdAt;

  DepositRequestModel({
    required this.id,
    required this.mt5AccountId,
    required this.referenceNumber,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory DepositRequestModel.fromJson(Map<String, dynamic> json) {
    return DepositRequestModel(
      id: json['id'] as int,
      mt5AccountId: json['mt5_account_id']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class BonusClaim {
  final int id;
  final String mt5Account;
  final String lotSize;
  final String bonusType;
  final bool allowBonusWithdrawal;
  final String bonusPercentage;
  final String bonusAmount;
  final String depositRequestId;
  final String status;
  final String createdAt;
  final String depositAmount;
  // Whether lot tracking applies to this bonus. When the backend sends
  // "N/A" for lot_size / current_lots, we keep the raw string for display
  // and skip progress math entirely.
  final bool hasLotTracking;
  final double currentLots;
  final double totalLots;
  final String claimDate;
  final String remainingDays;

  BonusClaim({
    required this.id,
    required this.mt5Account,
    required this.lotSize,
    required this.bonusType,
    required this.allowBonusWithdrawal,
    required this.bonusPercentage,
    required this.bonusAmount,
    required this.depositRequestId,
    required this.status,
    required this.createdAt,
    required this.depositAmount,
    required this.hasLotTracking,
    required this.currentLots,
    required this.totalLots,
    required this.claimDate,
    required this.remainingDays,
  });

  static double _parseLot(dynamic v) {
    // Backend can send a real number ("0.50", "12.3"), a numeric string, or
    // a sentinel like "N/A" / null. Anything non-numeric becomes 0.0 so
    // casting never throws.
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s.toUpperCase() == 'N/A') return 0.0;
    return double.tryParse(s) ?? 0.0;
  }

  static bool _hasLotValue(dynamic v) {
    if (v == null) return false;
    final s = v.toString().trim();
    return s.isNotEmpty && s.toUpperCase() != 'N/A';
  }

  factory BonusClaim.fromJson(Map<String, dynamic> json) {
    final rawLotSize = json['lot_size'];
    final rawCurrentLots = json['current_lots'];
    final hasTotal = _hasLotValue(rawLotSize);
    final hasCurrent = _hasLotValue(rawCurrentLots);

    return BonusClaim(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mt5Account: json['mt5_account']?.toString() ?? '',
      lotSize: rawLotSize?.toString() ?? 'N/A',
      bonusType: json['bonus_type']?.toString() ?? '',
      allowBonusWithdrawal: json['allow_bonus_withdrawal'] as bool? ?? false,
      bonusPercentage: json['bonus_percentage']?.toString() ?? '',
      bonusAmount: json['bonus_amount']?.toString() ?? '',
      depositRequestId: json['deposit_request_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      depositAmount: json['deposit_amount']?.toString() ?? '',
      hasLotTracking: hasTotal && hasCurrent,
      currentLots: _parseLot(rawCurrentLots),
      totalLots: _parseLot(rawLotSize),
      claimDate: json['claim_date']?.toString() ?? '',
      remainingDays: json['remaining_days']?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class BonusController extends GetxController {
  final tabIndex = 0.obs;

  // Available tab states
  final isLoadingAvailable = false.obs;
  final deposits = <DepositRequestModel>[].obs;
  final eligibleBonusesByDepositId = <String, List<EligibleBonus>>{}.obs;
  final expandedDepositIds = <int>{}.obs;

  // Claim History states
  final isLoadingHistory = false.obs;
  final claims = <BonusClaim>[].obs;
  final claimTotal = 0.obs;
  final claimCurrentPage = 1.obs;
  final claimLastPage = 1.obs;
  final isClaimLoadingMore = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAvailableBonuses();
    fetchClaimHistory();
  }

  void toggleDepositExpanded(int depositId) {
    if (expandedDepositIds.contains(depositId)) {
      expandedDepositIds.remove(depositId);
    } else {
      expandedDepositIds.add(depositId);
    }
    expandedDepositIds.refresh();
  }

  Future<void> fetchAvailableBonuses() async {
    try {
      isLoadingAvailable.value = true;
      final response = await ApiService.get(endpoint: ApiConstants.bonusList);
      if (response.success && response.data != null) {
        final rawData = response.data['data'];
        if (rawData != null) {
          // Parse deposits
          final List<dynamic> depList = rawData['newDepositRequests'] ?? [];
          deposits.value = depList.map((d) => DepositRequestModel.fromJson(d)).toList();

          // Parse eligible bonuses mapping safely
          final rawEligible = rawData['eligibleBonusesByDepositId'];
          final parsedEligible = <String, List<EligibleBonus>>{};
          if (rawEligible != null && rawEligible is Map) {
            rawEligible.forEach((key, val) {
              if (val is List) {
                parsedEligible[key.toString()] = val.map((b) => EligibleBonus.fromJson(b)).toList();
              }
            });
          }
          eligibleBonusesByDepositId.value = parsedEligible;

          // Auto-expand deposits that have bonuses
          expandedDepositIds.clear();
          for (var dep in deposits) {
            final key = dep.id.toString();
            if (parsedEligible[key] != null && parsedEligible[key]!.isNotEmpty) {
              expandedDepositIds.add(dep.id);
            }
          }
          expandedDepositIds.refresh();
        }
      } else {
        CustomToastService.showError(message: response.message ?? 'Failed to load available bonuses');
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error fetching available bonuses: $e');
    } finally {
      isLoadingAvailable.value = false;
    }
  }

  Future<void> fetchClaimHistory({bool loadMore = false}) async {
    if (loadMore) {
      if (claimCurrentPage.value >= claimLastPage.value || isClaimLoadingMore.value) return;
      isClaimLoadingMore.value = true;
    } else {
      isLoadingHistory.value = true;
      claimCurrentPage.value = 1;
    }

    try {
      final queryParams = {
        'page': claimCurrentPage.value.toString(),
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final response = await ApiService.get(
        endpoint: ApiConstants.bonusClaimList,
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final rawData = response.data['data'];
        if (rawData != null) {
          List<dynamic> rawClaims = [];
          if (rawData is List) {
            rawClaims = rawData;
          } else if (rawData is Map) {
            rawClaims = rawData['data'] ?? [];

            final pagination = rawData['pagination'];
            if (pagination != null && pagination is Map) {
              claimCurrentPage.value = (pagination['currentPage'] as num?)?.toInt() ?? 1;
              claimLastPage.value = (pagination['lastPage'] as num?)?.toInt() ?? 1;
              claimTotal.value = (pagination['total'] as num?)?.toInt() ?? 0;
            }
          }
          final parsedClaims = rawClaims.map((c) => BonusClaim.fromJson(c)).toList();

          if (loadMore) {
            claims.addAll(parsedClaims);
          } else {
            claims.value = parsedClaims;
          }
        }
      } else {
        CustomToastService.showError(message: response.message ?? 'Failed to load claim history');
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error fetching claim history: $e');
    } finally {
      isLoadingHistory.value = false;
      isClaimLoadingMore.value = false;
    }
  }

  Future<bool> claimBonusSubmit({
    required int bonusId,
    required int depositId,
    required int percentage,
    required String targetAccount,
  }) async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.bonusClaim,
        data: {
          'bonus_id': bonusId,
          'deposit_id': depositId,
          'selected_percentage': percentage,
          'target_mt5_account': targetAccount,
        },
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message ?? 'Bonus request submitted successfully!',
        );
        // Refresh both lists
        fetchAvailableBonuses();
        fetchClaimHistory();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to submit bonus claim.',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error submitting claim: $e');
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BonusScreen extends StatelessWidget {
  const BonusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.put(BonusController());

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text(
          languageService.tr('more_bonus'),
          style: AppTextStyles.screenTitle,
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            "assets/svg/trade/arro_back.svg",
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
            width: 24.w,
            height: 24.h,
          ),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          children: [
            _buildTabSwitcher(controller),
            SizedBox(height: 16.h),
            Expanded(
              child: Obx(() {
                if (controller.tabIndex.value == 0) {
                  return _buildAvailableTab(context, controller, languageService);
                } else {
                  return _buildHistoryTab(controller, languageService);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB SWITCHER
  // ───────────────────────────────────────────────────────────────────────────
  // Icon + label cards with an underline indicator.
  // Reads cleanly in both light and dark mode and intentionally does NOT look
  // like a segmented (Cupertino) control.
  Widget _buildTabSwitcher(BonusController controller) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EE),
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Obx(
        () => Row(
          children: [
            _buildTabCard(
              controller: controller,
              index: 0,
              icon: Icons.card_giftcard_rounded,
              label: 'Available Bonuses',
            ),
            SizedBox(width: 8.w),
            _buildTabCard(
              controller: controller,
              index: 1,
              icon: Icons.history_rounded,
              label: 'Claim History',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCard({
    required BonusController controller,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isDark = AppColors.isDarkMode;
    final isActive = controller.tabIndex.value == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.tabIndex.value = index,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
          decoration: BoxDecoration(
            // Active: brand-tinted surface (light) / elevated surface (dark).
            // Inactive: transparent. No white pill, no shadows — so it never
            // reads as a Cupertino segmented control.
            color: isActive
                ? (isDark
                    ? const Color(0xFF2C2C2E)
                    : AppColors.primary.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20.h,
                color: isActive
                    ? AppColors.primary
                    : (isDark
                        ? const Color(0xFF9A9AA0)
                        : AppColors.textSecondary),
              ),
              SizedBox(height: 6.h),
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppColors.textPrimary
                      : (isDark
                          ? const Color(0xFF8E8E93)
                          : AppColors.textSecondary),
                ),
              ),
              SizedBox(height: 6.h),
              // Underline indicator — only 24px wide, so it reads as a tab
              // selection cue, not a segmented slider.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2.5.h,
                width: isActive ? 24.w : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AVAILABLE TAB VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAvailableTab(
    BuildContext context,
    BonusController controller,
    LanguageService languageService,
  ) {
    return RefreshIndicator(
      onRefresh: () => controller.fetchAvailableBonuses(),
      color: AppColors.primary,
      child: Obx(() {
        if (controller.isLoadingAvailable.value) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        // Only display deposits that actually have eligible bonuses
        final validDeposits = controller.deposits.where((dep) {
          final key = dep.id.toString();
          final eligible = controller.eligibleBonusesByDepositId[key];
          return eligible != null && eligible.isNotEmpty;
        }).toList();

        if (validDeposits.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 32.h),
              _buildAvailableEmptyState(context),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: validDeposits.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final dep = validDeposits[index];
            final key = dep.id.toString();
            final eligibleList = controller.eligibleBonusesByDepositId[key] ?? [];

            return Obx(() {
              final isExpanded = controller.expandedDepositIds.contains(dep.id);

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isExpanded
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Deposit Request Info Bar
                    InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => controller.toggleDepositExpanded(dep.id),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        child: Row(
                          children: [
                            // Green Deposit Arrow Icon
                            Container(
                              width: 38.w,
                              height: 38.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F9F0),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFAEF1D4)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_downward,
                                size: 18.h,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deposit of \$${dep.amount}',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Ref: ${dep.referenceNumber}  •  Account: ${dep.mt5AccountId}',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Count badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.card_giftcard,
                                    size: 14.h,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${eligibleList.length} ${eligibleList.length == 1 ? "Bonus" : "Bonuses"}',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: 20.h,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded list of eligible bonuses
                    if (isExpanded) ...[
                      Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          children: eligibleList.map((bonus) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: AppColors.isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFFAF9FF),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${bonus.bonusPercentage}%',
                                              style: AppTextStyles.bodyText.copyWith(
                                                fontSize: 26.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF10B981),
                                                height: 1.1,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              '${bonus.bonusType.capitalizeFirst} Bonus',
                                              style: AppTextStyles.bodyText.copyWith(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              'Deposit Bonus available.',
                                              style: AppTextStyles.bodyText.copyWith(
                                                fontSize: 12.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Tag Chip
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          'REQUEST',
                                          style: AppTextStyles.bodyText.copyWith(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  // Allowed groups
                                  Text(
                                    'ALLOWED GROUPS',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2F9F0),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'All Groups',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                Divider(height: 1, color: AppColors.border),
                                SizedBox(height: 12.h),
                                // Details grid
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildDetailItem(
                                      label: 'MAX CAP',
                                      value: bonus.maxDepositCap != null && bonus.maxDepositCap.toString().isNotEmpty
                                          ? '\$${bonus.maxDepositCap}'
                                          : 'None',
                                    ),
                                    _buildDetailItem(
                                      label: 'MIN DEP',
                                      value: bonus.minDepositAmount != null && bonus.minDepositAmount.toString().isNotEmpty
                                          ? '\$${bonus.minDepositAmount}'
                                          : 'Any',
                                    ),
                                    _buildDetailItem(
                                      label: 'DURATION',
                                      value: bonus.maxBonusDurationDays != null && bonus.maxBonusDurationDays.toString().isNotEmpty
                                          ? '${bonus.maxBonusDurationDays} days'
                                          : '∞',
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16.h),
                                // Claim Reward Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 44.h,
                                  child: ElevatedButton(
                                    onPressed: () => _showClaimConfirmationDialog(
                                      context: context,
                                      controller: controller,
                                      bonus: bonus,
                                      deposit: dep,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Claim Reward',
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.isDarkMode ? Colors.black : Colors.white,
                                      ),
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
                ],
              ),
            );
          });
        },
        );
      }),
    );
  }

  Widget _buildDetailItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CLAIM HISTORY TAB VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHistoryTab(BonusController controller, LanguageService languageService) {
    return RefreshIndicator(
      onRefresh: () => controller.fetchClaimHistory(),
      color: AppColors.primary,
      child: Obx(() {
        if (controller.isLoadingHistory.value && controller.claims.isEmpty) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (controller.claims.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 120.h),
              _buildEmptyState(
                iconPath: 'assets/svg/more/bonus.svg',
                message: 'No bonus claims found in your history.',
              ),
            ],
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
              if (controller.claimCurrentPage.value < controller.claimLastPage.value) {
                controller.claimCurrentPage.value++;
                controller.fetchClaimHistory(loadMore: true);
              }
            }
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: controller.claims.length + (controller.isClaimLoadingMore.value ? 1 : 0),
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              if (index == controller.claims.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final claim = controller.claims[index];

              double progressPercent = 0.0;
              if (claim.hasLotTracking && claim.totalLots > 0.0) {
                progressPercent =
                    (claim.currentLots / claim.totalLots).clamp(0.0, 1.0);
              }

              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.4),
                    width: 1,
                  ),
                  boxShadow: !AppColors.isDarkMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Title, Date, Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                claim.bonusAmount,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${claim.bonusPercentage} ${claim.bonusType.capitalizeFirst} Bonus',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusBadge(claim.status),
                            SizedBox(height: 4.h),
                            Text(
                              _formatDateTime(claim.claimDate),
                              style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 11.sp,
                                  color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),
                    Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
                    SizedBox(height: 14.h),

                    // Middle Row: Details Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem(
                          label: 'MT5 ACCOUNT',
                          value: claim.mt5Account,
                        ),
                        _buildDetailItem(
                          label: 'DEPOSIT',
                          value: claim.depositAmount,
                        ),
                        _buildDetailItem(
                          label: 'DEP REF',
                          value: claim.depositRequestId,
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Bottom Section: Progress bar (only when backend reports
                    // real lot values — otherwise show the Remaining Time row).
                    if (claim.hasLotTracking && claim.totalLots > 0.0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Trading Progress',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(progressPercent * 100).toStringAsFixed(1)}%',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 6.h,
                          backgroundColor: AppColors.isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressPercent >= 1.0
                                ? const Color(0xFF10B981)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${claim.currentLots} / ${claim.lotSize} Lots',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_filled_rounded,
                                size: 12.h,
                                color: claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                    ? const Color(0xFFEF4444)
                                    : AppColors.textSecondary,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                    ? 'Expired'
                                    : '${claim.remainingDays} left',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                      ? const Color(0xFFEF4444)
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining Time',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_filled_rounded,
                                size: 12.h,
                                color: claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                    ? const Color(0xFFEF4444)
                                    : AppColors.textSecondary,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                    ? 'Expired'
                                    : claim.remainingDays,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: claim.remainingDays.isEmpty || claim.remainingDays.toLowerCase().contains('expired')
                                      ? const Color(0xFFEF4444)
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // Helper date formatter
  String _formatDateTime(String utcStr) {
    try {
      final dt = DateTime.parse(utcStr).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return utcStr;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.capitalizeFirst ?? '';

    switch (status.toLowerCase()) {
      case 'approved':
      case 'success':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String iconPath, required String message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconPath,
                width: 36.w,
                height: 36.h,
                colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableEmptyState(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 48.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/svg/more/bonus.svg',
              width: 36.w,
              height: 36.h,
              colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No Eligible Deposits Found',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'You have no recent deposits that are eligible for a bonus claim right now.',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: 180.w,
            height: 44.h,
            child: ElevatedButton(
              onPressed: () {
                String primaryAccountNumber = '';
                try {
                  final dashboard = Get.find<DashboardController>();
                  if (dashboard.mt5Accounts.isNotEmpty) {
                    primaryAccountNumber = dashboard.mt5Accounts.first.metaAccountNumber;
                  }
                } catch (_) {}

                Get.to(
                  () => PaymentMethodsScreen(accountNumber: primaryAccountNumber),
                  arguments: {
                    'from': 'bonus',
                    'accountNumber': primaryAccountNumber,
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.isDarkMode ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Make a Deposit',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CLAIM CONFIRMATION DIALOG
  // ───────────────────────────────────────────────────────────────────────────
  void _showClaimConfirmationDialog({
    required BuildContext context,
    required BonusController controller,
    required EligibleBonus bonus,
    required DepositRequestModel deposit,
  }) {
    final claimLoading = false.obs;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              padding: EdgeInsets.all(20.w),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32.w,
                            height: 32.h,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.card_giftcard,
                              size: 18.h,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Bonus Confirmation',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Icon(
                          Icons.close,
                          size: 20.h,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Paragraph text
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: 'You are about to claim the '),
                        TextSpan(
                          text: '${bonus.bonusPercentage}% ${bonus.bonusType}',
                          style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' bonus.'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Detailed grids row
                  Row(
                    children: [
                      Expanded(
                        child: _buildModalDetailBox(
                          label: 'MAX CAP',
                          value: bonus.maxDepositCap != null && bonus.maxDepositCap.toString().isNotEmpty
                              ? '\$${bonus.maxDepositCap}'
                              : 'Unlimited',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildModalDetailBox(
                          label: 'DURATION',
                          value: bonus.maxBonusDurationDays != null && bonus.maxBonusDurationDays.toString().isNotEmpty
                              ? '${bonus.maxBonusDurationDays} days'
                              : 'Unlimited',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildModalDetailBox(
                          label: 'MIN DEPOSIT',
                          value: bonus.minDepositAmount != null && bonus.minDepositAmount.toString().isNotEmpty
                              ? '\$${bonus.minDepositAmount}'
                              : 'Any',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Allowed accounts / groups
                  Text(
                    'ALLOWED ACCOUNTS / GROUPS',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F9F0),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'All Groups',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Actions row
                  Obx(() {
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: OutlinedButton(
                              onPressed: claimLoading.value ? null : () => Get.back(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.isDarkMode
                                      ? AppColors.border
                                      : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Cancel',
                                  maxLines: 1,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: ElevatedButton(
                              onPressed: claimLoading.value
                                  ? null
                                  : () async {
                                      claimLoading.value = true;
                                      final success = await controller.claimBonusSubmit(
                                        bonusId: bonus.id,
                                        depositId: deposit.id,
                                        percentage: bonus.bonusPercentage,
                                        targetAccount: deposit.mt5AccountId,
                                      );
                                      claimLoading.value = false;
                                      if (success) {
                                        Get.back();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.border,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                elevation: 0,
                              ),
                              child: claimLoading.value
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.isDarkMode ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Confirm & Claim',
                                        maxLines: 1,
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.isDarkMode ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1.drive(Tween<double>(begin: 0.8, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildModalDetailBox({required String label, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 8.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
