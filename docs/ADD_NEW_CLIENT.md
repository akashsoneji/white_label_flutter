# Add a New Client / Flavor

This project now supports a simple **one client = one folder** workflow.

## Folder structure

Create one folder:

```shell
assets/brands/{client}/
```

Required files:

```shell
assets/brands/{client}/brand.yaml
assets/brands/{client}/icon.png
assets/brands/{client}/logo.svg
assets/brands/{client}/splash_logo.svg
```

Optional files:

```shell
assets/brands/{client}/app_config.json
assets/brands/{client}/google-services.json
```

## brand.yaml template

```yaml
name: acme
type: child
inheritsFrom: vantage
label: Acme
themeMode: both

android:
  applicationId: com.acme.app
  appName: Acme

ios:
  bundleId: com.acme.app
  appName: Acme

colors:
  primary: "#5F259E"
  darkPrimary: "#5F259E"
  secondary: "#F8F3FF"
  accent: "#FFC93C"
  splashColor: "#5F259E"
  launcherBackground: "#5F259E"

urls:
  api: https://my.acme.com/api/
  websocket: wss://my.acme.com/trade-engine
  chart: https://my.acme.com

assets:
  appIcon: icon.png
  logo: logo.svg
  splashLogo: splash_logo.svg
```

## Generate + build

```shell
dart run scripts/generate_brand_config.dart
./build.sh acme apk release
```

## Run on iOS (Xcode)

iOS is fully auto-configured from `brand.yaml` — no manual Xcode changes are
needed for any current or future flavor:

```shell
dart run scripts/generate_brand_config.dart   # only when adding/changing a brand
dart run scripts/prepare_flavor.dart acme      # sets iOS bundle id, app name, icon, splash, flavor
open ios/Runner.xcworkspace                     # then just press Run in Xcode
```

The prepare step writes `ios/Flutter/Brand.xcconfig` (bundle id, display name,
`DART_DEFINES` for the active flavor, Flutter target), regenerates the iOS app
icon (`AppIcon.appiconset`), and sets the launch-screen color
(`appColor.colorset`). `Debug.xcconfig`/`Release.xcconfig` include
`Brand.xcconfig`, so Xcode-direct runs pick up the right flavor automatically.

Notes:
- iOS `bundleId` / `appName` come from the `ios:` block in `brand.yaml`.
- For iOS push notifications, add `assets/brands/acme/GoogleService-Info.plist`;
  it is copied to `ios/Runner/GoogleService-Info.plist` during prepare. If absent,
  iOS Firebase setup is skipped (the app still runs).
- After switching flavors you may need Xcode → Product → Clean Build Folder (⇧⌘K).

## Do not manually edit generated files

These files are generated from `assets/brands/*/brand.yaml`:

- `assets/config/brands/brands.yaml`
- `assets/config/brands/brands.json`
- `lib/clients/*/config.dart`
- `lib/clients/*/launcher_icons.yaml`
- `lib/flavor_config.dart`
- `android/brand_flavors.gradle`
- `android/app/src/{client}/res/values/colors.xml`
- `.vscode/launch.json`

## Notes

- `splashColor` controls Android splash background (`my_splash_color`).
- `launcherBackground` controls adaptive launcher icon background (`ic_launcher_background`).
- If `google-services.json` exists in the client folder, it is copied automatically to `android/app/src/{client}/google-services.json` during build.
- If `app_config.json` exists in the client folder, it is copied automatically to `assets/clients/{client}/app_config.json` during build and bundled with that client.
