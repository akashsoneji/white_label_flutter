# iQuote — Center-Right Slide-In Toast Notification

## Goal
Give the **iQuote** brand a distinct toast/notification UI that slides in from the **right edge**, anchored at the **vertical center** of the screen, and slides back out — without touching the toast UX of any other brand (tenax, vantage, meta, baazex, gtxprime, kantara, celestial, pipze, riyadex, skyriss, telifox, etc.).

## Approach
The existing pipeline is:

- Everyone calls `CustomToastService.showSuccess/showError/showInfo/showWarning` in `lib/widgets/custom_toast.dart`.
- Those forward to `AppNotificationController` (`lib/screens/common/view_models/app_notification_controller.dart`) which pushes items into an `RxList<AppNotification>`.
- A single global overlay widget `AppNotificationStack` (`lib/widgets/app_notification_stack.dart`) is mounted in `lib/main.dart` inside the app-wide `Stack`. It is currently hard-coded to `Positioned(top:…, left:16.w, right:16.w)` and renders each item via `AppNotificationItem` (`lib/widgets/app_notification_item.dart`).

The cleanest, least invasive change is to **branch the overlay layout inside `AppNotificationStack` when the active brand is iquote**, and use a dedicated iquote-styled item widget that animates in from the right. All call sites (`CustomToastService.show*`) stay untouched, so no controller/service/screen has to change.

Decisions / trade-offs:
- Branch on brand at the overlay layer (not per-call-site) → 100+ toast call sites keep working with zero edits.
- Use `FlavorConfig.usesIquoteUi()` (the same helper already used by `finance_ui_registry.dart` and `ui_registry.dart`) so children of the iquote parent inherit the new UI automatically. This matches the repo's parent/child brand pattern — do NOT invent a new brand check.
- Animate with a plain `AnimatedSwitcher` + `SlideTransition` (right → in, in → right) so we don't add a package. Duration ~250 ms enter, ~200 ms exit, curve `Curves.easeOutCubic` / `easeInCubic`.
- Vertical center = `Positioned(top: 0, bottom: 0, right: 0)` + `Align(alignment: Alignment.centerRight)`. This keeps it inside the same global `Stack` slot that already covers the safe area.
- Preserve the current stacking behaviour (max 5 for trading, 1 for generic) — that logic lives in the controller and stays untouched.
- Keep colors/icons semantically consistent with `CustomToast` (success/error/info/warning) but render a compact **pill / card** with rounded-left corners flush to the right edge — visually reads as a side drawer chip rather than a top banner.

Out of scope: notification content model, timers, sound, chart-screen trading notification stacking rules.

## Steps
- [x] Step 1 — Create `lib/widgets/brands/iquote/iquote_notification_item.dart`
  - New `StatefulWidget` `IquoteNotificationItem({required AppNotification notification})`.
  - Layout: right-flush card, `borderRadius: BorderRadius.only(topLeft: 20.r, bottomLeft: 20.r)`, coloured left accent bar (2–3 px) using `AppColors.success/error/info/warning`, white/dark bg from `AppColors`, subtle shadow, `maxWidth ~ 300.w`.
  - Contents: circular icon (same icon logic as `CustomToast._getIcon`), title (optional) + message using `AppTextStyles.bodyText`, close button that calls `Get.find<AppNotificationController>().removeNotification(notification.id)`.
  - Own entrance/exit anim: `AnimationController` (250 ms), `SlideTransition` from `Offset(1.2, 0)` → `Offset.zero`; on dispose the parent removes it, so no exit-anim needed at the item level (exit handled by `AnimatedSwitcher` in the stack).
  - Use `MouseRegion` / `GestureDetector` swipe-right-to-dismiss (`onHorizontalDragEnd` with positive velocity) — nice-to-have, keep small.

- [x] Step 2 — Update `lib/widgets/app_notification_stack.dart`
  - Import `FlavorConfig` and the new `IquoteNotificationItem`.
  - In `AppNotificationStack.build`, compute `final isIquote = FlavorConfig.usesIquoteUi();`.
  - If `isIquote`, return:
    ```dart
    Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: _IquoteNotificationContent(),
          ),
        ),
      ),
    );
    ```
    else return the existing top-anchored `Positioned` block untouched.
  - Add `_IquoteNotificationContent` (mirrors `_NotificationContent`) that renders an `AnimatedSwitcher` + `Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min)` of `IquoteNotificationItem`s. Use `notification.id` as `ValueKey` so `AnimatedSwitcher` picks up add/remove and animates.
  - Keep `Material(color: Colors.transparent)` wrapper so text/InkWell still work.

- [x] Step 3 — Verify mount point in `lib/main.dart` (confirmed at `lib/main.dart:700`, inside full-app `Stack`, no clipper).
  - Confirm `AppNotificationStack()` is already inside the top-level `Stack` that overlays the whole app (it is — do NOT re-mount). Just make sure nothing else clips at the right edge (e.g. a `ClipRect`). If a clipper is in the way, wrap the branch in a full-height `Positioned.fill` as above so the slide has room.

- [ ] Step 4 — Smoke test on iquote flavor
  - Run one of the iquote-parent launch configs (e.g. `PARENT=iquote`) and trigger:
    - a success toast (bonus claim / withdrawal),
    - an error toast (validation),
    - a rapid stream (one-click trading loop) to confirm the generic-single-item rule from `AppNotificationController._addNotification` still holds (only one iquote toast on screen at a time; new one replaces old with slide).
  - Then run **one non-iquote flavor** (e.g. `tenax` or `vantage`) and confirm the toast is unchanged (top banner, full width).

## Files
- `lib/widgets/app_notification_stack.dart` — branch layout on `FlavorConfig.usesIquoteUi()`; keep old path as default.
- `lib/widgets/brands/iquote/iquote_notification_item.dart` — **new**, iquote-only slide-in right-edge card.
- (read-only reference) `lib/widgets/custom_toast.dart`, `lib/screens/common/view_models/app_notification_controller.dart`, `lib/widgets/app_notification_item.dart`, `lib/main.dart`.

No changes to `CustomToastService`, `AppNotificationController`, `AppNotification` model, or any call site.

## Risks / Open questions
- **Landscape / tablets**: iquote is portrait-locked (`SystemChrome.setPreferredOrientations` in `main.dart`), so center-right will always look right; not an issue.
- **Keyboard**: when the keyboard is open, the vertical-center anchor may land behind the keyboard. Acceptable? If not, we can offset by `MediaQuery.viewInsets.bottom / 2`. Confirm with user or default to the offset.
- **Trading notifications on chart screen**: chart uses `addTradingNotification` (multi-item). On iquote, should those also stack from the right at center, or keep top-anchored? Current plan: **all** notifications on iquote use the right-center UI (simpler, consistent). Flag if trading UX should be different.
- **Max width / long messages**: cap at `300.w` with `maxLines: 3, overflow: TextOverflow.ellipsis` to keep the pill tidy.
- **Brand check helper**: assumed `FlavorConfig.usesIquoteUi()` exists (used in `lib/screens/finance/presentation/finance_ui_registry.dart` and `lib/app/ui_registry.dart`). If iquote UI should extend to a specific child that does NOT resolve via that helper, we'll need `resolveActiveUiParent() == 'iquote'` instead.
