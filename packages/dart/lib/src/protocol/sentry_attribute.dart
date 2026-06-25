import 'package:meta/meta.dart';

@Deprecated('Use SentryAttribute instead')
class SentryLogAttribute extends SentryAttribute {
  SentryLogAttribute._(super.value, super.type);

  factory SentryLogAttribute.string(String value) {
    return SentryLogAttribute._(value, 'string');
  }

  factory SentryLogAttribute.bool(bool value) {
    return SentryLogAttribute._(value, 'boolean');
  }

  factory SentryLogAttribute.int(int value) {
    return SentryLogAttribute._(value, 'integer');
  }

  factory SentryLogAttribute.double(double value) {
    return SentryLogAttribute._(value, 'double');
  }
}

class SentryAttribute {
  @internal
  final String type;
  final dynamic value;

  @internal
  SentryAttribute(this.value, this.type);

  factory SentryAttribute.string(String value) {
    return SentryAttribute(value, 'string');
  }

  factory SentryAttribute.bool(bool value) {
    return SentryAttribute(value, 'boolean');
  }

  factory SentryAttribute.int(int value) {
    return SentryAttribute(value, 'integer');
  }

  factory SentryAttribute.double(double value) {
    return SentryAttribute(value, 'double');
  }

  factory SentryAttribute.stringArray(List<String> value) {
    return SentryAttribute(List<String>.unmodifiable(value), 'array');
  }

  factory SentryAttribute.boolArray(List<bool> value) {
    return SentryAttribute(List<bool>.unmodifiable(value), 'array');
  }

  factory SentryAttribute.intArray(List<int> value) {
    return SentryAttribute(List<int>.unmodifiable(value), 'array');
  }

  factory SentryAttribute.doubleArray(List<double> value) {
    return SentryAttribute(List<double>.unmodifiable(value), 'array');
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'type': type,
    };
  }
}
