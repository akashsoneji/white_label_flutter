import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_shipping_details_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class TradeWinRedeemController extends GetxController {
  TradeWinRedeemController({
    required this.product,
    required this.initialQuantity,
  });

  final TradeWinProductModel product;
  final int initialQuantity;

  final RxInt currentStep = 1.obs;
  final RxInt quantity = 1.obs;
  final RxBool isSubmitting = false.obs;
  final RxString claimReferenceNo = ''.obs;

  static const _prefPrefix = 'trade_win_shipping_';
  static const redeemTag = 'trade_win_redeem';

  double get totalCost => product.requiredPoints * quantity.value;

  double get balanceAfter {
    if (!Get.isRegistered<TradeWinController>()) return 0;
    final current =
        Get.find<TradeWinController>().stats.value?.totalPoints ?? 0;
    return (current - totalCost).clamp(0, double.infinity);
  }

  @override
  void onInit() {
    super.onInit();
    quantity.value = initialQuantity.clamp(
      1,
      product.stock > 0 ? product.stock : 1,
    );
  }

  static Future<TradeWinShippingDetailsModel> loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return TradeWinShippingDetailsModel(
      name: prefs.getString('${_prefPrefix}name') ?? '',
      phone: prefs.getString('${_prefPrefix}phone') ?? '',
      email: prefs.getString('${_prefPrefix}email') ?? '',
      address: prefs.getString('${_prefPrefix}address') ?? '',
      city: prefs.getString('${_prefPrefix}city') ?? '',
      country: prefs.getString('${_prefPrefix}country') ?? '',
    );
  }

  static Future<void> saveAddress(TradeWinShippingDetailsModel details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefPrefix}name', details.name);
    await prefs.setString('${_prefPrefix}phone', details.phone);
    await prefs.setString('${_prefPrefix}email', details.email);
    await prefs.setString('${_prefPrefix}address', details.address);
    await prefs.setString('${_prefPrefix}city', details.city);
    await prefs.setString('${_prefPrefix}country', details.country);
  }

  static bool validateShipping(TradeWinShippingDetailsModel details) {
    return details.name.isNotEmpty &&
        details.phone.isNotEmpty &&
        details.email.isNotEmpty &&
        details.address.isNotEmpty &&
        details.city.isNotEmpty &&
        details.country.isNotEmpty;
  }

  void goToStep(int step) {
    currentStep.value = step.clamp(1, 3);
  }

  Future<void> completeAndGoHome() async {
    if (Get.isRegistered<TradeWinController>()) {
      final tradeWin = Get.find<TradeWinController>();
      tradeWin.mainTabIndex.value = 0;
      await tradeWin.fetchProducts(showLoader: false, audience: 'client');
      await tradeWin.fetchPastWins(reset: true);
    }

    FocusManager.instance.primaryFocus?.unfocus();
    if (Get.currentRoute == AppPages.TRADE_WIN_MAIN) {
      Get.back(closeOverlays: true);
      return;
    }
    Get.until((route) => route.settings.name == AppPages.TRADE_WIN_MAIN);
  }

  Future<void> submitRedemption({
    required TradeWinShippingDetailsModel shipping,
    required bool rememberAddress,
  }) async {
    if (!validateShipping(shipping)) return;

    isSubmitting.value = true;
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.tradeWinClaim,
        data: {
          'product_id': product.id,
          'quantity': quantity.value,
          'shipping_details': shipping.toJson(),
        },
      );

      if (!response.success) {
        CustomToastService.showError(
          message:
              response.message ??
              Get.find<LanguageService>().tr('tw_claim_failed'),
        );
        isSubmitting.value = false;
        return;
      }

      if (rememberAddress) {
        await saveAddress(shipping);
      }

      claimReferenceNo.value = _parseClaimReference(response.data);

      if (Get.isRegistered<TradeWinController>()) {
        final tradeWin = Get.find<TradeWinController>();
        tradeWin.fetchProducts(showLoader: false);
        tradeWin.fetchPastWins(reset: true);
      }

      currentStep.value = 3;
    } catch (e) {
      CustomToastService.showError(message: e.toString());
    } finally {
      isSubmitting.value = false;
    }
  }

  String _parseClaimReference(dynamic raw) {
    final maps = <Map<String, dynamic>>[];
    void collect(dynamic node) {
      if (node is Map) {
        maps.add(Map<String, dynamic>.from(node));
        final inner = node['data'];
        if (inner is Map) collect(inner);
      }
    }

    collect(raw);
    for (final m in maps) {
      for (final key in ['reference_no', 'reference', 'reference_number']) {
        final v = m[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    return '';
  }
}
