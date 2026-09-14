import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crm_app/screens/home/more/camera_screen.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/language_service.dart';

class IdScannerController extends GetxController {
  var frontImagePath = ''.obs;
  var backImagePath = ''.obs;
  var isLoading = false.obs;
  var currentSide = 'front'.obs; // 'front' or 'back'

  CameraController? cameraController;
  List<CameraDescription>? cameras;

  @override
  void onInit() {
    super.onInit();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  Future<void> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> startCamera() async {
    await requestCameraPermission();

    if (cameras != null && cameras!.isNotEmpty) {
      cameraController = CameraController(cameras![0], ResolutionPreset.high);

      try {
        await cameraController!.initialize();
        Get.to(() => CameraScreen());
      } catch (e) {
        print('Error starting camera: $e');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
        message: TranslationUtils.tr(
          'id_scanner_controller_failed_to_start_camera_please_check',
        ),
            title: TranslationUtils.tr('close_position_error'),
          );
        }
      }
    }
  }

  Future<void> captureImage() async {
    if (cameraController != null && cameraController!.value.isInitialized) {
      try {
        isLoading.value = true;
        final image = await cameraController!.takePicture();

        if (currentSide.value == 'front') {
          frontImagePath.value = image.path;
        } else {
          backImagePath.value = image.path;
        }

        await cameraController!.dispose();
        cameraController = null;
        Get.back(closeOverlays: true);

        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message: TranslationUtils.trArgs(
              'id_scanner_side_captured_successfully',
              {'side': '${currentSide.value.capitalizeFirst}'},
            ),
            title: TranslationUtils.tr('create_account_success'),
          );
        }
      } catch (e) {
        print('Error capturing image: $e');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'id_scanner_controller_failed_to_capture_image',
            ),
            title: TranslationUtils.tr('close_position_error'),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }
  }

  void setCameraForFrontSide() {
    currentSide.value = 'front';
    startCamera();
  }

  void setCameraForBackSide() {
    currentSide.value = 'back';
    startCamera();
  }

  void submitRequest() {
    if (frontImagePath.value.isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'id_scanner_controller_please_capture_the_front_side_of',
          ),
          title: TranslationUtils.tr('id_scanner_controller_missing_image'),
        );
      }
      return;
    }

    // Handle submission logic here
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showSuccess(
        message: TranslationUtils.tr(
          'id_scanner_controller_id_card_submitted_successfully',
        ),
        title: TranslationUtils.tr('create_account_success'),
      );
    }
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}
