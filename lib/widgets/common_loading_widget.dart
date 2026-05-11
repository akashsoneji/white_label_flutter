import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:crm_app/constants/color.dart';

class CommonLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool isFullScreen;
  final Color? backgroundColor;

  const CommonLoadingWidget({
    super.key,
    this.message,
    this.size = 50.0,
    this.color,
    this.isFullScreen = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? AppColors.primary;
    final bgColor = backgroundColor ?? Colors.transparent;

    Widget loadingContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoadingAnimationWidget.fourRotatingDots(
          color: loadingColor,
          size: size,
        ),
        // if (message != null) ...[
        //   const SizedBox(height: 16),
        //   Text(
        //     message!,
        //     style: TextStyle(
        //       color: AppColors.whiteColor,
        //       fontSize: 16,
        //       fontWeight: FontWeight.w500,
        //     ),
        //     textAlign: TextAlign.center,
        //   ),
        // ],
      ],
    );

    if (isFullScreen) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: loadingContent,
          ),
        ),
      );
    }

    return Center(child: loadingContent);
  }
}

// Overlay loading widget for showing loading on top of current screen
class OverlayLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const OverlayLoadingWidget({
    super.key,
    this.message,
    this.size = 50.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CommonLoadingWidget(
      message: message,
      size: size,
      color: color,
      isFullScreen: true,
      backgroundColor: backgroundColor,
    );
  }
}

// Button loading widget for showing loading inside buttons
class ButtonLoadingWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const ButtonLoadingWidget({super.key, this.size = 20.0, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: color ?? AppColors.whiteColor,
        size: size,
      ),
    );
  }
}
