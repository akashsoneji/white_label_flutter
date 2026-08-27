---
name: flutter-widget-composition-and-performance
description: |
  Best practices for widget composition, performance optimization, const constructors, 60/120fps scrolling, RepaintBoundary, and preventing unnecessary rebuilds in Flutter.
  Use when refactoring monolithic widgets, optimizing slow scrolling lists, reducing CPU/memory footprint, or decomposing complex UI screens into clean components.
  Triggers on: "performance", "optimize widget", "rebuild", "const constructor", "ListView.builder", "Slivers", "RepaintBoundary", "slow scrolling", "lag".
---

# Flutter Widget Composition & Performance Best Practices

Follow these rules to ensure smooth 60/120fps UI performance and clean, maintainable widget architecture:

## 1. Extract Widgets Over Helper Methods
- **Antipattern**: Using private helper methods like `Widget _buildUserCard() { ... }`.
  - Helper methods do NOT create a separate element in the widget tree; when the parent rebuilds, the helper method always executes from scratch.
  - Helper methods cannot use `const` caching.
- **Best Practice**: Extract into a dedicated `StatelessWidget` with a `const` constructor:
  ```dart
  class UserCard extends StatelessWidget {
    final UserModel user;
    const UserCard({super.key, required this.user});

    @override
    Widget build(BuildContext context) {
      return Card(...);
    }
  }
  ```

## 2. Leverage `const` Constructors Everywhere
- Always mark widgets, `EdgeInsets`, `BoxDecoration`, `SizedBox`, and `TextStyle` with `const` when their values are compile-time constants.
- `const` widgets are instantiated once and reused across rebuilds, short-circuiting unnecessary element updates.

## 3. Scope Rebuilds Narrowly
- Keep `setState()`, `ref.watch()`, or `Consumer` as deep down the widget tree as possible.
- Never place a state listener at the root of a large `Scaffold` if only a small counter or badge updates.
- Wrap only the dynamic part inside a localized `Consumer` or `ValueListenableBuilder`.

## 4. List and Grid Optimization
- Never use `Column` or `SingleChildScrollView(child: Column(children: ...))` for long or dynamic lists.
- Always use `ListView.builder` or `CustomScrollView` with `SliverList` / `SliverGrid`:
  - They lazily instantiate only visible widgets on screen.
  - Use `itemExtent` or `prototypeItem` when children have uniform height to eliminate layout measurement overhead.
  - Set `addAutomaticKeepAlives: false` and `addRepaintBoundaries: true` when list items are static to conserve memory.

## 5. Repaint Boundaries for Heavy or Animated Widgets
- Wrap complex custom painters, live charts, video players, or frequently animating components in `RepaintBoundary`:
  ```dart
  RepaintBoundary(
    child: LiveCandlestickChartWidget(...),
  )
  ```
  This isolates raster repainting so surrounding UI elements do not get repainted every frame.
