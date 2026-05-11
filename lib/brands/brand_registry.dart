import 'dart:convert';

import 'package:flutter/services.dart';

import 'brand_id.dart';

/// Registry of brands available in the build (from an asset JSON).
class BrandRegistry {
  final BrandId defaultBrand;
  final List<BrandId> brands;

  const BrandRegistry({required this.defaultBrand, required this.brands});

  static const String assetPath = 'assets/config/brands/brands.json';

  static Future<BrandRegistry> loadFromAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('Invalid brands.json: expected JSON object');
    }
    final map = decoded.cast<String, dynamic>();

    final defaultId = BrandId.fromString((map['default'] ?? '').toString());
    final list = map['brands'];
    final brands =
        (list is List)
            ? list.map((e) => BrandId.fromString(e.toString())).toList()
            : <BrandId>[];

    final effectiveBrands = <BrandId>{
      BrandId.tenax,
      ...brands,
      defaultId,
    }.toList();

    return BrandRegistry(defaultBrand: defaultId, brands: effectiveBrands);
  }
}

