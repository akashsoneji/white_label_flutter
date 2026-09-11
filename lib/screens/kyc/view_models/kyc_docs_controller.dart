import 'dart:io';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/kyc/presentation/pages/kyc_camera_screen.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository.dart';

class KycDocsController extends GetxController {
  final KycRepository _repo = Get.find<KycRepository>();
  CameraController? cameraController;
  List<CameraDescription>? _cameras;
  String? _currentDocumentType; // Store document type for camera capture

  @override
  void onInit() {
    super.onInit();
    _initializeCamera();
    _loadKycStatus();
  }

  @override
  void onClose() {
    _disposeCamera();
    super.onClose();
  }

  // Dispose camera controller safely
  Future<void> _disposeCamera() async {
    if (cameraController != null) {
      try {
        final camController = cameraController;
        cameraController = null; // Clear reference first
        if (camController!.value.isInitialized) {
          await camController.dispose();
        } else {
          // If not initialized, just dispose
          await camController.dispose();
        }
      } catch (e) {
        print('Error disposing camera: $e');
        // Try to dispose anyway
        try {
          await cameraController?.dispose();
        } catch (e2) {
          print('Error in final camera disposal: $e2');
        }
        cameraController = null;
      }
    }
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  // Request camera permission
  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  // Observable variables
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString _authToken = ''.obs;

  // Document images
  final Rx<File?> idProofFront = Rx<File?>(null);
  final Rx<File?> idProofBack = Rx<File?>(null);
  final Rx<File?> addressProofFront = Rx<File?>(null);
  final Rx<File?> addressProofBack = Rx<File?>(null);

  // Existing server documents map: subdocument_type -> {status, image_url, id}
  final RxMap<String, Map<String, dynamic>> existingDocuments =
      <String, Map<String, dynamic>>{}.obs;

  // Upload states
  final RxBool isIdProofFrontUploaded = false.obs;
  final RxBool isIdProofBackUploaded = false.obs;
  final RxBool isAddressProofFrontUploaded = false.obs;
  final RxBool isAddressProofBackUploaded = false.obs;

  // Upload progress
  final RxMap<String, double> uploadProgress = <String, double>{}.obs;

  // Start camera for taking document photo
  Future<void> startCamera({required String documentType}) async {
    try {
      // Enforce gating at controller level as a safety net
      if (!canUpload(documentType)) {
        CustomToastService.showInfo(
          message: TranslationUtils.tr(
            'kyc_docs_controller_this_document_is_optional_or_not',
          ),
        );
        return;
      }

      await _requestCameraPermission();

      if (_cameras == null || _cameras!.isEmpty) {
        await _initializeCamera();
        if (_cameras == null || _cameras!.isEmpty) {
          CustomToastService.showError(
            message: TranslationUtils.tr(
              'deposit_instruction_controller_no_camera_available_on_this_device',
            ),
          );
          return;
        }
      }

      // Store document type for later use
      _currentDocumentType = documentType;

      // Dispose existing controller if any
      if (cameraController != null) {
        await cameraController!.dispose();
        cameraController = null;
      }

      // Pick camera lens (front/back) when both are available
      final hasFront = _cameras!.any(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final hasBack = _cameras!.any(
        (c) => c.lensDirection == CameraLensDirection.back,
      );

      CameraDescription selectedCamera;
      if (hasFront && hasBack) {
        final picked = await Get.bottomSheet<CameraDescription>(
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 24.h,
                  horizontal: 24.w,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      TranslationUtils.tr('kyc_docs_controller_select_camera'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    ListTile(
                      leading: Icon(Icons.camera_front),
                      title: Text(
                        TranslationUtils.tr('kyc_docs_controller_front_camera'),
                      ),
                      onTap: () => Get.back(
                        result: _cameras!.firstWhere(
                          (c) =>
                              c.lensDirection == CameraLensDirection.front,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.camera_rear),
                      title: Text(
                        TranslationUtils.tr('kyc_docs_controller_back_camera'),
                      ),
                      onTap: () => Get.back(
                        result: _cameras!.firstWhere(
                          (c) => c.lensDirection == CameraLensDirection.back,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          isScrollControlled: true,
        );
        if (picked == null) {
          return; // User dismissed the picker
        }
        selectedCamera = picked;
      } else {
        selectedCamera = hasFront
            ? _cameras!.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.front,
              )
            : _cameras!.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.back,
              );
      }

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset
            .medium, // Use medium instead of high for better memory management
      );

      try {
        await cameraController!.initialize();
        // Small delay to ensure camera is fully ready
        await Future.delayed(const Duration(milliseconds: 200));
        // Navigate to camera screen
        Get.to(() => KycCameraScreen());
      } catch (e) {
        print('Error starting camera: $e');
        CustomToastService.showError(
          message: 'Failed to start camera: ${e.toString()}',
        );
        await cameraController?.dispose();
        cameraController = null;
        // Try to navigate back if camera failed
        if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
          Get.back(closeOverlays: true);
        }
      }
    } catch (e) {
      print('❌ Error starting camera: $e');
      CustomToastService.showError(message: 'Error starting camera: $e');
      await cameraController?.dispose();
      cameraController = null;
    }
  }

  // Capture image from camera (called from camera screen)
  Future<void> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'deposit_instruction_controller_camera_is_not_ready_please_wait',
        ),
      );
      return;
    }

