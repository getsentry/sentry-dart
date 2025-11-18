import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('$SentryLog to json', () {
    final timestamp = DateTime.now();
    final traceId = SentryId.newId();

    final logItem = SentryLog(
      timestamp: timestamp,
      traceId: traceId,
      level: SentryLogLevel.info,
      body: 'fixture-body',
      attributes: {
        'test': SentryAttribute.string('fixture-test'),
        'test2': SentryAttribute.bool(true),
        'test3': SentryAttribute.int(9001),
        'test4': SentryAttribute.double(9000.1),
        'test5': SentryAttribute.intArr([1, 2, 3]),
        'test6': SentryAttribute.doubleArr([1.1, 2.2, 3.3]),
        'test7': SentryAttribute.stringArr(['a', 'b', 'c']),
        'test8': SentryAttribute.int(12, unit: SentryUnit.count),
      },
      severityNumber: 1,
    );

    final json = logItem.toJson();

    expect(json, {
      'timestamp': timestamp.toIso8601String(),
      'trace_id': traceId.toString(),
      'level': 'info',
      'body': 'fixture-body',
      'attributes': {
        'test': {
          'value': 'fixture-test',
          'type': 'string',
        },
        'test2': {
          'value': true,
          'type': 'boolean',
        },
        'test3': {
          'value': 9001,
          'type': 'integer',
        },
        'test4': {
          'value': 9000.1,
          'type': 'double',
        },
        'test5': {
          'value': [1, 2, 3],
          'type': 'integer[]',
        },
        'test6': {
          'value': [1.1, 2.2, 3.3],
          'type': 'double[]',
        },
        'test7': {
          'value': ['a', 'b', 'c'],
          'type': 'string[]',
        },
        'test8': {
          'value': 12,
          'type': 'integer',
          'unit': 'count',
        },
      },
      'severity_number': 1,
    });
  });

  test('$SentryLevel without severity number infers from level in toJson', () {
    final logItem = SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.trace,
      body: 'fixture-body',
      attributes: {
        'test': SentryAttribute.string('fixture-test'),
      },
    );

    var json = logItem.toJson();
    expect(json['severity_number'], 1);

    logItem.level = SentryLogLevel.debug;
    json = logItem.toJson();
    expect(json['severity_number'], 5);

    logItem.level = SentryLogLevel.info;
    json = logItem.toJson();
    expect(json['severity_number'], 9);

    logItem.level = SentryLogLevel.warn;
    json = logItem.toJson();
    expect(json['severity_number'], 13);

    logItem.level = SentryLogLevel.error;
    json = logItem.toJson();
    expect(json['severity_number'], 17);

    logItem.level = SentryLogLevel.fatal;
    json = logItem.toJson();
    expect(json['severity_number'], 21);
  });
}
