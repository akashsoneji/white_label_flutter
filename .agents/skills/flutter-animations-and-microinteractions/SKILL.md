---
name: flutter-animations-and-microinteractions
description: |
  Patterns and best practices for creating fluid Flutter animations, Hero transitions, micro-interactions, spring physics, and staggered list reveals.
  Use when adding UI delight, animating buttons/modals/loaders, creating smooth page transitions, or implementing custom animated widgets.
  Triggers on: "animation", "micro-interaction", "Hero transition", "AnimatedContainer", "AnimationController", "staggered animation", "shimmer effect", "haptic feedback".
---

# Flutter Animations & Micro-Interactions

Follow these guidelines to create fluid, 60/120fps animated UI experiences in Flutter:

## 1. Choose the Right Animation Level
- **Implicit Animations** (Simplest & Best for most UI state changes):
  - `AnimatedContainer`, `AnimatedOpacity`, `AnimatedPadding`, `AnimatedAlign`, `AnimatedCrossFade`, `AnimatedScale`, `AnimatedRotation`.
  - Use when animating a single property based on state changes (e.g. active tab expand, color transition, card selection).
  - Always provide a modern curve like `Curves.easeInOutCubic` or `Curves.easeOutBack` with a duration of 200–350ms.
- **Explicit Animations** (When fine-grained controller, looping, or sequence is needed):
  - Use `AnimationController` + `SingleTickerProviderStateMixin`.
  - Always remember to `controller.dispose()` in `dispose()`.
  - Use `AnimatedBuilder` or `ListenableBuilder` to rebuild only the animated subtree.

## 2. Micro-Interactions on Tap & Press
Add spring press feedback to custom buttons or cards:
```dart
class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ScaleButton({super.key, required this.child, required this.onTap});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

## 3. Hero Animations for Shared Elements
- Connect list items to detail screens seamlessly using matching `Hero(tag: item.id, child: ...)`.
- Ensure the inner widget hierarchy (clip radius, aspect ratio) matches to avoid warping during flight.

## 4. Staggered List Entrance Animation
When a list loads, reveal items with subtle staggered fade & slide-in:
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: ItemTile(item: items[index]),
    );
  },
);
```

## 5. Skeleton / Shimmer Loading Placeholder
- Provide a smooth shimmer gradient overlay during data fetching instead of a generic blank spinner.
