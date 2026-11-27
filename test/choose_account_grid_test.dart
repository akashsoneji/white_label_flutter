import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/screens/home/choose_account_screen.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _UnusedFinanceRepository implements FinanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves fixed plans instead of calling the API.
class _FixedPlanController extends PlanController {
  @override
  Future<void> fetchPlan({int? groupId, bool? isDemo}) async {}
}

const _instruments = '+300 Instruments. Forex, Metals, Indices, Energy';

PlanModel _plan(String title, {List<Map<String, dynamic>> custom = const []}) {
  return PlanModel.fromJson({
    'id': title.hashCode,
    'plan_title': title,
    'spread': 1.4,
    'leverage': '1:500',
    'minimum_deposit': '100.00',
    'stop_out_level': '30',
    'trading_instruments': _instruments,
    'custom_properties': custom,
  });
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => const GetMaterialApp(home: ChooseAccountScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    Get.put(LanguageService());
    Get.put<FinanceRepository>(_UnusedFinanceRepository());
    final controller = Get.put<PlanController>(_FixedPlanController());
    controller.plans.assignAll([
      _plan(
        'Cent',
        custom: [
          {'label': 'comission', 'value': '15'},
          {'label': 'Ib commision', 'value': '2'},
        ],
      ),
      _plan('Standard'),
    ]);
  });

  tearDown(Get.reset);

  testWidgets('phone: one column, full instruments, custom rows', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text(_instruments), findsNWidgets(2));
    expect(find.text('comission'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Ib commision'), findsOneWidget);

    final cent = tester.getTopLeft(find.text('Cent'));
    final standard = tester.getTopLeft(find.text('Standard'));
    expect(standard.dx, cent.dx);
    expect(standard.dy, greaterThan(cent.dy));
  });

  testWidgets('tablet: two cards side by side', (tester) async {
    await _pumpAt(tester, const Size(768, 1024));

    expect(tester.takeException(), isNull);
    final cent = tester.getTopLeft(find.text('Cent'));
    final standard = tester.getTopLeft(find.text('Standard'));
    expect(standard.dy, cent.dy);
    expect(standard.dx, greaterThan(cent.dx));
  });
}
