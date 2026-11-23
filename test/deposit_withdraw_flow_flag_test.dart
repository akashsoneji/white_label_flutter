import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

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
  group('useNewDepositWithdrawFlow brand flag', () {
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

    tearDown(FlavorConfig.reset);

    test('covers every flavor', () {
      expect(brands.keys.toSet(), Flavor.values.map((f) => f.name).toSet());
    });

    test('is off by default for every brand', () {
      final enabled = brands.entries
          .where((entry) => entry.value.useNewDepositWithdrawFlow)
          .map((entry) => entry.key)
          .toSet();
      expect(enabled, isEmpty);
    });

    test('every activated flavor exposes the flag as false', () {
      for (final flavor in Flavor.values) {
        FlavorConfig.reset();
        final config = FlavorConfig.activate(flavor);
        expect(config.useNewDepositWithdrawFlow, isFalse,
            reason: '${flavor.name} must keep the old deposit/withdraw flow');
        expect(FlavorConfig.instance.useNewDepositWithdrawFlow, isFalse);
      }
    });

    test('FlavorConfig carries the flag through the factory and copyWith', () {
      FlavorConfig.reset();
      final config = FlavorConfig(
        flavor: Flavor.vantage,
        appName: 'vantage',
        appTitle: 'vantage',
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
        useNewDepositWithdrawFlow: true,
      );
      expect(config.useNewDepositWithdrawFlow, isTrue);
      expect(FlavorConfig.instance.useNewDepositWithdrawFlow, isTrue);
      expect(
        config.copyWith(useNewDepositWithdrawFlow: false)
            .useNewDepositWithdrawFlow,
        isFalse,
      );
      expect(config.copyWith().useNewDepositWithdrawFlow, isTrue);
    });
  });
}
