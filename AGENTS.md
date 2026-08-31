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

