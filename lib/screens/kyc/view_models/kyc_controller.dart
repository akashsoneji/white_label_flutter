import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/language_service.dart';

// Document Type Model
class DocumentType {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  DocumentType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });
}

// KYC Controller
class KYCController extends GetxController {
  final RxBool showBottomSheet = false.obs;
  final RxString selectedDocument = ''.obs;
  final RxBool isUploading = false.obs;

  final List<DocumentType> documentTypes = [
    DocumentType(
      title: 'Passport',
      subtitle: TranslationUtils.tr('kyc_doc_international'),
      icon: Icons.book,
      iconColor: AppColors.primary,
    ),
    DocumentType(
      title: 'ID/Aadhar card',
      subtitle: TranslationUtils.tr('kyc_controller_eu_gb_issued'),
      icon: Icons.credit_card,
      iconColor: AppColors.primary,
    ),
    DocumentType(
      title: 'Driving License\'s',
      subtitle: TranslationUtils.tr('kyc_controller_eu_gb_issued'),
      icon: Icons.directions_car,
      iconColor: AppColors.primary,
    ),
  ];

  void showDocumentSelection() {
    showBottomSheet.value = true;
  }

  void hideDocumentSelection() {
    showBottomSheet.value = false;
  }

  void selectDocument(DocumentType document) {
    selectedDocument.value = document.title;
    hideDocumentSelection();

    // Navigate to next step or handle document selection
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showSuccess(
        message: TranslationUtils.trArgs('kyc_you_selected_document', {
          'title': document.title,
        }),
        title: TranslationUtils.tr('kyc_controller_document_selected'),
      );
    }
  }
}
