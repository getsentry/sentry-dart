import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('$SentryLogItem to json', () {
    final timestamp = DateTime.now();
    final traceId = SentryId.newId();

    final logItem = SentryLogItem(
      timestamp: timestamp,
      traceId: traceId,
      level: SentryLogLevel.info,
      body: 'fixture-body',
      attributes: {
        'test': SentryLogAttribute.string('fixture-test'),
        'test2': SentryLogAttribute.boolean(true),
        'test3': SentryLogAttribute.integer(9001),
        'test4': SentryLogAttribute.double(9000.1),
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
      },
      'severity_number': 1,
    });
  });
}
