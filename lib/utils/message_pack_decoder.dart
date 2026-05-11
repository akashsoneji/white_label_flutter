/**
 * MessagePack Binary Decoder Utility
 * 
 * Provides binary decoding for WebSocket messages to improve performance.
 * MessagePack is ~50-70% smaller than JSON and 5-10x faster to parse.
 */

import 'dart:typed_data';
import 'package:messagepack/messagepack.dart';

class MessagePackDecoder {
  /// Check if data is binary (MessagePack) format
  /// WebSocket messages can be either String (JSON) or Uint8List (binary)
  static bool isBinaryMessage(dynamic message) {
    return message is Uint8List || message is List<int>;
  }

  /// Decode MessagePack binary data to Dart object
  /// Handles the array-of-arrays structure from trade engine
  /// Returns null if decoding fails (fallback to JSON)
  static dynamic decodeBinary(Uint8List binaryData) {
    try {
      final unpacker = Unpacker(binaryData);
      return _unpackValue(unpacker);
    } catch (e) {
      print('⚠️ MessagePack: Decoding error: $e');
      return null;
    }
  }

  /// Recursively unpack a value (handles nested arrays and maps)
  /// Uses try-catch to determine type since unpackXXX methods throw on wrong type
  static dynamic _unpackValue(Unpacker unpacker) {
    // Try array first (most common in our data structure)
    try {
      final listLength = unpacker.unpackListLength();
      final List<dynamic> list = [];
      for (int i = 0; i < listLength; i++) {
        list.add(_unpackValue(unpacker));
      }
      return list;
    } catch (e) {
      // Not an array, continue
    }
    
    // Try map
    try {
      final mapLength = unpacker.unpackMapLength();
      final Map<String, dynamic> map = {};
      for (int i = 0; i < mapLength; i++) {
        final key = unpacker.unpackString();
        if (key == null) break;
        final value = _unpackValue(unpacker);
        map[key] = value;
      }
      return map;
    } catch (e) {
      // Not a map, continue
    }
    
    // Try primitive types
    // Try string first (most common in our data)
    try {
      final str = unpacker.unpackString();
      if (str != null) return str;
    } catch (e) {
      // Not a string, continue
    }
    
    // Try double (for prices)
    try {
      final dbl = unpacker.unpackDouble();
      if (dbl != null) return dbl;
    } catch (e) {
      // Not a double, continue
    }
    
    // Try int
    try {
      final intVal = unpacker.unpackInt();
      if (intVal != null) return intVal;
    } catch (e) {
      // Not an int, continue
    }
    
    // Try bool
    try {
      final boolVal = unpacker.unpackBool();
      if (boolVal != null) return boolVal;
    } catch (e) {
      // Not a bool, continue
    }
    
    // Try null (check first byte for 0xc0)
    try {
      // Null is encoded as 0xc0 in MessagePack
      // We can't peek, so we'll let other methods handle it
      // If all other types fail, it might be null or an error
    } catch (e) {
      // Continue
    }
    
    // If all fail, return null
    return null;
  }

  /// Decode WebSocket message (handles both JSON and binary)
  /// Returns decoded data or null if both formats fail
  static dynamic decodeWebSocketMessage(dynamic message) {
    // Check if message is binary (MessagePack)
    if (isBinaryMessage(message)) {
      final binaryData = message is Uint8List 
          ? message 
          : Uint8List.fromList(message as List<int>);
      
      final decoded = decodeBinary(binaryData);
      if (decoded != null) {
        return decoded;
      }
      // If binary decoding fails, return null (caller should handle)
      print('⚠️ MessagePack: Binary decode failed, message might be corrupted');
      return null;
    }
    
    // Message is JSON string - return as-is for JSON parsing
    return message;
  }

  /// Get message format type for debugging
  static String getMessageFormat(dynamic message) {
    if (isBinaryMessage(message)) {
      return 'binary (MessagePack)';
    } else if (message is String) {
      return 'JSON';
    } else {
      return 'unknown';
    }
  }

  /// Get message size for performance monitoring
  static Map<String, dynamic> getMessageSize(dynamic message) {
    if (isBinaryMessage(message)) {
      final binaryData = message is Uint8List 
          ? message 
          : Uint8List.fromList(message as List<int>);
      return {
        'format': 'binary',
        'size': binaryData.length,
        'sizeKB': (binaryData.length / 1024).toStringAsFixed(2),
      };
    } else if (message is String) {
      final utf8Bytes = message.codeUnits.length * 2; // Approximate
      return {
        'format': 'JSON',
        'size': utf8Bytes,
        'sizeKB': (utf8Bytes / 1024).toStringAsFixed(2),
      };
    }
    return {'format': 'unknown', 'size': 0, 'sizeKB': '0.00'};
  }
}

