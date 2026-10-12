import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesStorageService {
  static const String _favoritesKey = 'favorite_instruments';
  static const String _favoritesNamesKey = 'favorite_instruments_names';
  static FavoritesStorageService? _instance;

  // Singleton pattern
  static FavoritesStorageService get instance {
    _instance ??= FavoritesStorageService._();
    return _instance!;
  }

  FavoritesStorageService._();

  // Get all favorite instruments
  Future<List<String>> getFavoriteInstruments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_favoritesKey);

      if (json == null || json.isEmpty) return <String>[];
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<String>();
    } catch (e) {
      print('Error getting favorites: $e');
      return <String>[];
    }
  }

  // Get favorite names map
  Future<Map<String, String>> getFavoriteNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_favoritesNamesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      print('Error getting favorite names: $e');
    }
    return {};
  }

  // Save favorite names map
  Future<void> saveFavoriteNames(Map<String, String> names) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoritesNamesKey, jsonEncode(names));
    } catch (e) {
      print('Error saving favorite names: $e');
    }
  }

  // Save favorites list
  Future<void> saveFavoriteInstruments(List<String> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(favorites);
      await prefs.setString(_favoritesKey, json);
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  // Add single instrument to favorites
  Future<bool> addToFavorites(String symbol, {String? name}) async {
    try {
      final favorites = await getFavoriteInstruments();
      if (!favorites.contains(symbol)) {
        favorites.add(symbol);
        await saveFavoriteInstruments(favorites);

        if (name != null) {
          final names = await getFavoriteNames();
          names[symbol] = name;
          await saveFavoriteNames(names);
        }
        return true;
      }
      return false; // Already exists
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  // Remove single instrument from favorites
  Future<bool> removeFromFavorites(String symbol) async {
    try {
      final favorites = await getFavoriteInstruments();
      if (favorites.remove(symbol)) {
        await saveFavoriteInstruments(favorites);

        final names = await getFavoriteNames();
        if (names.containsKey(symbol)) {
          names.remove(symbol);
          await saveFavoriteNames(names);
        }
        return true;
      }
      return false; // Not found
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  // Check if instrument is in favorites
  Future<bool> isFavorite(String symbol) async {
    try {
      final favorites = await getFavoriteInstruments();
      return favorites.contains(symbol);
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Toggle favorite status
  Future<bool> toggleFavorite(String symbol, {String? name}) async {
    try {
      final isFav = await isFavorite(symbol);
      if (isFav) {
        return await removeFromFavorites(symbol);
      } else {
        return await addToFavorites(symbol, name: name);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }

  // Clear all favorites
  Future<void> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
    } catch (e) {
      print('Error clearing favorites: $e');
    }
  }


  // Get favorites count
  Future<int> getFavoritesCount() async {
    try {
      final favorites = await getFavoriteInstruments();
      return favorites.length;
    } catch (e) {
      print('Error getting favorites count: $e');
      return 0;
    }
  }
}
