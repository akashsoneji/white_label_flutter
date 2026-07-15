---
name: project-tasks-json-fixed-2026-07-13
description: "tasks.json: 10 prepare-<brand> tasks fixed with CLIENT env prefix (2026-07-13)"
type: project
createdAt: 1783936787990
updatedAt: 1783936787990
---

`.vscode/tasks.json` me saare 10 `prepare-<brand>` tasks update ho gaye (2026-07-13) taaki har F5 press pe `CLIENT=<brand> FLAVOR=<brand> dart run scripts/generate_brand_config.dart` prepend ho.

**Why:** User ne 2026-07-13 ko confirm kiya ki Pipze launch config select karke F5 maarte hi Skyriss UI load ho raha tha — yani `lib/flavor_config.dart` aur `prepare_flavor.dart` ke assets mismatch ho rahe the. Root cause: tasks sirf `prepare_flavor.dart <brand>` call karte the bina generator re-run ke, isliye stale enum (`enum Flavor { pipze }` ya multi-brand) rehta tha jab `activateByName('pipze')` resolve nahi kar paata tha.

**How to apply:**
- Saare 10 `prepare-<brand>` tasks ab full triple-step chain chalaate hain: (1) `CLIENT=<brand> FLAVOR=<brand> dart run scripts/generate_brand_config.dart`, (2) `dart run scripts/prepare_flavor.dart <brand>`, (3) `rm -rf .dart_tool/flutter_build`
- Verified brands: baazex, celestial, gtxprime, kantara, meta, pipze, skyriss, telifox, tenax, vantage. JSON validity confirmed via `python3 json.load`.
- User ko VS Code window reload karne ki zaroorat hai (`Cmd+Shift+P` → "Developer: Reload Window") taaki updated tasks apply ho jayein.
- Agar future me koi naya brand add ho to `scripts/generate_brand_config.dart` ka template already `CLIENT=<brand> FLAVOR=<brand>` prepend karta hai — lekin `.vscode/tasks.json` ko manually edit karna pade to same pattern follow karein.

Related: [[project-debug-after-release-mismatch-2026-07-09]], [[project-brand-switch-flows-2026-07-09]], [[project-3-parents-7-children-2026-07-09]].
