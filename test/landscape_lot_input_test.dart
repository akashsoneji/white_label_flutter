import 'package:crm_app/utils/precision_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrecisionHelper.parseLotInput', () {
    test('keeps a valid lot inside the range', () {
      expect(PrecisionHelper.parseLotInput('0.5', 0.01, 2), 0.5);
      expect(PrecisionHelper.parseLotInput(' 1.25 ', 0.01, 2), 1.25);
    });

    test('falls back to the minimum lot for empty or invalid input', () {
      expect(PrecisionHelper.parseLotInput('', 0.01, 2), 0.01);
      expect(PrecisionHelper.parseLotInput('abc', 0.01, 2), 0.01);
      expect(PrecisionHelper.parseLotInput('.', 0.01, 2), 0.01);
      expect(PrecisionHelper.parseLotInput('0', 0.01, 2), 0.01);
      expect(PrecisionHelper.parseLotInput('-1', 0.01, 2), 0.01);
    });

    test('clamps to the account lot range', () {
      expect(PrecisionHelper.parseLotInput('0.001', 0.01, 2), 0.01);
      expect(PrecisionHelper.parseLotInput('50', 0.01, 2), 2);
    });

    test('rounds away floating point noise', () {
      expect(PrecisionHelper.parseLotInput('0.019999999999999997', 0.01, 2), 0.02);
    });
  });

  group('PrecisionHelper.clamp lot stepping', () {
    test('stepping past the limits stays inside the range', () {
      expect(PrecisionHelper.clamp(0.01 - 0.01, 0.01, 2), 0.01);
      expect(PrecisionHelper.clamp(2 + 0.01, 0.01, 2), 2);
    });

    test('repeated 0.01 steps do not drift', () {
      var lot = 0.01;
      for (var i = 0; i < 10; i++) {
        lot = PrecisionHelper.clamp(lot + 0.01, 0.01, 2);
      }
      expect(lot, 0.11);
    });
  });
}
