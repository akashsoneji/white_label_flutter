---
name: project-debug-after-release-mismatch-2026-07-09
description: "Debug-after-release cross-contamination bug + fix (2026-07-09)"
type: project
createdAt: 1783602892478
updatedAt: 1783602892478
---

Debug-after-release cross-contamination bug + fix (2026-07-09):

**Bug:** User built Pipze release with `./build.sh pipze apk release`, then ran Celestial debug in VS Code — but Celestial UI didn't show, Pipze UI rendered instead. Same pattern for any other brand mismatch.

**Root cause:**
1. `./build.sh <brand> apk release` runs `dart run scripts/generate_brand_config.dart` first which **emits a single-client `lib/flavor_config.dart`** with only that brand's enum entry (e.g. `enum Flavor { pipze }`).
2. User then runs F5 → `prepare-celestial` task ran only `prepare_flavor.dart celestial` (asset swap) but **did NOT re-run** the generator with `CLIENT=celestial`.
3. `lib/flavor_config.dart` was still the pipze single-client variant. Even though `main.dart:_initializeFlavor()` correctly reads `String.fromEnvironment('CLIENT') = 'celestial'`, `FlavorConfig.activateByName('celestial')` called `Flavor.values.firstWhere(...)` and fell back to `Flavor.pipze` because `Flavor.celestial` literally didn't exist in the enum. Result: Pipze UI.

**Why:** `scripts/generate_brand_config.dart:_brandsForCurrentBuild()` calls `_envClientName()` which reads `Platform.environment['CLIENT'|'FLAVOR']`. The single-client filter only kicks in when one of those env vars is set. `./build.sh` sets them; VS Code task shells did not.

**Fix (2026-07-09):** Updated all 10 `prepare-<brand>` tasks in `.vscode/tasks.json` to prepend the generator step with `CLIENT=<brand> FLAVOR=<brand>` set, so the single-client filter matches. Example for Celestial:
```
"args": [
  "-lc",
  "CLIENT=celestial FLAVOR=celestial dart run scripts/generate_brand_config.dart && dart run scripts/prepare_flavor.dart celestial && rm -rf .dart_tool/flutter_build"
]
```
Verified: after `CLIENT=pipze FLAVOR=pipze ...` → enum = `pipze`. After `CLIENT=celestial FLAVOR=celestial ...` → enum = `celestial`.

**How to apply:**
- Every `prepare-<brand>` task MUST prepend `CLIENT=<brand> FLAVOR=<brand> dart run scripts/generate_brand_config.dart` before calling `prepare_flavor.dart <brand>`. Otherwise a previous release build's single-client enum wins and `activateByName(<brand>)` falls back to whatever enum entry exists.
- `scripts/generate_brand_config.dart` regenerates `.vscode/launch.json` and `.vscode/tasks.json` on every run — so when you add a new brand, regenerate the files (the generator's tasks.json template includes the `CLIENT=<brand> FLAVOR=<brand>` prefix for new entries).
- After any single-client build, running the generator WITHOUT `CLIENT` env restores the multi-brand enum (10 entries) — useful for IDE analysis and the dev-only `BrandSwitcher` widget.
- `lib/main.dart:_initializeFlavor()` reads `String.fromEnvironment('CLIENT')` first, falls back to `String.fromEnvironment('FLAVOR')`, then defaults to `vantage`. If the binary was compiled single-client (e.g. `enum Flavor { pipze }`), it MUST be the right brand, otherwise the brand name from `--dart-define` won't be matched by `activateByName()`.

Related: [[project-brand-switch-flows-2026-07-09]], [[project-3-parents-7-children-2026-07-09]], [[project-feature-folder-restructure]].
