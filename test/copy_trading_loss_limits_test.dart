import 'package:crm_app/controllers/copy_trading/copy_trading_subscribe_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _settingsJson = {
  'loss_limits_allowed': true,
  'defaults': {'max_drawdown_pct': 20, 'daily_loss_pct': 5, 'equity_floor_pct': 0},
  'caps': {'max_drawdown_pct_max': 50, 'daily_loss_pct_max': 10, 'equity_floor_pct_min': 20},
  'terms_required': true,
  'kyc_required': false,
};

CopyTradingSubscribeController _controller(CopierSafetySettings settings) {
  // Not Get.put: onInit (network) does not run.
  final c = CopyTradingSubscribeController(masterCode: 'MST-0007', planId: 12);
  c.safety.value = settings;
  return c;
}

void main() {
  group('CopierSafetySettings.fromJson (TSK-0216)', () {
    test('parses defaults, caps and flags', () {
      final s = CopierSafetySettings.fromJson(_settingsJson);

      expect(s.lossLimitsAllowed, isTrue);
      expect(s.defaultMaxDrawdownPct, 20);
      expect(s.defaultDailyLossPct, 5);
      expect(s.maxDrawdownPctMax, 50);
      expect(s.dailyLossPctMax, 10);
      expect(s.equityFloorPctMin, 20);
      expect(s.termsRequired, isTrue);
      expect(s.kycRequired, isFalse);
    });

    test('accepts numbers sent as strings and missing blocks', () {
      final s = CopierSafetySettings.fromJson({
        'loss_limits_allowed': false,
        'caps': {'max_drawdown_pct_max': '50.5'},
      });

      expect(s.lossLimitsAllowed, isFalse);
      expect(s.maxDrawdownPctMax, 50.5);
      expect(s.defaultMaxDrawdownPct, 0);
      expect(s.termsRequired, isFalse);
    });

    test('equity floor min and default are a % of the investment', () {
      final s = CopierSafetySettings.fromJson({
        'defaults': {'equity_floor_pct': 10},
        'caps': {'equity_floor_pct_min': 20},
      });

      expect(s.equityFloorMinUsd(1000), 200);
      expect(s.equityFloorDefaultUsd(1000), 100);
      expect(s.equityFloorMinUsd(0), 0);
    });
  });

  group('CopierSafetySettings.validate', () {
    final s = CopierSafetySettings.fromJson(_settingsJson);

    test('empty fields (broker default) are valid', () {
      expect(s.validate(investment: 1000), isNull);
    });

    test('max drawdown over the cap is refused', () {
      final issue = s.validate(maxDrawdownPct: 60, investment: 1000)!;

      expect(issue.field, LossLimitField.maxDrawdown);
      expect(issue.problem, LossLimitProblem.aboveMax);
      expect(issue.limit, 50);
    });

    test('daily loss over the cap is refused', () {
      final issue = s.validate(dailyLossPct: 11)!;

      expect(issue.field, LossLimitField.dailyLoss);
      expect(issue.problem, LossLimitProblem.aboveMax);
      expect(issue.limit, 10);
    });

    test('0% and more than 100% are out of range', () {
      expect(s.validate(maxDrawdownPct: 0)!.problem, LossLimitProblem.outOfRange);
      final noCap = CopierSafetySettings.fromJson({'loss_limits_allowed': true});
      expect(noCap.validate(dailyLossPct: 101)!.problem, LossLimitProblem.outOfRange);
      expect(noCap.validate(dailyLossPct: 100), isNull);
    });

    test('equity floor below 20% of the investment is refused with the minimum', () {
      final issue = s.validate(equityFloor: 199.99, investment: 1000)!;

      expect(issue.field, LossLimitField.equityFloor);
      expect(issue.problem, LossLimitProblem.belowMin);
      expect(issue.limit, 200);
      expect(s.validate(equityFloor: 200, investment: 1000), isNull);
    });

    test('edit (no investment) skips the equity floor minimum', () {
      expect(s.validate(equityFloor: 10), isNull);
    });

    test('limits inside the caps pass', () {
      expect(
        s.validate(maxDrawdownPct: 30, dailyLossPct: 5, equityFloor: 300, investment: 1000),
        isNull,
      );
    });
  });

  group('subscribe payload fields', () {
    test('sends only the typed limits as numbers, plus terms_accepted', () {
      final c = _controller(CopierSafetySettings.fromJson(_settingsJson));
      c.maxDrawdownPct.value = 30;
      c.equityFloor.value = 300;
      c.termsAccepted.value = true;

      final fields = c.lossLimitSubscribeFields();

      expect(fields, {'max_drawdown_pct': 30.0, 'equity_floor': 300.0, 'terms_accepted': true});
      expect(fields.containsKey('daily_loss_pct'), isFalse);
    });

    test('limits off: no limit keys even when values are set', () {
      final c = _controller(const CopierSafetySettings(termsRequired: false));
      c.maxDrawdownPct.value = 30;

      expect(c.lossLimitSubscribeFields(), isEmpty);
    });
  });

  group('update payload fields', () {
    test('always sends all 3 keys, null for an empty field', () {
      final c = _controller(CopierSafetySettings.fromJson(_settingsJson));
      c.maxDrawdownPct.value = 25;

      final payload = c.buildUpdateSettingsPayload();

      expect(payload['max_drawdown_pct'], 25.0);
      expect(payload.containsKey('daily_loss_pct'), isTrue);
      expect(payload['daily_loss_pct'], isNull);
      expect(payload.containsKey('equity_floor'), isTrue);
      expect(payload['equity_floor'], isNull);
      expect(payload.containsKey('terms_accepted'), isFalse);
    });

    test('limits off: the update does not send limit keys', () {
      final c = _controller(CopierSafetySettings.none);

      expect(c.buildUpdateSettingsPayload().containsKey('max_drawdown_pct'), isFalse);
    });
  });

  test('subscription detail fills the inputs from safety.own', () {
    final c = _controller(CopierSafetySettings.fromJson(_settingsJson));
    c.applySubscriptionDetail({
      'sizing_method': 'fixed',
      'safety': {
        'own': {'max_drawdown_pct': 25, 'daily_loss_pct': null, 'equity_floor': '300'},
        'effective': {'max_drawdown_pct': 25, 'daily_loss_pct': 5, 'equity_floor': 300},
      },
    });

    expect(c.maxDrawdownPct.value, 25);
    expect(c.dailyLossPct.value, isNull);
    expect(c.equityFloor.value, 300);
    expect(c.effectiveLimits?['daily_loss_pct'], 5);
  });
}
