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
  final String type;
  final dynamic value;
  SentryUnit? unit;

  @internal
  SentryAttribute(this.value, this.type, {this.unit});

  factory SentryAttribute.string(String value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'string', unit: unit);
  }

  factory SentryAttribute.bool(bool value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'boolean', unit: unit);
  }

  factory SentryAttribute.int(int value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'integer', unit: unit);
  }

  factory SentryAttribute.double(double value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'double', unit: unit);
  }

  factory SentryAttribute.stringArr(List<String> value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'string[]', unit: unit);
  }

  factory SentryAttribute.intArr(List<int> value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'integer[]', unit: unit);
  }

  factory SentryAttribute.doubleArr(List<double> value, {SentryUnit? unit}) {
    return SentryAttribute(value, 'double[]', unit: unit);
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'type': type,
      if (unit != null) 'unit': unit!.asString,
    };
  }
}

enum SentryUnit { milliseconds, seconds, bytes, count, percent }

extension SentryUnitExtension on SentryUnit {
  String get asString {
    switch (this) {
      case SentryUnit.milliseconds:
        return "ms";
      case SentryUnit.seconds:
        return "s";
      case SentryUnit.bytes:
        return "bytes";
      case SentryUnit.count:
        return "count";
      case SentryUnit.percent:
        return "percent";
    }
  }
}
