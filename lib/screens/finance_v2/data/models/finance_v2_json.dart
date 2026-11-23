import 'dart:convert';

/// Null-safe readers shared by the finance_v2 models. The server sends money
/// as decimal strings and flags as bool, 0/1 or "0"/"1", so nothing here
/// assumes a Dart type.
String jsonString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String? jsonStringOrNull(dynamic value) {
  final text = jsonString(value);
  return text.isEmpty ? null : text;
}

bool jsonBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = jsonString(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

int jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(jsonString(value)) ?? 0;
}

/// A map from an object or from a JSON-encoded string (some gateway values
/// arrive double-encoded); anything else gives an empty map.
Map<String, dynamic> jsonMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is String && value.trim().startsWith('{')) {
    try {
      return jsonMap(jsonDecode(value));
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> jsonMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map(jsonMap).toList(growable: false);
}

List<String> jsonStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map(jsonString)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? jsonDateTime(dynamic value) {
  final text = jsonString(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
