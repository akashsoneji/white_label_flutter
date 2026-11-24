import 'package:crm_app/models/enabled_modules_model.dart';
import 'package:crm_app/screens/trading_central/trading_central_model.dart';
import 'package:crm_app/screens/trading_central/trading_central_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = <String, dynamic>{
    'status': true,
    'success': true,
    'data': {
      'enabled': true,
      'deposit_required': true,
      'has_first_deposit': true,
      'can_access': true,
      'menu_label': 'Trading Central',
      'deposit_total': 700,
      'pages': [
        {
          'key': 'economic_calendar',
          'label': 'Economic Calendar',
          'min_deposit': 0,
          'unlocked': true,
          'url': 'https://site.tradingcentral.com/f6aa0a/serve.shtml?tkn=abc',
        },
        {
          'key': 'marketbuzz_ranking',
          'label': 'Market Buzz',
          'min_deposit': 100000,
          'unlocked': false,
          'url': '',
        },
      ],
    },
  };

  test('payload is read from the full body or from the inner data', () {
    final fromBody = TradingCentralService.extractPayload(body);
    final fromInner = TradingCentralService.extractPayload(body['data']);
    expect(fromBody?['menu_label'], 'Trading Central');
    expect(fromInner?['menu_label'], 'Trading Central');
    expect(TradingCentralService.extractPayload(null), isNull);
  });

  test('unlocked page with url can open, locked page cannot', () {
    final settings = TradingCentralSettings.fromJson(
      TradingCentralService.extractPayload(body)!,
    );

    expect(settings.canAccess, isTrue);
    expect(settings.depositTotal, 700);
    expect(settings.pages, hasLength(2));
    expect(settings.pages.first.canOpen, isTrue);

    final locked = settings.pages.last;
    expect(locked.canOpen, isFalse);
    expect(locked.minDeposit, 100000);
  });

  test('unlocked page without a url cannot open', () {
    final page = TradingCentralPage.fromJson(const {
      'key': 'x',
      'label': 'X',
      'unlocked': true,
      'url': '',
    });
    expect(page.canOpen, isFalse);
  });

  test('trading_central module flag gates the menu entry', () {
    expect(
      EnabledModulesModel.fromJson(const {'trading_central': true})
          .tradingCentral,
      isTrue,
    );
    expect(EnabledModulesModel.fromJson(const {}).tradingCentral, isFalse);
  });
}
