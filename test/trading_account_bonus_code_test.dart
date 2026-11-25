import 'package:crm_app/screens/home/widgets/bonus_code_field.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Future<void> _pump(
  WidgetTester tester, {
  required TextEditingController controller,
  String? errorText,
}) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => GetMaterialApp(
        home: Scaffold(
          body: BonusCodeField(controller: controller, errorText: errorText),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => Get.put(LanguageService()));

  group('PlanModel accepts_promo_code (TSK-0180)', () {
    test('reads true, 1 and "1" as accepting a code', () {
      for (final value in [true, 1, '1']) {
        final plan = PlanModel.fromJson({'id': 2, 'accepts_promo_code': value});
        expect(plan.acceptsPromoCode, isTrue, reason: 'value $value');
      }
    });

    test('missing or false means no bonus code field', () {
      expect(PlanModel.fromJson({'id': 1}).acceptsPromoCode, isFalse);
      expect(
        PlanModel.fromJson({'id': 1, 'accepts_promo_code': false})
            .acceptsPromoCode,
        isFalse,
      );
    });
  });

  group('BonusCodeField', () {
    testWidgets('keeps at most 8 allowed characters', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      await tester.enterText(find.byType(TextField), 'WEL COME!12_-3');
      await tester.pump();

      expect(controller.text, 'WELCOME1');
    });

    testWidgets('shows the server error under the field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        controller: controller,
        errorText: 'This bonus code is not valid.',
      );

      expect(find.text('This bonus code is not valid.'), findsOneWidget);
    });

    testWidgets('turns off autocorrect and suggestions', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
    });
  });
}
