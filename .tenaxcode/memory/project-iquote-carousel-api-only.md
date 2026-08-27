---
name: project-iquote-carousel-api-only
description: "iQuote home carousel fix: hide carousel entirely when banner API returns empty (drop the 3 fallback slides — user wants no static carousel content)."
type: project
createdAt: 1787822007556
updatedAt: 1787822007556
---

iQuote home carousel — user wants: if API returns banners, render them; if API returns empty, hide the entire carousel (NO static fallback slides like "Refer & Earn Program"). API endpoint `GET /user/banners?page=dashboard` already wired via `BannerController` (lib/screens/trading/view_models/banner_controller.dart) — banners populated into `RxList<BannerItem> banners`. Carousel widget `_PromoCarousel` (L704+) currently ALWAYS renders, falling back to 3 hardcoded slides (`_fallbackSlides` L725-750: Profit Ranking / Refer & Earn / Promotions) when API empty. User doesn't want that fallback.

FIX PLAN in `lib/screens/home/iquote_home_screen.dart`:
1. DELETE the `_fallbackSlides` field (L725-750 — 26 lines) and the unused `FlavorConfig` import is NOT used here so leave alone.
2. In `_PromoCarouselState.build()` (L784-786), wrap the existing `return Obx(() { ... })` so that when `banners.isEmpty` it returns `SizedBox.shrink()` — including the PageView indicator dots (currently rendered below the pageview using `banners.length` or `_fallbackSlides.length`).
3. Update the `_timer.periodic` (L759-773): the `totalCount` computation uses `_fallbackSlides.length` — change to just `_bannerController.banners.length`. When 0 the if (totalCount > 1) skips anyway, fine. Stop timer in dispose if empty.
4. The unused `Get.toNamed(AppPages.CHOOSE_ACCOUNT)` / `IquoteHomeScreen.handleSwitchToIB()` / `Get.to(() => PromotionalScreen())` references inside `_fallbackSlides` get deleted with the field — they become unused and are fine to remove.
5. PageView indicator dots need to be aware of new "empty = hide" semantics — currently rendered inside the carousel's build return; will be naturally excluded since the whole build returns SizedBox.shrink().

After fix, `_PromoCarousel` becomes a pure "render API banners or nothing" widget. analyze the file. flutter bin `~/development/flutter/bin/flutter`.
