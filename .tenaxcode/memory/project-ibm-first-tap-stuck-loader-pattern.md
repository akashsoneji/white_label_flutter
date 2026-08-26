---
name: project-ibm-first-tap-stuck-loader-pattern
description: "IBM first-tap-stuck-loader bug pattern: Obx body gate reads non-reactive bool instead of subscribing to controller Rx loading flag; fix = read controller.isXxxLoading.value inside Obx"
type: project
createdAt: 1787727833100
updatedAt: 1787727833100
---

IBM screens have a recurring "first tap shows only loader / never renders, second tap works" bug.

**Root cause pattern:** A screen's `body: Obx(() {...})` gates on a PLAIN (non-reactive) bool field (e.g. `_tabsResolved`, `_isLoaded`) and reads NO `.value` observable, so the Obx has no reactive subscription. The loader only lifts via a post-frame `setState`, which loses the race on the first (cold) navigation because the shared singleton `IbmController` RxMaps are empty. Second tap works because the shared controller data is now warm and the awaited fetch returns instantly.

**Fix pattern:** inside the Obx, ALSO read the controller's Rx loading flag (`controller.isProfileLoading.value` / dashboard loading Rx) so the Obx gets a real subscription and repaints when the fetch's `finally` flips it false.

**ALREADY FIXED (2026-08-26):** `lib/screens/ibm/presentation/pages/ibm_client_profile_screen.dart` body gate (~L344) now reads `final loading = controller.isProfileLoading.value;` and gates `if (!_tabsResolved && loading)`.

**CURRENT TASK (user reported via GIF):** SAME first-tap bug on the "IB Dashboard" entry → opens `IbmMainShell` (does `Get.put(IbmController())` in build) → tab 0 = `IbmManagerPortalScreen` (`lib/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart`). Need to check that screen's initState (fires dashboard fetch) + its build gate for the same non-reactive Obx pattern and apply the same fix (subscribe to the dashboard loading Rx in the Obx). Nav path: More screen IB Dashboard tile → `_handleSwitchToIB()` → `IbmController.checkSystemAndNavigate()` (controller L72) shows Get.dialog loader, awaits getSystemStatus, then `Get.toNamed(Routes.IBM_MANAGER_PORTAL)` (L110) = `IbmMainShell`.

flutter bin = `~/development/flutter/bin/flutter`. analyze single file after edit.
