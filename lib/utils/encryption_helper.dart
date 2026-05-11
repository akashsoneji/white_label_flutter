import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class EncryptionHelper {
  // Master Secret Key (32 bytes for AES-256)
  static const String _masterSecretKey =
      'base64:ydW/qyP21Vxnn1S5mUIqZl9V4vdW/v6Z7sLfZOKyOrI=';

  /// Decrypts an AES-256-CBC encrypted payload returned by the API.
  ///
  /// [encryptedBase64] — the `payload` field from the API response (Base64 string)
  /// [ivBase64]        — the `iv` field from the API response (Base64 string)
  ///
  /// Returns the decrypted JSON string, or throws on failure.
  static String decryptPayload(String encryptedBase64, String ivBase64) {
    final keyBytes = utf8.encode(_masterSecretKey).sublist(0, 32);
    final key = Key(Uint8List.fromList(keyBytes));
    final iv = IV.fromBase64(ivBase64);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);

    return decrypted;
  }

  /// Convenience method: pass the entire `data` map from the API response.
  /// Returns a decoded Map if the data was encrypted, otherwise returns it as-is.
  ///
  /// Example API response shape:
  /// ```json
  /// {
  ///   "status": true,
  ///   "message": "Success",
  ///   "data": {
  ///     "encrypted": true,
  ///     "payload": "...",
  ///     "iv": "..."
  ///   }
  /// }
  /// ```
  static Map<String, dynamic> decryptIfEncrypted(Map<String, dynamic> data) {
    final isEncrypted = data['encrypted'] == true;

    if (!isEncrypted) {
      return data; // Not encrypted — return as-is
    }

    final payload = data['payload'] as String?;
    final iv = data['iv'] as String?;

    if (payload == null || iv == null) {
      throw Exception(
        'EncryptionHelper: encrypted=true but payload/iv missing',
      );
    }

    final decryptedJson = decryptPayload(payload, iv);
    final decoded = jsonDecode(decryptedJson);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('EncryptionHelper: decrypted value is not a JSON object');
  }
}
