import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crm_app/screens/home/more/camera_screen.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

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
            message: 'Failed to start camera. Please check permissions.',
            title: 'Error',
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
            message:
                '${currentSide.value.capitalizeFirst} side captured successfully!',
            title: 'Success',
          );
        }
      } catch (e) {
        print('Error capturing image: $e');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: 'Failed to capture image',
            title: 'Error',
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
          message: 'Please capture the front side of your ID',
          title: 'Missing Image',
        );
      }
      return;
    }

    // Handle submission logic here
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showSuccess(
        message: 'ID card submitted successfully!',
        title: 'Success',
      );
    }
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}
