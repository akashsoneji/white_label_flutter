---
name: flutter-screen-builder
description: |
  Comprehensive blueprint for building full Flutter screens following feature-first architecture, clean UI state handling, loading shimmers, error retries, and empty states.
  Use when creating a brand new screen, feature page, dashboard tab, or modal view.
  Triggers on: "create screen", "build screen", "new page", "feature screen", "screen-builder", "presentation screen".
---

# Flutter Screen Builder Blueprint

Follow this step-by-step blueprint when creating new Flutter screens:

## 1. Directory & File Placement
Always place screen files inside feature presentation layers:
```
lib/screens/<feature_name>/
├── presentation/
│   ├── pages/          # Full screen pages (e.g. trading_overview_screen.dart)
│   └── widgets/        # Feature-specific sub-widgets (e.g. order_book_widget.dart)
├── view_models/        # State controllers / notifiers
└── models/             # Domain / response models
```

## 2. Standard Screen Structure Checklist
Every screen must handle the **4 Core UI States**:
1. **Loading State**: Display a subtle skeleton/shimmer loader matching the expected card/list layout (avoid a single generic center spinner if possible).
2. **Error State**: Informative error message with an actionable **"Retry"** button.
3. **Empty State**: Friendly illustration/icon, clear explanation, and a primary CTA (e.g. "No transactions yet. Start trading").
4. **Data State**: Clean, responsive layout wrapped in `SafeArea` and `RefreshIndicator` where applicable.

## 3. Template Screen Pattern
```dart
import 'package:flutter/material.dart';

class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Title'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // refresh trigger
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header / Summary Card
                    const FeatureHeaderCard(),
                    const SizedBox(height: 16),

                    // Section Title
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // Dynamic List or Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: FeatureItemTile(index: index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 4. UI Rules
- One public widget per file. Prefix private helper widgets with an underscore `_`.
- Avoid putting network requests or complex data parsing in widget `build()` methods.
- Support dark and light theme gracefully by reading from `Theme.of(context)`.
