import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/kyc/view_models/kyc_bank_controller.dart';
import 'package:crm_app/models/bank_withdralList_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/authenticated_network_image.dart';

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
        leading: const AppBackButton(),
        title: Text(
          languageService.tr('withdrawal_withdrawalMethod'),
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
              languageService.tr('bank_list_screen_no_withdrawal_methods'),
              style: AppTextStyles.heading.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              languageService.tr(
                'bank_list_screen_you_haven_added_any_withdrawal_methods',
              ),
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
                languageService.tr('bank_list_screen_add_withdrawal_method'),
                style: AppTextStyles.bodyText.copyWith(
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
        padding: EdgeInsets.only(bottom: kBottomNavigationBarHeight),
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
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _getDisplaySubtitle(method),
              style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textSecondary),
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
        badgeColor = AppColors.success;
        break;
      case 'rejected':
        badgeColor = AppColors.error;
        break;
      case 'pending':
        badgeColor = AppColors.warning;
        break;
      default:
        badgeColor = AppColors.textGrey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        status?.toUpperCase() ?? 'UNKNOWN',
        style: AppTextStyles.bodyText.copyWith(
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
        detailRows.add(
          _buildDetailRow(
            languageService.tr('bank_list_screen_bank_name'),
            method.bankName!,
          ),
        );
      }
      if (_hasValue(method.bankAccountNo)) {
        detailRows.add(
          _buildDetailRow(
            languageService.tr('bank_list_screen_bank_account_no'),
            method.bankAccountNo!,
          ),
        );
      }
      if (_hasValue(method.ifscIban)) {
        detailRows.add(
          _buildDetailRow(
            languageService.tr('bank_list_screen_iban_ifsc_code'),
            method.ifscIban!,
          ),
        );
      }
    } else if (methodType == 'upi') {
      // UPI method: show upiAddress, holderName, currency, relationship
      if (_hasValue(method.upiAddress)) {
        detailRows.add(
          _buildDetailRow(
            languageService.tr('bank_list_screen_upi_address'),
            method.upiAddress!,
          ),
        );
      }
    } else if (methodType == 'crypto') {
      // Crypto method: show cryptoAddress, holderName, currency, relationship
      if (_hasValue(method.cryptoAddress)) {
        detailRows.add(
          _buildDetailRow(
            languageService.tr('bank_list_screen_crypto_address'),
            method.cryptoAddress!,
          ),
        );
      }
    }

    // Common fields for all methods
    if (_hasValue(method.holderName)) {
      detailRows.add(
        _buildDetailRow(
          languageService.tr('bank_list_screen_account_holder_name'),
          method.holderName!,
        ),
      );
    }
    if (_hasValue(method.currency)) {
      detailRows.add(
        _buildDetailRow(
          languageService.tr('common_currency'),
          method.currency!,
        ),
      );
    }
    if (_hasValue(method.cryptoNetwork)) {
      detailRows.add(
        _buildDetailRow(
          languageService.tr('bank_list_screen_network'),
          method.cryptoNetwork!,
        ),
      );
    }

    // Proof image — fetched with auth header, tap to open full-screen view.
    // Stored proof paths are not publicly reachable, so load it through
    // `image-proxy/{id}` like the web portal does.
    if (_hasValue(method.proofImg)) {
      final proofUrl = method.id != null
          ? '${ApiConstants.baseUrl}${ApiConstants.withdrawalImageProxy(method.id!)}'
          : method.proofImg!;
      detailRows.add(
        Padding(
          padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageService.tr('bank_list_screen_proof'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () => _openProofViewer(proofUrl),
                child: AuthenticatedNetworkImage(
                  url: proofUrl,
                  width: double.infinity,
                  height: 180.h,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (method.id != null) {
      final id = method.id!;
      detailRows.add(
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Obx(() {
            final deleting = controller.deletingIds.contains(id);
            return TextButton.icon(
              onPressed: deleting ? null : () => _confirmDelete(id),
              icon: deleting
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : Icon(Icons.delete_outline, size: 18.sp, color: AppColors.error),
              label: Text(
                languageService.tr('bank_list_delete'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            );
          }),
        ),
      );
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

  void _confirmDelete(int id) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          languageService.tr('bank_list_delete_title'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          languageService.tr('bank_list_delete_message'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(languageService.tr('bank_list_delete_cancel')),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteWithdrawalMethod(id);
            },
            child: Text(
              languageService.tr('bank_list_delete'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
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
              style: AppTextStyles.bodyText.copyWith(
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
              style: AppTextStyles.bodyText.copyWith(
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

  // Full-screen proof image viewer with pinch-to-zoom.
  void _openProofViewer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProofImageViewer(url: url),
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
        return '${method.bankName ?? languageService.tr('withdrawal_bank')} - $last4';
      case 'upi':
        return 'UPI';
      case 'crypto':
        return 'Crypto';
      default:
        final methodName =
            method.withdrawalMethod ??
            languageService.tr('bank_list_screen_unknown');
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

/// Full-screen viewer for the proof image. Pinch-to-zoom is delegated to
/// [InteractiveViewer] which gives natural pan + scale gestures out of the
/// box. The image is fetched via [AuthenticatedNetworkImage] so the auth
/// token is attached.
class _ProofImageViewer extends StatelessWidget {
  const _ProofImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          TranslationUtils.tr('bank_list_screen_proof'),
          style: AppTextStyles.bodyText.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: AuthenticatedNetworkImage(
            url: url,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
