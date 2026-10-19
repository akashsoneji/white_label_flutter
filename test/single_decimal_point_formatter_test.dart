import 'package:crm_app/utils/single_decimal_point_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _apply(String oldText, String newText) =>
    const SingleDecimalPointFormatter().formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(text: newText),
    );

void main() {
  group('SingleDecimalPointFormatter', () {
    test('allows the first decimal point', () {
      expect(_apply('4160', '4160.').text, '4160.');
    });

    test('rejects a second decimal point anywhere', () {
      expect(_apply('4160.55', '4160..55').text, '4160.55');
      expect(_apply('4160.55', '4160.55.').text, '4160.55');
      expect(_apply('4160.55', '.4160.55').text, '4160.55');
    });

    test('rejects a pasted value with several decimal points', () {
      expect(_apply('', '4160..55.806').text, '');
    });

    test('lets text that already has several dots be cleaned up', () {
      expect(_apply('4160..55.806', '4160.55.806').text, '4160.55.806');
      expect(_apply('4160..55.806', '4160..55.80').text, '4160..55.80');
    });

    test('still blocks adding a dot to text that already has several', () {
      expect(_apply('4160..55', '4160..55.').text, '4160..55');
    });
  });
}
