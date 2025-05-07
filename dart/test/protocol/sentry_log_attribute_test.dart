import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('$SentryLogAttribute string to json', () {
    final attribute = SentryLogAttribute.string('test');
    final json = attribute.toJson();
    expect(json, {
      'value': 'test',
      'type': 'string',
    });
  });

  test('$SentryLogAttribute boolean to json', () {
    final attribute = SentryLogAttribute.bool(true);
    final json = attribute.toJson();
    expect(json, {
      'value': true,
      'type': 'boolean',
    });
  });

  test('$SentryLogAttribute integer to json', () {
    final attribute = SentryLogAttribute.int(1);
    final json = attribute.toJson();

    expect(json, {
      'value': 1,
      'type': 'integer',
    });
  });

  test('$SentryLogAttribute double to json', () {
    final attribute = SentryLogAttribute.double(1.0);
    final json = attribute.toJson();

    expect(json, {
      'value': 1.0,
      'type': 'double',
    });
  });
}
