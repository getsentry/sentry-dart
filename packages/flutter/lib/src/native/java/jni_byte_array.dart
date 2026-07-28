import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

/// Builds a [JByteArray] from Dart [bytes]. JNIgen 1.0.0 dropped the
/// `JByteArray.from` factory in favour of allocate-then-fill.
@internal
JByteArray toJByteArray(List<int> bytes) =>
    JByteArray(bytes.length)..setRange(0, bytes.length, bytes);
