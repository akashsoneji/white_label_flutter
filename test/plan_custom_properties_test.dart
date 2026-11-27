import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanModel custom_properties', () {
    test('reads label/value rows in order', () {
      final plan = PlanModel.fromJson({
        'id': 30,
        'plan_title': 'Cent',
        'custom_properties': [
          {'label': 'comission', 'value': '15'},
          {'label': 'Ib commision', 'value': 2},
        ],
      });

      expect(plan.customProperties.length, 2);
      expect(plan.customProperties[0].label, 'comission');
      expect(plan.customProperties[0].value, '15');
      expect(plan.customProperties[1].label, 'Ib commision');
      expect(plan.customProperties[1].value, '2');
    });

    test('is empty when missing, empty or not a list', () {
      expect(PlanModel.fromJson({'id': 1}).customProperties, isEmpty);
      expect(
        PlanModel.fromJson({'id': 1, 'custom_properties': []}).customProperties,
        isEmpty,
      );
      expect(
        PlanModel.fromJson({'id': 1, 'custom_properties': {}}).customProperties,
        isEmpty,
      );
    });

    test('skips rows without a label and non-map entries', () {
      final plan = PlanModel.fromJson({
        'id': 1,
        'custom_properties': [
          {'label': '  ', 'value': '5'},
          'junk',
          {'label': 'Swap', 'value': null},
        ],
      });

      expect(plan.customProperties.length, 1);
      expect(plan.customProperties.single.label, 'Swap');
      expect(plan.customProperties.single.value, '');
    });
  });
}
