---
name: flutter-ui-audit-and-fix
description: |
  Checklist and iterative workflow for auditing Flutter UI code, fixing layout issues, eliminating lint warnings, and ensuring zero flutter analyze errors.
  Use when validating newly built screens, fixing lints, refactoring UI components, or running self-correcting fix loops.
  Triggers on: "flutter analyze", "fix lints", "lint errors", "audit UI", "fix layout issues", "check code".
---

# Flutter UI Audit & Self-Correcting Fix Workflow

Use this checklist and workflow to audit and fix Flutter UI code:

## 1. Static Analysis Checklist
Run `flutter analyze` and resolve all issues:
- **`prefer_const_constructors`**: Ensure all unmodified widget declarations use `const`.
- **`use_build_context_synchronously`**: When using `BuildContext` across async gaps (`await`), verify `if (!mounted) return;` or `if (!context.mounted) return;` is present before accessing `Navigator`, `Theme`, `ScaffoldMessenger`, or `MediaQuery`.
- **`avoid_print`**: Replace `print(...)` with `debugPrint(...)` or proper logging.
- **`sized_box_for_whitespace`**: Use `SizedBox(...)` instead of empty `Container(...)` for spacers.

## 2. Common UI Bug Checklist
- [ ] **RenderFlex overflow**: Check if any `Row` or `Column` contains unconstrained text or dynamic content without `Expanded` / `Flexible`.
- [ ] **Keyboard obstruction**: Confirm forms and input dialogs are wrapped in `SingleChildScrollView` or have `resizeToAvoidBottomInset: true`.
- [ ] **Hardcoded dimensions**: Verify container widths do not exceed mobile screen bounds (e.g. avoid fixed `width: 400` on mobile viewports; use `double.infinity` with padding or `constraints.maxWidth`).
- [ ] **Missing null safety checks**: Verify all model properties and nullable string fields are guarded with fallbacks (`title ?? ''`).

## 3. Autonomous Fix Loop Pattern
When tasked with fixing issues:
1. Run `flutter analyze` on the target file or project.
2. Read the error line, file path, and lint rule.
3. Apply targeted, precise code edits.
4. Re-run `flutter analyze` until 0 errors remain.
