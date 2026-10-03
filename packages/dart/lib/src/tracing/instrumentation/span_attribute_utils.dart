import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

const synchronousAttributeKey = 'sync';

SentryAttribute? sentryAttributeFromValue(dynamic value) {
  if (value is String) {
    return SentryAttribute.string(value);
  } else if (value is int) {
    return SentryAttribute.int(value);
  } else if (value is double) {
    return SentryAttribute.double(value);
  } else if (value is bool) {
    return SentryAttribute.bool(value);
  } else if (value is List<String>) {
    return SentryAttribute.stringArray(value);
  } else if (value is List<int>) {
    return SentryAttribute.intArray(value);
  } else if (value is List<double>) {
    return SentryAttribute.doubleArray(value);
  } else if (value is List<bool>) {
    return SentryAttribute.boolArray(value);
  } else if (value is SentryAttribute) {
    return value;
  }
  internalLogger.info(
    'StreamingInstrumentationSpan: Unsupported data type in setData: $value',
  );
  return null;
}
