import 'package:crm_app/screens/home/widgets/group_terms_acceptance.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Taps the "Terms and Conditions" span (it has its own recognizer inside the
/// rich text, so a plain tester.tap would hit the surrounding row).
void _tapTermsLink(WidgetTester tester) {
  final rich = tester.widget<Text>(find.byKey(const Key('group_terms_link')));
  var tapped = false;
  rich.textSpan!.visitChildren((span) {
    final recognizer = span is TextSpan ? span.recognizer : null;
    if (recognizer is TapGestureRecognizer) {
      recognizer.onTap!();
      tapped = true;
      return false;
    }
    return true;
  });
  expect(tapped, isTrue, reason: 'terms link span has no tap recognizer');
}

Future<void> _pump(
  WidgetTester tester, {
  required String? terms,
  bool accepted = false,
  ValueChanged<bool>? onChanged,
}) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupTermsAcceptance(
              termsText: terms,
              accepted: accepted,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => Get.put(LanguageService()));

  group('PlanModel terms fields (TSK-0179)', () {
    test('reads terms_enabled and terms_text', () {
      final plan = PlanModel.fromJson({
        'id': 12,
        'plan_title': 'Standard',
        'terms_enabled': true,
        'terms_text': '1. Trading carries risk.\n2. Bonus terms apply.',
      });

      expect(plan.termsEnabled, isTrue);
      expect(plan.termsText, '1. Trading carries risk.\n2. Bonus terms apply.');
    });

    test('accepts 1 / "1" as enabled', () {
      expect(PlanModel.fromJson({'terms_enabled': 1}).termsEnabled, isTrue);
      expect(PlanModel.fromJson({'terms_enabled': '1'}).termsEnabled, isTrue);
    });

    test('groups without the fields stay as before', () {
      final plan = PlanModel.fromJson({'id': 3});
      expect(plan.termsEnabled, isFalse);
      expect(plan.termsText, isNull);
      expect(
        PlanModel.fromJson({'terms_enabled': false, 'terms_text': null})
            .termsEnabled,
        isFalse,
      );
    });
  });

  group('GroupTermsAcceptance', () {
    testWidgets('checkbox reports the new value', (tester) async {
      bool? last;
      await _pump(tester, terms: 'Short terms', onChanged: (v) => last = v);

      await tester.tap(find.byKey(const Key('group_terms_checkbox')));
      expect(last, isTrue);
    });

    testWidgets('terms text is hidden until the link is tapped', (tester) async {
      await _pump(tester, terms: 'Line one\nLine two');
      expect(find.byKey(const Key('group_terms_text')), findsNothing);

      _tapTermsLink(tester);
      await tester.pump();

      // Plain text, line breaks kept.
      expect(find.text('Line one\nLine two'), findsOneWidget);
      expect(find.byKey(const Key('group_terms_toggle')), findsNothing);
    });

    testWidgets('long terms are cut at 280 characters with Show more / less',
        (tester) async {
      final longTerms = List.filled(400, 'a').join();
      await _pump(tester, terms: longTerms);

      _tapTermsLink(tester);
      await tester.pump();

      final cut = '${'a' * GroupTermsAcceptance.previewLength}…';
      expect(find.text(cut), findsOneWidget);

      await tester.tap(find.byKey(const Key('group_terms_toggle')));
      await tester.pump();
      expect(find.text(longTerms), findsOneWidget);

      // The full text pushes the toggle below the 800x600 test viewport.
      await tester.ensureVisible(find.byKey(const Key('group_terms_toggle')));
      await tester.tap(find.byKey(const Key('group_terms_toggle')));
      await tester.pump();
      expect(find.text(cut), findsOneWidget);
    });
  });
}
