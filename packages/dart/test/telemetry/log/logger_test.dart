import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/log/default_logger.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('$DefaultSentryLogger', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void verifyCaptureLog(SentryLogLevel level) {
      expect(fixture.capturedLogs.length, 1);
      final capturedLog = fixture.capturedLogs[0];

      expect(capturedLog.level, level);
      expect(capturedLog.body, 'test');
      // The attributes might have additional trace context, so check key attributes
      expect(capturedLog.attributes['string']?.value, 'string');
    }

    test('info', () {
      final logger = fixture.getSut();

      logger.info('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.info);
    });

    test('trace', () {
      final logger = fixture.getSut();

      logger.trace('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.trace);
    });

    test('debug', () {
      final logger = fixture.getSut();

      logger.debug('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.debug);
    });

    test('warn', () {
      final logger = fixture.getSut();

      logger.warn('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.warn);
    });

    test('error', () {
      final logger = fixture.getSut();

      logger.error('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.error);
    });

    test('fatal', () {
      final logger = fixture.getSut();

      logger.fatal('test', attributes: fixture.attributes);

      verifyCaptureLog(SentryLogLevel.fatal);
    });

    // This is mostly an edge case but let's cover it just in case
    test('per-log attributes override fmt template attributes on same key', () {
      final logger = fixture.getSut();

      logger.fmt.info(
        'Hello, %s!',
        ['World'],
        attributes: {
          'sentry.message.template': SentryAttribute.string('OVERRIDE'),
          'sentry.message.parameter.0': SentryAttribute.string('Earth'),
        },
      );

      final attrs = fixture.capturedLogs[0].attributes;
      expect(attrs['sentry.message.template']?.value, 'OVERRIDE');
      expect(attrs['sentry.message.parameter.0']?.value, 'Earth');
    });

    test('sets trace id from default scope propagation context', () {
      final logger = fixture.getSut();

      logger.info('test');

      expect(fixture.capturedLogs.length, 1);
      final capturedLog = fixture.capturedLogs[0];
      expect(capturedLog.traceId, fixture.scope.propagationContext.traceId);
    });

    test('sets span id when span is active on default scope', () {
      final span = _MockSpan();
      fixture.scope.span = span;

      final logger = fixture.getSut();

      logger.info('test');

      expect(fixture.capturedLogs.length, 1);
      final capturedLog = fixture.capturedLogs[0];
      expect(capturedLog.spanId, span.context.spanId);
    });

    test('sets timestamp from clock provider', () {
      final logger = fixture.getSut();

      logger.info('test');

      expect(fixture.capturedLogs.length, 1);
      final capturedLog = fixture.capturedLogs[0];
      expect(capturedLog.timestamp, fixture.timestamp);
    });

    test('includes attributes when provided', () {
      final logger = fixture.getSut();

      logger.info('test', attributes: {'key': SentryAttribute.string('value')});

      expect(fixture.capturedLogs.length, 1);
      final capturedLog = fixture.capturedLogs[0];
      expect(capturedLog.attributes['key']?.value, 'value');
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(0);
  final capturedLogs = <SentryLog>[];
  late final Scope scope;

  final attributes = <String, SentryAttribute>{
    'string': SentryAttribute.string('string'),
    'int': SentryAttribute.int(1),
    'double': SentryAttribute.double(1.23456789),
    'bool': SentryAttribute.bool(true),
    'double_int': SentryAttribute.double(1.0),
    'nan': SentryAttribute.double(double.nan),
    'positive_infinity': SentryAttribute.double(double.infinity),
    'negative_infinity': SentryAttribute.double(double.negativeInfinity),
  };

  Fixture() {
    scope = Scope(options);
  }

  SentryLogger getSut() {
    return DefaultSentryLogger(
      captureLogCallback: (log) async {
        capturedLogs.add(log);
      },
      clockProvider: () => timestamp,
      scopeProvider: () => scope,
    );
  }
}

class _MockSpan implements ISentrySpan {
  final SentrySpanContext _context = SentrySpanContext(operation: 'test');

  @override
  SentrySpanContext get context => _context;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
