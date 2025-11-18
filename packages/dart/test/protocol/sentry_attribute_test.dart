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

  test('$SentryAttribute units to json', () {
    final cases = <SentryUnit, String>{
      SentryUnit.milliseconds: 'ms',
      SentryUnit.seconds: 's',
      SentryUnit.bytes: 'bytes',
      SentryUnit.count: 'count',
      SentryUnit.percent: 'percent',
    };

    cases.forEach((unit, unitString) {
      final attribute = SentryAttribute.int(1, unit: unit);
      final json = attribute.toJson();
      expect(json, {
        'value': 1,
        'type': 'integer',
        'unit': unitString,
      });
    });
  });

  test('$SentryAttribute stringArr to json', () {
    final attribute = SentryAttribute.stringArr(['a', 'b']);
    final json = attribute.toJson();
    expect(json, {
      'value': ['a', 'b'],
      'type': 'string[]',
    });
  });

  test('$SentryAttribute stringArr with unit to json', () {
    final attribute =
        SentryAttribute.stringArr(['x', 'y'], unit: SentryUnit.count);
    final json = attribute.toJson();
    expect(json, {
      'value': ['x', 'y'],
      'type': 'string[]',
      'unit': 'count',
    });
  });

  test('$SentryAttribute intArr to json', () {
    final attribute = SentryAttribute.intArr([1, 2, 3]);
    final json = attribute.toJson();
    expect(json, {
      'value': [1, 2, 3],
      'type': 'integer[]',
    });
  });

  test('$SentryAttribute intArr with unit to json', () {
    final attribute = SentryAttribute.intArr([4, 5], unit: SentryUnit.count);
    final json = attribute.toJson();
    expect(json, {
      'value': [4, 5],
      'type': 'integer[]',
      'unit': 'count',
    });
  });

  test('$SentryAttribute doubleArr to json', () {
    final attribute = SentryAttribute.doubleArr([1.0, 2.5]);
    final json = attribute.toJson();
    expect(json, {
      'value': [1.0, 2.5],
      'type': 'double[]',
    });
  });

  test('$SentryAttribute doubleArr with unit to json', () {
    final attribute =
        SentryAttribute.doubleArr([0.1, 0.2], unit: SentryUnit.seconds);
    final json = attribute.toJson();
    expect(json, {
      'value': [0.1, 0.2],
      'type': 'double[]',
      'unit': 's',
    });
  });

  test('$SentryAttribute unit set after construction to json', () {
    final attribute = SentryAttribute.double(2.5);
    final jsonWithoutUnit = attribute.toJson();
    expect(jsonWithoutUnit, {
      'value': 2.5,
      'type': 'double',
    });

    attribute.unit = SentryUnit.bytes;
    final jsonWithUnit = attribute.toJson();
    expect(jsonWithUnit, {
      'value': 2.5,
      'type': 'double',
      'unit': 'bytes',
    });
  });

  test('$SentryUnit asString correctly maps', () {
    final strings = SentryUnit.values.map((e) => e.asString);
    expect(strings, ['ms', 's', 'bytes', 'count', 'percent']);
  });
}
