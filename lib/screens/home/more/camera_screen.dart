import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:crm_app/screens/kyc/view_models/id_scanner_controller.dart';
import 'package:crm_app/services/language_service.dart';
import '../../../widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class CameraScreen extends StatelessWidget {
  final IdScannerController controller = Get.find<IdScannerController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: controller.cameraController != null &&
                controller.cameraController!.value.isInitialized
                ? CameraPreview(controller.cameraController!)
                : Center(
              child: CommonLoadingWidget(
                size: 40.0,
                // Camera screen is always dark; keep loader high-contrast.
                color: Colors.white,
              ),
            ),
          ),

          PositionedDirectional(
            top: MediaQuery.of(context).padding.top,
            start: 4,
            child: const AppBackButton(),
          ),

          // Overlay for ID card frame
          Positioned.fill(
            child: CustomPaint(
              painter: IdCardOverlayPainter(),
            ),
          ),

          // Top instruction
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Obx(() => Text(
                  TranslationUtils.trArgs('camera_position_side_of_id', {
                    'side': controller.currentSide.value,
                  }),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontSize: 16,
                  ),
                )),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                // Capture button
                Obx(() => GestureDetector(
                  onTap: controller.isLoading.value
                      ? null
                      : controller.captureImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: controller.isLoading.value
                        ? Center(
                      child: CommonLoadingWidget(
                        size: 30.0,
                        color: Colors.black,
                      ),
                    )
                        : Container(
                      margin: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )),

                // Flip camera button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor.withOpacity(0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flip_camera_ios,
                    color: AppColors.whiteColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class IdCardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5);

    // Draw dark overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Calculate card frame dimensions
    final cardWidth = size.width * 0.8;
    final cardHeight = cardWidth * 0.63; // Standard ID card aspect ratio
    final cardLeft = (size.width - cardWidth) / 2;
    final cardTop = (size.height - cardHeight) / 2;

    // Clear the card area
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
        Radius.circular(12),
      ),
      clearPaint,
    );

    // Draw card frame corners
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = AppColors.whiteColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(cardLeft, cardTop + cornerLength)
        ..lineTo(cardLeft, cardTop)
        ..lineTo(cardLeft + cornerLength, cardTop),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(cardLeft + cardWidth - cornerLength, cardTop)
        ..lineTo(cardLeft + cardWidth, cardTop)
        ..lineTo(cardLeft + cardWidth, cardTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(cardLeft, cardTop + cardHeight - cornerLength)
        ..lineTo(cardLeft, cardTop + cardHeight)
        ..lineTo(cardLeft + cornerLength, cardTop + cardHeight),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(cardLeft + cardWidth - cornerLength, cardTop + cardHeight)
        ..lineTo(cardLeft + cardWidth, cardTop + cardHeight)
        ..lineTo(cardLeft + cardWidth, cardTop + cardHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}