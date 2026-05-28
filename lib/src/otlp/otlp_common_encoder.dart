import 'package:purple_otel_api/purple_otel_api.dart';
import 'protobuf_writer.dart';

abstract final class OtlpCommonEncoder {
  static void encodeAnyValue(ProtobufWriter w, int field, AttributeValue value) {
    final inner = ProtobufWriter();
    value.map(
      string: (v) => inner.writeString(1, v),
      int: (v) => inner.writeInt64(3, v),
      double: (v) => inner.writeDouble(4, v),
      bool: (v) => inner.writeBool(2, v),
      list: (values) {
        final arr = ProtobufWriter();
        for (final v in values) {
          encodeAnyValue(arr, 1, v);
        }
        inner.writeMessage(5, arr);
      },
      bytes: (v) => inner.writeBytes(7, v),
    );
    w.writeMessage(field, inner);
  }

  static void encodeKeyValue(ProtobufWriter w, int field, String key, AttributeValue value) {
    final inner = ProtobufWriter();
    inner.writeString(1, key);
    encodeAnyValue(inner, 2, value);
    w.writeMessage(field, inner);
  }

  static void encodeResource(ProtobufWriter w, int field, Resource resource) {
    if (resource.attributes.isEmpty) return;
    final inner = ProtobufWriter();
    for (final entry in resource.attributes.entries.entries) {
      encodeKeyValue(inner, 1, entry.key, entry.value);
    }
    w.writeMessage(field, inner);
  }

  static void encodeInstrumentationScope(ProtobufWriter w, int field, InstrumentationScope scope) {
    final inner = ProtobufWriter();
    inner.writeString(1, scope.name);
    if (scope.version != null) inner.writeString(2, scope.version!);
    w.writeMessage(field, inner);
  }

  static int _nanoTime(DateTime dt) =>
      dt.microsecondsSinceEpoch * 1000;
}
