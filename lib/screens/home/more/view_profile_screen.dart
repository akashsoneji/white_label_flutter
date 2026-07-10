import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/edit_profile_controller.dart';
import 'package:crm_app/services/dropdown_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Read-only profile view shown when the user's profile is fully verified.
/// Designed to look polished in both light & dark mode (uses AppColors which
/// already switches on theme).
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final LanguageService languageService = Get.find<LanguageService>();
  final EditProfileController controller = Get.put(EditProfileController());
  late final DropdownService dropdownService;

  @override
  void initState() {
    super.initState();
    dropdownService = Get.find<DropdownService>();
  }

  String _safe(String value) => value.trim().isEmpty ? '—' : value.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        title: Text(
          languageService.tr('view_profile'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isInitializing.value) {
          return Center(
            child: CommonLoadingWidget(
              size: 50.0,
              color: AppColors.primary,
            ),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48.h, color: AppColors.error),
                  SizedBox(height: 16.h),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subheading
                        .copyWith(color: AppColors.error),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: controller.initializeData,
                    child: Text(languageService.tr('edit_profile_retry')),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16.w,
            8.h,
            16.w,
            24.h + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              SizedBox(height: 18.h),
              _buildSection(
                title: languageService.tr('edit_profile_personal_info'),
                children: [
                  _row(
                    icon: Icons.badge_outlined,
                    label: languageService.tr('kyc_details_title'),
                    value: _safe(controller.title.value),
                  ),
                  _row(
                    icon: Icons.person_outline,
                    label: languageService.tr('edit_profile_first_name'),
                    value: _safe(controller.firstName.value),
                  ),
                  _row(
                    icon: Icons.person_outline,
                    label: languageService.tr('edit_profile_last_name'),
                    value: _safe(controller.lastName.value),
                  ),
                  _row(
                    icon: Icons.wc_outlined,
                    label: languageService.tr('edit_profile_gender'),
                    value: _safe(controller.gender.value),
                  ),
                  _row(
                    icon: Icons.cake_outlined,
                    label: languageService.tr('edit_profile_date_of_birth'),
                    value: _safe(controller.dateOfBirth.value),
                    isLast: true,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              _buildSection(
                title: languageService.tr('edit_profile_contact_info'),
                children: [
                  _row(
                    icon: Icons.email_outlined,
                    label: languageService.tr('edit_profile_email'),
                    value: _safe(controller.email.value),
                    verified: true,
                  ),
                  _row(
                    icon: Icons.phone_outlined,
                    label: languageService.tr('edit_profile_mobile_number'),
                    value: _safe(controller.phone.value),
                    verified: true,
                    isLast: true,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              _buildSection(
                title: languageService.tr('edit_profile_address_info'),
                children: [
                  _row(
                    icon: Icons.public_outlined,
                    label: languageService.tr('register_country'),
                    value: _safe(dropdownService.selectedCountryText),
                  ),
                  _row(
                    icon: Icons.map_outlined,
                    label: languageService.tr('edit_profile_state'),
                    value: _safe(dropdownService.selectedStateText),
                  ),
                  _row(
                    icon: Icons.location_city_outlined,
                    label: languageService.tr('edit_profile_city'),
                    value: _safe(dropdownService.selectedCityText),
                  ),
                  _row(
                    icon: Icons.home_outlined,
                    label: languageService.tr('register_address'),
                    value: _safe(controller.address.value),
                  ),
                  _row(
                    icon: Icons.markunread_mailbox_outlined,
                    label: languageService.tr('edit_profile_postcode'),
                    value: _safe(controller.postcode.value),
                    isLast: true,
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _buildVerifiedFooter(),
            ],
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header (avatar + name + verified badge)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final fullName =
        '${controller.firstName.value} ${controller.lastName.value}'.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person,
                  size: 38.r,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified,
                    size: 18.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? '—' : fullName,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _safe(controller.email.value),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12.sp,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        languageService.tr('profile_verified'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reusable section card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey.withValues(alpha: 0.75),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.icongrey.withValues(alpha: 0.14),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Field row (label + value)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    bool verified = false,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.icongrey.withValues(alpha: 0.14),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (verified)
            Icon(
              Icons.verified,
              size: 18.sp,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildVerifiedFooter() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => {},
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 18.sp, color: AppColors.primary),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  languageService.tr('view_profile_readonly_note'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
