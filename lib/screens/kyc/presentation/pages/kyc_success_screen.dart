import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/kyc_scaffold.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'dart:async';

class KycSuccessScreen extends StatefulWidget {
  const KycSuccessScreen({Key? key}) : super(key: key);

  @override
  State<KycSuccessScreen> createState() => _KycSuccessScreenState();
}

class _KycSuccessScreenState extends State<KycSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _contentController;
  late AnimationController _featuresController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;

  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _messageSlide;
  late Animation<double> _messageOpacity;
  // ignore: unused_field
  late Animation<double> _featuresOpacity;
  // ignore: unused_field
  late Animation<double> _buttonScale;
  late Animation<double> _pulseAnimation;

  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _featuresController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Define animations
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    _messageSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _messageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    _featuresOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _featuresController, curve: Curves.easeInOut),
    );

    _buttonScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations with delays
    _iconController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      _contentController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      _featuresController.forward();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      _buttonController.forward();
    });

    // Start pulse animation after icon appears
    Future.delayed(const Duration(milliseconds: 800), () {
      _pulseController.repeat(reverse: true);
    });

    // Start countdown timer
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        _navigateToTrading();
      }
    });
  }

  void _navigateToTrading() {
    // Navigate to trading screen (main dashboard with bottom navigation)
    Get.offAllNamed(Routes.TRADING);
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
    _featuresController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KycScaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon with Scale and Pulse Animation
              Stack(
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _iconController,
                        _pulseController,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _iconScale.value,
                          child: Opacity(
                            opacity: _iconOpacity.value,
                            child: Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: EdgeInsets.only(top: 25.h),
                                width: 100.w,
                                height: 100.h,

                                child: BrandLogo(
                                  source: FlavorConfig.effectiveLogo,
                                  color: null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Center(
                    child: Container(
                      height: 140.h,
                      child: Image.asset(
                        'assets/animation/3QqFEnMu0w.gif',
                        width: 250.w,
                        height: 250.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32.h),

              // Success Title with Slide and Fade Animation
              AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleOpacity,
                      child: Text(
                        'Withdrawal Method Added!',
                        style: AppTextStyles.centerbodyHeading,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 5.h),

              // Success Message with Slide and Fade Animation
              AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _messageSlide,
                    child: FadeTransition(
                      opacity: _messageOpacity,
                      child: Text(
                        'Your withdrawal method has been added and is pending verification.',
                        style: AppTextStyles.grey14400h57,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 48.h),

              // Features List with Fade Animation
            ],
          ),
        ),
      ),
    );
  }
}
