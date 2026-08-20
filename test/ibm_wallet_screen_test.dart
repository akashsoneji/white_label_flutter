import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_wallet_screen.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/services/language_service.dart';

void main() {
  testWidgets('IbmWalletScreen renders without exception', (WidgetTester tester) async {
    Get.put(IbmController());
    Get.put(LanguageService());

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => GetMaterialApp(
          home: const Scaffold(body: IbmWalletScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(IbmWalletScreen), findsOneWidget);
  });
}
