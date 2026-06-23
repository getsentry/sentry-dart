import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';

/// Builds a [JByteArray] from Dart [bytes]. JNIgen 1.0.0 dropped the
/// `JByteArray.from` factory in favour of allocate-then-fill.
@internal
JByteArray toJByteArray(List<int> bytes) =>
    JByteArray(bytes.length)..setRange(0, bytes.length, bytes);

/// Normalizes [value], encodes it as UTF-8 JSON and wraps it in a [JByteArray].
@internal
JByteArray jsonToJByteArray(Object? value) =>
    toJByteArray(encodeUtf8Json(normalize(value)));
