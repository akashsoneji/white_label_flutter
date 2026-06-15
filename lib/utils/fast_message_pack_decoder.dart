// lib/utils/fast_message_pack_decoder.dart
//
// High-performance MessagePack decoder optimized for trade engine price streams.
// Trade engine sends mostly: [tag, [[symbol, bid, ask, ...], [symbol, bid, ask, ...]]]
// This decoder peeks at the first byte to dispatch the right type, avoiding
// the slow try-catch chain of the generic Unpacker.

import 'dart:typed_data';
import 'dart:convert';

class FastMessagePackDecoder {
  // MessagePack format prefixes (https://github.com/msgpack/msgpack/blob/master/spec.md)
  static const int _mpNil = 0xc0;
  static const int _mpFalse = 0xc2;
  static const int _mpTrue = 0xc3;
  static const int _mpBin8 = 0xc4;
  static const int _mpBin16 = 0xc5;
  static const int _mpBin32 = 0xc6;
  static const int _mpFloat = 0xca;
  static const int _mpDouble = 0xcb;
  static const int _mpUint8 = 0xcc;
  static const int _mpUint16 = 0xcd;
  static const int _mpUint32 = 0xce;
  static const int _mpUint64 = 0xcf;
  static const int _mpInt8 = 0xd0;
  static const int _mpInt16 = 0xd1;
  static const int _mpInt32 = 0xd2;
  static const int _mpInt64 = 0xd3;
  static const int _mpStr8 = 0xd9;
  static const int _mpStr16 = 0xda;
  static const int _mpStr32 = 0xdb;
  static const int _mpArray16 = 0xdc;
  static const int _mpArray32 = 0xdd;
  static const int _mpMap16 = 0xde;
  static const int _mpMap32 = 0xdf;

  // Positive fixint (0x00 - 0x7f) → 0..127
  // Negative fixint (0xe0 - 0xff) → -32..-1
  // Fixmap (0x80 - 0x8f)
  // Fixarray (0x90 - 0x9f)
  // Fixstr (0xa0 - 0xbf)

  /// Decode binary MessagePack to Dart object. Returns null on failure.
  /// Optimized: dispatches on first byte to avoid try-catch chains.
  static dynamic decode(Uint8List data) {
    if (data.isEmpty) return null;
    try {
      final view = ByteData.sublistView(data);
      final reader = _MsgPackReader(data, view, 0);
      return _unpack(reader);
    } catch (_) {
      return null;
    }
  }

  /// Check if data looks like binary MessagePack (vs UTF-8 JSON)
  static bool isBinary(Uint8List data) {
    if (data.isEmpty) return false;
    // JSON always starts with {, [, ", or a digit/signed digit
    // MessagePack commonly starts with array tag (0x90-0x9f or 0xdc-0xdd)
    // or a primitive tag
    final first = data[0];
    // Strong MessagePack signals: array tags
    if (first >= 0x90 && first <= 0x9f) return true; // fixarray
    if (first == 0xdc || first == 0xdd) return true; // array16/32
    if (first == 0xde || first == 0xdf) return true; // map16/32
    if (first >= 0x80 && first <= 0x8f) return true; // fixmap
    if (first == 0xc0 || first == 0xc2 || first == 0xc3) return true; // nil/false/true
    if (first == 0xca || first == 0xcb) return true; // float/double
    if (first == 0xcc || first == 0xcd || first == 0xce || first == 0xcf) return true;
    if (first == 0xd0 || first == 0xd1 || first == 0xd2 || first == 0xd3) return true;
    if (first == 0xd9 || first == 0xda || first == 0xdb) return true; // str8/16/32
    return false;
  }

