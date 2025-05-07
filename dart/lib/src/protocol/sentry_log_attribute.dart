class SentryLogAttribute {
  final dynamic value;
  final String type;

  const SentryLogAttribute._(this.value, this.type);

  factory SentryLogAttribute.string(String value) {
    return SentryLogAttribute._(value, 'string');
  }

  factory SentryLogAttribute.boolean(bool value) {
    return SentryLogAttribute._(value, 'boolean');
  }

  factory SentryLogAttribute.integer(int value) {
    return SentryLogAttribute._(value, 'integer');
  }

  factory SentryLogAttribute.double(double value) {
    return SentryLogAttribute._(value, 'double');
  }

  // In the future the SDK will also support string[], boolean[], integer[], double[] values.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'type': type,
    };
  }
}
