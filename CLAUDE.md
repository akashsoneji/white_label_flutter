# Flutter Project Assistant Guide

## Essential Commands
- `flutter pub get` — Fetch dependencies
- `flutter analyze` — Run Dart/Flutter analyzer
- `flutter test` — Run unit and widget tests
- `dart run build_runner build --delete-conflicting-outputs` — Generate code (if needed)
- `flutter run` — Start development debug build

## Architecture & Conventions
- **Folder Structure**: Feature-first structure in `lib/screens/<feature_name>/` or `lib/features/`.
- **UI State**: Presentation separated from business logic. Always handle 4 core states: Loading (Shimmer), Error (with Retry), Empty, and Data.
- **Widgets**: Single public widget per file. Prefix private helper widgets with `_`. Always prefer `StatelessWidget` with `const` constructors over monolithic helper methods.
- **Theming**: Never hardcode hex colors or fixed text styles. Always consume `Theme.of(context)`.
- **Layouts**: Always build responsive layouts using `LayoutBuilder` / `MediaQuery.sizeOf(context)` / `Flexible` / `Expanded`. Guard against `RenderFlex` overflows.

## What NOT to do
- Do not edit generated files (`*.g.dart`, `*.freezed.dart`) directly.
- Do not add heavy external packages without confirmation.
- Do not put network requests or long computations inside widget `build()` methods.
- Do not hardcode device-specific pixel dimensions for full-screen elements.
