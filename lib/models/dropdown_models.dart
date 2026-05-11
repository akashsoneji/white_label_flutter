// To parse this JSON data, do
//
//     final countryModel = countryModelFromJson(jsonString);

import 'dart:convert';

CountryModel countryModelFromJson(String str) =>
    CountryModel.fromJson(json.decode(str));

String countryModelToJson(CountryModel data) => json.encode(data.toJson());

class CountryModel {
  final int? id;
  final String? name;
  final String? nationality;
  final String? phonecode;
  final String? iso2;
  final String? emoji;

  CountryModel({
    this.id,
    this.name,
    this.nationality,
    this.phonecode,
    this.iso2,
    this.emoji,
  });

  CountryModel copyWith({
    int? id,
    String? name,
    String? nationality,
    String? phonecode,
    String? iso2,
    String? emoji,
  }) => CountryModel(
    id: id ?? this.id,
    name: name ?? this.name,
    nationality: nationality ?? this.nationality,
    phonecode: phonecode ?? this.phonecode,
    iso2: iso2 ?? this.iso2,
    emoji: emoji ?? this.emoji,
  );

  factory CountryModel.fromJson(Map<String, dynamic> json) => CountryModel(
    id: json["id"],
    name: json["name"],
    nationality: json["nationality"],
    phonecode: json["phonecode"],
    iso2: json["iso2"],
    emoji: json["emoji"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "nationality": nationality,
    "phonecode": phonecode,
    "iso2": iso2,
    "emoji": emoji,
  };
}

class StateModel {
  final int id;
  final String name;
  final int countryId;

  StateModel({required this.id, required this.name, required this.countryId});

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] is String ? json['name'] : '',
      countryId:
          json['country_id'] is int
              ? json['country_id']
              : int.tryParse(json['country_id'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'country_id': countryId};
  }
}

class CityModel {
  final int id;
  final String name;
  final int stateId;

  CityModel({required this.id, required this.name, required this.stateId});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] is String ? json['name'] : '',
      stateId:
          json['state_id'] is int
              ? json['state_id']
              : int.tryParse(json['state_id'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'state_id': stateId};
  }
}

class DropdownResponse {
  final bool success;
  final String message;
  final List<dynamic> data;

  DropdownResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory DropdownResponse.fromJson(Map<String, dynamic> json) {
    return DropdownResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] is List ? json['data'] : [],
    );
  }
}