  static dynamic _unpack(_MsgPackReader r) {
    if (r.isAtEnd) return null;
    final b = r.readByte();

    // Positive fixint (0..127)
    if (b <= 0x7f) return b;
    // Negative fixint (-32..-1)
    if (b >= 0xe0) return b - 0x100;

    // Fixstr (0xa0-0xbf) — length 0..31
    if (b >= 0xa0 && b <= 0xbf) {
      final len = b & 0x1f;
      return r.readUtf8(len);
    }
    // Fixarray (0x90-0x9f) — length 0..15
    if (b >= 0x90 && b <= 0x9f) {
      final len = b & 0x0f;
      return _readList(r, len);
    }
    // Fixmap (0x80-0x8f) — length 0..15
    if (b >= 0x80 && b <= 0x8f) {
      final len = b & 0x0f;
      return _readMap(r, len);
    }

    switch (b) {
      case _mpNil:
        return null;
      case _mpFalse:
        return false;
      case _mpTrue:
        return true;
      case _mpFloat:
        return r.readFloat32();
      case _mpDouble:
        return r.readFloat64();
      case _mpUint8:
        return r.readUint8();
      case _mpUint16:
        return r.readUint16();
      case _mpUint32:
        return r.readUint32();
      case _mpUint64:
        return r.readUint64();
      case _mpInt8:
        return r.readInt8();
      case _mpInt16:
        return r.readInt16();
      case _mpInt32:
        return r.readInt32();
      case _mpInt64:
        return r.readInt64();
      case _mpStr8:
        return r.readUtf8(r.readUint8());
      case _mpStr16:
        return r.readUtf8(r.readUint16());
      case _mpStr32:
        return r.readUtf8(r.readUint32());
      case _mpBin8:
        return r.readBytes(r.readUint8());
      case _mpBin16:
        return r.readBytes(r.readUint16());
      case _mpBin32:
        return r.readBytes(r.readUint32());
      case _mpArray16:
        return _readList(r, r.readUint16());
      case _mpArray32:
        return _readList(r, r.readUint32());
      case _mpMap16:
        return _readMap(r, r.readUint16());
      case _mpMap32:
        return _readMap(r, r.readUint32());
      default:
        return null;
    }
  }

  static List<dynamic> _readList(_MsgPackReader r, int length) {
    final list = List<dynamic>.filled(length, null, growable: false);
    for (int i = 0; i < length; i++) {
      list[i] = _unpack(r);
    }
    return list;
  }

  static Map<String, dynamic> _readMap(_MsgPackReader r, int length) {
    final map = <String, dynamic>{};
    for (int i = 0; i < length; i++) {
      final key = _unpack(r);
      final value = _unpack(r);
      map[key?.toString() ?? ''] = value;
    }
    return map;
  }
}

class _MsgPackReader {
  final Uint8List _bytes;
  final ByteData _view;
  int _pos;

  _MsgPackReader(this._bytes, this._view, this._pos);

  bool get isAtEnd => _pos >= _bytes.length;

  int readByte() => _bytes[_pos++];

  int readUint8() => _view.getUint8(_pos++);

  int readUint16() {
    final v = _view.getUint16(_pos);
    _pos += 2;
    return v;
  }

  int readUint32() {
    final v = _view.getUint32(_pos);
    _pos += 4;
    return v;
  }

  int readUint64() {
    final lo = _view.getUint32(_pos);
    final hi = _view.getUint32(_pos + 4);
    _pos += 8;
    return hi == 0 ? lo : lo | (hi << 32);
  }

  int readInt8() {
    final v = _view.getInt8(_pos);
    _pos += 1;
    return v;
  }

  int readInt16() {
    final v = _view.getInt16(_pos);
    _pos += 2;
    return v;
  }

  int readInt32() {
    final v = _view.getInt32(_pos);
    _pos += 4;
    return v;
  }

  int readInt64() {
    final v = _view.getInt64(_pos);
    _pos += 8;
    return v;
  }

  double readFloat32() {
    final v = _view.getFloat32(_pos);
    _pos += 4;
    return v;
  }

  double readFloat64() {
    final v = _view.getFloat64(_pos);
    _pos += 8;
    return v;
  }

  String readUtf8(int length) {
    final start = _pos;
    _pos += length;
    return utf8.decode(_bytes.sublist(start, start + length), allowMalformed: true);
  }

  Uint8List readBytes(int length) {
    final start = _pos;
    _pos += length;
    return _bytes.sublist(start, start + length);
  }
}
