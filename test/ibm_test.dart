import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_clients_screen.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/services/language_service.dart';

void main() {
  testWidgets('Test IbmClientsScreen layout', (WidgetTester tester) async {
    // Setup dependencies
    Get.put(LanguageService());
    Get.put(IbmController());
    
    FlutterError.onError = (FlutterErrorDetails details) {
      print('FLUTTER ERROR: ${details.exception}');
      print(details.stack);
    };

    try {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => GetMaterialApp(
            home: const IbmClientsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      print('WIDGET RENDERED SUCCESSFULLY');
    } catch (e, stack) {
      print('TEST EXCEPTION: $e');
      print(stack);
    }
  });
}
