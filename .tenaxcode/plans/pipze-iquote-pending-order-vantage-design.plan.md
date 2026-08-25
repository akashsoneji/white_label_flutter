# Pipze (iquote parent) — Apply Vantage Pending-Order & Modify-Order Design

## Goal
Make the **Pending Order** screen and the **Modify (Edit) Pending Order** screen look and behave exactly like the Vantage design when the Pipze/iQuote app runs under the **iquote** UI parent. Today, under the iquote parent these screens fall back to the plain base design, which is not properly styled.

## Background (what exists today)
- The same child flavor (e.g. `pipze`) can run under different UI parents via `--dart-define=PARENT=vantage|iquote|...` (see `lib/app/ui_registry.dart` and `lib/brands/brand_resolver.dart`). "Pipze (vantage)" and "Pipze (iquote)" are two build configs sharing one flavor.
- **Pending order screen**: `lib/screens/home/pending_order_screen.dart`
  - Uses an `isVantage` gate in `build()` to pick the design:
    - Chart: `isVantage ? _buildChartSectionDense() : _buildChartSection()` (around line 622).
    - Body: `isVantage ? VantagePendingOrderContent(...) : PendingOrderContent(...)` (around lines 629–675).
  - The polished/compact Vantage design is in:
    - `lib/screens/home/brands/vantage/vantage_pending_order_content.dart`
    - `lib/screens/home/brands/vantage/vantage_pending_order_quote_pill.dart`
- **Modify / edit pending order screen**: `lib/screens/home/edit_order_screen.dart` — needs the same treatment (currently no Vantage fork wired for iquote parent).
- The `isVantage` flag is derived from a `FlavorConfig` parent check (the same helper family used across the app, e.g. `usesVantageUi()`), gated on `PARENT=vantage`. Under `PARENT=iquote` it is `false`, so the base (unstyled) content renders.

## Approach
Two viable options — **Option A is recommended** (smallest, reuses the existing Vantage fork verbatim, no new UI files):

- **Option A (recommended): Extend the existing gate to include the iquote parent.**
  Change the design-selection condition in `pending_order_screen.dart` (and `edit_order_screen.dart`) from "is Vantage" to "uses Vantage-style compact UI OR uses iquote UI". Both parents then render the identical `VantagePendingOrderContent` / dense chart / Vantage quote pill. Zero new widgets; guarantees pixel-parity with the Vantage design the user pointed at.
  - Introduce a single readable flag, e.g. `final useCompactOrderUi = FlavorConfig.instance.usesVantageUi() || FlavorConfig.instance.usesIquoteUi();` and replace every `isVantage ?` in these two screens with it.

- **Option B (only if iquote must diverge visually later): Create an iquote fork.**
  Copy `vantage_pending_order_content.dart` → `lib/screens/home/brands/iquote/iquote_pending_order_content.dart` and wire a third branch. More files, more drift risk. Not needed if the requirement is "same as Vantage".

Decision needed from user before Agent mode implements: **A or B** (default assumed: A).

## Steps
- [x] Step 1 — Confirmed. `pending_order_screen.dart:511` derived the design from `FlavorConfig.isVantage()`, which is just `usesVantageUi()`. Both `usesVantageUi()` (`flavor_config.dart:128`) and `usesIquoteUi()` (`flavor_config.dart:137`) already exist and honor `--dart-define=PARENT=`. No predicate needed to be added.
- [x] Step 2 — Done. In `pending_order_screen.dart:511` the gate is now `FlavorConfig.usesVantageUi() || FlavorConfig.usesIquoteUi()` (kept the local `isVantage` name so all 7 downstream `isVantage ?` sites — chart section, body, padding — now also apply under the iquote parent). Analyzer clean.
- [x] Step 3 — Verified NOT needed. `edit_order_screen.dart` (Modify Pending Order) is a single shared widget with NO brand fork and NO `isVantage` branching. Both Vantage and iQuote position screens navigate to the exact same `EditOrderScreen` (`iquote_position_screen.dart:1137`, `trade_screen.dart:2905`), so the modify screen is already identical across parents. No fork existed to reuse; no change required.
- [x] Step 4 — Confirmed. `presentation/pages/pending_order_screen.dart` and `.../edit_order_screen.dart` are pure re-exports of the `home/*` files; no change needed.
- [ ] Step 5 — Build & run Pipze under `--dart-define=PARENT=iquote` and open Pending Order + Modify Pending Order. Compare side-by-side with Pipze under `PARENT=vantage`; they must be visually identical. (Manual QA — pending user run.)

## Files
- `lib/screens/home/pending_order_screen.dart` — replace `isVantage` gate with combined vantage/iquote flag so iquote renders the Vantage pending-order design.
- `lib/screens/home/edit_order_screen.dart` — same gate change for the Modify Pending Order screen; wire Vantage-style content for iquote parent.
- `lib/flavor_config.dart` — confirm/add `usesIquoteUi()` (or equivalent) predicate used by the gate. (Modify only if the predicate is missing.)
- `lib/screens/home/brands/vantage/vantage_pending_order_content.dart` — reused as-is (no change under Option A).
- `lib/screens/home/brands/vantage/vantage_pending_order_quote_pill.dart` — reused as-is (no change under Option A).

## Risks / Open questions
- **Confirm predicate exists**: Whether `FlavorConfig` already exposes `usesIquoteUi()`. If not, the implementer must add it (single-line predicate mirroring `usesVantageUi()`), which slightly widens scope.
- **Modify screen fork**: `edit_order_screen.dart` may not yet have a Vantage layout branch at all. If so, this becomes a layout port (reuse the Vantage pending-order content styling), not just a one-line gate flip. Needs verification when the search tools recover.
- **Design intent**: This assumes iquote should be *pixel-identical* to Vantage on these two screens (Option A). If iquote should keep its own colors/branding but the Vantage *layout*, the reused `VantagePendingOrderContent` already pulls colors from `AppColors`, so per-brand theming still applies automatically — confirm this is acceptable.
- **Other brands under iquote parent**: The gate widening affects every child flavor running `PARENT=iquote` (not just pipze). Confirm that is intended (likely yes, since the design lives at the parent level).
