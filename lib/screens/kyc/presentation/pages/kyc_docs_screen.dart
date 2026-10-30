import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/kyc/data/models/kyc_document_config.dart';
import 'package:crm_app/screens/kyc/view_models/kyc_docs_controller.dart';
import 'package:crm_app/widgets/kyc_scaffold.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/routes/app_pages.dart';

class KycDocsScreen extends StatelessWidget {
  const KycDocsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      final KycDocsController controller = Get.put(KycDocsController());
      final languageService = Get.find<LanguageService>();
      return KycScaffold(
        title: languageService.tr('kyc_upload_documents'),
        body: Container(
          color: AppColors.whiteColor, // Ensure white background
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24.h),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDocumentSection(
                            controller: controller,
                            category: kycIdProof,
                            title: languageService.tr('kyc_id_proof'),
                            frontTitle: languageService.tr('kyc_id_proof_front'),
                            backTitle: languageService.tr('kyc_id_proof_back'),
                          ),
                          SizedBox(height: 24.h),
                          _buildDocumentSection(
                            controller: controller,
                            category: kycAddressProof,
                            title: languageService.tr('kyc_address_proof'),
                            frontTitle:
                                languageService.tr('kyc_address_proof_front'),
                            backTitle:
                                languageService.tr('kyc_address_proof_back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Save Button
                  Obx(() {
                    final hasLocalSelection =
                        controller.idProofFront.value != null ||
                        controller.idProofBack.value != null ||
                        controller.addressProofFront.value != null ||
                        controller.addressProofBack.value != null;
                    final isEnabled =
                        hasLocalSelection && !controller.isLoading.value;
                    return ElevatedButton(
                      onPressed: isEnabled ? _handleSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isEnabled
                                ? AppColors.primary
                                : AppColors.textGreyLight,
                        foregroundColor: AppColors.whiteColor,
                        padding: EdgeInsets.all(0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child:
                          controller.isLoading.value
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ButtonLoadingWidget(
                                    size: 20.0,
                                    color: AppColors.whiteColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    TranslationUtils.tr('kyc_docs_screen_uploading'),
                                    style: AppTextStyles.black14600h1_71
                                        .copyWith(color: AppColors.whiteColor),
                                  ),
                                ],
                              )
                              : Text(
                                hasLocalSelection
                                    ? TranslationUtils.tr(
                                      'kyc_docs_screen_upload_selected_documents',
                                    )
                                    : TranslationUtils.tr(
                                      'kyc_docs_screen_select_required_documents',
                                    ),
                                style: AppTextStyles.black14600h1_71.copyWith(
                                  color: AppColors.whiteColor,
                                ),
                              ),
                    );
                  }),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error in KycDocsScreen: $e');
      // Fallback UI in case of error
      return Scaffold(
        backgroundColor: AppColors.whiteColor,
        appBar: AppBar(
          backgroundColor: AppColors.whiteColor,
          title: Text(Get.find<LanguageService>().tr('kyc_upload_documents')),
          leading: const AppBackButton(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                Get.find<LanguageService>().tr('kyc_error_loading'),
                style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(closeOverlays: true),
                child: Text(Get.find<LanguageService>().tr('kyc_go_back')),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// One category: an option dropdown when the admin defined a list, then
  /// only the sides that option (or the default rule) needs.
  Widget _buildDocumentSection({
    required KycDocsController controller,
    required String category,
    required String title,
    required String frontTitle,
    required String backTitle,
  }) {
    return Obx(() {
      final options = controller.documentConfig.value?.optionsFor(category) ??
          const <KycDocumentOption>[];
      final frontType = '${category}_$kycSideFront';
      final backType = '${category}_$kycSideBack';
      final showFront = controller.isSideVisible(frontType);
      final showBack = controller.isSideVisible(backType);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.black16400h1_5),
          SizedBox(height: 10.h),
          if (options.isNotEmpty) ...[
            _buildOptionDropdown(controller, category, options),
            SizedBox(height: 10.h),
          ],
          if (!showFront && !showBack)
            Text(
              TranslationUtils.tr('kyc_doc_pick_document_first'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: showFront
                      ? _buildUploadTile(
                          controller: controller,
                          documentType: frontType,
                          title: frontTitle,
                          isActive: true,
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: showBack
                      ? _buildUploadTile(
                          controller: controller,
                          documentType: backType,
                          title: backTitle,
                          isActive: controller.isRequired(backType),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      );
    });
  }

  /// Locked once the category has documents on the server: the server keeps
  /// the earlier pick for re-uploads.
  Widget _buildOptionDropdown(
    KycDocsController controller,
    String category,
    List<KycDocumentOption> options,
  ) {
    final isLocked = controller.hasServerDocs(category);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: controller.pickedOptionFor(category)?.id,
          hint: Text(
            TranslationUtils.tr('kyc_doc_select_document_type'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textGrey,
            ),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<String>(
                value: option.id,
                child: Text(
                  option.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
          ],
          onChanged: isLocked
              ? null
              : (id) => controller.selectDocumentOption(
                    category,
                    options.firstWhereOrNull((option) => option.id == id),
                  ),
        ),
      ),
    );
  }

  Widget _buildUploadTile({
    required KycDocsController controller,
    required String documentType,
    required String title,
    required bool isActive,
  }) {
    return Obx(() {
      try {
        final imageFile = controller.getImageFile(documentType);
        final isSelected = imageFile != null;
        final uploadProgress = controller.uploadProgress[documentType] ?? 0.0;
        final isLoading = controller.isLoading.value;
        final canTap = controller.canUpload(documentType);
        final required = controller.isRequired(documentType);

        return GestureDetector(
          onTap:
              canTap ? () => _showImagePicker(controller, documentType) : null,
          child: Container(
            height: 165.h,
            width: 155.w,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Colors.green.withAlpha(30)
                      : (required || isActive)
                      ? AppColors.primary.withAlpha(30)
                      : AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected ? Border.all(color: Colors.green, width: 2) : null,
            ),
            child: Stack(
              children: [
                // Dashed border overlay (only if not selected)
                if (!isSelected)
                  CustomPaint(
                    size: Size.infinite,
                    painter: DashedBorderPainter(
                      color:
                          (required || isActive)
                              ? AppColors.primary
                              : AppColors.icongrey,
                      strokeWidth: 1,
                      dashPattern: [6, 4],
                    ),
                  ),

                // Image or placeholder
                if (imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imageFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  // If no locally picked file, try to show existing server image
                  _buildExistingImage(controller, documentType) ??
                      // Content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color:
                                    (required || isActive)
                                        ? AppColors.primary
                                        : AppColors.textGreyLight,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : Icons.add,
                                color: AppColors.whiteColor,
                                size: 24.w,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              title,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected
                                        ? Colors.green
                                        : AppColors.isDarkMode
                                        ? AppColors.primary
                                        : AppColors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                // Upload progress indicator
                if (isLoading && uploadProgress > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: uploadProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),

                // Status overlays (selected or server status)
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors.whiteColor,
                        size: 16,
                      ),
                    ),
                  ),
                if (!isSelected)
                  _buildServerStatusChip(controller, documentType),
              ],
            ),
          ),
        );
      } catch (e) {
        print('Error in _buildUploadTile: $e');
        // Fallback tile in case of error
        return Container(
          height: 165.h,
          width: 155.w,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 32),
                SizedBox(height: 8),
                Text(
                  TranslationUtils.tr('close_position_error'),
                  style: AppTextStyles.bodyText.copyWith(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  // Builds Image.network with auth headers if existing server doc is present
  Widget? _buildExistingImage(
    KycDocsController controller,
    String documentType,
  ) {
    final url = controller.getExistingDocUrl(documentType);
    if (url == null) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        headers: controller.authImageHeaders,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox.shrink(),
      ),
    );
  }

  Widget _buildServerStatusChip(
    KycDocsController controller,
    String documentType,
  ) {
    final doc = controller.getExistingDoc(documentType);
    final status = controller.statusFor(documentType);
    final required = controller.isRequired(documentType);
    final hasLocal = controller.getImageFile(documentType) != null;
    if (!required && !hasLocal && doc == null) {
      return Positioned(
        bottom: 8,
        left: 8,
        right: 8,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            TranslationUtils.tr('kyc_docs_screen_optional'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(color: AppColors.whiteColor, fontSize: 12),
          ),
        ),
      );
    }
    if (doc == null) return SizedBox.shrink();
    Color bg;
    String text;
    switch (status) {
      case 'approved':
        bg = Colors.green;
        text = TranslationUtils.tr('kyc_verification_approved');
        break;
      case 'rejected':
        bg = Colors.red;
        text = TranslationUtils.tr('kyc_docs_screen_rejected_re_upload');
        break;
      default:
        bg = Colors.orange;
        text = TranslationUtils.tr('kyc_verification_under_review');
    }

    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyText.copyWith(color: AppColors.whiteColor, fontSize: 12),
        ),
      ),
    );
  }

  /// Shows the image picker bottom sheet - this is the ONLY entry point for image picking
  /// No other popups or dialogs should be used for selecting images
  void _showImagePicker(KycDocsController controller, String documentType) {
    // Use showModalBottomSheet - this is the ONLY popup used for image picking
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: 24.h,
              bottom: 24.h + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        TranslationUtils.trArgs('kyc_docs_screen_upload_name', {
                          'name': _getDocumentDisplayName(documentType),
                        }),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        print('🔄 Closing image picker bottom sheet');
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          print('📷 Camera button pressed');
                          // Close bottom sheet immediately
                          Navigator.of(context).pop();
                          print('✅ Bottom sheet closed');

                          // Wait for bottom sheet to close completely
                          await Future.delayed(Duration(milliseconds: 300));

                          // Then pick image
                          try {
                            print('🔄 Starting camera image picker');
                            await controller.pickImageFromCamera(
                              documentType: documentType,
                            );
                            print('✅ Camera image picked successfully');
                          } catch (e) {
                            print('❌ Error picking image from camera: $e');
                          }
                        },
                        icon: Icon(Icons.camera_alt),
                        label: Text(
                          Get.find<LanguageService>().tr('kyc_camera'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          print('🖼️ Gallery button pressed');
                          // Close bottom sheet immediately
                          Navigator.of(context).pop();
                          print('✅ Bottom sheet closed');

                          // Wait for bottom sheet to close completely
                          await Future.delayed(Duration(milliseconds: 300));

                          // Then pick image
                          try {
                            print('🔄 Starting gallery image picker');
                            await controller.pickImageFromGallery(
                              documentType: documentType,
                            );
                            print('✅ Gallery image picked successfully');
                          } catch (e) {
                            print('❌ Error picking image from gallery: $e');
                          }
                        },
                        icon: Icon(Icons.photo_library),
                        label: Text(
                          Get.find<LanguageService>().tr('kyc_gallery'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDocumentDisplayName(String documentType) {
    switch (documentType) {
      case 'id_proof_front':
        return TranslationUtils.tr('kyc_id_proof_front');
      case 'id_proof_back':
        return TranslationUtils.tr('kyc_id_proof_back');
      case 'address_proof_front':
        return TranslationUtils.tr('kyc_address_proof_front');
      case 'address_proof_back':
        return TranslationUtils.tr('kyc_address_proof_back');
      default:
        return TranslationUtils.tr('kyc_docs_screen_document');
    }
  }

  void _handleSave() {
    // Upload all documents first, then navigate
    final KycDocsController controller = Get.find<KycDocsController>();
    controller.uploadAllDocuments().then((_) {
      if (controller.areAllDocumentsUploaded) {
        // Navigate to next screen (KYC Bank details) after successful upload
        Get.toNamed(
          AppPages.KYC_BANK,
          arguments: {
            'screen_name': 'Add Withdrawal Method',
            'isFromKYC': true,
          },
        );
      }
    });
  }
}

// Custom painter for dashed borders
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(10),
          ),
        );

    // Create dashed effect
    final dashWidth = dashPattern[0];
    final dashSpace = dashPattern[1];

    final pathMetrics = path.computeMetrics().first;
    final pathLength = pathMetrics.length;

    double distance = 0;
    bool draw = true;

    while (distance < pathLength) {
      if (draw) {
        final start = pathMetrics.getTangentForOffset(distance);
        final end = pathMetrics.getTangentForOffset(
          distance + dashWidth > pathLength ? pathLength : distance + dashWidth,
        );

        if (start != null && end != null) {
          canvas.drawLine(start.position, end.position, paint);
        }
      }

      distance += dashWidth + dashSpace;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
