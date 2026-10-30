/// Parsed `GET user/kyc` document settings: admin-defined document options per
/// category, the default-flow back-side rule and the already submitted sides.
library;

const String kycIdProof = 'id_proof';
const String kycAddressProof = 'address_proof';
const String kycSideFront = 'front';
const String kycSideBack = 'back';

class KycDocumentOption {
  const KycDocumentOption({
    required this.id,
    required this.name,
    required this.frontRequired,
    required this.backRequired,
  });

  /// Opaque id; sent back to the server exactly as received.
  final String id;
  final String name;
  final bool frontRequired;
  final bool backRequired;

  factory KycDocumentOption.fromJson(Map<String, dynamic> json) {
    return KycDocumentOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      frontRequired: json['front_required'] == true,
      backRequired: json['back_required'] == true,
    );
  }
}

class KycSubmittedDocument {
  const KycSubmittedDocument({
    required this.subdocumentType,
    required this.documentOption,
    required this.documentOptionName,
    required this.status,
    required this.remark,
  });

  /// `id_proof_front`, `id_proof_back`, `address_proof_front`, `address_proof_back`.
  final String subdocumentType;
  final String documentOption;
  final String documentOptionName;

  /// `pending`, `approved` or `rejected`.
  final String status;
  final String remark;

  bool get isRejected => status == 'rejected';

  // `back_side_required` on these rows is a legacy field that does not follow
  // the picked option, so it is deliberately not parsed.
  factory KycSubmittedDocument.fromJson(Map<String, dynamic> json) {
    return KycSubmittedDocument(
      subdocumentType: json['subdocument_type']?.toString() ?? '',
      documentOption: json['document_option']?.toString() ?? '',
      documentOptionName: json['document_option_name']?.toString() ?? '',
      status: (json['status']?.toString() ?? '').toLowerCase(),
      remark: json['remark']?.toString() ?? '',
    );
  }
}

class KycDocumentConfig {
  const KycDocumentConfig({
    required this.kycMode,
    required this.idProofOptions,
    required this.addressProofOptions,
    required this.requiredBackSides,
    required this.documents,
    required this.documentsSubmitted,
    required this.hasRejectedDocuments,
  });

  final String kycMode;
  final List<KycDocumentOption> idProofOptions;
  final List<KycDocumentOption> addressProofOptions;
  final List<String> requiredBackSides;
  final List<KycSubmittedDocument> documents;
  final bool documentsSubmitted;
  final bool hasRejectedDocuments;

  /// Sumsub / Shufti clients verify through the provider SDK; the upload APIs
  /// refuse them, so the manual form must not be shown.
  bool get isProviderMode => kycMode == 'sumsub' || kycMode == 'shufti';

  /// After a rejection only the rejected sides are re-uploaded.
  bool get isReupload => documentsSubmitted && hasRejectedDocuments;

  /// [body] is the whole `GET user/kyc` envelope.
  factory KycDocumentConfig.fromKycResponse(Map<String, dynamic> body) {
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final details = data['user_details'] is Map<String, dynamic>
        ? data['user_details'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final options = data['document_options'] is Map<String, dynamic>
        ? data['document_options'] as Map<String, dynamic>
        : const <String, dynamic>{};

    List<KycDocumentOption> parseOptions(dynamic raw) => raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(KycDocumentOption.fromJson)
            .where((o) => o.id.isNotEmpty)
            .toList()
        : const [];

    final rawDocuments = data['documents'];
    final rawBackSides = data['required_back_sides'];

    return KycDocumentConfig(
      kycMode: (data['kyc_mode']?.toString() ?? 'manual').toLowerCase(),
      idProofOptions: parseOptions(options[kycIdProof]),
      addressProofOptions: parseOptions(options[kycAddressProof]),
      requiredBackSides: rawBackSides is List
          ? rawBackSides.map((e) => e.toString()).toList()
          : const [],
      documents: rawDocuments is List
          ? rawDocuments
              .whereType<Map<String, dynamic>>()
              .map(KycSubmittedDocument.fromJson)
              .toList()
          : const [],
      documentsSubmitted: details['documents_submitted'] == true,
      hasRejectedDocuments: details['has_rejected_documents'] == true,
    );
  }

  List<KycDocumentOption> optionsFor(String category) =>
      category == kycIdProof ? idProofOptions : addressProofOptions;

  KycSubmittedDocument? documentFor(String category, String side) =>
      documents.firstWhereOrNullBy('${category}_$side');

  /// The option picked on an earlier submit, if the admin still offers it.
  KycDocumentOption? previouslyPickedOption(String category) {
    final options = optionsFor(category);
    for (final doc in documents) {
      if (!doc.subdocumentType.startsWith('${category}_')) continue;
      for (final option in options) {
        if (option.id == doc.documentOption) return option;
      }
    }
    return null;
  }

  /// Keeps [current] if the admin still offers it, otherwise falls back to the
  /// option remembered on the submitted documents (or none).
  KycDocumentOption? resolvePick(String category, KycDocumentOption? current) {
    if (current != null) {
      for (final option in optionsFor(category)) {
        if (option.id == current.id) return option;
      }
    }
    return previouslyPickedOption(category);
  }

  bool hasSubmittedDocuments(String category) =>
      documents.any((doc) => doc.subdocumentType.startsWith('${category}_'));

  /// Whether [side] of [category] needs a file on a first submission.
  /// With an option list the picked option decides; without one the front is
  /// always required and the back only when listed in `required_back_sides`.
  bool isSideRequired(String category, String side, KycDocumentOption? picked) {
    if (optionsFor(category).isEmpty) {
      return side == kycSideFront ||
          requiredBackSides.contains('${category}_$kycSideBack');
    }
    if (picked == null) return false;
    return side == kycSideFront ? picked.frontRequired : picked.backRequired;
  }

  /// Default flow shows both sides (back may be optional); an option list
  /// shows only the sides the picked option requires.
  bool isSideVisible(String category, String side, KycDocumentOption? picked) {
    if (optionsFor(category).isEmpty) return true;
    return isSideRequired(category, side, picked);
  }
}

extension on List<KycSubmittedDocument> {
  KycSubmittedDocument? firstWhereOrNullBy(String subdocumentType) {
    for (final doc in this) {
      if (doc.subdocumentType == subdocumentType) return doc;
    }
    return null;
  }
}
