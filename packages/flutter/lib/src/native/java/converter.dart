import 'package:jni/jni.dart';

/// Converts a JNI `JObject` wrapper to a Dart object.
///
/// Supported mappings:
/// - java.lang.String -> String
/// - java.lang.Boolean -> bool
/// - java.lang.Number and subclasses -> num (int/double best-effort)
/// - java.util.List -> List (recursively converted)
/// - java.util.Set -> Set (recursively converted)
/// - java.util.Map -> Map (recursively converted)
/// - java.lang.Object[] (JArray) -> List (recursively converted)
/// - java.nio.ByteBuffer (direct) -> Uint8List (shares underlying storage)
///
/// For any unrecognized type, [convertOther] is invoked.
Object? toDartObject(
  JObject? javaObject, {
  Object? Function(JObject?) convertOther = _defaultDartConverter,
}) {
  if (javaObject == null) return null;
  // Strings
  if (javaObject.isA(JString.type)) {
    return javaObject.as(JString.type, releaseOriginal: true).toDartString();
  }
  // Booleans
  if (javaObject.isA(JBoolean.type)) {
    return javaObject.as(JBoolean.type, releaseOriginal: true).booleanValue();
  }
  // Numbers
  if (javaObject.isA(JNumber.type)) {
    final number = javaObject.as(JNumber.type, releaseOriginal: true);
    // Prefer integer forms when possible.
    if (number.isA(JDouble.type) || number.isA(JFloat.type)) {
      return number.doubleValue();
    }
    if (number.isA(JInteger.type) ||
        number.isA(JLong.type) ||
        number.isA(JShort.type)) {
      return number.longValue();
    }
    return number.doubleValue();
  }
  // Collections
  if (javaObject.isA(JList.type(JObject.nullableType))) {
    final jlist = javaObject.as(
      JList.type(JObject.nullableType),
      releaseOriginal: true,
    );
    final result = <Object?>[];
    for (final item in jlist) {
      result.add(
        item == null ? null : toDartObject(item, convertOther: convertOther),
      );
    }
    return result;
  }
  if (javaObject.isA(JSet.type(JObject.nullableType))) {
    final jset = javaObject.as(
      JSet.type(JObject.nullableType),
      releaseOriginal: true,
    );
    final result = <Object?>{};
    for (final item in jset) {
      result.add(
        item == null ? null : toDartObject(item, convertOther: convertOther),
      );
    }
    return result;
  }
  if (javaObject.isA(JMap.type(JObject.nullableType, JObject.nullableType))) {
    final jmap = javaObject.as(
      JMap.type(JObject.nullableType, JObject.nullableType),
      releaseOriginal: true,
    );
    final result = <Object?, Object?>{};
    for (final key in jmap.keys) {
      // Fetch value BEFORE converting key, since converting can release `key`.
      final value = jmap[key];
      final dartKey =
          key == null ? null : toDartObject(key, convertOther: convertOther);
      final dartValue = value == null
          ? null
          : toDartObject(value, convertOther: convertOther);
      result[dartKey] = dartValue;
    }
    return result;
  }
  // Object arrays
  if (javaObject.isA(JArray.type(JObject.nullableType))) {
    final jarray = javaObject.as(
      JArray.type(JObject.nullableType),
      releaseOriginal: true,
    );
    final result = <Object?>[];
    for (final element in jarray) {
      result.add(
        element == null
            ? null
            : toDartObject(element, convertOther: convertOther),
      );
    }
    return result;
  }
  // ByteBuffer -> Uint8List
  if (javaObject.isA(JByteBuffer.type)) {
    final buffer = javaObject.as(JByteBuffer.type, releaseOriginal: true);
    return buffer.asUint8List();
  }

  return convertOther(javaObject);
}

Object? _defaultDartConverter(JObject? obj) => obj;

extension JObjectToDart on JObject? {
  Object? toDart({
    Object? Function(JObject?) convertOther = _defaultDartConverter,
  }) =>
      toDartObject(this, convertOther: convertOther);
}

extension JListToDartList<E extends JObject?> on JList<E> {
  List<Object?> toDartList({
    Object? Function(JObject?) convertOther = _defaultDartConverter,
  }) =>
      map(
        (e) => e == null ? null : toDartObject(e, convertOther: convertOther),
      ).toList();
}

extension JSetToDartSet<E extends JObject?> on JSet<E> {
  Set<Object?> toDartSet({
    Object? Function(JObject?) convertOther = _defaultDartConverter,
  }) =>
      map(
        (e) => e == null ? null : toDartObject(e, convertOther: convertOther),
      ).toSet();
}

extension JMapToDartMap<K extends JObject?, V extends JObject?> on JMap<K, V> {
  Map<Object?, Object?> toDartMap({
    Object? Function(JObject?) convertOther = _defaultDartConverter,
  }) =>
      Map.fromEntries(entries
          .map((kv) => MapEntry(toDartObject(kv.key), toDartObject(kv.value))));
}

extension JArrayToDartList<E extends JObject?> on JArray<E> {
  List<Object?> toDartList({
    Object? Function(JObject?) convertOther = _defaultDartConverter,
  }) =>
      map(
        (e) => e == null ? null : toDartObject(e, convertOther: convertOther),
      ).toList();
}
