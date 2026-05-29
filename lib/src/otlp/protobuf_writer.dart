import 'dart:convert';
import 'dart:typed_data';

/// A zero-allocation Protobuf-encoding writer for the OTLP wire format.
///
/// Produces binary encoded messages using standard Protobuf field encoding:
/// varint-packed field tags, length-delimited strings/bytes/sub-messages, and
/// fixed-width 64-bit values (used for doubles and fixed64).
///
/// Wire format: [Protocol Buffers](https://protobuf.dev/programming-guides/encoding/)
final class ProtobufWriter {
  final List<int> _buffer = [];

  /// Encodes a variable-length unsigned integer.
  ///
  /// Uses the standard Protobuf varint encoding where the MSB of each byte
  /// indicates whether more bytes follow.
  void writeVarint(int value) {
    var v = value;
    while (v > 127) {
      _buffer.add((v & 0x7F) | 0x80);
      v = v >> 7;
    }
    _buffer.add(v & 0x7F);
  }

  void _writeField(int fieldNumber, int wireType) {
    writeVarint((fieldNumber << 3) | wireType);
  }

  static const int _varint = 0;
  static const int _i64 = 1;
  static const int _lengthDelimited = 2;

  /// Writes a [field] as a 32-bit signed integer.
  void writeInt32(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  /// Writes a [field] as a 64-bit signed integer.
  void writeInt64(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  /// Writes a [field] as a 32-bit unsigned integer.
  void writeUint32(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  /// Writes a [field] as a 64-bit fixed-width signed integer (little-endian).
  void writeFixed64(int field, int value) {
    _writeField(field, _i64);
    _writeFixed64Raw(value);
  }

  /// Writes a [field] as a 64-bit IEEE 754 double (little-endian).
  void writeDouble(int field, double value) {
    _writeField(field, _i64);
    final bytes = ByteData(8)..setFloat64(0, value, Endian.little);
    for (var i = 0; i < 8; i++) {
      _buffer.add(bytes.getUint8(i));
    }
  }

  /// Writes a [field] as a boolean (varint-encoded 0 or 1).
  void writeBool(int field, bool value) {
    _writeField(field, _varint);
    _buffer.add(value ? 1 : 0);
  }

  /// Writes a [field] as a UTF-8 encoded string.
  void writeString(int field, String value) {
    final bytes = utf8.encode(value);
    _writeField(field, _lengthDelimited);
    writeVarint(bytes.length);
    _buffer.addAll(bytes);
  }

  /// Writes a [field] as raw bytes.
  void writeBytes(int field, List<int> bytes) {
    _writeField(field, _lengthDelimited);
    writeVarint(bytes.length);
    _buffer.addAll(bytes);
  }

  /// Writes a [field] as a nested message.
  ///
  /// The [message] is serialized to bytes and written as a length-delimited field.
  void writeMessage(int field, ProtobufWriter message) {
    final bytes = message.toBytes();
    _writeField(field, _lengthDelimited);
    writeVarint(bytes.length);
    _buffer.addAll(bytes);
  }

  void _writeFixed64Raw(int value) {
    for (var i = 0; i < 8; i++) {
      _buffer.add((value >> (i * 8)) & 0xFF);
    }
  }

  /// Returns the accumulated Protobuf bytes.
  Uint8List toBytes() => Uint8List.fromList(_buffer);
}
