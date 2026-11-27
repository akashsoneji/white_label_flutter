class BankWithdrawleList {
  bool? status;
  String? message;
  Data? data;

  BankWithdrawleList({this.status, this.message, this.data});

  BankWithdrawleList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

/// How the proof upload behaves for one withdrawal method.
enum ProofUploadMode { hidden, optional, required }

/// Rules shared with the web portal (SettingsBankAccounts.vue):
/// - card never takes a document;
/// - [requireProofImageByMethod] decides whether the upload is shown; a method
///   missing from the map is hidden, while a server that sends no map at all
///   keeps the old "always shown" behaviour;
/// - when shown, [proofDocumentRequired] (Admin > Settings > Financial Rules)
///   makes it required (true) or optional (false).
ProofUploadMode resolveProofUploadMode({
  required String method,
  required Map<String, bool>? requireProofImageByMethod,
  required bool proofDocumentRequired,
}) {
  final key = method.toLowerCase();
  if (key.isEmpty || key == 'card') return ProofUploadMode.hidden;
  final isShown =
      requireProofImageByMethod == null || requireProofImageByMethod[key] == true;
  if (!isShown) return ProofUploadMode.hidden;
  return proofDocumentRequired
      ? ProofUploadMode.required
      : ProofUploadMode.optional;
}

/// Multipart field POST user/withdrawal expects the proof file in.
String? proofFieldNameFor(String method) {
  switch (method.toLowerCase()) {
    case 'bank':
      return 'bank_proof_img';
    case 'upi':
      return 'upi_proof_img';
    case 'crypto':
      return 'crypto_proof_img';
    case 'local':
      return 'local_proof_img';
    default:
      return null;
  }
}

class Data {
  List<WithdrawalMethods>? withdrawalMethods;
  List<Currencies>? currencies;
  List<AllowedCryptoNetwork>? allowedCryptoNetworks;
  Map<String, bool>? requireProofImageByMethod;

  /// Broker switch for a compulsory proof document. Servers without
  /// TSK-0049 don't send the key; treat that as ON to keep the old behaviour.
  bool proofDocumentRequired = true;

  Data({
    this.withdrawalMethods,
    this.currencies,
    this.allowedCryptoNetworks,
    this.requireProofImageByMethod,
    this.proofDocumentRequired = true,
  });

  Data.fromJson(Map<String, dynamic> json) {
    if (json['require_proof_image_by_method'] is Map) {
      requireProofImageByMethod = (json['require_proof_image_by_method'] as Map)
          .map((k, v) => MapEntry(k.toString().toLowerCase(), _isTrue(v)));
    }
    if (json.containsKey('proof_document_required') &&
        json['proof_document_required'] != null) {
      proofDocumentRequired = _isTrue(json['proof_document_required']);
    }
    if (json['withdrawalMethods'] != null) {
      withdrawalMethods = <WithdrawalMethods>[];
      json['withdrawalMethods'].forEach((v) {
        withdrawalMethods!.add(new WithdrawalMethods.fromJson(v));
      });
    }
    if (json['currencies'] != null) {
      currencies = <Currencies>[];
      json['currencies'].forEach((v) {
        currencies!.add(new Currencies.fromJson(v));
      });
    }
    if (json['allowed_crypto_networks'] != null) {
      allowedCryptoNetworks = <AllowedCryptoNetwork>[];
      json['allowed_crypto_networks'].forEach((v) {
        allowedCryptoNetworks!.add(AllowedCryptoNetwork.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.withdrawalMethods != null) {
      data['withdrawalMethods'] =
          this.withdrawalMethods!.map((v) => v.toJson()).toList();
    }
    if (this.currencies != null) {
      data['currencies'] = this.currencies!.map((v) => v.toJson()).toList();
    }
    if (this.allowedCryptoNetworks != null) {
      data['allowed_crypto_networks'] =
          this.allowedCryptoNetworks!.map((v) => v.toJson()).toList();
    }
    if (this.requireProofImageByMethod != null) {
      data['require_proof_image_by_method'] = this.requireProofImageByMethod;
    }
    data['proof_document_required'] = this.proofDocumentRequired;
    return data;
  }

  static bool _isTrue(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';
}

class AllowedCryptoNetwork {
  String? slug;
  String? label;

  AllowedCryptoNetwork({this.slug, this.label});

  AllowedCryptoNetwork.fromJson(Map<String, dynamic> json) {
    slug = json['slug']?.toString();
    label = json['label']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['slug'] = slug;
    data['label'] = label;
    return data;
  }
}

class WithdrawalMethods {
  int? id;
  String? withdrawalMethod;
  String? currency;
  String? relationship;
  String? holderName;
  String? bankName;
  String? bankAccountNo;
  String? ifscIban;
  String? upiAddress;
  String? cryptoAddress;
  String? cryptoNetwork;
  String? proofImg;
  String? status;
  String? approvalRejectionReason;

  WithdrawalMethods({
    this.id,
    this.withdrawalMethod,
    this.currency,
    this.relationship,
    this.holderName,
    this.bankName,
    this.bankAccountNo,
    this.ifscIban,
    this.upiAddress,
    this.cryptoAddress,
    this.cryptoNetwork,
    this.proofImg,
    this.status,
    this.approvalRejectionReason,
  });

  WithdrawalMethods.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    withdrawalMethod = json['withdrawal_method'];
    currency = json['currency'];
    relationship = json['relationship'];
    holderName = json['holder_name'];
    bankName = json['bank_name'];
    bankAccountNo = json['bank_account_no'];
    ifscIban = json['ifsc_iban'];
    upiAddress = json['upi_address'];
    cryptoAddress = json['crypto_address'];
    cryptoNetwork = json['crypto_network']?.toString();
    proofImg = json['proof_img'];
    status = json['status'];
    approvalRejectionReason = json['approval_rejection_reason']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['withdrawal_method'] = this.withdrawalMethod;
    data['currency'] = this.currency;
    data['relationship'] = this.relationship;
    data['holder_name'] = this.holderName;
    data['bank_name'] = this.bankName;
    data['bank_account_no'] = this.bankAccountNo;
    data['ifsc_iban'] = this.ifscIban;
    data['upi_address'] = this.upiAddress;
    data['crypto_address'] = this.cryptoAddress;
    data['crypto_network'] = this.cryptoNetwork;
    data['proof_img'] = this.proofImg;
    data['status'] = this.status;
    data['approval_rejection_reason'] = this.approvalRejectionReason;
    return data;
  }
}

class Currencies {
  String? currency;

  Currencies({this.currency});

  Currencies.fromJson(Map<String, dynamic> json) {
    currency = json['currency'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['currency'] = this.currency;
    return data;
  }
}
