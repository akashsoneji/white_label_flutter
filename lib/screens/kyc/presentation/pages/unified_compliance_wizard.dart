import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/models/dropdown_models.dart';
import 'package:crm_app/screens/kyc/view_models/compliance_controller.dart';

class UnifiedComplianceWizard extends StatefulWidget {
  const UnifiedComplianceWizard({Key? key}) : super(key: key);

  @override
  State<UnifiedComplianceWizard> createState() => _UnifiedComplianceWizardState();
}

class _UnifiedComplianceWizardState extends State<UnifiedComplianceWizard> {
  late final ComplianceController controller;
  late final LanguageService languageService;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = Get.put(ComplianceController());
    languageService = Get.find<LanguageService>();
    controller.fetchRegulationSchema();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Obx(() {
        final step = controller.currentStep.value;
        return Scaffold(
          backgroundColor: AppColors.scaffold,
          appBar: AppBar(
            backgroundColor: AppColors.card,
            elevation: 0.5,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              'KYC Verification',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.textPrimary.withOpacity(0.6)),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14.w,
                    color: AppColors.textPrimary,
                  ),
                ),
                onPressed: _showExitConfirmation,
              ),
              SizedBox(width: 12.w),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildStepper(),
                Expanded(
                  child: controller.isSchemaLoading.value
                      ? Center(
                          child: CommonLoadingWidget(
                            message: 'Loading details...',
                            size: 40.0,
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          child: _buildCurrentStepChild(step),
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomActionBar(step),
        );
      }),
    );
  }

  // --- Exit Confirmation Dialog ---
  void _showExitConfirmation() {
    Get.dialog(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: AlertDialog(
          backgroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Get.back(closeOverlays: true),
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.icongrey),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14.w,
                      color: AppColors.icongrey,
                    ),
                  ),
                ),
              ),
              SvgPicture.asset(
                'assets/svg/kyc/personalcard.svg',
                height: 60.h,
                width: 60.w,
                color: AppColors.primary,
              ),
              SizedBox(height: 16.h),
              Text('Verify Later?', style: AppTextStyles.black16600),
            ],
          ),
          content: Text(
            'You can continue later, but you won\'t get all benefits until verification is complete',
            style: AppTextStyles.grey14400h57,
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Get.back(closeOverlays: true);
                      Get.offAllNamed('/trading');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withAlpha(20),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Verify\nLater',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(closeOverlays: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Resolves child widget based on step
  Widget _buildCurrentStepChild(int step) {
    try {
      switch (step) {
        case 0:
          return _buildStep1ProfileAndCompliance();
        case 1:
          return _buildStep2Documents();
        case 2:
          return _buildStep3Review();
        default:
          return _buildStep4Complete();
      }
    } catch (e, stack) {
      return Container(
        padding: EdgeInsets.all(16.w),
        margin: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rendering Error (Step $step):',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              e.toString(),
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              stack.toString(),
              style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 10.sp),
            ),
          ],
        ),
      );
    }
  }

  // --- UI Stepper Header ---
  Widget _buildStepper() {
    final step = controller.currentStep.value;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildStepNode(0, '1', 'Profile', step >= 0),
              _buildStepLine(step >= 1),
              _buildStepNode(1, '2', 'Documents', step >= 1),
              _buildStepLine(step >= 2),
              _buildStepNode(2, '3', 'Review', step >= 2),
              _buildStepLine(step >= 3),
              _buildStepNode(3, '4', 'Complete', step >= 3),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            step == 0
                ? 'Complete Your Profile'
                : step == 1
                    ? 'Upload Documents'
                    : step == 2
                        ? 'Review and Submit'
                        : 'Verification Submitted',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            step == 0
                ? 'Please provide your personal details to continue'
                : step == 1
                    ? 'Please upload front and back pictures of verification proofs'
                    : step == 2
                        ? 'Confirm details before finishing'
                        : 'Your details have been successfully saved',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String num, String label, bool isActive) {
    final isCurrent = controller.currentStep.value == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary
                : isActive
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
            border: Border.all(
              color: isCurrent
                  ? AppColors.primary
                  : isActive
                      ? AppColors.primary.withOpacity(0.4)
                      : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: isCurrent
                    ? Colors.white
                    : isActive
                        ? AppColors.primary
                        : AppColors.textGrey,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.textGrey,
          ),
        )
      ],
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 16.h),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2.h,
          decoration: BoxDecoration(
            color: isDone ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
      ),
    );
  }

  // --- Step 1 Layout (Profile Info + Residential Address + Compliance Form) ---
  Widget _buildStep1ProfileAndCompliance() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile loaded banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.isDarkMode ? Colors.green.withOpacity(0.08) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.isDarkMode ? Colors.green.withOpacity(0.3) : const Color(0xFFDCFCE7)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: const Color(0xFF16A34A), size: 18.w),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Profile details loaded dynamically from client database.',
                    style: TextStyle(fontSize: 11.5.sp, color: const Color(0xFF15803D), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Card 1: Basic Profile Information
          _buildPremiumSectionCard(
            title: 'Basic Profile Information',
            icon: Icons.person_pin_rounded,
            children: [
              _buildFormRow(
                _buildFormInput('email', 'Email Address', isRequired: true, readOnly: true, prefixIcon: Icons.email_outlined),
                _buildFormInput('mobile', 'Mobile Number', isRequired: true, isPhone: true, prefixIcon: Icons.phone_android_outlined),
              ),
              SizedBox(height: 14.h),
              _buildFormRow(
                _buildFormInput('first_name', 'First Name', isRequired: true, prefixIcon: Icons.badge_outlined),
                _buildFormInput('last_name', 'Last Name', isRequired: true, prefixIcon: Icons.badge_outlined),
              ),
              SizedBox(height: 14.h),
              _buildOptionsDropdownField(
                label: 'Title Selector',
                fieldKey: 'title',
                options: const [
                  {'value': 'Mr', 'label': 'Mr'},
                  {'value': 'Mrs', 'label': 'Mrs'},
                  {'value': 'Ms', 'label': 'Ms'},
                  {'value': 'Dr', 'label': 'Dr'},
                  {'value': 'Other', 'label': 'Other'},
                ],
              ),
              SizedBox(height: 14.h),
              _buildOptionsDropdownField(
                label: 'Gender Selector',
                fieldKey: 'gender',
                options: const [
                  {'value': 'male', 'label': '♂ Male'},
                  {'value': 'female', 'label': '♀ Female'},
                  {'value': 'other', 'label': 'Other'},
                ],
              ),
              SizedBox(height: 14.h),
              _buildDatePickerInput('dob', 'Date of Birth (DD-MM-YYYY)', isRequired: true, prefixIcon: Icons.calendar_today_outlined),
            ],
          ),

          SizedBox(height: 20.h),

          // Card 2: Residential Address
          _buildPremiumSectionCard(
            title: 'Residential Address',
            icon: Icons.map_rounded,
            children: [
              _buildFormRow(
                _buildLocationDropdown(
                  label: 'Country',
                  type: 'country',
                  prefixIcon: Icons.public_rounded,
                  isRequired: true,
                ),
                _buildFormInput('nationality', 'Nationality', isRequired: true, prefixIcon: Icons.flag_outlined),
              ),
              SizedBox(height: 14.h),
              _buildFormRow(
                _buildLocationDropdown(
                  label: 'State',
                  type: 'state',
                  prefixIcon: Icons.landscape_outlined,
                  isRequired: true,
                ),
                _buildLocationDropdown(
                  label: 'City',
                  type: 'city',
                  prefixIcon: Icons.location_city_outlined,
                  isRequired: true,
                ),
              ),
              SizedBox(height: 14.h),
              _buildFormRow(
                _buildFormInput('address_1', 'Address Line 1', isRequired: true, prefixIcon: Icons.location_on_outlined),
                _buildFormInput('address_2', 'Address Line 2 (Optional)', prefixIcon: Icons.location_on_outlined),
              ),
              SizedBox(height: 14.h),
              _buildFormInput('postcode', 'Pincode / ZIP', isRequired: true, prefixIcon: Icons.pin_drop_outlined),
            ],
          ),

          SizedBox(height: 20.h),

          // Card 3: Compliance & Questionnaire
          _buildPremiumSectionCard(
            title: 'Compliance Information',
            icon: Icons.gavel_rounded,
            children: [
              _buildComplianceSchemaFields(),
            ],
          ),
        ],
      ),
    );
  }

  // Group inputs inside premium visual card containers
  Widget _buildPremiumSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20.w),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border, thickness: 0.8, height: 24.h),
          ...children,
        ],
      ),
    );
  }

  // --- Dynamic Schema Mapping Renderers ---
  Widget _buildComplianceSchemaFields() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.schemaFields.length,
      itemBuilder: (context, index) {
        final field = controller.schemaFields[index];
        if (field is! Map<String, dynamic>) return const SizedBox.shrink();
        
        if (!controller.isFieldVisible(field)) {
          return const SizedBox.shrink();
        }

        final type = field['field_type']?.toString() ?? '';
        final key = field['field_key']?.toString() ?? '';
        final label = field['label']?.toString() ?? '';
        final isRequired = field['is_required'] == true;

        if (type == 'info') {
          return Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 14.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.isDarkMode ? AppColors.surface : const Color(0xFFFBF8F6),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.isDarkMode ? AppColors.border : const Color(0xFFEEE5E0)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.isDarkMode ? AppColors.textPrimary : const Color(0xFF85533A),
              ),
            ),
          );
        }

        if (type == 'radio') {
          // The title selector (Mr/Mrs/...) is rendered as a normal
          // dropdown field with a bottom-sheet picker instead of the
          // segment-card style used for other radio fields.
          final List options = field['options'] is List ? field['options'] as List : [];
          if (key == 'title') {
            final currentVal = controller.formAnswers[key] ?? '';
            final selectedLabel = options
                    .firstWhereOrNull((opt) => opt['value']?.toString() == currentVal)
                    ?['label']
                    ?.toString() ??
                'Select...';
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel(label, isRequired),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () => _showOptionsSelectorBottomSheet(key, label, options),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.textFieldBg,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 16.w),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              selectedLabel,
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                color: currentVal.isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                fontWeight: currentVal.isEmpty ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.unfold_more_rounded, color: AppColors.textGrey, size: 18.w),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Sleek horizontal visual selector cards for other radio fields
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputLabel(label, isRequired),
                SizedBox(height: 6.h),
                _buildVisualSelectableCards(key, options),
              ],
            ),
          );
        }

        if (type == 'select') {
          final List options = field['options'] is List ? field['options'] as List : [];
          final currentVal = controller.formAnswers[key] ?? '';
          final selectedLabel = options.firstWhereOrNull((opt) => opt['value']?.toString() == currentVal)?['label']?.toString() ?? 'Select Option...';

          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputLabel(label, isRequired),
                SizedBox(height: 6.h),
                GestureDetector(
                  onTap: () => _showOptionsSelectorBottomSheet(key, label, options),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.textFieldBg,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.layers_outlined, color: AppColors.primary, size: 16.w),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            selectedLabel,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: currentVal.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                              fontWeight: currentVal.isEmpty ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.unfold_more_rounded, color: AppColors.textGrey, size: 18.w),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel(label, isRequired),
              SizedBox(height: 6.h),
              TextFormField(
                initialValue: controller.formAnswers[key]?.toString() ?? '',
                onChanged: (val) {
                  controller.formAnswers[key] = val;
                },
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Enter details...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 18.w),
                  filled: true,
                  fillColor: AppColors.textFieldBg,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (value) {
                  if (isRequired && (value == null || value.trim().isEmpty)) {
                    return 'Field is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // SLEEK visual tab card selectors for choice/radios (Yes/No card selector)
  Widget _buildVisualSelectableCards(String key, List options) {
    final currentVal = controller.formAnswers[key] ?? '';
    return Row(
      children: options.map((opt) {
        final String val = opt['value']?.toString() ?? '';
        final String label = opt['label']?.toString() ?? '';
        final isSelected = currentVal == val;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              controller.formAnswers[key] = val;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: opt == options.last ? 0 : 10.w),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.06)
                    : AppColors.textFieldBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AppColors.primary : AppColors.textGrey,
                    size: 16.w,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Step 2 Layout (KYC Documents Upload) ---
  Widget _buildStep2Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green success details box
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.isDarkMode ? Colors.green.withOpacity(0.08) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.isDarkMode ? Colors.green.withOpacity(0.3) : const Color(0xFFDCFCE7)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF16A34A), size: 18.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Your profile details have been saved. Please upload the required documents.',
                  style: TextStyle(fontSize: 12.sp, color: const Color(0xFF15803D), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        Text(
          'Upload Verification Documents',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        SizedBox(height: 2.h),
        Text(
          'Supported formats: JPG, PNG, PDF (Max 15MB each)',
          style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 16.h),

        // Upload Card 1: Identity Proof
        _buildUploadCard(
          title: 'Identity Document',
          subtitle: 'Passport, National ID or Driver\'s License',
          frontKey: 'identity_front',
          backKey: 'identity_back',
          frontFile: controller.idProofFront.value,
          backFile: controller.idProofBack.value,
        ),
        SizedBox(height: 16.h),

        // Upload Card 2: Address Proof
        _buildUploadCard(
          title: 'Address Proof',
          subtitle: 'Utility bill, Bank statement, or official letter',
          frontKey: 'address_front',
          backKey: 'address_back',
          frontFile: controller.addressProofFront.value,
          backFile: controller.addressProofBack.value,
        ),
        SizedBox(height: 16.h),

        // Summary
        _buildUploadSummary(),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required String frontKey,
    required String backKey,
    required File? frontFile,
    required File? backFile,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.primary, size: 18.w),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildUploadBox(
                  label: 'Front Side',
                  key: frontKey,
                  file: frontFile,
                  isRequired: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildUploadBox(
                  label: 'Back Side',
                  key: backKey,
                  file: backFile,
                  isRequired: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox({
    required String label,
    required String key,
    required File? file,
    required bool isRequired,
  }) {
    final hasFile = file != null;
    final isImage = hasFile && (
      file.path.toLowerCase().endsWith('.png') ||
      file.path.toLowerCase().endsWith('.jpg') ||
      file.path.toLowerCase().endsWith('.jpeg')
    );

    return AspectRatio(
      aspectRatio: 1.25,
      child: GestureDetector(
        onTap: () => controller.pickDocument(key),
        child: Container(
          decoration: BoxDecoration(
            color: hasFile
                ? AppColors.primary.withOpacity(0.01)
                : AppColors.textFieldBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasFile ? AppColors.primary : AppColors.border,
              width: hasFile ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasFile) ...[
                if (isImage)
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 36.w),
                        SizedBox(height: 4.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            file.path.split('/').last,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: GestureDetector(
                    onTap: () {
                      controller.clearDocument(key);
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 14.w,
                      ),
                    ),
                  ),
                ),
                
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    color: Colors.black.withOpacity(0.65),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ] else ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                        size: 20.w,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? Colors.red.withOpacity(0.08)
                            : AppColors.textGrey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        isRequired ? 'Required' : 'Optional',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: isRequired ? Colors.red : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSummary() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Details Summary', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Required Documents Selected:', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
              Text('${controller.getRequiredCount()}/2', style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Optional Documents Selected:', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
              Text('${controller.getOptionalCount()}/2', style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Combined Upload Size:', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
              Text(controller.getUploadedSizeSummary(), style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Step 3 Layout (Review Summary Screen before Final Submission) ---
  Widget _buildStep3Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium double check alert
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.primary, size: 20.w),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Please confirm that all details entered below are 100% accurate and match your uploaded documents.',
                  style: TextStyle(
                    fontSize: 11.5.sp, 
                    color: AppColors.primary, 
                    fontWeight: FontWeight.w700, 
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // Profile & Address Card
        _buildReviewSectionCard('Profile & Address Details', {
          'Name': '${controller.formAnswers['first_name'] ?? ''} ${controller.formAnswers['last_name'] ?? ''}'.trim(),
          'Email': controller.formAnswers['email']?.toString() ?? '',
          'Mobile': controller.formAnswers['mobile']?.toString() ?? '',
          'Gender / Date of Birth': '${controller.formAnswers['gender']?.toString().toUpperCase() ?? ''} (${controller.formAnswers['dob'] ?? ''})',
          'Address': '${controller.formAnswers['address_1'] ?? ''}, ${controller.formAnswers['address_2'] ?? ''}'.trim(),
          'City / State': '${controller.formAnswers['city_name'] ?? ''}, ${controller.formAnswers['state_name'] ?? ''}',
          'Country / Pincode': '${controller.formAnswers['country_name'] ?? ''} - ${controller.formAnswers['postcode'] ?? ''}',
        }),
        SizedBox(height: 20.h),

        // Visual Documents Card
        _buildPremiumSectionCard(
          title: 'Identity Documents Proof',
          icon: Icons.badge_outlined,
          children: [
            Row(
              children: [
                _buildDocumentReviewTile('ID Proof Front', controller.idProofFront.value, true),
                SizedBox(width: 10.w),
                _buildDocumentReviewTile('ID Proof Back', controller.idProofBack.value, false),
              ],
            ),
          ],
        ),
        SizedBox(height: 20.h),

        _buildPremiumSectionCard(
          title: 'Address Documents Proof',
          icon: Icons.home_work_outlined,
          children: [
            Row(
              children: [
                _buildDocumentReviewTile('Address Front', controller.addressProofFront.value, true),
                SizedBox(width: 10.w),
                _buildDocumentReviewTile('Address Back', controller.addressProofBack.value, false),
              ],
            ),
          ],
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildDocumentReviewTile(String title, File? file, bool isRequired) {
    final hasFile = file != null;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: hasFile ? AppColors.primary.withOpacity(0.04) : AppColors.textFieldBg,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: hasFile ? AppColors.primary.withOpacity(0.4) : AppColors.border,
            width: hasFile ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : (isRequired ? Icons.cancel_outlined : Icons.info_outline),
              color: hasFile ? const Color(0xFF16A34A) : (isRequired ? Colors.red : AppColors.textGrey),
              size: 16.w,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    hasFile ? file.path.split('/').last.split('.').last.toUpperCase() : 'Not Uploaded',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: hasFile ? AppColors.primary : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSectionCard(String heading, Map<String, String> values) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, color: AppColors.primary, size: 18.w),
              SizedBox(width: 8.w),
              Text(heading, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Divider(color: AppColors.border, thickness: 0.8, height: 24.h),
          ...values.entries.map((e) {
            if (e.value.isEmpty || e.value.startsWith('-')) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      '${e.key}:',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      e.value,
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // --- Step 4 Layout (Success Screen with Timeline Progress Tracker) ---
  Widget _buildStep4Complete() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 20.h),
          // Glow design Checkmark circle icon
          Container(
            height: 90.w,
            width: 90.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.isDarkMode ? Colors.green.withOpacity(0.08) : const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.check_rounded,
              color: const Color(0xFF22C55E),
              size: 48.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "Verification Request Submitted!",
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            "Your profile details and documents are now being reviewed by our compliance team.",
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),

          // Innovative Verification Progress Card Tracker
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Timeline Progress',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 16.h),
                _buildTimelineStep(
                  label: 'Profile Information Submitted',
                  desc: 'Regulation questionnaire saved successfully.',
                  isCompleted: true,
                  isActive: false,
                ),
                _buildTimelineStep(
                  label: 'KYC Document Proofs Uploaded',
                  desc: 'Identity and address proof attached.',
                  isCompleted: true,
                  isActive: false,
                ),
                _buildTimelineStep(
                  label: 'Account Under Compliance Review',
                  desc: 'Average verification time: 2-4 business hours.',
                  isCompleted: false,
                  isActive: true,
                ),
                _buildTimelineStep(
                  label: 'Verification Approved',
                  desc: 'Access deposit, transfer and trading features.',
                  isCompleted: false,
                  isActive: false,
                  isLast: true,
                ),
              ],
            ),
          ),
          SizedBox(height: 36.h),

          // Finish Done Button
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton(
              onPressed: () {
                Get.offAllNamed('/trading');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                elevation: 0,
              ),
              child: Text(
                "Done",
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required String desc,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20.w,
              height: 20.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? const Color(0xFF16A34A)
                    : isActive
                        ? AppColors.primary
                        : AppColors.border,
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : isActive
                          ? AppColors.primary
                          : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 12.w)
                    : isActive
                        ? Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5.w,
                height: 36.h,
                color: isCompleted ? const Color(0xFF22C55E) : AppColors.border,
              ),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isCompleted || isActive
                      ? AppColors.textPrimary
                      : AppColors.textGrey,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Dynamic Bottom Action Bar ---
  Widget? _buildBottomActionBar(int step) {
    if (step == 3) return null; // Complete page manages its own Done button
    
    return Container(
      padding: EdgeInsets.only(
        left: 16.w, 
        right: 16.w, 
        top: 12.h, 
        bottom: Platform.isIOS ? 24.h : 12.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (step == 0)
            Expanded(
              child: SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            FocusScope.of(context).unfocus();
                            await controller.submitQuestionnaire();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 0,
                  ),
                  child: controller.isLoading.value
                      ? ButtonLoadingWidget(size: 20.0, color: Colors.white)
                      : Text(
                          'Update Profile & Continue',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          if (step == 1) ...[
            OutlinedButton(
              onPressed: () {
                controller.currentStep.value = 0;
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text('Back', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: (controller.idProofFront.value == null || controller.addressProofFront.value == null)
                      ? null
                      : () {
                          controller.currentStep.value = 2; // Move to Review
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue to Review',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
          if (step == 2) ...[
            OutlinedButton(
              onPressed: () {
                controller.currentStep.value = 1;
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text('Edit Info', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          final success = await controller.submitDocuments();
                          if (success) {
                            controller.currentStep.value = 3;
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 0,
                  ),
                  child: controller.isLoading.value
                      ? ButtonLoadingWidget(size: 20.0, color: Colors.white)
                      : Text(
                          'Confirm & Submit',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Row helper for Form Inputs ---
  Widget _buildFormRow(Widget first, Widget second) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: 12.w),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildFormInput(
    String key,
    String label, {
    bool isRequired = false,
    bool readOnly = false,
    bool isPhone = false,
    required IconData prefixIcon,
  }) {
    final isMobileField = key == 'mobile';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label, isRequired),
        SizedBox(height: 6.h),
        TextFormField(
          initialValue: controller.formAnswers[key]?.toString() ?? '',
          readOnly: readOnly,
          onChanged: (val) {
            controller.formAnswers[key] = val;
            if (isMobileField) {
              controller.checkMobileAvailability(val, "+971");
            }
          },
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: TextStyle(
            color: readOnly ? AppColors.textGrey : AppColors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: readOnly ? '' : 'Enter...',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 18.w),
            filled: true,
            fillColor: readOnly ? AppColors.surface : AppColors.textFieldBg,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            return null;
          },
        ),
        if (isMobileField)
          Obx(() {
            if (controller.isCheckingMobile.value) {
              return Padding(
                padding: EdgeInsets.only(top: 4.h, left: 4.w),
                child: Row(
                  children: [
                    SizedBox(
                      width: 10.w,
                      height: 10.h,
                      child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                    ),
                    SizedBox(width: 6.w),
                    Text('Checking availability...', style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey)),
                  ],
                ),
              );
            }
            if (!controller.isMobileAvailable.value && controller.mobileError.value.isNotEmpty) {
              return Padding(
                padding: EdgeInsets.only(top: 4.h, left: 4.w),
                child: Text(
                  controller.mobileError.value,
                  style: TextStyle(fontSize: 11.sp, color: Colors.red, fontWeight: FontWeight.w500),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
      ],
    );
  }

  // Dropdown field that opens the bottom-sheet options picker on tap.
  // Used for Title/Gender and other radio-style fields where the choice
  // list is small enough for a sheet but the segment-card row would be
  // cramped on smaller screens.
  Widget _buildOptionsDropdownField({
    required String label,
    required String fieldKey,
    required List<Map<String, String>> options,
    IconData prefixIcon = Icons.expand_circle_down_outlined,
  }) {
    final currentVal = controller.formAnswers[fieldKey]?.toString() ?? '';
    final selectedLabel = options
            .firstWhereOrNull((opt) => opt['value'] == currentVal)
            ?['label']
            ?.toString() ??
        'Select...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelText('$label *'),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: () => _showOptionsSelectorBottomSheet(fieldKey, label, options),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.textFieldBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(prefixIcon, color: AppColors.primary, size: 16.w),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    selectedLabel,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: currentVal.isEmpty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: currentVal.isEmpty ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.unfold_more_rounded, color: AppColors.textGrey, size: 18.w),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerInput(String key, String label, {bool isRequired = false, required IconData prefixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label, isRequired),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final lastDate = DateTime(now.year - 18, now.month, now.day);
            final firstDate = DateTime(1930);

            // Clamp initialDate into [firstDate, lastDate]. The RxMap may
            // hold a stale value populated by the API / autofill (e.g. a
            // stored DOB that's now out of range) — without clamping,
            // showDatePicker throws and the picker silently fails to open.
            final raw = controller.formAnswers[key]?.toString() ?? '';
            final parsed = DateTime.tryParse(raw);
            DateTime initial = lastDate;
            if (parsed != null) {
              if (parsed.isBefore(firstDate)) {
                initial = firstDate;
              } else if (parsed.isAfter(lastDate)) {
                initial = lastDate;
              } else {
                initial = parsed;
              }
            }

            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null) {
              controller.formAnswers[key] = picked.toIso8601String().split('T')[0];
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.textFieldBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(prefixIcon, color: AppColors.primary, size: 18.w),
                SizedBox(width: 8.w),
                // Wrap in Obx so the displayed date refreshes when
                // formAnswers[key] changes. Without this, picking a date
                // mutates the RxMap but the Text widget never rebuilds.
                Expanded(
                  child: Obx(
                    () {
                      final v = controller.formAnswers[key]?.toString() ?? '';
                      return Text(
                        v.isNotEmpty ? v : 'Select Date of Birth',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: v.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                          fontWeight: v.isEmpty ? FontWeight.w400 : FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                Icon(Icons.calendar_month_rounded, color: AppColors.textGrey, size: 16.w),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  Widget _buildInputLabel(String label, bool isRequired) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        children: [
          if (isRequired)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showOptionsSelectorBottomSheet(String key, String title, List options) {
    Get.bottomSheet(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
              SizedBox(height: 12.h),
              Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Divider(color: AppColors.border, height: 20.h),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final val = opt['value']?.toString() ?? '';
                    final lbl = opt['label']?.toString() ?? '';
                    final isSel = controller.formAnswers[key] == val;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                      onTap: () {
                        controller.formAnswers[key] = val;
                        Get.back();
                      },
                      title: Text(lbl, style: TextStyle(fontSize: 14.sp, color: isSel ? AppColors.primary : AppColors.textPrimary, fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
                      trailing: isSel ? Icon(Icons.check_circle, color: AppColors.primary, size: 20.w) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String type,
    required IconData prefixIcon,
    required bool isRequired,
  }) {
    return Obx(() {
      String displayValue = '';
      VoidCallback? onTap;

      if (type == 'country') {
        displayValue = controller.dropdownService.selectedCountry.value?.name ?? '';
        onTap = () => _showCountryOptions();
      } else if (type == 'state') {
        displayValue = controller.dropdownService.selectedState.value?.name ?? '';
        final hasCountry = controller.dropdownService.selectedCountry.value != null;
        onTap = hasCountry ? () => _showStateOptions() : () {
          CustomToastService.showWarning(message: 'Please select a country first.');
        };
      } else if (type == 'city') {
        displayValue = controller.dropdownService.selectedCity.value?.name ?? '';
        final hasState = controller.dropdownService.selectedState.value != null;
        onTap = hasState ? () => _showCityOptions() : () {
          CustomToastService.showWarning(message: 'Please select a state first.');
        };
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel(label, isRequired),
          SizedBox(height: 6.h),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.textFieldBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(prefixIcon, color: AppColors.primary, size: 18.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      displayValue.isNotEmpty ? displayValue : 'Select...',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: displayValue.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                        fontWeight: displayValue.isEmpty ? FontWeight.w400 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, color: AppColors.textGrey, size: 20.w),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showCountryOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<CountryModel> filteredCountries = <CountryModel>[].obs;

    filteredCountries.value = List.from(controller.dropdownService.countries);

    Get.bottomSheet(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Select Country',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: searchController,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  prefixIcon: Icon(Icons.search, color: AppColors.textGrey, size: 18.w),
                  filled: true,
                  fillColor: AppColors.textFieldBg,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (value) {
                  filteredCountries.value = controller.dropdownService.countries
                      .where((country) => (country.name ?? '')
                          .toLowerCase()
                          .contains(value.toLowerCase()))
                      .toList();
                },
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: Obx(
                  () => ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return ListTile(
                        leading: Text(
                          country.emoji ?? '',
                          style: TextStyle(fontSize: 22.sp),
                        ),
                        title: Text(
                          country.name ?? '',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          controller.dropdownService.selectCountry(country);
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showStateOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<StateModel> filteredStates = <StateModel>[].obs;

    filteredStates.value = List.from(controller.dropdownService.states);

    Get.bottomSheet(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Select State',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: searchController,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search states...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  prefixIcon: Icon(Icons.search, color: AppColors.textGrey, size: 18.w),
                  filled: true,
                  fillColor: AppColors.textFieldBg,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (value) {
                  filteredStates.value = controller.dropdownService.states
                      .where((state) => state.name
                          .toLowerCase()
                          .contains(value.toLowerCase()))
                      .toList();
                },
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: Obx(
                  () => ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredStates.length,
                    itemBuilder: (context, index) {
                      final state = filteredStates[index];
                      return ListTile(
                        title: Text(
                          state.name,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          controller.dropdownService.selectState(state);
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showCityOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<CityModel> filteredCities = <CityModel>[].obs;

    filteredCities.value = List.from(controller.dropdownService.cities);

    Get.bottomSheet(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Select City',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: searchController,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search cities...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  prefixIcon: Icon(Icons.search, color: AppColors.textGrey, size: 18.w),
                  filled: true,
                  fillColor: AppColors.textFieldBg,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (value) {
                  filteredCities.value = controller.dropdownService.cities
                      .where((city) => city.name
                          .toLowerCase()
                          .contains(value.toLowerCase()))
                      .toList();
                },
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: Obx(
                  () => ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = filteredCities[index];
                      return ListTile(
                        title: Text(
                          city.name,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          controller.dropdownService.selectCity(city);
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
