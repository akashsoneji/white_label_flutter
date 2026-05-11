import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/kyc/view_models/kyc_bank_controller.dart';
import 'package:crm_app/models/bank_withdralList_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';

class BankListScreen extends StatefulWidget {
  const BankListScreen({Key? key}) : super(key: key);

  @override
  State<BankListScreen> createState() => _BankListScreenState();
}

class _BankListScreenState extends State<BankListScreen> {
  final KycBankController controller = Get.put(KycBankController());
  final RxMap<int, bool> expandedItems = <int, bool>{}.obs;
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    // Fetch withdrawal list when screen loads
    controller.fetchWithdrawalList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(closeOverlays: true),
          icon: SvgPicture.asset('assets/svg/trade/arro_back.svg'),
        ),
        title: Text(
          'Withdrawal Method',
          style: AppTextStyles.heading.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              // Navigate to KYC bank screen to add new withdrawal method
              // Refresh list when returning with result
              Get.toNamed(
                AppPages.KYC_BANK,
                arguments: {
                  'screen_name': 'Withdrawal Method',
                  'isFromKYC': false,
                },
              )?.then((result) {
                // Refresh list when returning (result will be true if submission was successful)
                if (result == true && mounted) {
                  Future.delayed(Duration(milliseconds: 200), () {
                    if (mounted) {
                      controller.fetchWithdrawalList();
                    }
                  });
                }
              });
            },
            icon: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.add, color: AppColors.textPrimary, size: 20.sp),
            ),
          ),
        ],
      ),
      body: Obx(() {
        // Show loading indicator while fetching data
        if (controller.isLoading.value) {
          return Center(
            child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
          );
        }

        // After loading completes, show data or empty state
        final list = controller.bankWithdrawalList;

        if (list.isEmpty) {
          return _buildEmptyState();
        }

        return _buildWithdrawalList();
      }),
    );
  }

  // Empty state when no withdrawal methods exist
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 60.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Withdrawal Methods',
              style: AppTextStyles.heading.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You haven\'t added any withdrawal methods yet.\nAdd your first withdrawal method to get started.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                // Navigate to KYC bank screen to add new withdrawal method
                // Refresh list when returning with result
                Get.toNamed(
                  AppPages.KYC_BANK,
                  arguments: {
                    'screen_name': 'Withdrawal Method',
                    'isFromKYC': false,
                  },
                )?.then((result) {
                  // Refresh list when returning (result will be true if submission was successful)
                  if (result == true && mounted) {
                    Future.delayed(Duration(milliseconds: 200), () {
                      if (mounted) {
                        controller.fetchWithdrawalList();
                      }
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Add Withdrawal Method',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List of withdrawal methods
  Widget _buildWithdrawalList() {
    return RefreshIndicator(
      onRefresh: () async {
        await controller.fetchWithdrawalList();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          itemCount: controller.bankWithdrawalList.length,
          itemBuilder: (context, index) {
            final method = controller.bankWithdrawalList[index];
            return _buildWithdrawalItem(method);
          },
        ),
      ),
    );
  }

  // Individual withdrawal method item
  Widget _buildWithdrawalItem(WithdrawalMethods method) {
    final isExpanded =
        method.id != null ? (expandedItems[method.id!] ?? false) : false;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Main item content
          ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 8.h,
            ),
            onTap: () {
              if (method.id != null) {
                setState(() {
                  expandedItems[method.id!] = !isExpanded;
                });
              }
            },
            title: Text(
              _getDisplayTitle(method),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _getDisplaySubtitle(method),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusBadge(method.status),
                SizedBox(width: 8.w),
                AnimatedRotation(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  turns: isExpanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.icongrey,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),

          // Expanded details with smooth animation
          AnimatedSize(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                isExpanded ? _buildExpandedDetails(method) : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Status badge
  Widget _buildStatusBadge(String? status) {
    Color badgeColor;
    switch (status?.toLowerCase()) {
      case 'approved':
        badgeColor = const Color(0xFF4CAF50);
        break;
      case 'rejected':
        badgeColor = const Color(0xFFF44336);
        break;
      case 'pending':
        badgeColor = const Color(0xFFFF9800);
        break;
      default:
        badgeColor = const Color(0xFF9E9E9E);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        status?.toUpperCase() ?? 'UNKNOWN',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.whiteColor,
        ),
      ),
    );
  }

  // Helper method to check if a value is not null and not empty
  bool _hasValue(String? value) {
    return value != null && value.isNotEmpty;
  }

  // Expanded details section
  Widget _buildExpandedDetails(WithdrawalMethods method) {
    final methodType = method.withdrawalMethod?.toLowerCase() ?? '';
    final List<Widget> detailRows = [];

    // Show method-specific fields based on withdrawal method type
    if (methodType == 'bank') {
      // Bank method: show bankName, bankAccountNo, ifscIban, holderName, currency, relationship
      if (_hasValue(method.bankName)) {
        detailRows.add(_buildDetailRow('Bank Name', method.bankName!));
      }
      if (_hasValue(method.bankAccountNo)) {
        detailRows.add(
          _buildDetailRow('Bank Account No.', method.bankAccountNo!),
        );
      }
      if (_hasValue(method.ifscIban)) {
        detailRows.add(_buildDetailRow('IBAN/IFSC Code', method.ifscIban!));
      }
    } else if (methodType == 'upi') {
      // UPI method: show upiAddress, holderName, currency, relationship
      if (_hasValue(method.upiAddress)) {
        detailRows.add(_buildDetailRow('UPI Address', method.upiAddress!));
      }
    } else if (methodType == 'crypto') {
      // Crypto method: show cryptoAddress, holderName, currency, relationship
      if (_hasValue(method.cryptoAddress)) {
        detailRows.add(
          _buildDetailRow('Crypto Address', method.cryptoAddress!),
        );
      }
    }

    // Common fields for all methods
    if (_hasValue(method.holderName)) {
      detailRows.add(
        _buildDetailRow('Account Holder Name', method.holderName!),
      );
    }
    if (_hasValue(method.currency)) {
      detailRows.add(_buildDetailRow('Currency', method.currency!));
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.r),
          bottomRight: Radius.circular(12.r),
        ),
      ),
      child: Column(children: detailRows),
    );
  }

  // Detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get display title for withdrawal method
  String _getDisplayTitle(WithdrawalMethods method) {
    switch (method.withdrawalMethod?.toLowerCase()) {
      case 'bank':
        final accountNo = method.bankAccountNo ?? '';
        final last4 =
            accountNo.length > 4
                ? accountNo.substring(accountNo.length - 4)
                : accountNo;
        return '${method.bankName ?? 'Bank'} - $last4';
      case 'upi':
        return 'UPI';
      case 'crypto':
        return 'Crypto';
      default:
        final methodName = method.withdrawalMethod ?? 'Unknown';
        return methodName[0].toUpperCase() + methodName.substring(1);
    }
  }

  // Get display subtitle for withdrawal method
  String _getDisplaySubtitle(WithdrawalMethods method) {
    switch (method.withdrawalMethod?.toLowerCase()) {
      case 'bank':
        return method.holderName ?? '';
      case 'upi':
        return method.upiAddress ?? '';
      case 'crypto':
        return method.cryptoAddress ?? '';
      default:
        return '';
    }
  }
}
