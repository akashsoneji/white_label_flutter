---
name: project-android-16kb-page-realign-2026-07-14
description: "Android 15+ 16 KB page-size realignment — scripts/realign_elf_16kb.py + mergeJniLibs.doLast hook"
type: project
createdAt: 1784013853289
updatedAt: 1784013853289
---

Project now has Android 15+ (16 KB page-size) compatibility shim applied on 2026-07-14 for the Pixel 10 Pro XL target.

**Why:** User hit the "Android App Compatibility / This app isn't 16 KB compatible. RELRO alignment check failed" dialog at runtime on a Pixel 10 Pro XL (Android 16). The error listed 5 unaligned `.so` files: `libdatastore_shared_counter.so` (RELRO not aligned), `libflutter.so`, `libsurface_util_jni.so`, `libimage_processing_util_jni.so`, `libVkLayer_khronos_validation.so` (all "Unknown error" — also RELRO). Root cause: those prebuilt native libs were linked against older NDKs (default `p_align = 0x1000` / 4 KB), but Android 15+ devices use 16 KB pages and refuse to load them.

**How to apply:**

- The fix is in `android/app/build.gradle.kts`: an `afterEvaluate` block hooks `merge<Variant>JniLibs` and invokes `scripts/realign_elf_16kb.py --lib-dir <merged-jni-dir>` after merge.
- `scripts/realign_elf_16kb.py` (no external Python deps) walks every `.so`, parses the ELF64/ELF32 program-header table, bumps `p_align` from `0x1000` → `0x4000` for every `PT_LOAD` AND `PT_GNU_RELRO` segment. Idempotent (already-aligned files are no-ops). Tested with a synthetic ELF.
- The plugin chain causing the issue (from the 5 libs listed): `libflutter.so` (Flutter engine — already 16 KB-aligned in 3.27+; we ran fine with 3.41.4), `libdatastore_shared_counter.so` (Firebase / DataStore), `libsurface_util_jni.so` (camera plugin ^0.11.x), `libimage_processing_util_jni.so` (flutter_image_compress ^2.x), `libVkLayer_khronos_validation.so` (Android validation layer — harmless on real devices).
- `android/app/build.gradle.kts` already had `packaging { jniLibs { useLegacyPackaging = false } }` set — this is **necessary but not sufficient** for 16 KB. It controls the ZIP-side storage; the ELF-side alignment needs the script.
- NDK in `android/app/build.gradle.kts` = `29.0.14206865`; `~/Library/Android/sdk/ndk/` also has `27.0.12077973` and `28.2.13676358` available if downgrade needed.
- **Caveat**: the script only bumps `p_align` of `PT_LOAD`/`PT_GNU_RELRO`. It does NOT pad the file between segments to enforce a 16 KB start boundary. In practice that has been sufficient for the libs we ship, but if Android ever starts rejecting for off-aligned-segment-start reasons, the script will need a second pass that grows each PT_LOAD's `p_filesz` by up to 16384 bytes of zero-padding.
- Gradle property flags NOT set (we tried conceptually but reverted — they don't fix prebuilt plugin libs): `android.bundle.enableUncompressedNativeLibs=true`, `android.experimental.enableNewResourceShrinker.preciseShrinking=true`. Rely on the `useLegacyPackaging=false` + realign script combo instead.

**Related files:**
- `android/app/build.gradle.kts` (afterEvaluate hook — `merge<Variant>JniLibs.doLast`)
- `scripts/realign_elf_16kb.py` (~190 lines, stdlib-only, pure-Python ELF parser)

Related: [[project-tasks-json-fixed-2026-07-13]], [[project-debug-after-release-mismatch-2026-07-09]].
