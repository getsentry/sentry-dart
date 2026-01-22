import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('$SentryLog to json', () {
    final timestamp = DateTime.now();
    final traceId = SentryId.newId();
    final spanId = SpanId.newId();

    final logItem = SentryLog(
      timestamp: timestamp,
      traceId: traceId,
      spanId: spanId,
      level: SentryLogLevel.info,
      body: 'fixture-body',
      attributes: {
        'test': SentryAttribute.string('fixture-test'),
        'test2': SentryAttribute.bool(true),
        'test3': SentryAttribute.int(9001),
        'test4': SentryAttribute.double(9000.1),
      },
      severityNumber: 1,
    );

    final json = logItem.toJson();

    expect(json, {
      'timestamp': timestamp.toIso8601String(),
      'trace_id': traceId.toString(),
      'span_id': spanId.toString(),
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
