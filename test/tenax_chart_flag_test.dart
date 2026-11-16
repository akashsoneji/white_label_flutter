import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:tenax_chart/tenax_chart.dart';

import 'package:crm_app/clients/baazex/config.dart';
import 'package:crm_app/clients/base_config.dart';
import 'package:crm_app/clients/celestial/config.dart';
import 'package:crm_app/clients/gtxprime/config.dart';
import 'package:crm_app/clients/iquote/config.dart';
import 'package:crm_app/clients/kantara/config.dart';
import 'package:crm_app/clients/meta/config.dart';
import 'package:crm_app/clients/moneygenius/config.dart';
import 'package:crm_app/clients/pipze/config.dart';
import 'package:crm_app/clients/proactive/config.dart';
import 'package:crm_app/clients/riyadex/config.dart';
import 'package:crm_app/clients/skyriss/config.dart';
import 'package:crm_app/clients/starfx/config.dart';
import 'package:crm_app/clients/telifox/config.dart';
import 'package:crm_app/clients/tenax/config.dart';
import 'package:crm_app/clients/vantage/config.dart';
import 'package:crm_app/flavor_config.dart';

void main() {
  group('useNewChart brand flag', () {
    const brands = <String, BaseClientConfig>{
      'baazex': BaazexConfig(),
      'celestial': CelestialConfig(),
      'gtxprime': GtxprimeConfig(),
      'iquote': IquoteConfig(),
      'kantara': KantaraConfig(),
      'meta': MetaConfig(),
      'moneygenius': MoneygeniusConfig(),
      'pipze': PipzeConfig(),
      'proactive': ProactiveConfig(),
      'riyadex': RiyadexConfig(),
      'skyriss': SkyrissConfig(),
      'starfx': StarfxConfig(),
      'telifox': TelifoxConfig(),
      'tenax': TenaxConfig(),
      'vantage': VantageConfig(),
    };

    test('is on only for tenax and proactive', () {
      final enabled = brands.entries
          .where((entry) => entry.value.useNewChart)
          .map((entry) => entry.key)
          .toSet();
      expect(enabled, {'tenax', 'proactive'});
    });

    // The chart's live bars (`subscribe_bars` → `k` frames) only exist on the
    // /ws/stream socket. A useNewChart brand outside that set shows history
    // but its last candle never moves.
    test('every useNewChart brand runs on the single stream socket', () {
      for (final entry in brands.entries.where((e) => e.value.useNewChart)) {
        FlavorConfig.reset();
        FlavorConfig(
          flavor: Flavor.values.byName(entry.key),
          appName: entry.key,
          appTitle: entry.key,
          primaryColor: const Color(0xFF000000),
          darkPrimaryColor: const Color(0xFF000000),
          secondaryColor: const Color(0xFF000000),
          accentColor: const Color(0xFF000000),
          apiBaseUrl: '',
          websocketUrl: '',
          chartBaseUrl: '',
          appIconPath: '',
          svgLogoPath: '',
          splashLogoPath: '',
          useNewChart: true,
        );
        expect(FlavorConfig.usesSingleStreamSocket, isTrue,
            reason: '${entry.key} has useNewChart but no /ws/stream socket');
      }
      FlavorConfig.reset();
    });
  });

  group('engine bar parsing', () {
    test('k frame scales prices by its own digits and reads the closed flag',
        () {
      final bar = TenaxBar.fromEngineFrame(
        <dynamic>['XAUUSD', '15m', 1700000000, 265012, 265100, 264900, 265050, 12, 1, 2],
      );
      expect(bar.symbol, 'XAUUSD');
      expect(bar.interval, '15m');
      expect(bar.time, 1700000000);
      expect(bar.open, closeTo(2650.12, 1e-9));
      expect(bar.high, closeTo(2651.00, 1e-9));
      expect(bar.low, closeTo(2649.00, 1e-9));
      expect(bar.close, closeTo(2650.50, 1e-9));
      expect(bar.volume, 12);
      expect(bar.closed, isTrue);
    });

    test('k frame with closed=0 is the forming bar', () {
      final bar = TenaxBar.fromEngineFrame(
        <dynamic>['EURUSD', '1m', 1, 108000, 108010, 107990, 108005, 0, 0, 5],
      );
      expect(bar.closed, isFalse);
      expect(bar.close, closeTo(1.08005, 1e-12));
    });

    test('tagged keeps prices and swaps symbol/interval', () {
      final bar = TenaxBar.fromEngineFrame(
        <dynamic>['XAUUSD', '15m', 1, 1, 1, 1, 1, 0, 0, 0],
      ).tagged('XAUUSD.c', '15m');
      expect(bar.symbol, 'XAUUSD.c');
      expect(bar.close, 1);
    });

    test('/api/bars page: only the last row is the forming bar', () {
      final page = TenaxBarsPage.fromEngineJson(<String, dynamic>{
        'digits': 2,
        'server_offset_minutes': 120,
        'bars': <List<dynamic>>[
          <dynamic>[1, 100, 110, 90, 105, 3],
          <dynamic>[2, 105, 120, 100, 115, 4],
        ],
      });
      expect(page.serverOffsetMinutes, 120);
      expect(page.bars, hasLength(2));
      expect(page.bars.first.closed, isTrue);
      expect(page.bars.last.closed, isFalse);
      expect(page.bars.last.close, closeTo(1.15, 1e-9));
    });

    test('/api/bars page without offset or bars is empty with offset 0', () {
      final page = TenaxBarsPage.fromEngineJson(<String, dynamic>{'digits': 5});
      expect(page.bars, isEmpty);
      expect(page.serverOffsetMinutes, 0);
    });
  });
}
