---
name: project-ibm-dashboard-tile-double-tap-nav-race
description: "RESOLVED: IB Dashboard first-tap-nothing bug = Get.back(closeOverlays:true)+Get.toNamed race in checkSystemAndNavigate; fixed with plain Get.back + await Future.delayed(Duration.zero)"
type: project
createdAt: 1787727912449
updatedAt: 1787727953106
---

RESOLVED (2026-08-26): "IB Dashboard tile: first tap nothing, second tap works" bug.

**ROOT CAUSE:** `IbmController.checkSystemAndNavigate()` (`lib/screens/ibm/view_models/ibm_controller.dart` ~L72) closed the loader dialog with `Get.back(closeOverlays: true)` and then IMMEDIATELY called `Get.toNamed(Routes.IBM_MANAGER_PORTAL)` in the same synchronous block. `closeOverlays:true` races the subsequent route push in GetX and swallows the first navigation.

**FIX APPLIED (right after `final response = await _apiProvider.getSystemStatus();`, ~L83):** replaced `Get.back(closeOverlays: true);` with:
```
if (Get.isDialogOpen ?? false) Get.back();
await Future.delayed(Duration.zero);
```
This dismisses only the loader and yields one microtask so the route stack settles before `Get.toNamed`. Applies to BOTH branches (IBM_MANAGER_PORTAL + IBM_APPLICATION) since the dismiss is now before the branch. Analyze clean.

The destination screen `IbmManagerPortalScreen` was already fine (its Obx gate L112 reads `controller.isLoading.value` reactively). Links: [[project-ibm-dashboard-tile-double-tap-nav-race]] [[project-ibm-first-tap-stuck-loader-pattern]].
