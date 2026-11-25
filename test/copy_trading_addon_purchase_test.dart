import 'package:crm_app/controllers/copy_trading/copy_trading_copier_subscriptions_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CopierSubscriptionItem addon_purchase (TSK-0025)', () {
    test('parses a bought add-on', () {
      final item = CopierSubscriptionItem.fromJson({
        'id': 7,
        'status': 'active',
        'addon_purchase': {
          'id': 3,
          'option_name': 'VIP Signals',
          'fee': '10.00',
          'status': 'purchased',
          'purchased_at': '2026-11-24T10:00:00Z',
          'refunded_at': null,
        },
      });

      expect(item.hasAddon, isTrue);
      expect(item.addonName, 'VIP Signals');
      expect(item.addonFee, 10);
      expect(item.isAddonRefunded, isFalse);
    });

    test('marks the add-on refunded from refunded_at or status', () {
      final byDate = CopierSubscriptionItem.fromJson({
        'addon_purchase': {
          'option_name': 'VIP Signals',
          'fee': 10,
          'status': 'purchased',
          'refunded_at': '2026-11-24T11:00:00Z',
        },
      });
      final byStatus = CopierSubscriptionItem.fromJson({
        'addon_purchase': {'option_name': 'VIP Signals', 'fee': 10, 'status': 'refunded'},
      });

      expect(byDate.isAddonRefunded, isTrue);
      expect(byStatus.isAddonRefunded, isTrue);
    });

    test('no add-on when addon_purchase is null or ""', () {
      expect(CopierSubscriptionItem.fromJson({'addon_purchase': null}).hasAddon, isFalse);
      expect(CopierSubscriptionItem.fromJson({'addon_purchase': ''}).hasAddon, isFalse);
      expect(CopierSubscriptionItem.fromJson({}).hasAddon, isFalse);
    });
  });
}
