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

  test('$SentryAttribute string array to json', () {
    final attribute = SentryAttribute.stringArray(['a', 'b']);
    expect(attribute.toJson(), {
      'value': ['a', 'b'],
      'type': 'array',
    });
  });

  test('$SentryAttribute int array to json', () {
    final attribute = SentryAttribute.intArray([1, 2]);
    expect(attribute.toJson(), {
      'value': [1, 2],
      'type': 'array',
    });
  });

  test('$SentryAttribute double array to json', () {
    final attribute = SentryAttribute.doubleArray([1.0, 2.0]);
    expect(attribute.toJson(), {
      'value': [1.0, 2.0],
      'type': 'array',
    });
  });

  test('$SentryAttribute bool array to json', () {
    final attribute = SentryAttribute.boolArray([true, false]);
    expect(attribute.toJson(), {
      'value': [true, false],
      'type': 'array',
    });
  });

  test('$SentryAttribute empty array to json', () {
    final attribute = SentryAttribute.stringArray([]);
    expect(attribute.toJson(), {
      'value': <String>[],
      'type': 'array',
    });
  });
}
