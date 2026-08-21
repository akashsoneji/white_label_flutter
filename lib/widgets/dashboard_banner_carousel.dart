import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/models/banner_model.dart';
import 'package:crm_app/screens/trading/view_models/banner_controller.dart';

class DashboardBannerCarousel extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? borderRadius;
  final bool showIndicator;

  const DashboardBannerCarousel({
    super.key,
    this.margin,
    this.padding,
    this.height,
    this.borderRadius,
    this.showIndicator = true,
  });

  @override
  State<DashboardBannerCarousel> createState() => _DashboardBannerCarouselState();
}

class _DashboardBannerCarouselState extends State<DashboardBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  late final BannerController _bannerController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _bannerController = Get.isRegistered<BannerController>()
        ? Get.find<BannerController>()
        : Get.put(BannerController(), permanent: true);

    _startAutoPlay();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _stopAutoPlay();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final banners = _bannerController.banners;
      if (_pageController.hasClients && banners.length > 1) {
        final nextPage = (_currentPage + 1) % banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final banners = _bannerController.banners;
      if (banners.isEmpty) {
        return const SizedBox.shrink();
      }

      final carouselHeight = widget.height ?? 125.h;
      final radius = widget.borderRadius ?? 14.r;

      return Container(
        margin: widget.margin ?? EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
        padding: widget.padding ?? EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  final imageUrl = banner.imageUrl ?? '';

                  return GestureDetector(
                    onTap: () => _bannerController.handleBannerTap(banner),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 2.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.fill,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFallbackCard(banner),
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: AppColors.cardBackGround,
                                    alignment: Alignment.center,
                                    child: Center(
                                      child: SizedBox(
                                        width: 24.w,
                                        height: 24.w,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _buildFallbackCard(banner),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.showIndicator && banners.length > 1) ...[
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (idx) {
                  final isSelected = _currentPage == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: isSelected ? 16.w : 5.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textGrey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildFallbackCard(BannerItem banner) {
    return Container(
      color: AppColors.cardBackGround,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_rounded,
            color: AppColors.primary,
            size: 32.sp,
          ),
          if (banner.title != null && banner.title!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              banner.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
