# Project rules

## Imported from .cursorrules

# Cursor & Windsurf Rules for Flutter UI Development

1. Always follow Flutter official responsive design principles (`LayoutBuilder`, `MediaQuery.sizeOf(context)`).
2. Avoid hardcoded hex colors and dimensions; use `Theme.of(context)`.
3. Use `const` constructors on all widgets where possible to optimize rebuilds.
4. Always handle Loading (Shimmer), Error (with retry), and Empty UI states cleanly.
5. Refer to `.agents/skills/` for comprehensive task blueprints.

## Imported from CLAUDE.md

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

## Imported from AGENTS.md

# AI Assistant Guidelines for Flutter Development

## Core Principles
1. **Responsive & Adaptive UI**:
   - Follow Flutter official layout rules (`constraints down, sizes up, parent sets position`).
   - Use `LayoutBuilder`, `MediaQuery.sizeOf(context)`, and `Flexible`/`Expanded` to prevent `RenderFlex` overflows.
2. **Design & Theming**:
   - Strictly avoid hardcoded color literals (`Color(0xFF...)`). Always consume `Theme.of(context).colorScheme` or `ThemeExtension`.
   - Maintain high visual polish (glassmorphism, subtle card borders, consistent rounded corners, smooth micro-interactions).
3. **Performance**:
   - Use `const` constructors everywhere applicable.
   - Use `ListView.builder` / `SliverList` for long lists.
   - Isolate frequent repaints with `RepaintBoundary`.
4. **Skills & Rules Architecture**:
   - Skills are located in `.agents/skills/` and mirrored in `.claude/skills/`.
   - Rules are located in `.agents/rules/` (including `flutter_ui_design_rules.md` and `hot_reload.md`).
   - `.mcp.json` configures the official Dart & Flutter `dart-mcp-server`.

## Available Skills Catalog

### 1. Flutter UI, Architecture & Performance
- `flutter-screen-builder`: Blueprint for clean screens, state management, shimmer loading, and error states.
- `flutter-widget-composition-and-performance`: 60/120fps scrolling, `const` optimization, widget decomposition, `RepaintBoundary`.
- `flutter-design-system-and-theming`: Material 3, cohesive color scheme tokens, glassmorphism, consistent spacing.
- `flutter-animations-and-microinteractions`: Smooth physics, spring transitions, subtle hover/press feedback.
- `flutter-build-responsive-layout`: Adaptive breakpoints, `LayoutBuilder`, `MediaQuery.sizeOf(context)`.
- `flutter-apply-architecture-best-practices`: Clean separation across UI, Domain/Logic, and Data layers.
- `flutter-fix-layout-issues`: Diagnosing and fixing RenderFlex overflows, unbounded heights, and constraint bugs.
- `flutter-ui-audit-and-fix`: Automated checklist for lint compliance, visual polish, and zero `flutter analyze` errors.
- `flutter-setup-declarative-routing`: Navigation routing setup (e.g., `go_router`).
- `flutter-setup-localization`: Multi-language and `intl` localization setup.
- `flutter-implement-json-serialization`: Standard JSON serialization patterns for Flutter models.
- `flutter-use-http-package`: Clean REST API integration using `http`.

### 2. Dart Language & Quality
- `dart-use-pattern-matching`: Dart 3 pattern matching, switch expressions, and destructuring.
- `dart-use-primary-constructors`: Modern concise constructor syntax.
- `dart-run-static-analysis`: Running `dart analyze` and mechanical `dart fix --apply`.
- `dart-fix-runtime-errors`: Stack trace diagnosis and targeted resolution.
- `dart-resolve-package-conflicts`: Resolving pub dependency version mismatches.
- `dart-setup-ffi-assets`: FFI asset compilation and dynamic linking.
- `dart-use-ffigen`: Automated C/C++ FFI binding generation.
- `dart-build-cli-app`: Command-line tools and entrypoint structure.
- `dart-write-documentation`: Effective Dart API documentation guidelines.
- `dart-use-doc-examples`: Injecting validated doc examples using `@example`.

### 3. Testing & Verification
- `dart-add-unit-test`: Logic unit tests using `package:test`.
- `dart-generate-test-mocks`: External service mocking with `mockito`.
- `dart-migrate-to-checks-package`: Fluent assertions migration with `package:checks`.
- `dart-collect-coverage`: LCOV code coverage reporting.
- `flutter-add-widget-test`: Component widget testing with `WidgetTester`.
- `flutter-add-integration-test`: End-to-end integration tests using `integration_test`.
- `flutter-add-widget-preview`: Component isolated previews and interactive testing.

### 4. Code Quality & Review
- `code-review`: Multi-step iterative code review process (correctness, efficiency, maintainability).
- `api-review`: Canonical API design guidelines for public interfaces and methods.
- `code-documentation`: Standard-compliant documentation patterns.
- `natural-writing`: Clear, concise, non-redundant engineering writing.
