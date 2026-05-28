import 'dart:convert';
import 'dart:typed_data';

final class ProtobufWriter {
  final List<int> _buffer = [];

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

  void writeInt32(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  void writeInt64(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  void writeUint32(int field, int value) {
    _writeField(field, _varint);
    writeVarint(value);
  }

  void writeFixed64(int field, int value) {
    _writeField(field, _i64);
    _writeFixed64Raw(value);
  }

  void writeDouble(int field, double value) {
    _writeField(field, _i64);
    final bytes = ByteData(8)..setFloat64(0, value, Endian.little);
    for (var i = 0; i < 8; i++) {
      _buffer.add(bytes.getUint8(i));
    }
  }

  void writeBool(int field, bool value) {
    _writeField(field, _varint);
    _buffer.add(value ? 1 : 0);
  }

  void writeString(int field, String value) {
    final bytes = utf8.encode(value);
    _writeField(field, _lengthDelimited);
    writeVarint(bytes.length);
    _buffer.addAll(bytes);
  }

  void writeBytes(int field, List<int> bytes) {
    _writeField(field, _lengthDelimited);
    writeVarint(bytes.length);
    _buffer.addAll(bytes);
  }

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

  Uint8List toBytes() => Uint8List.fromList(_buffer);
}
