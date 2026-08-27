---
name: flutter-build-responsive-layout
description: |
  Official guidelines for building responsive, adaptive Flutter user interfaces across mobile, tablet, desktop, and foldable screens.
  Use whenever creating new screens, designing layouts, handling orientation changes, fixing RenderFlex overflow errors, or sizing widgets adaptively.
  Triggers on: "responsive layout", "adaptive UI", "fix overflow", "RenderFlex error", "screen size", "tablet layout", "mobile layout".
---

# Flutter Responsive & Adaptive Layout Guidelines

Follow these rules and patterns when designing and implementing Flutter layouts:

## Core Principles
1. **Window-Based Measurement Over Device Checks**:
   - Never hardcode checks for specific device models or hardware types (e.g. avoid `isTablet = width > 600` based on device properties).
   - Use `MediaQuery.sizeOf(context)` or `MediaQuery.of(context).size` for window-level sizing.
   - Use `LayoutBuilder` for component-level sizing based on parent widget constraints.
   - Core Flutter rule: **Constraints go down, sizes go up, parent sets position.**

2. **Preventing RenderFlex Overflows**:
   - Always wrap unbounded children in `Expanded` or `Flexible` inside `Row` or `Column` when children have dynamic content (text, images, dynamic lists).
   - Use `SingleChildScrollView` or `CustomScrollView` when a column or form may exceed the viewport height (e.g., when the on-screen keyboard appears).
   - Set `resizeToAvoidBottomInset: true` on `Scaffold` for form screens with input fields.
   - Use `TextOverflow.ellipsis` with `maxLines` on `Text` widgets inside bounded containers to prevent horizontal/vertical text overflow.

3. **Breakpoints and Adaptive Sizing**:
   - Define standard adaptive breakpoints:
     - **Compact (Mobile)**: width < 600
     - **Medium (Tablet/Foldable)**: 600 <= width < 840
     - **Expanded (Desktop/Web)**: width >= 840
   - Example Helper Pattern:
     ```dart
     class ResponsiveLayout extends StatelessWidget {
       final Widget mobile;
       final Widget? tablet;
       final Widget? desktop;

       const ResponsiveLayout({
         super.key,
         required this.mobile,
         this.tablet,
         this.desktop,
       });

       static bool isMobile(BuildContext context) =>
           MediaQuery.sizeOf(context).width < 600;
       static bool isTablet(BuildContext context) =>
           MediaQuery.sizeOf(context).width >= 600 &&
           MediaQuery.sizeOf(context).width < 840;
       static bool isDesktop(BuildContext context) =>
           MediaQuery.sizeOf(context).width >= 840;

       @override
       Widget build(BuildContext context) {
         return LayoutBuilder(
           builder: (context, constraints) {
             if (constraints.maxWidth >= 840 && desktop != null) {
               return desktop!;
             } else if (constraints.maxWidth >= 600 && tablet != null) {
               return tablet!;
             }
             return mobile;
           },
         );
       }
     }
     ```

4. **SafeArea and Inset Handling**:
   - Always wrap root screen content in `SafeArea` or handle `MediaQuery.paddingOf(context)` / `MediaQuery.viewInsetsOf(context)`.
   - Use `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` for bottom sheets or dialogs with text fields.

5. **Grid & Flow Layouts**:
   - Use `GridView.builder` with `SliverGridDelegateWithMaxCrossAxisExtent` rather than fixed column counts so grids automatically adapt across screen widths:
     ```dart
     GridView.builder(
       gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent: 220,
         mainAxisSpacing: 12,
         crossAxisSpacing: 12,
         childAspectRatio: 1.1,
       ),
       itemCount: items.length,
       itemBuilder: (context, index) => ItemCard(item: items[index]),
     )
     ```
