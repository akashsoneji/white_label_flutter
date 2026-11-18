import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/chart/landscape_chart/landscape_chart_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() => Get.put(LanguageService()));
  tearDown(Get.reset);

  Future<void> pumpButton(WidgetTester tester, VoidCallback onTap) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FullscreenChartButton(onTap: onTap, size: 32, radius: 6),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the fullscreen icon at the requested size', (
    tester,
  ) async {
    await pumpButton(tester, () {});

    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(Container).first), const Size(32, 32));
  });

  testWidgets('tapping it opens the landscape chart callback once', (
    tester,
  ) async {
    var taps = 0;
    await pumpButton(tester, () => taps++);

    await tester.tap(find.byType(FullscreenChartButton));
    await tester.pump();

    expect(taps, 1);
  });

  // Regression: on a phone in landscape the 48px IconButton tap targets of
  // the lot stepper left the SELL/BUY tiles too short ("BOTTOM OVERFLOWED").
  for (final size in const [Size(640, 360), Size(740, 360), Size(800, 340)]) {
    testWidgets('landscape trade panel fits a ${size.width}x${size.height} '
        'phone without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final isOpen = ValueNotifier(true);
      final lotController = TextEditingController(text: '0.01');
      addTearDown(isOpen.dispose);
      addTearDown(lotController.dispose);

      // AppTextStyles' base styles read ScreenUtil, as in the real app.
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
          home: LandscapeChartPage(
            isOpen: isOpen,
            chartBuilder:
                (_) => const ColoredBox(
                  key: ValueKey('chart'),
                  color: Colors.white,
                ),
            currentSymbol: () => 'XAUUSD.cent',
            onSymbolChanged: (_) {},
            volumeController: lotController,
            minLot: () => 0.01,
            maxLot: () => 100,
            bid: () => '3770.78',
            ask: () => '3771.13',
            spread: () => '35',
            onSell: () {},
            onBuy: () {},
          ),
          ),
        ),
      );
      // Past the chart cover's reveal delay and fade.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LandscapeTradeTile), findsNWidgets(2));

      // One top bar, left to right: minimize, symbol, SELL, −, lot, +, BUY.
      final tiles = find.byType(LandscapeTradeTile);
      final order = [
        find.byIcon(Icons.fullscreen_exit_rounded),
        find.text('XAUUSD'),
        tiles.first,
        find.byIcon(Icons.remove_rounded),
        find.text('0.01'),
        find.byIcon(Icons.add_rounded),
        tiles.last,
      ];
      final centres = order.map((f) => tester.getCenter(f)).toList();
      for (var i = 1; i < centres.length; i++) {
        expect(centres[i].dx, greaterThan(centres[i - 1].dx));
        expect((centres[i].dy - centres[0].dy).abs(), lessThan(4));
      }
      // Translations are not loaded in tests, so labels are their keys.
      expect(
        tester.widget<LandscapeTradeTile>(tiles.first).label,
        contains('SELL'),
      );
      expect(
        tester.widget<LandscapeTradeTile>(tiles.last).label,
        contains('BUY'),
      );

      // The chart fills the full width under the bar.
      final chart = tester.getRect(find.byKey(const ValueKey('chart')));
      expect(chart.top, greaterThanOrEqualTo(tester.getRect(tiles.first).bottom));
      expect(chart.width, size.width);
    });
  }

  Future<void> pumpPage(WidgetTester tester, {Color? base}) async {
    final isOpen = ValueNotifier(true);
    final lotController = TextEditingController(text: '0.01');
    addTearDown(isOpen.dispose);
    addTearDown(lotController.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, __) => MaterialApp(
              theme: ThemeData(scaffoldBackgroundColor: base),
              home: LandscapeChartPage(
                isOpen: isOpen,
                chartBuilder: (_) => const SizedBox.expand(),
                currentSymbol: () => 'XAUUSD',
                onSymbolChanged: (_) {},
                volumeController: lotController,
                minLot: () => 0.01,
                maxLot: () => 100,
                bid: () => '3770.78',
                ask: () => '3771.13',
                spread: () => '35',
                onSell: () {},
                onBuy: () {},
              ),
            ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  // The camera hole sits mid-edge, below the bar: the bar may use the strip
  // its inset reserves, and only clears the rounded corners.
  for (final (name, hole, expectedInset) in const [
    ('below the bar', Rect.fromLTWH(0, 160, 40, 40), 24.0),
    ('inside the bar', Rect.fromLTWH(0, 8, 40, 40), 40.0),
  ]) {
    testWidgets('top bar side inset with the camera hole $name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: 40);
      tester.view.displayFeatures = [
        DisplayFeature(
          bounds: hole,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ];
      addTearDown(tester.view.reset);
      await pumpPage(tester);

      final exitButton = find.ancestor(
        of: find.byIcon(Icons.fullscreen_exit_rounded),
        matching: find.byType(IconButton),
      );
      final buy = find.byType(LandscapeTradeTile).last;
      expect(tester.getRect(exitButton).left, expectedInset);
      expect(tester.getRect(buy).right, 740 - expectedInset);
      expect(tester.takeException(), isNull);
    });
  }

  // Regression: with the camera cutout on one end only, the BUY tile ran
  // into the rounded corner on the other end and was clipped.
  testWidgets('top bar keeps both ends clear and uses the theme background', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 40);
    addTearDown(tester.view.reset);
    final isOpen = ValueNotifier(true);
    final lotController = TextEditingController(text: '0.01');
    addTearDown(isOpen.dispose);
    addTearDown(lotController.dispose);
    const base = Color(0xFFFAFAFA);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, __) => MaterialApp(
              theme: ThemeData(scaffoldBackgroundColor: base),
              home: LandscapeChartPage(
                isOpen: isOpen,
                chartBuilder: (_) => const SizedBox.expand(),
                currentSymbol: () => 'XAUUSD',
                onSymbolChanged: (_) {},
                volumeController: lotController,
                minLot: () => 0.01,
                maxLot: () => 100,
                bid: () => '3770.78',
                ask: () => '3771.13',
                spread: () => '35',
                onSell: () {},
                onBuy: () {},
              ),
            ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final exit = tester.getRect(find.byIcon(Icons.fullscreen_exit_rounded));
    final buy = tester.getRect(find.byType(LandscapeTradeTile).last);
    expect(exit.left, greaterThanOrEqualTo(40));
    expect(buy.right, lessThanOrEqualTo(740 - 40));

    // The bar is the nearest decorated Container around the minimize button.
    final bar = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.fullscreen_exit_rounded),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          )
          .first,
    );
    expect((bar.decoration! as BoxDecoration).color, base);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen swings in without rotating the device, and the '
      'chart only goes back once the close animation ends', (tester) async {
    // Portrait phone: the device must stay like this the whole time.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final orientationCalls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationCalls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final isOpen = ValueNotifier(false);
    final lotController = TextEditingController(text: '0.01');
    addTearDown(isOpen.dispose);
    addTearDown(lotController.dispose);
    const chartKey = ValueKey('chart');

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openLandscapeChart(
                context,
                isOpen: isOpen,
                pageBuilder: (_) => LandscapeChartPage(
                  isOpen: isOpen,
                  chartBuilder:
                      (_) => const ColoredBox(key: chartKey, color: Colors.white),
                  currentSymbol: () => 'XAUUSD',
                  onSymbolChanged: (_) {},
                  volumeController: lotController,
                  minLot: () => 0.01,
                  maxLot: () => 100,
                  bid: () => '1',
                  ask: () => '2',
                  spread: () => '1',
                  onSell: () {},
                  onBuy: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    double coverOpacity() => tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey('landscape-chart-cover')),
        )
        .opacity;

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Mid-swing the WebView stays put in portrait; it would paint black
    // wherever it has not redrawn while turning and resizing.
    expect(isOpen.value, isFalse);
    expect(find.byKey(chartKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(isOpen.value, isTrue);
    await tester.pump();
    expect(find.byKey(chartKey), findsOneWidget);
    // Covered until it has had time to redraw at the landscape size.
    expect(coverOpacity(), 1);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(coverOpacity(), 0);
    // Laid out landscape inside a portrait screen.
    final pageContext = tester.element(find.byType(LandscapeChartPage));
    expect(MediaQuery.sizeOf(pageContext), const Size(740, 360));
    expect(tester.takeException(), isNull);

    // +/− still change the lot without a keyboard.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(lotController.text, '0.02');

    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pump();
    // The cover comes back first, while the chart is still in the page.
    expect(coverOpacity(), 1);
    expect(isOpen.value, isTrue);

    await tester.pump(const Duration(milliseconds: 260));
    // Handed back before the page starts swinging out.
    expect(isOpen.value, isFalse);
    expect(find.byType(LandscapeChartPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(LandscapeChartPage), findsNothing);
    expect(
      orientationCalls.where((args) => '$args'.contains('landscape')),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
