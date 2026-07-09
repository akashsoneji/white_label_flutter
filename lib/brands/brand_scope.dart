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
    // UiRegistry. Passing a `client:` argument no longer works because
    // the constructor no longer accepts it (it would force the UI to
    // follow the brand resolver instead of the flavor config used by
    // the rest of the app — causing Pipze to render Tenax's UI).
    return BrandWidgetsFromSlots(UiRegistry.instance);
  }
}

