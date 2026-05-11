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

class Data {
  List<WithdrawalMethods>? withdrawalMethods;
  List<Currencies>? currencies;

  Data({this.withdrawalMethods, this.currencies});

  Data.fromJson(Map<String, dynamic> json) {
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
  String? proofImg;
  String? status;

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
    this.proofImg,
    this.status,
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
    proofImg = json['proof_img'];
    status = json['status'];
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
    data['proof_img'] = this.proofImg;
    data['status'] = this.status;
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
