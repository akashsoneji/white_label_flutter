---
name: flutter-add-widget-preview
description: |
  Official guidelines for creating isolated Flutter widget previews, UI component testing, golden tests, and widget smoke tests.
  Use when validating UI widgets in isolation, setting up preview files, or writing component-level tests with WidgetTester.
  Triggers on: "widget preview", "widget test", "golden test", "preview component", "test UI", "WidgetTester".
---

# Flutter Widget Preview & Isolated UI Testing

Use these techniques to preview and test widgets in isolation without requiring full end-to-end emulator launch:

## 1. Widget Preview Pattern
Create dedicated preview wrapper widgets (or test harnesses) to quickly verify visual states:

```dart
// test/previews/custom_card_preview.dart or lib/widgets/previews/custom_card_preview.dart

import 'package:flutter/material.dart';

class WidgetPreviewScaffold extends StatelessWidget {
  final Widget child;
  final ThemeMode themeMode;

  const WidgetPreviewScaffold({
    super.key,
    required this.child,
    this.themeMode = ThemeMode.dark,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: themeMode == ThemeMode.dark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

## 2. Component Widget Tests
Verify widget rendering and interaction with `testWidgets`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders balance and triggers callback on tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BalanceCard(
            balance: '\$12,450.00',
            onDepositPressed: () => tapped = true,
          ),
        ),
      ),
    );

    // Verify presence of text
    expect(find.text('\$12,450.00'), findsOneWidget);

    // Tap button and verify
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
```
