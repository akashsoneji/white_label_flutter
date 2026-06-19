# iOS Flavor Build — one terminal command, then run directly from Xcode (future-flavor-proof)

> **Active test flavor: `tenax`** (bundle: `com.tenax.app`, name: `Tenax`, primary/splash: `#4A0C54`).
> **Design rule: iOS prep is 100% data-driven from `assets/brands/<flavor>/brand.yaml` — NO flavor name is ever hardcoded in any iOS file or in the script.** Isi wajah se future me koi bhi naya flavor add karo to bina kisi iOS change ke `dart run scripts/prepare_flavor.dart <newflavor>` + Xcode Run kaam karega.

## Goal
Terminal se ek hi command (`dart run scripts/prepare_flavor.dart <flavor>`, ya `./debug.sh`/`./build.sh`) chalane par iOS ka **app icon, app display name, bundle id, splash background, brand colors, Firebase config, aur active flavor (dart-define)** automatically set ho jaye. Uske baad bas **Xcode kholo aur normal Run** karo — koi alag flavor-specific scheme ya extra Debug/Release/Profile variant nahi chahiye (standard Debug/Release/Profile hi rahenge). **Yeh kisi bhi current YA future flavor ke liye same kaam kare.**

## Future-flavor compatibility (core principle)
- iOS ke saare flavor-specific values **runtime me `brand.yaml` se padhe** jaate hain — script me koi `if (flavor == 'tenax')` type branching nahi.
- Generated files (`ios/Flutter/Brand.xcconfig`, `AppIcon.appiconset`, `appColor.colorset`, optional `GoogleService-Info.plist`) har prep-run par **overwrite** hote hain → flavor switch instant.
- Naya flavor add karna = bas `assets/brands/<newflavor>/` folder + `brand.yaml` banao, `dart run scripts/generate_brand_config.dart` chalao, phir `dart run scripts/prepare_flavor.dart <newflavor>` → Xcode Run. **Koi iOS file manually chhune ki zaroorat nahi.**
- `prepare_flavor.dart` pehle se `loadBrandNames()` se sab flavors dynamically discover karta hai (`assets/brands/*/brand.yaml`) — naya flavor automatically valid maana jayega.

## Current state (research findings)
- `scripts/prepare_flavor.dart` abhi **sirf Android** ke liye sab karta hai (google-services, splash, colors.xml, launcher icons → `android/app/src/<flavor>/`). iOS ke liye kuch nahi. → `scripts/prepare_flavor.dart:38-44`
- `loadBrandNames()` / `loadBrandColors()` already `assets/brands/*/brand.yaml` se data-driven hain → iOS step bhi inhi helpers ko reuse karega. → `scripts/prepare_flavor.dart`
- `lib/clients/<flavor>/launcher_icons.yaml` me `ios: true` already hai (har flavor ke liye generate hota hai by `generate_brand_config.dart`). → `lib/clients/tenax/launcher_icons.yaml`
- iOS `Info.plist` me `CFBundleDisplayName`/`CFBundleName` **hardcoded "Tenax"**. → `ios/Runner/Info.plist:11,21`
- `project.pbxproj` me `PRODUCT_BUNDLE_IDENTIFIER = com.pipze.app` **hardcoded** (Debug/Release/Profile). → `ios/Runner.xcodeproj/project.pbxproj:463,658,693`
- Flavor runtime me `String.fromEnvironment('CLIENT'|'FLAVOR')` (compile-time dart-define). → `lib/main.dart` `_initializeFlavor()`
- Xcode-direct build par Flutter `DART_DEFINES` (comma-separated base64 `key=value`) ko xcconfig/build settings se padhta hai (mechanism `generate_brand_config.dart` `_envClientName()` me bhi use hota hai). → confirmed
- `LaunchScreen.storyboard` background = **`appColor` named color** → `ios/Runner/Assets.xcassets/appColor.colorset/Contents.json` se (RGB 0–1). Dono editable, confirmed.
- `assets/brands/<flavor>/brand.yaml` me `ios.bundleId`, `ios.appName`, `colors.primary/splashColor` har flavor ke liye maujood. → `assets/brands/tenax/brand.yaml`

## Approach (key decisions)
1. **Generated xcconfig** `ios/Flutter/Brand.xcconfig` (prep har baar overwrite kare), values **brand.yaml se**:
   - `PRODUCT_BUNDLE_IDENTIFIER` ← `ios.bundleId` (fallback `com.<flavor>.app`)
   - `BRAND_DISPLAY_NAME` ← `ios.appName` (fallback `label`)
   - `DART_DEFINES` = base64(`CLIENT=<flavor>`),base64(`FLAVOR=<flavor>`)
   - `FLUTTER_TARGET=lib/main.dart`
2. **Debug.xcconfig + Release.xcconfig** me `#include? "Brand.xcconfig"` (Generated.xcconfig ke baad; idempotent). Profile bhi Release.xcconfig use karta hai → auto-cover. Koi naya variant nahi.
3. **pbxproj** ke Runner Debug/Release/Profile se hardcoded `PRODUCT_BUNDLE_IDENTIFIER = com.pipze.app` line hatao taaki xcconfig se aaye. RunnerTests chhodenge. **(One-time edit; iske baad har flavor cover.)**
4. **Info.plist** display name dynamic: `CFBundleDisplayName`=`$(BRAND_DISPLAY_NAME)`, `CFBundleName`=`$(BRAND_DISPLAY_NAME)`. **(One-time edit; har flavor cover.)**
5. **iOS app icon**: prep me `dart run flutter_launcher_icons -f lib/clients/<flavor>/launcher_icons.yaml` (ios:true) → `AppIcon.appiconset` overwrite. Flavor-agnostic (config path flavor se banta hai).
6. **iOS splash color**: `appColor.colorset/Contents.json` me `splashColor` (fallback `primary`) → light+dark dono. Color brand.yaml se parse.
7. **Firebase (iOS)**: agar `assets/brands/<flavor>/GoogleService-Info.plist` ho to `ios/Runner/GoogleService-Info.plist` copy; warna stale handle/skip. (Android `google-services.json` jaisa hi pattern, har flavor ke liye.)
8. Sab kuch `prepareIos(flavor, brandColors)` me, jo `main()` me Android steps ke saath call ho → **ek command se dono platforms, kisi bhi flavor ke liye.**

