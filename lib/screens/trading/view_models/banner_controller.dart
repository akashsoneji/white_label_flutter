import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/models/banner_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/bonus/presentation/pages/scratch_card_screen.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/flavor_config.dart';

class BannerController extends GetxController {
  final RxList<BannerItem> banners = <BannerItem>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchBanners();
  }

  /// Fetch active dashboard banners from api/user/banners?page=dashboard
  Future<void> fetchBanners({String page = 'dashboard', bool showLoading = false}) async {
    try {
      if (showLoading) isLoading.value = true;
      final response = await ApiService.get(
        endpoint: 'user/banners',
        queryParameters: {'page': page},
      );

      if (response.success && response.data != null) {
        final bannerResponse = BannerResponse.fromJson(response.data!);
        final items = bannerResponse.data?.banners ?? <BannerItem>[];
        banners.assignAll(items);
      } else {
        banners.clear();
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 BannerController: Error fetching banners: $e');
      }
      banners.clear();
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  /// Handles tap on a banner with smart in-app redirection and external fallback
  Future<void> handleBannerTap(BannerItem banner) async {
    final clickUrl = banner.clickUrl?.trim() ?? '';
    final title = (banner.title ?? '').toLowerCase();
    final imageAlt = (banner.imageAlt ?? '').toLowerCase();
    final urlLower = clickUrl.toLowerCase();

    // 1. In-app navigation matches
    if (urlLower.contains('/promotion/trade-win') ||
        urlLower.contains('tradewin') ||
        title.contains('trade & win') ||
        imageAlt.contains('trade & win')) {
      Get.toNamed(AppPages.TRADE_WIN_MAIN);
      return;
    }

    if (urlLower.contains('/scratch') ||
        title.contains('scratch') ||
        imageAlt.contains('scratch') ||
        title.contains('scretch')) {
      Get.to(
        () => const ScratchCardListScreen(),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
      return;
    }

    if (urlLower.contains('/bonus') ||
        title.contains('bonus') ||
        imageAlt.contains('bonus')) {
      Get.toNamed(AppPages.BONUS);
      return;
    }

    if (urlLower.contains('/contest') ||
        urlLower.contains('/demo-contest') ||
        title.contains('contest')) {
      if (EnabledModulesService.flags.democontest) {
        Get.toNamed(AppPages.DEMO_CONTEST);
      }
      return;
    }

    if (urlLower.contains('/deposit') || title.contains('deposit')) {
      Get.toNamed(AppPages.DEPOSIT);
      return;
    }

    if (urlLower.contains('/ib') ||
        urlLower.contains('/partnership') ||
        title.contains('refer')) {
      // Module off: the banner must not open IB (in-app or via its web URL).
      if (!EnabledModulesService.flags.ib) return;
      if (FlavorConfig.usesIquoteUi()) {
        Get.toNamed(AppPages.IB_DASHBOARD);
      } else {
        Get.toNamed(AppPages.IB_DASHBOARD);
      }
      return;
    }

    if (urlLower.contains('/promotion')) {
      Get.to(() => const PromotionalScreen());
      return;
    }

    if (urlLower.contains('/account') || urlLower.contains('/accounts')) {
      Get.toNamed(AppPages.CHOOSE_ACCOUNT);
      return;
    }

    // 2. External URL or generic URL fallback
    if (clickUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(clickUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (kDebugMode) {
          print('🚨 BannerController: Failed to launch URL $clickUrl: $e');
        }
      }
    }
  }
}
