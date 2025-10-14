import 'package:jni/jni.dart';

Object? _defaultJniToDartConverter(JObject? o) => o;

extension JMapToDartMap<$K extends JObject?, $V extends JObject?>
    on JMap<$K, $V> {
  Map<Object?, Object?> toDartMap({
    Object? Function(JObject?) convertOther = _defaultJniToDartConverter,
  }) {
    return Map<Object?, Object?>.fromEntries(
      keys.map((k) {
        final v = this[k];
        return MapEntry<Object?, Object?>(
          convertOther(k),
          v == null ? null : convertOther(v),
        );
      }),
    );
  }
}