> **One-time vs per-flavor:** Steps 3 (pbxproj) aur 4 (Info.plist) ek hi baar ke structural edits hain — uske baad sab flavors ke liye reusable. Baaki sab har prep-run par flavor ke hisaab se regenerate hota hai.

## Steps
- [x] **1. iOS prep function** — `scripts/prepare_flavor.dart` me `prepareIos(String flavor, {Map<String,String> brandColors})`; `main()` me Android steps ke baad call. ✅
- [x] **2. iOS metadata loader** — `loadIosMeta(flavor)` brand.yaml ka `ios.bundleId`/`ios.appName` padhta hai (fallback `com.<flavor>.app` / `label`). Data-driven, no hardcode. ✅
- [x] **3. Brand.xcconfig generate (overwrite)** — bundle id, display name, `DART_DEFINES` (base64 CLIENT+FLAVOR), `FLUTTER_TARGET`. Verified via xcodebuild. ✅
- [x] **4. xcconfig includes (one-time, idempotent)** — `Debug.xcconfig` & `Release.xcconfig` me `#include? "Brand.xcconfig"`. ✅
- [x] **5. pbxproj un-hardcode (one-time)** — Runner Debug/Release/Profile se `PRODUCT_BUNDLE_IDENTIFIER = com.pipze.app` removed (RunnerTests untouched). ✅
- [x] **6. Info.plist dynamic name (one-time)** — `CFBundleDisplayName`/`CFBundleName` → `$(BRAND_DISPLAY_NAME)`. ✅
- [x] **7. iOS app icon** — `flutter_launcher_icons` (ios) → `AppIcon.appiconset` overwrite. ✅
- [x] **8. iOS splash color** — `appColor.colorset/Contents.json` me `splashColor`/`primary` (light+dark). tenax #4A0C54 verified. ✅
- [x] **9. iOS Firebase (optional, per-flavor)** — `assets/brands/<flavor>/GoogleService-Info.plist` ho to copy; warna skip. ✅
- [x] **10. Test (tenax)** — `dart run scripts/prepare_flavor.dart tenax` + `flutter build ios --config-only --simulator` → "Building com.tenax.app for simulator". xcodebuild settings: bundle=com.tenax.app, name=Tenax, DART_DEFINES=CLIENT/FLAVOR=tenax. ✅
- [x] **11. Future-flavor smoke test** — `skyriss` pe prepare → bundle=com.skyriss.app, name=Skyriss, splash=#000000, **bina kisi manual iOS edit ke**; phir tenax pe wapas switch. ✅
- [x] **12. Docs update** — `docs/ADD_NEW_CLIENT.md` me "Run on iOS (Xcode)" section add. ✅

## Files
- `scripts/prepare_flavor.dart` — `prepareIos()` + `loadIosMeta()`; `main()` se call. (primary, data-driven)
- `ios/Flutter/Brand.xcconfig` — **naya, generated, overwritten har run** (bundle id, display name, DART_DEFINES, FLUTTER_TARGET).
- `ios/Flutter/Debug.xcconfig` — `#include? "Brand.xcconfig"` (one-time).
- `ios/Flutter/Release.xcconfig` — `#include? "Brand.xcconfig"` (one-time; Profile cover).
- `ios/Runner.xcodeproj/project.pbxproj` — hardcoded bundle id hatana (one-time, 3 Runner lines).
- `ios/Runner/Info.plist` — `CFBundleDisplayName`/`CFBundleName` → `$(BRAND_DISPLAY_NAME)` (one-time).
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` — per-flavor icon overwrite.
- `ios/Runner/Assets.xcassets/appColor.colorset/Contents.json` — per-flavor splash color.
- `ios/Runner/GoogleService-Info.plist` — (optional) per-flavor Firebase overwrite.
- `docs/ADD_NEW_CLIENT.md` — iOS workflow note (future flavors).
- `assets/brands/<flavor>/brand.yaml` — source of truth (read-only).

## Risks / Open questions
- **Future flavor checklist** (jo Agent docs me likhega): (1) `assets/brands/<newflavor>/` me `brand.yaml` + `icon.png` + `logo.svg` + `splash_logo.svg`; (2) `dart run scripts/generate_brand_config.dart`; (3) `dart run scripts/prepare_flavor.dart <newflavor>`; (4) Xcode Run. iOS me kuch manual nahi.
- **Xcode caching**: bundle id/name change ke baad kabhi "Clean Build Folder" (⇧⌘K) lage.
- **pbxproj edit**: sirf 3 Runner lines, RunnerTests nahi — corruption se bachav.
- **DART_DEFINES override**: include order se Brand.xcconfig ka `DART_DEFINES` jeete; verify via `FlavorConfig.instance.flavor`.
- **iOS Firebase per-flavor**: jab tak brand folder me `GoogleService-Info.plist` na ho, Firebase iOS skip rahega (app chalega; init error gracefully handled in `main.dart`). Naya flavor agar push notifications chahta hai to uska plist daalna hoga.
- **Splash logo (SVG)**: iOS launch screen me SVG nahi render hota — sirf background color; logo image scope se bahar.
- **`pod install`**: pehli baar / pods change pe; warna nahi.
