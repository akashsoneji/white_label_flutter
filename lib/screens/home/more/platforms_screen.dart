import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/common/webview_screen.dart';
import 'package:crm_app/screens/more/view_models/platform_links_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// "Platforms": broker-configured trading platform downloads.
class PlatformsScreen extends StatelessWidget {
  const PlatformsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlatformLinksController());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.backgroundLight,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('platforms_title'),
          style: AppTextStyles.heading,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final links = controller.links.toList();
          if (controller.isLoading.value && links.isEmpty) {
            return const Center(child: CommonLoadingWidget(isFullScreen: false));
          }
          if (controller.errorMessage.value.isNotEmpty && links.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              message: controller.errorMessage.value,
              onRetry: controller.loadLinks,
            );
          }
          if (links.isEmpty) {
            return _CenteredMessage(
              icon: Icons.download_for_offline_outlined,
              message: TranslationUtils.tr('platforms_empty'),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadLinks,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemCount: links.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, index) => _PlatformCard(link: links[index]),
            ),
          );
        }),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final PlatformLink link;

  const _PlatformCard({required this.link});

  IconData get _fallbackIcon => switch (link.slug.toLowerCase()) {
        'ios' => Icons.apple,
        'android' => Icons.android,
        'windows' || 'desktop' || 'mac' || 'macos' => Icons.desktop_windows_outlined,
        'web' || 'webtrader' || PlatformLink.webTradingSlug => Icons.language,
        _ => Icons.download_rounded,
      };

  Future<void> _open() async {
    if (link.slug == PlatformLink.webTradingSlug) {
      Get.to(() => WebViewScreen(url: link.url, title: link.name));
      return;
    }
    final uri = Uri.tryParse(link.url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      CustomToastService.showError(
        message: TranslationUtils.tr('platforms_open_failed'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(_fallbackIcon, size: 24.sp, color: AppColors.primary);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: _open,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: link.imageUrl.isEmpty
                    ? fallback
                    : Image.network(
                        link.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback,
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (link.description.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        link.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.open_in_new_rounded,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40.sp),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('common_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
