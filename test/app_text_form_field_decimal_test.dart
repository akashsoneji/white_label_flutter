import 'package:crm_app/widgets/AppTextField.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TextEditingController> _pumpField(
  WidgetTester tester, {
  TextInputType? keyboardType,
}) async {
  final controller = TextEditingController();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: AppTextFormField(
            controller: controller,
            keyboardType: keyboardType,
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  const decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

  testWidgets('decimal AppTextFormField keeps only one decimal point',
      (tester) async {
    final controller = await _pumpField(tester, keyboardType: decimalKeyboard);

    await tester.enterText(find.byType(TextFormField), '4163.');
    expect(controller.text, '4163.');

    await tester.enterText(find.byType(TextFormField), '4163..');
    expect(controller.text, '4163.');

    await tester.enterText(find.byType(TextFormField), '4163.66');
    await tester.enterText(find.byType(TextFormField), '4163.66.61');
    expect(controller.text, '4163.66');
  });

  testWidgets('a pasted value with several decimal points is rejected',
      (tester) async {
    final controller = await _pumpField(tester, keyboardType: decimalKeyboard);

    await tester.enterText(find.byType(TextFormField), '4163....6661');
    expect(controller.text, '');
  });

  testWidgets('non-decimal fields are not restricted', (tester) async {
    final controller = await _pumpField(tester);

    await tester.enterText(find.byType(TextFormField), 'a.b.c');
    expect(controller.text, 'a.b.c');
  });
}
