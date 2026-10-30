import 'package:crm_app/screens/kyc/data/models/kyc_document_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _kyc({
  Object? documentOptions,
  List<String> requiredBackSides = const [],
  List<Map<String, dynamic>> documents = const [],
  String kycMode = 'manual',
  bool documentsSubmitted = false,
  bool hasRejected = false,
}) {
  return {
    'status': true,
    'data': {
      'user_details': {
        'documents_submitted': documentsSubmitted,
        'has_rejected_documents': hasRejected,
        'rejection_comments': <dynamic>[],
      },
      'documents': documents,
      'required_back_sides': requiredBackSides,
      'document_options':
          documentOptions ?? {'id_proof': <dynamic>[], 'address_proof': <dynamic>[]},
      'kyc_mode': kycMode,
    },
  };
}

const _options = {
  'id_proof': [
    {'id': 'opt_passport', 'name': 'Passport', 'front_required': true, 'back_required': false},
    {'id': 'opt_dl', 'name': 'Driving Licence', 'front_required': true, 'back_required': true},
  ],
  'address_proof': [
    {'id': 'opt_utility', 'name': 'Utility Bill', 'front_required': true, 'back_required': false},
  ],
};

void main() {
  group('default flow (toggles OFF)', () {
    test('front required, back optional but visible', () {
      final config = KycDocumentConfig.fromKycResponse(_kyc());
      expect(config.isSideRequired(kycIdProof, kycSideFront, null), isTrue);
      expect(config.isSideRequired(kycIdProof, kycSideBack, null), isFalse);
      expect(config.isSideVisible(kycIdProof, kycSideBack, null), isTrue);
    });

    test('back required only when listed in required_back_sides', () {
      final config = KycDocumentConfig.fromKycResponse(
        _kyc(requiredBackSides: ['address_proof_back']),
      );
      expect(config.isSideRequired(kycAddressProof, kycSideBack, null), isTrue);
      expect(config.isSideRequired(kycIdProof, kycSideBack, null), isFalse);
    });

    test('missing document_options keys fall back to default flow', () {
      final config = KycDocumentConfig.fromKycResponse({'data': <String, dynamic>{}});
      expect(config.idProofOptions, isEmpty);
      expect(config.kycMode, 'manual');
      expect(config.isProviderMode, isFalse);
    });
  });

  group('option list (toggles ON)', () {
    final config = KycDocumentConfig.fromKycResponse(
      _kyc(documentOptions: _options, requiredBackSides: ['id_proof_back']),
    );

    test('nothing is required or shown until an option is picked', () {
      expect(config.isSideVisible(kycIdProof, kycSideFront, null), isFalse);
      expect(config.isSideRequired(kycIdProof, kycSideFront, null), isFalse);
    });

    test('picked option decides the sides, not required_back_sides', () {
      final passport = config.idProofOptions.first;
      final licence = config.idProofOptions.last;
      expect(config.isSideRequired(kycIdProof, kycSideBack, passport), isFalse);
      expect(config.isSideVisible(kycIdProof, kycSideBack, passport), isFalse);
      expect(config.isSideRequired(kycIdProof, kycSideBack, licence), isTrue);
    });
  });

  group('submitted documents', () {
    final config = KycDocumentConfig.fromKycResponse(
      _kyc(
        documentOptions: _options,
        documentsSubmitted: true,
        hasRejected: true,
        documents: [
          {
            'subdocument_type': 'id_proof_back',
            'document_option': 'opt_dl',
            'document_option_name': 'Driving Licence',
            'status': 'rejected',
            'remark': 'Back side is blurry',
            'back_side_required': false,
          },
          {
            'subdocument_type': 'address_proof_front',
            'document_option': 'opt_removed',
            'status': 'approved',
          },
        ],
      ),
    );

    test('re-upload mode and the rejected side with its remark', () {
      expect(config.isReupload, isTrue);
      final back = config.documentFor(kycIdProof, kycSideBack);
      expect(back?.isRejected, isTrue);
      expect(back?.remark, 'Back side is blurry');
    });

    test('earlier pick is restored only while the admin still offers it', () {
      expect(config.previouslyPickedOption(kycIdProof)?.id, 'opt_dl');
      expect(config.previouslyPickedOption(kycAddressProof), isNull);
    });
  });

  test('sumsub / shufti are provider mode', () {
    expect(KycDocumentConfig.fromKycResponse(_kyc(kycMode: 'sumsub')).isProviderMode, isTrue);
    expect(KycDocumentConfig.fromKycResponse(_kyc(kycMode: 'shufti')).isProviderMode, isTrue);
  });
}
