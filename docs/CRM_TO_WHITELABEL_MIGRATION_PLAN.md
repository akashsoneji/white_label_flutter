# CRM App → Whitelabel App Migration Plan

**Project:** `whitelabel/app` (package: `crm_app`)  
**Source:** `/Users/akash/Desktop/Soneji Infotech/xelthio/app/crmapp`  
**Target flavor:** **Vantage** (parent) + **Celestial** (child)  
**Last updated:** 2026-06-03  
**Status:** ✅ Migration complete (CRM parity for active flavors)

---

## 0. Non-Breaking Merge Policy (CONFIRMED)

> **Existing Vantage/Celestial UI, screens, and flows were NOT modified.**  
> CRM features added using **additive-only** changes.

| Rule | Detail |
|------|--------|
| **Source files** | CRM `controller` + UI/design files used as reference |
| **Target pattern** | Logic in `view_models/` + `presentation/pages/` |
| **Existing screens** | Bank / Crypto / UPI / Local deposit — **unchanged** |
| **No multibroker** | Tenax broker code **never** ported |
| **No extra flavors** | Only `vantage`, `celestial`, `tenax` (legacy) |

---

## 1. Progress Tracker

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1 — Cregis crypto deposit | ✅ Complete | Controller + 2 screens + routes |
| Phase 2 — Service layer parity | ✅ Complete | Logic already matches CRM (import paths only differ); `api_service` intentionally refactored in whitelabel |
| Phase 3 — Copy trading subscription | ✅ Complete | Mock `subscription_setup` routes to live `COPY_TRADING_HUB` |
| Phase 3 — IB / drawer / PMAM stubs | ✅ Parity | Same as CRM (placeholders / coming soon) |
| Phase 4 — Celestial app_config | ✅ Complete | `assets/config/celestial/app_config.json` |
| Phase 4 — iOS Celestial + Vantage | ✅ Complete | xcconfigs + Xcode build configurations |
| Phase 4 — iOS scripts | ✅ Complete | `update_ios_flavor.sh`, `run_ios_flavor.sh` → tenax/vantage/celestial |
| Phase 4 — Android release signing | ✅ Scaffold | `keystore.properties.example` + conditional signing in `build.gradle.kts` |
| Phase 5 — Cleanup (xelthio dead code) | ⏸ Deferred | Optional; no flavor uses xelthio screens |

---

## 2. Feature Status (All Plan Items)

### High priority

| # | Feature | Status |
|---|---------|--------|
| 1 | Cregis crypto deposit | ✅ Done |
| 2 | Deposit instruction (Cregis UI) | ✅ Done |
| 3 | Deposit controller API | ✅ Done (via `FinanceRepository`) |
| 4 | Copy trading subscription | ✅ Done (redirect to live hub flow) |

### Medium priority

| # | Feature | Status |
|---|---------|--------|
| 5–9 | IB placeholder screens (5) | ✅ CRM parity (stubs in both apps) |
| 10 | Global drawer | ✅ CRM parity (coming soon in both) |
| 11 | PMAM export PDF | ✅ CRM parity (coming soon in both) |
| 12 | Celestial app_config | ✅ Done |
| 13 | Service layer parity | ✅ Verified |

### Low priority / infrastructure

| # | Item | Status |
|---|------|--------|
| 14 | Dark mode | ⏸ Off by design (`enableDarkModeGlobal = false`) |
| 15 | iOS flavor setup | ✅ Done |
| 16 | Android release signing | ✅ Scaffold ready (add `android/keystore.properties`) |

---

## 3. Files Added / Modified

### New files

```
lib/screens/finance/presentation/pages/cregis_address_screen.dart
lib/screens/finance/presentation/pages/cregis_success_screen.dart
assets/config/celestial/app_config.json
ios/Flutter/Debug-Celestial.xcconfig
ios/Flutter/Release-Celestial.xcconfig
ios/Flutter/Profile-Celestial.xcconfig
ios/Flutter/Debug-Vantage.xcconfig
ios/Flutter/Release-Vantage.xcconfig
ios/Flutter/Profile-Vantage.xcconfig
android/keystore.properties.example
```

### Modified (additive / infra only)

```
lib/constants/api_const.dart
lib/screens/finance/view_models/deposit_instruction_controller.dart
lib/screens/finance/presentation/pages/deposit_instruction_screen.dart
lib/screens/finance/view_models/deposit_controller.dart
lib/screens/copy_trading/presentation/pages/subscription_setup_screen.dart
lib/routes/app_routes.dart
lib/routes/app_pages.dart
pubspec.yaml
scripts/update_ios_flavor.sh
scripts/run_ios_flavor.sh
ios/Runner.xcodeproj/project.pbxproj
android/app/build.gradle.kts
.gitignore
```

---

## 4. Build Commands

### Android

```bash
# Vantage
flutter run --flavor vantage --dart-define=CLIENT=vantage --dart-define=FLAVOR=vantage

# Celestial
flutter run --flavor celestial --dart-define=CLIENT=celestial --dart-define=FLAVOR=celestial

# Release (after adding android/keystore.properties)
flutter build apk --flavor vantage --dart-define=CLIENT=vantage --dart-define=FLAVOR=vantage --release
```

### iOS

```bash
bash scripts/update_ios_flavor.sh celestial
bash scripts/run_ios_flavor.sh celestial

# Or manually:
flutter run --dart-define=CLIENT=celestial --dart-define=FLAVOR=celestial
```

Xcode configurations: `Debug-Celestial`, `Release-Celestial`, `Profile-Celestial`, `Debug-Vantage`, `Release-Vantage`, `Profile-Vantage`

### Android signing setup

```bash
cp android/keystore.properties.example android/keystore.properties
# Edit with your keystore path and credentials
```

---

## 5. Test Checklist

### Cregis

- [ ] Deposit methods list shows Cregis gateway
- [ ] Network selection from `cregis_network_map`
- [ ] Checkout flow → browser → polling → success
- [ ] Address flow → QR + copy → polling → success
- [ ] Bank / Crypto / UPI / Local deposits unchanged

### General

- [ ] Vantage + Celestial Android builds
- [ ] iOS builds with updated xcconfigs
- [ ] Copy trading: legacy setup screen → hub redirect works
- [ ] No multibroker code in whitelabel

---

## 6. What Was NOT Ported (By Design)

- Multibroker (Tenax broker selection)
- 12+ extra CRM flavors (pipze, octa, onsa, etc.)
- IB / drawer / PMAM full UI (not implemented in CRM either)
- xelthio dead brand files cleanup (optional future task)

---

*Migration complete for Vantage parent + Celestial child. Existing UI preserved.*
