import 'dart:convert';

CurrencyListModel currencyListModelFromJson(String str) =>
    CurrencyListModel.fromJson(json.decode(str));

String currencyListModelToJson(CurrencyListModel data) =>
    json.encode(data.toJson());

class CurrencyListModel {
  bool? status;
  String? message;
  CurrencyData? data;

  CurrencyListModel({this.status, this.message, this.data});

  factory CurrencyListModel.fromJson(Map<String, dynamic> json) {
    return CurrencyListModel(
      status: json["status"],
      message: json["message"],
      data: json["data"] == null ? null : CurrencyData.fromJson(json["data"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

class CurrencyData {
  List<String>? currencies;

  CurrencyData({this.currencies});

  factory CurrencyData.fromJson(Map<String, dynamic> json) {
    return CurrencyData(
      currencies:
          json["currencies"] == null
              ? null
              : List<String>.from(json["currencies"].map((x) => x)),
    );
  }

  Map<String, dynamic> toJson() => {
    "currencies":
        currencies == null
            ? null
            : List<dynamic>.from(currencies!.map((x) => x)),
  };
}
