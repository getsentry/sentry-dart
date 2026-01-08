import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('$SentryAttribute string to json', () {
    final attribute = SentryAttribute.string('test');
    final json = attribute.toJson();
    expect(json, {
      'value': 'test',
      'type': 'string',
    });
  });

  test('$SentryAttribute bool to json', () {
    final attribute = SentryAttribute.bool(true);
    final json = attribute.toJson();
    expect(json, {
      'value': true,
      'type': 'boolean',
    });
  });

  test('$SentryAttribute int to json', () {
    final attribute = SentryAttribute.int(1);
    final json = attribute.toJson();

    expect(json, {
      'value': 1,
      'type': 'integer',
    });
  });

  test('$SentryAttribute double to json', () {
    final attribute = SentryAttribute.double(1.0);
    final json = attribute.toJson();

    expect(json, {
      'value': 1.0,
      'type': 'double',
    });
  });
}
