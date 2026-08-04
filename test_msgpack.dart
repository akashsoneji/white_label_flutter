import 'dart:typed_data';
import 'package:messagepack/messagepack.dart';
import 'lib/utils/message_pack_decoder.dart';

void main() {
  final packer = Packer();
  packer.packListLength(3);
  packer.packString("hello");
  packer.packDouble(42.5);
  packer.packInt(10);
  final bytes = packer.takeBytes();
  
  print("Bytes: $bytes");
  final decoded = MessagePackDecoder.decodeBinary(bytes);
  print("Decoded: $decoded");
}
