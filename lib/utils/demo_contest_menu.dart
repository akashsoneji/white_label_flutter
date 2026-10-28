import 'package:get/get.dart';
import 'package:crm_app/services/app_settings_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/services/language_service.dart';

/// Where the Demo Contest menu entry goes: `enabled-modules.democontest`
/// switches it on, `app-settings.demo_contest_menu_inside_promotion` moves it
/// under Promotions with `demo_contest_menu_label` as its name.
class DemoContestMenu {
  DemoContestMenu._();

  static bool get _moduleOn =>
      Get.isRegistered<EnabledModulesService>() &&
      Get.find<EnabledModulesService>().current.democontest;

  static bool get _insidePromotion =>
      Get.isRegistered<AppSettingsService>() &&
      Get.find<AppSettingsService>().current.demoContestMenuInsidePromotion;

  /// Show the entry in its usual place (More screen / brand settings).
  static bool get showStandalone => _moduleOn && !_insidePromotion;

  /// Show the entry inside the Promotions screen.
  static bool get showInPromotion => _moduleOn && _insidePromotion;

  static String get label {
    final custom = Get.isRegistered<AppSettingsService>()
        ? Get.find<AppSettingsService>().current.demoContestMenuLabel.trim()
        : '';
    return custom.isNotEmpty ? custom : TranslationUtils.tr('more_demo_contest');
  }
}
