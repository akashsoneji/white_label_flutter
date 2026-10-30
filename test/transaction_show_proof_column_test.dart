import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction.fromJson show_proof_column', () {
    test('true when the admin toggle is ON', () {
      final parsed = Transaction.fromJson({
        'status': true,
        'data': <dynamic>[],
        'show_proof_column': true,
      });
      expect(parsed.showProofColumn, isTrue);
    });

    test('false when OFF', () {
      final parsed = Transaction.fromJson({
        'status': true,
        'data': <dynamic>[],
        'show_proof_column': false,
      });
      expect(parsed.showProofColumn, isFalse);
    });

    test('defaults to false when the key is missing', () {
      final parsed = Transaction.fromJson({'status': true, 'data': <dynamic>[]});
      expect(parsed.showProofColumn, isFalse);
    });
  });
}
