import 'package:crm_app/models/bank_withdralList_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Data.fromJson proof settings', () {
    test('reads proof_document_required false', () {
      final data = Data.fromJson({
        'require_proof_image_by_method': {'bank': true, 'upi': false},
        'proof_document_required': false,
      });
      expect(data.proofDocumentRequired, isFalse);
      expect(data.requireProofImageByMethod, {'bank': true, 'upi': false});
    });

    test('reads proof_document_required true', () {
      final data = Data.fromJson({'proof_document_required': true});
      expect(data.proofDocumentRequired, isTrue);
    });

    test('missing proof_document_required keeps the document compulsory', () {
      final data = Data.fromJson({
        'require_proof_image_by_method': {'bank': true},
      });
      expect(data.proofDocumentRequired, isTrue);
    });

    test('accepts 1/0 and lower-cases method keys', () {
      final data = Data.fromJson({
        'require_proof_image_by_method': {'Bank': 1, 'LOCAL': 0},
        'proof_document_required': 0,
      });
      expect(data.requireProofImageByMethod, {'bank': true, 'local': false});
      expect(data.proofDocumentRequired, isFalse);
    });

    test('no map in the response stays null', () {
      final data = Data.fromJson({});
      expect(data.requireProofImageByMethod, isNull);
    });
  });

  group('resolveProofUploadMode', () {
    const byMethod = {
      'bank': true,
      'upi': false,
      'crypto': true,
      'local': true,
    };

    test('shown + switch ON is required', () {
      expect(
        resolveProofUploadMode(
          method: 'Bank',
          requireProofImageByMethod: byMethod,
          proofDocumentRequired: true,
        ),
        ProofUploadMode.required,
      );
    });

    test('shown + switch OFF is optional', () {
      for (final method in ['bank', 'crypto', 'local']) {
        expect(
          resolveProofUploadMode(
            method: method,
            requireProofImageByMethod: byMethod,
            proofDocumentRequired: false,
          ),
          ProofUploadMode.optional,
          reason: method,
        );
      }
    });

    test('upload turned off for the method is hidden, switch ON or OFF', () {
      for (final switchOn in [true, false]) {
        expect(
          resolveProofUploadMode(
            method: 'UPI',
            requireProofImageByMethod: byMethod,
            proofDocumentRequired: switchOn,
          ),
          ProofUploadMode.hidden,
        );
      }
    });

    test('method missing from the map is hidden', () {
      expect(
        resolveProofUploadMode(
          method: 'wallet',
          requireProofImageByMethod: byMethod,
          proofDocumentRequired: true,
        ),
        ProofUploadMode.hidden,
      );
    });

    test('card is always hidden', () {
      expect(
        resolveProofUploadMode(
          method: 'Card',
          requireProofImageByMethod: const {'card': true},
          proofDocumentRequired: true,
        ),
        ProofUploadMode.hidden,
      );
      expect(
        resolveProofUploadMode(
          method: 'card',
          requireProofImageByMethod: null,
          proofDocumentRequired: true,
        ),
        ProofUploadMode.hidden,
      );
    });

    test('server without the map keeps the old required upload', () {
      expect(
        resolveProofUploadMode(
          method: 'bank',
          requireProofImageByMethod: null,
          proofDocumentRequired: true,
        ),
        ProofUploadMode.required,
      );
    });
  });

  group('proofFieldNameFor', () {
    test('returns the per-method field', () {
      expect(proofFieldNameFor('Bank'), 'bank_proof_img');
      expect(proofFieldNameFor('UPI'), 'upi_proof_img');
      expect(proofFieldNameFor('crypto'), 'crypto_proof_img');
      expect(proofFieldNameFor('Local'), 'local_proof_img');
    });

    test('card and unknown methods have no field and never deposit_proof', () {
      expect(proofFieldNameFor('card'), isNull);
      expect(proofFieldNameFor('wallet'), isNull);
    });
  });
}
