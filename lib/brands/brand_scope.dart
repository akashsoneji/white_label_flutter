import 'package:get/get.dart';

import 'brand_id.dart';
import 'brand_resolver.dart';
import 'brand_widgets.dart';
import '../app/ui_registry.dart';

/// Global access point for brand-dependent UI.
class BrandScope {
  BrandScope._();

  static BrandResolver get resolver => Get.find<BrandResolver>();

  static BrandId get brandId => resolver.activeBrand.value;

  static BrandWidgets get widgets {
    // ✅ Use the singleton — the active brand is already resolved via
    // `FlavorConfig.instance.flavor.name` by `activeClient` inside
    return BrandWidgetsFromSlots(UiRegistry.instance);
  }
}