    if (_currentDocumentType == null) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'kyc_docs_controller_document_type_not_set',
        ),
      );
      return;
    }

    try {
      isLoading.value = true;

      // Store reference before disposing
      final camController = cameraController;
      final image = await camController!.takePicture();

      final File imageFile = File(image.path);

      // Clear reference first, then dispose
      cameraController = null;
      update(); // Notify GetBuilder to rebuild

      // Dispose after a small delay to ensure UI has updated
      await Future.delayed(const Duration(milliseconds: 100));
      await camController.dispose();

      Get.back(closeOverlays: true); // Close camera screen

      // Check file size and compress if needed
      final fileSize = await imageFile.length();
      print(
        '📸 Original image size: ${(fileSize / 1024).toStringAsFixed(2)} KB',
      );

      // If file is larger than 1MB, show warning
      if (fileSize > 1024 * 1024) {
        print(
          '⚠️ Large image detected: ${(fileSize / 1024).toStringAsFixed(2)} KB',
        );
        CustomToastService.showWarning(
          message: TranslationUtils.tr(
            'kyc_docs_controller_large_image_detected_upload_may_take',
          ),
        );
      }

      // Save image to the correct document type
      switch (_currentDocumentType!) {
        case 'id_proof_front':
          idProofFront.value = imageFile;
          break;
        case 'id_proof_back':
          idProofBack.value = imageFile;
          break;
        case 'address_proof_front':
          addressProofFront.value = imageFile;
          break;
        case 'address_proof_back':
          addressProofBack.value = imageFile;
          break;
      }

      // Clear document type
      _currentDocumentType = null;

      CustomToastService.showSuccess(
        message: TranslationUtils.tr(
          'kyc_bank_controller_image_captured_successfully',
        ),
      );
    } catch (e) {
      print('❌ Error capturing image: $e');
      CustomToastService.showError(
        message: 'Failed to capture image: ${e.toString()}',
      );

      // Clean up on error
      try {
        final camController = cameraController;
        cameraController = null;
        update();
        await camController?.dispose();
      } catch (disposeError) {
        print('Error disposing camera: $disposeError');
      }

      _currentDocumentType = null;
    } finally {
      isLoading.value = false;
    }
  }

  // Keep old method for backward compatibility (but it now calls startCamera)
  Future<void> pickImageFromCamera({required String documentType}) async {
    await startCamera(documentType: documentType);
  }

  // Pick image from gallery
  Future<void> pickImageFromGallery({required String documentType}) async {
    try {
      // Enforce gating at controller level as a safety net
      if (!canUpload(documentType)) {
        CustomToastService.showInfo(
          message: TranslationUtils.tr(
            'kyc_docs_controller_this_document_is_optional_or_not',
          ),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.single.path != null) {
        final File imageFile = File(result.files.single.path!);

        // Check file size and compress if needed
        final fileSize = await imageFile.length();
        print(
          '📸 Original image size: ${(fileSize / 1024).toStringAsFixed(2)} KB',
        );

        // If file is larger than 1MB, show warning
        if (fileSize > 1024 * 1024) {
          print(
            '⚠️ Large image detected: ${(fileSize / 1024).toStringAsFixed(2)} KB',
          );
          CustomToastService.showWarning(
            message: TranslationUtils.tr(
              'kyc_docs_controller_large_image_detected_upload_may_take',
            ),
          );
        }

        switch (documentType) {
          case 'id_proof_front':
            idProofFront.value = imageFile;
            break;
          case 'id_proof_back':
            idProofBack.value = imageFile;
            break;
          case 'address_proof_front':
            addressProofFront.value = imageFile;
            break;
          case 'address_proof_back':
            addressProofBack.value = imageFile;
            break;
        }

        // Don't auto-upload - wait for save button press
        CustomToastService.showSuccess(
          message: TranslationUtils.tr(
            'kyc_docs_controller_image_selected_successfully',
          ),
        );
      }
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      errorMessage.value = 'Error picking image: $e';
      CustomToastService.showError(message: 'Error picking image: $e');
    }
  }

  Future<void> _loadKycStatus() async {
    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      _authToken.value = token ?? '';

      final response = await _repo.getKycStatus(token: token ?? '');

      if (!response.success) {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('kyc_docs_controller_failed_to_load_kyc_status');
        return;
      }

      final data = response.data;
      if (data is Map &&
          data['data'] != null &&
          data['data']['documents'] != null) {
        final List docs = data['data']['documents'] as List;
        final Map<String, Map<String, dynamic>> mapped = {};
        final Map<String, DateTime> latestAt = {};
        for (final d in docs) {
          final sub = d['subdocument_type']?.toString() ?? '';
          if (sub.isEmpty) continue;
          // choose latest by created_at fallback to id
          DateTime created;
          try {
            created = DateTime.parse((d['created_at'] ?? '').toString());
          } catch (_) {
            final id =
                (d['id'] is int)
                    ? d['id'] as int
                    : int.tryParse('${d['id']}') ?? 0;
            created = DateTime.fromMillisecondsSinceEpoch(id);
          }
          final prev = latestAt[sub];
          if (prev != null && prev.isAfter(created)) {
            continue;
          }
          latestAt[sub] = created;
          mapped[sub] = {
            'status': d['status']?.toString() ?? 'pending',
            'image_url': d['image_url']?.toString() ?? '',
            'id': d['id'],
            'remark': d['remark']?.toString() ?? '',
            // correct field from API: back_side_required
            if (d.containsKey('back_side_required'))
              'back_side_required': d['back_side_required'],
          };
        }
        existingDocuments.assignAll(mapped);
      }
    } catch (e) {
      errorMessage.value = 'Error fetching KYC status: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // Helpers for UI
  Map<String, dynamic>? getExistingDoc(String subdocumentType) {
    return existingDocuments[subdocumentType];
  }

  String? getExistingDocUrl(String subdocumentType) {
    final doc = existingDocuments[subdocumentType];
    if (doc == null) return null;
    final url = doc['image_url']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Map<String, String> get authImageHeaders => {
    if (_authToken.value.isNotEmpty)
      'Authorization': 'Bearer ${_authToken.value}',
    'Accept': 'image/*',
  };

  // ===== Requirement & gating helpers =====
  bool isBackRequired(String group) {
    final front = getExistingDoc('${group}_front');
    final requireVal = (front?['back_side_required'] ?? 0).toString();
    return requireVal == '1';
  }

  bool isRequired(String documentType) {
    if (documentType.endsWith('_front')) return true;
    final group =
        documentType.startsWith('id_proof') ? 'id_proof' : 'address_proof';
    return isBackRequired(group);
  }

  String statusFor(String documentType) {
    return (getExistingDoc(documentType)?['status'] ?? 'none')
        .toString()
        .toLowerCase();
  }

  bool canUpload(String documentType) {
    final status = statusFor(documentType);
    if (status == 'approved') return false; // don't allow uploads over approved
    if (status == 'rejected') return true; // allow re-upload of rejected
    final required = isRequired(documentType);
    final hasLocal = getImageFile(documentType) != null;
    final hasServer = getExistingDoc(documentType) != null && status != 'none';
    if (required && !hasLocal && !hasServer) return true; // first-time required
    if (!required) {
      // Optional backs: allow first-time upload, and allow if rejected; block if pending/approved
      if (!hasServer && !hasLocal) return true; // allow optional upload
      if (status == 'pending') return false;
      if (status == 'rejected') return true;
      return false; // approved handled above
    }
    return false;
  }

  // Selected-any helper to enable common upload button for multiple rejected docs
  bool get hasAnySelected {
    return idProofFront.value != null ||
        idProofBack.value != null ||
        addressProofFront.value != null ||
        addressProofBack.value != null;
  }

  // Upload document to API

  // Check if all required documents are selected (initial flow)
  bool get areAllRequiredDocumentsSelected {
    return idProofFront.value != null && addressProofFront.value != null;
  }

  // Check if all required documents are uploaded
  bool get areAllDocumentsUploaded {
    // Determine required types dynamically (backs depend on requirement)
    final List<String> requiredTypes = [
      'id_proof_front',
      'address_proof_front',
    ];
    if (isBackRequired('id_proof')) requiredTypes.add('id_proof_back');
    if (isBackRequired('address_proof'))
      requiredTypes.add('address_proof_back');

    bool isTypeSatisfied(String t) {
      final status = statusFor(t);
      final satisfiedByServer = status == 'pending' || status == 'approved';
      final satisfiedByLocal = isDocumentUploaded(t);
      return satisfiedByServer || satisfiedByLocal;
    }

    for (final t in requiredTypes) {
      if (!isTypeSatisfied(t)) return false;
    }
    return true;
  }

  // Check if specific document is uploaded
  bool isDocumentUploaded(String documentType) {
    switch (documentType) {
      case 'id_proof_front':
        return isIdProofFrontUploaded.value;
      case 'id_proof_back':
        return isIdProofBackUploaded.value;
      case 'address_proof_front':
        return isAddressProofFrontUploaded.value;
      case 'address_proof_back':
        return isAddressProofBackUploaded.value;
      default:
        return false;
    }
  }

  // Get image file for document type
  File? getImageFile(String documentType) {
    switch (documentType) {
      case 'id_proof_front':
        return idProofFront.value;
      case 'id_proof_back':
        return idProofBack.value;
      case 'address_proof_front':
        return addressProofFront.value;
      case 'address_proof_back':
        return addressProofBack.value;
      default:
        return null;
    }
  }

  // Upload all selected documents individually with correct subdocument types
  Future<void> uploadAllDocuments() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final token = await SecureStorageService.getAuthToken();

      // Prepare list of selected uploads
      final uploads = <Map<String, dynamic>>[
        {
          'file': idProofFront.value,
          'type': 'id_proof_front',
          'name': TranslationUtils.tr('kyc_id_proof_front'),
        },
        {
          'file': idProofBack.value,
          'type': 'id_proof_back',
          'name': TranslationUtils.tr('kyc_id_proof_back'),
        },
        {
          'file': addressProofFront.value,
          'type': 'address_proof_front',
          'name': TranslationUtils.tr('kyc_address_proof_front'),
        },
        {
          'file': addressProofBack.value,
          'type': 'address_proof_back',
          'name': TranslationUtils.tr('kyc_address_proof_back'),
        },
      ];

      final attempted = uploads.where((u) => u['file'] != null).length;
      int succeeded = 0;

      for (final u in uploads) {
        final file = u['file'] as File?;
        if (file == null) continue;
        final ok = await _uploadDocument(
          file,
          u['type'] as String,
          u['name'] as String,
          token ?? '',
        );
        if (ok) succeeded++;
      }

      // Refresh server state once after all uploads
      await _loadKycStatus();

      if (attempted == 0) {
        CustomToastService.showError(
          message: TranslationUtils.tr(
            'kyc_docs_controller_please_select_document_first',
          ),
        );
      } else if (succeeded == attempted) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('kyc_docs_controller_upload_successful'),
        );
      } else {
        CustomToastService.showError(
          message: TranslationUtils.tr(
            'kyc_docs_controller_some_documents_failed_to_upload_please',
          ),
        );
      }
    } catch (e) {
      errorMessage.value = 'Error uploading documents: $e';
      CustomToastService.showError(message: 'Error uploading documents: $e');
    } finally {
      isLoading.value = false;
      uploadProgress.clear();
    }
  }

  // Upload individual document
  Future<bool> _uploadDocument(
    File file,
    String subdocumentType,
    String documentName,
    String token,
  ) async {
    try {
      // Prepare form data for this specific document
      final Map<String, dynamic> formData = {
        'document_type': 'kyc',
        'subdocument_type': subdocumentType,
        // 'back_side_required': false,
      };

      // Upload single file
      final response = await _repo.uploadKycDocument(
        token: token,
        file: file,
        formData: formData,
        onProgress: (progress) {
          uploadProgress[subdocumentType] = progress;
        },
      );

      if (response.success) {
        // Mark this specific document as uploaded
        switch (subdocumentType) {
          case 'id_proof_front':
            isIdProofFrontUploaded.value = true;
            break;
          case 'id_proof_back':
            isIdProofBackUploaded.value = true;
            break;
          case 'address_proof_front':
            isAddressProofFrontUploaded.value = true;
            break;
          case 'address_proof_back':
            isAddressProofBackUploaded.value = true;
            break;
        }

        // Clear local selection for this doc and optimistically set pending
        _clearSelectedFor(subdocumentType);
        _markServerStatusPending(subdocumentType);

        print('✅ $documentName uploaded successfully');
        return true;
      } else {
        print('❌ $documentName upload failed: ${response.message}');
        return false;
      }
    } catch (e) {
      print('❌ $documentName upload error: $e');
      return false;
    }
  }

  void _clearSelectedFor(String documentType) {
    switch (documentType) {
      case 'id_proof_front':
        idProofFront.value = null;
        break;
      case 'id_proof_back':
        idProofBack.value = null;
        break;
      case 'address_proof_front':
        addressProofFront.value = null;
        break;
      case 'address_proof_back':
        addressProofBack.value = null;
        break;
    }
  }

  void _markServerStatusPending(String documentType) {
    final existing = Map<String, dynamic>.from(
      existingDocuments[documentType] ?? {},
    );
    existing['status'] = 'pending';
    existingDocuments[documentType] = existing;
    existingDocuments.refresh();
  }

  // Clear all data
  void clearAllData() {
    idProofFront.value = null;
    idProofBack.value = null;
    addressProofFront.value = null;
    addressProofBack.value = null;

    isIdProofFrontUploaded.value = false;
    isIdProofBackUploaded.value = false;
    isAddressProofFrontUploaded.value = false;
    isAddressProofBackUploaded.value = false;

    uploadProgress.clear();
    errorMessage.value = '';
  }
}
